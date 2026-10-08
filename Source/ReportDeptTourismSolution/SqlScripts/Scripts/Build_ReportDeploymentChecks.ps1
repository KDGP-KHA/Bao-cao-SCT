param(
 [Parameter(Mandatory=$true)][string]$CategoryDatabase,
 [Parameter(Mandatory=$true)][string]$ReportDatabase,
 [string]$RoleMappingPath = (Join-Path $PSScriptRoot "../../CenIT.ReportTourism.WebApp/Configs/AppSettings.config"),
 [Parameter(Mandatory=$true)][string]$PreflightPath,
 [Parameter(Mandatory=$true)][string]$VerifyPath
)
$ErrorActionPreference='Stop'
$root=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
 . (Join-Path $PSScriptRoot 'ReportDeployment.Common.ps1')
Assert-ReportDatabaseNames $CategoryDatabase $ReportDatabase
$roles=Read-ReportRoleMapping $RoleMappingPath
$roleValues=Get-ReportRoleValues $roles
function Literal([string]$value) { return "N'"+$value.Replace("'","''")+"'" }
function Retarget([string]$value) {
 if ($value -eq 'baocaosct.khanhhoa.gov.vn.cate') { return $CategoryDatabase }
 if ($value -eq 'baocaosct.khanhhoa.gov.vn') { return $ReportDatabase }
 return Convert-ReportDatabaseReferences $value $CategoryDatabase $ReportDatabase
}
$objects=@{}
$dependencies=@{}
$files=@(Get-ChildItem (Join-Path $root '2. New Report Permission') -Filter '*.sql') + @(Get-ChildItem (Join-Path $root 'Chatbot') -Filter '*.sql')
foreach ($file in $files) {
 $database=if ($file.Name -eq '01_CategoryPermissions.sql' -or $file.Name -like 'f_Chatbot*' -or $file.Name -like 'p_Cate_Chatbot*') { $CategoryDatabase } else { $ReportDatabase }
 foreach ($batch in [regex]::Split([IO.File]::ReadAllText($file.FullName),'(?im)^\s*GO\s*$')) {
  $use=[regex]::Match($batch,'(?im)^USE \[([^\]]+)\]')
  if ($use.Success) { $database=Retarget $use.Groups[1].Value }
  $definition=[regex]::Match($batch,'(?ims)^(?:ALTER|CREATE)\s+(FUNCTION|PROCEDURE)\s+dbo\.(\w+).*')
  if ($definition.Success) {
   $name=$definition.Groups[2].Value
   $canonical=[regex]::Replace((Retarget $definition.Value.Trim()),'(?i)^(ALTER|CREATE)\s+','').TrimEnd(';').TrimEnd()
   $canonical=[regex]::Replace($canonical,'(?m)[ \t]+(?=\r?$)','')
   $objects[$database+'/'+$name]=@{ database=$database; name=$name; type=$(if ($definition.Groups[1].Value -eq 'FUNCTION') {'IF'} else {'P'}); definition=$canonical }
  }
  foreach ($reference in [regex]::Matches($batch,'(?i)(?:\[(?<db>[^\]]+)\]\.)?dbo\.(?<name>\w+)')) {
   $referenceDb=if ($reference.Groups['db'].Success) { Retarget $reference.Groups['db'].Value } else { $database }
   $name=$reference.Groups['name'].Value
   $dependencies[$referenceDb+'/'+$name]=@{ database=$referenceDb; name=$name }
  }
 }
}
# Existing operational procedures are required by the application's import workflow.
# Export plugins are separate features, not dependencies of this SQL release.
foreach ($name in @('p_Report_DataImports_ImportDatas','p_Report_DataImports_Delete','p_Report_DataImports_CheckDataImport','p_Report_DataImports_Get','p_Report_DataImports_GetDataImport','p_Report_DataImports_GetViaEnterpriseOnMonth','p_Report_DataImports_GetForUserOnMonth')) {
 $dependencies[$ReportDatabase+'/'+$name]=@{database=$ReportDatabase;name=$name}
}
# This migration creates its one new table; the rest of the application's schema must exist.
$grantTable='Report_UserBusinessIndustryPermissions'
$dependencies.Remove($CategoryDatabase+'/'+$grantTable)
$dependencies.Remove($CategoryDatabase+'/Report_RoleMappings')
$dependencies.Remove($ReportDatabase+'/DataReport')
$dependencies.Remove($ReportDatabase+'/DataReportWithIndexLevel')
foreach ($key in $objects.Keys) { $dependencies.Remove($key) }
$indexes=@()
$indexSource=[IO.File]::ReadAllText((Join-Path $root '2. New Report Permission/04_PerformanceIndexes.sql'))
$database=$ReportDatabase
foreach ($batch in [regex]::Split($indexSource,'(?im)^\s*GO\s*$')) {
 $use=[regex]::Match($batch,'(?im)^USE \[([^\]]+)\]')
 if ($use.Success) { $database=Retarget $use.Groups[1].Value }
 foreach ($index in [regex]::Matches($batch,'(?is)CREATE NONCLUSTERED INDEX (\w+)\s+ON dbo\.(\w+)\(([^)]+)\)(?:\s+INCLUDE\(([^)]+)\))?')) {
  $keys=($index.Groups[3].Value -split ',' | ForEach-Object Trim) -join ','
  $includes=($index.Groups[4].Value -split ',' | Where-Object { $_.Trim() } | ForEach-Object Trim | Sort-Object) -join ','
  $indexes+=@{ database=$database; name=$index.Groups[1].Value; table=$index.Groups[2].Value; keys=$keys; includes=$includes }
 }
}
if (!$indexes.Count -or !$objects.Count) { throw 'Empty release object/index manifest.' }
$guard=@"
:ON ERROR EXIT
SET NOCOUNT ON;
IF DB_ID(N'$CategoryDatabase') IS NULL OR DB_ID(N'$ReportDatabase') IS NULL
 THROW 50120,'Both existing application databases are required; this is not an empty-database bootstrap.',1;
USE [$ReportDatabase];
IF EXISTS(SELECT 1 FROM sys.databases WHERE name IN(N'$CategoryDatabase',N'$ReportDatabase') AND compatibility_level<110)
 THROW 50121,'Compatibility level 110 or higher is required.',1;
"@
$preflight=New-Object 'Collections.Generic.List[string]'
$preflight.Add("-- Read-only prerequisite check. Requires visible metadata in both databases.`n"+$guard)
# Surface existing cross-database audit dependencies; never rewrite the base procedures.
$preflight.Add("SELECT o.name BaseProcedure,d.referenced_database_name ExistingDatabase,d.referenced_schema_name ExistingSchema,d.referenced_entity_name ExistingObject FROM [$ReportDatabase].sys.sql_expression_dependencies d JOIN [$ReportDatabase].sys.objects o ON o.object_id=d.referencing_id WHERE o.name IN('p_Report_DataImports_ImportDatas','p_Report_DataImports_Delete','p_Report_DataImports_CheckDataImport') AND d.referenced_database_name IS NOT NULL ORDER BY o.name,d.referenced_database_name,d.referenced_entity_name;")
$preflight.Add('DECLARE @Required TABLE(DatabaseName sysname,ObjectName sysname,ColumnName sysname NULL);')
foreach ($dependency in $dependencies.Values | Sort-Object database,name) {
 $preflight.Add('INSERT @Required VALUES('+(Literal $dependency.database)+','+(Literal $dependency.name)+',NULL);')
}
$requiredColumns=@{}
foreach ($index in $indexes) {
 foreach ($column in (($index.keys+','+$index.includes) -split ',' | Where-Object { $_ })) { $requiredColumns[$index.database+'/'+$index.table+'/'+$column]=@($index.database,$index.table,$column) }
}
foreach ($entry in @(@('Sys_Users','UserId'),@('Sys_Users','UserName'),@('Cate_BusinessIndustry','IndustryId'),@('Sys_Messages','LangCode'),@('Sys_Messages','LabelKey'),@('Sys_Messages','Message'))) {
 $requiredColumns[$CategoryDatabase+'/'+$entry[0]+'/'+$entry[1]]=@($CategoryDatabase,$entry[0],$entry[1])
}
$requiredColumns[$ReportDatabase+'/Report_ReportFiles/CreatedBy']=@($ReportDatabase,'Report_ReportFiles','CreatedBy')
foreach ($entry in $requiredColumns.Values | Sort-Object { $_ -join '/' }) {
 $preflight.Add('INSERT @Required VALUES('+(($entry | ForEach-Object { Literal $_ }) -join ',')+');')
}
$preflight.Add(@"
IF OBJECT_ID(N'[$CategoryDatabase].dbo.$grantTable','U') IS NOT NULL
 INSERT @Required VALUES(N'$CategoryDatabase',N'$grantTable',N'UserId'),(N'$CategoryDatabase',N'$grantTable',N'IndustryId'),(N'$CategoryDatabase',N'$grantTable',N'SavedBy'),(N'$CategoryDatabase',N'$grantTable',N'SavedOn');
SELECT DatabaseName,ObjectName,ColumnName,'MISSING OR METADATA NOT VISIBLE' Status FROM @Required
WHERE OBJECT_ID(QUOTENAME(DatabaseName)+'.dbo.'+QUOTENAME(ObjectName)) IS NULL
 OR (ColumnName IS NOT NULL AND COL_LENGTH(QUOTENAME(DatabaseName)+'.dbo.'+QUOTENAME(ObjectName),ColumnName) IS NULL);
IF EXISTS(SELECT 1 FROM @Required WHERE OBJECT_ID(QUOTENAME(DatabaseName)+'.dbo.'+QUOTENAME(ObjectName)) IS NULL
 OR (ColumnName IS NOT NULL AND COL_LENGTH(QUOTENAME(DatabaseName)+'.dbo.'+QUOTENAME(ObjectName),ColumnName) IS NULL))
 THROW 50123,'Required deployment dependencies are missing or inaccessible. Inspect the preceding object/column rows before deploying.',1;
IF NOT EXISTS(SELECT 1 FROM [$CategoryDatabase].sys.columns c JOIN [$CategoryDatabase].sys.tables t ON t.object_id=c.object_id
 JOIN [$CategoryDatabase].sys.schemas s ON s.schema_id=t.schema_id
 WHERE s.name='dbo' AND t.name='Sys_Messages' AND c.name='Message' AND c.system_type_id IN(99,231,239))
 THROW 50123,'Sys_Messages.Message must be a Unicode type (ntext/nvarchar/nchar).',1;
SELECT 'PASS' PreflightStatus,'Existing dependency objects and required index/label columns found; stage execution still required.' Detail;
-- Informational only: these exports are not created or called by this release.
SELECT plugin.ObjectName,CASE WHEN OBJECT_ID(N'[$ReportDatabase].dbo.'+plugin.ObjectName,N'P') IS NULL
 THEN 'NOT INSTALLED OR NOT VISIBLE (optional export)' ELSE 'INSTALLED' END AS OptionalExportStatus
FROM (VALUES(N'usp_Report_KTXH_TheoEnterprise'),(N'usp_Report_KTXH_Tong'),
 (N'usp_Report_KTXH_Type2_TheoEnterprise'),(N'usp_Report_KTXH_Type2_Tong'),
 (N'usp_Report_HoatDongXuatKhau_TheoEnterprise')) plugin(ObjectName);
"@)
$roleValidation=@"
DECLARE @RoleMap TABLE(SemanticKey varchar(80),RoleId int,ScopeMode varchar(10),IsIndustryEditorTarget bit);
INSERT @RoleMap VALUES $roleValues;
IF EXISTS(SELECT 1 FROM @RoleMap m LEFT JOIN [$CategoryDatabase].dbo.Sys_Roles r ON r.RoleId=m.RoleId WHERE r.RoleId IS NULL OR r.IsDeleted<>0)
 THROW 50124,'Configured role is missing, deleted or inaccessible.',1;
IF NOT EXISTS(SELECT 1 FROM [$CategoryDatabase].dbo.Sys_Functions WHERE Area='Report' AND Name='Dashboard' AND IsDeleted=0)
 OR NOT EXISTS(SELECT 1 FROM [$CategoryDatabase].dbo.Sys_Functions WHERE Area='Report' AND Name='Import' AND IsDeleted=0)
 OR NOT EXISTS(SELECT 1 FROM [$CategoryDatabase].dbo.Sys_Functions WHERE Area='Cate' AND Name='Enterprise' AND IsDeleted=0)
 THROW 50124,'Required reporting/registry functions are missing or deleted.',1;
-- Province mapping is eligibility only: existing function permissions still decide actual access.
IF EXISTS(SELECT 1 FROM @RoleMap m JOIN [$CategoryDatabase].dbo.Sys_Permissions p ON p.RoleId=m.RoleId
 JOIN [$CategoryDatabase].dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
 WHERE m.ScopeMode='enterprise' AND f.Area='Sys' AND f.Name='User' AND p.Action IN('Add','Edit','Delete'))
 THROW 50124,'Enterprise role has forbidden user-management permissions.',1;
IF NOT EXISTS(SELECT 1 FROM [$CategoryDatabase].dbo.Sys_Permissions p JOIN [$CategoryDatabase].dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
 JOIN @RoleMap m ON m.RoleId=p.RoleId WHERE m.SemanticKey='SystemAdministrator' AND f.Area='Sys' AND f.Name='User' AND p.Action='Edit')
 THROW 50124,'System administrator requires Sys/User/Edit.',1;
"@
$preflight.Add(@"
IF OBJECT_ID(N'[$CategoryDatabase].dbo.Report_RoleMappings','U') IS NOT NULL
 AND (COL_LENGTH(N'[$CategoryDatabase].dbo.Report_RoleMappings',N'ScopeMode') IS NULL
 OR COL_LENGTH(N'[$CategoryDatabase].dbo.Report_RoleMappings',N'IsProvince') IS NOT NULL)
 THROW 50124,'Existing release mapping schema is incompatible; review before deployment.',1;
"@)
$preflight.Add($roleValidation)
$preflight.Add(@"
IF NOT EXISTS(SELECT 1 FROM [$ReportDatabase].sys.table_types t JOIN [$ReportDatabase].sys.schemas s ON s.schema_id=t.schema_id WHERE s.name='dbo' AND t.name='DataReport')
 OR NOT EXISTS(SELECT 1 FROM [$ReportDatabase].sys.table_types t JOIN [$ReportDatabase].sys.schemas s ON s.schema_id=t.schema_id WHERE s.name='dbo' AND t.name='DataReportWithIndexLevel')
 THROW 50123,'Required existing import table types are missing.',1;
"@)
$verify=New-Object 'Collections.Generic.List[string]'
$verify.Add("-- Post-deployment metadata/text checks only; no persistent writes. Run with VIEW DEFINITION in both databases.`n"+$guard)
$verify.Add($roleValidation)
$verify.Add(@"
IF OBJECT_ID(N'[$CategoryDatabase].dbo.Report_RoleMappings','U') IS NULL
 THROW 50124,'Role mapping table missing.',1;
IF EXISTS(SELECT * FROM @RoleMap EXCEPT SELECT SemanticKey,RoleId,ScopeMode,IsIndustryEditorTarget FROM [$CategoryDatabase].dbo.Report_RoleMappings)
 OR EXISTS(SELECT SemanticKey,RoleId,ScopeMode,IsIndustryEditorTarget FROM [$CategoryDatabase].dbo.Report_RoleMappings EXCEPT SELECT * FROM @RoleMap)
 THROW 50124,'Deployed role mapping differs from application release mapping.',1;
"@)
$verify.Add('DECLARE @Issues TABLE(CheckName nvarchar(80),DatabaseName sysname,ObjectName sysname,Detail nvarchar(500));
DECLARE @Expected TABLE(DatabaseName sysname,ObjectName sysname,ObjectType varchar(2),Definition nvarchar(max));')
foreach ($object in $objects.Values | Sort-Object database,name) {
 $verify.Add('INSERT @Expected VALUES('+(Literal $object.database)+','+(Literal $object.name)+','+(Literal $object.type)+','+(Literal $object.definition)+');')
}
$verify.Add(@"
;WITH RawActual AS (
 SELECT N'$CategoryDatabase' DatabaseName,o.name COLLATE Latin1_General_100_BIN2 ObjectName,o.type COLLATE DATABASE_DEFAULT ObjectType,m.definition COLLATE Latin1_General_100_BIN2 Definition
 FROM [$CategoryDatabase].sys.objects o JOIN [$CategoryDatabase].sys.schemas s ON s.schema_id=o.schema_id LEFT JOIN [$CategoryDatabase].sys.sql_modules m ON m.object_id=o.object_id WHERE s.name='dbo'
 UNION ALL
 SELECT N'$ReportDatabase',o.name COLLATE Latin1_General_100_BIN2,o.type COLLATE DATABASE_DEFAULT,m.definition COLLATE Latin1_General_100_BIN2
 FROM [$ReportDatabase].sys.objects o JOIN [$ReportDatabase].sys.schemas s ON s.schema_id=o.schema_id LEFT JOIN [$ReportDatabase].sys.sql_modules m ON m.object_id=o.object_id WHERE s.name='dbo'
), Actual AS (
 SELECT a.DatabaseName,a.ObjectName,a.ObjectType,
 SUBSTRING(a.Definition,NULLIF(CHARINDEX(CASE WHEN a.ObjectType='IF' THEN 'FUNCTION dbo.' ELSE 'PROCEDURE dbo.' END+a.ObjectName,a.Definition),0),2147483647) Definition
 FROM RawActual a
)
INSERT @Issues SELECT 'Procedure/function',e.DatabaseName,e.ObjectName,
 CASE WHEN a.ObjectName IS NULL THEN 'Missing' WHEN a.ObjectType<>e.ObjectType THEN 'Wrong object type' WHEN a.Definition IS NULL THEN 'Definition inaccessible/encrypted' ELSE 'Installed definition differs from this generated release' END
FROM @Expected e LEFT JOIN Actual a ON a.DatabaseName=e.DatabaseName AND a.ObjectName=e.ObjectName
CROSS APPLY(SELECT REPLACE(REPLACE(REPLACE(REPLACE(a.Definition,CHAR(13),''),CHAR(10),''),CHAR(9),''),' ','') ActualText) normalized
WHERE a.ObjectName IS NULL OR a.ObjectType<>e.ObjectType OR a.Definition IS NULL OR
 CASE WHEN RIGHT(normalized.ActualText,1)=';' THEN LEFT(normalized.ActualText,LEN(normalized.ActualText)-1) ELSE normalized.ActualText END
 <>REPLACE(REPLACE(REPLACE(REPLACE(e.Definition,CHAR(13),''),CHAR(10),''),CHAR(9),''),' ','') COLLATE Latin1_General_100_BIN2;
DECLARE @Indexes TABLE(DatabaseName sysname,TableName sysname,IndexName sysname,KeyColumns nvarchar(max),IncludeColumns nvarchar(max));
"@)
foreach ($index in $indexes) {
 $verify.Add('INSERT @Indexes VALUES('+((@($index.database,$index.table,$index.name,$index.keys,$index.includes) | ForEach-Object { Literal $_ }) -join ',')+');')
}
foreach ($index in $indexes) {
 $db=$index.database; $table=$index.table
 $predicate=Get-ReportIndexCoverage $index $db
 $verify.Add("IF NOT EXISTS(SELECT 1 FROM [$db].sys.indexes i WHERE $predicate) INSERT @Issues VALUES('Index',N'$db',N'$($index.name)','Missing enabled unfiltered equivalent covering index');")
 $preflight.Add("SELECT N'$db' DatabaseName,N'$($index.name)' RequestedIndex,i.name EquivalentExistingIndex FROM [$db].sys.indexes i WHERE $predicate;")
}
$seed=[IO.File]::ReadAllText((Join-Path $root 'Scripts/Seed_Dashboard_SysMessages.sql'))
$seed+=[IO.File]::ReadAllText((Join-Path $root 'Scripts/Seed_UserIndustryPermissions_SysMessages.sql'))
$labels=[regex]::Matches($seed,"\(N'((?:Dashboard_|User_IndustryPermissions_)[^']+)', N'((?:''|[^'])*)'\)")
$verify.Add('DECLARE @Labels TABLE(LabelKey nvarchar(100),Message nvarchar(max));')
foreach ($label in $labels) { $verify.Add('INSERT @Labels VALUES('+(Literal $label.Groups[1].Value)+','+(Literal ($label.Groups[2].Value.Replace("''","'")))+');') }
$verify.Add(@"
INSERT @Issues SELECT 'Dashboard label',N'$CategoryDatabase',e.LabelKey,'Missing or duplicate label'
FROM @Labels e WHERE (SELECT COUNT(*) FROM [$CategoryDatabase].dbo.Sys_Messages m WHERE m.LangCode=N'vi-VN' AND m.LabelKey=e.LabelKey)<>1;
IF OBJECT_ID(N'[$CategoryDatabase].dbo.$grantTable','U') IS NULL
 INSERT @Issues VALUES('Grant table',N'$CategoryDatabase',N'$grantTable','Missing');
ELSE BEGIN
 INSERT @Issues SELECT 'Grant column',N'$CategoryDatabase',N'$grantTable','Missing or incompatible '+expected.Name
 FROM(VALUES('UserId',56,4),('IndustryId',56,4),('SavedBy',167,255),('SavedOn',61,8)) expected(Name,TypeId,MaxLength)
 LEFT JOIN [$CategoryDatabase].sys.columns c ON c.object_id=OBJECT_ID(N'[$CategoryDatabase].dbo.$grantTable') AND c.name=expected.Name
 WHERE c.name IS NULL OR c.system_type_id<>expected.TypeId OR c.max_length<>expected.MaxLength OR c.is_nullable<>0;
 IF NOT EXISTS(SELECT 1 FROM [$CategoryDatabase].sys.indexes i
 WHERE i.object_id=OBJECT_ID(N'[$CategoryDatabase].dbo.$grantTable') AND i.is_primary_key=1 AND i.is_disabled=0
 AND (SELECT COUNT(*) FROM [$CategoryDatabase].sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2
 AND EXISTS(SELECT 1 FROM [$CategoryDatabase].sys.index_columns ic JOIN [$CategoryDatabase].sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND c.name='UserId')
 AND EXISTS(SELECT 1 FROM [$CategoryDatabase].sys.index_columns ic JOIN [$CategoryDatabase].sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND c.name='IndustryId'))
 INSERT @Issues VALUES('Grant primary key',N'$CategoryDatabase',N'$grantTable','Expected enabled primary key (UserId,IndustryId)');
 INSERT @Issues SELECT 'Grant foreign key',N'$CategoryDatabase',N'$grantTable','Missing/disabled/untrusted relationship to '+expected.TargetTable
 FROM(VALUES('UserId','Sys_Users','UserId'),('IndustryId','Cate_BusinessIndustry','IndustryId')) expected(SourceColumn,TargetTable,TargetColumn)
 WHERE NOT EXISTS(SELECT 1 FROM [$CategoryDatabase].sys.foreign_keys fk
 JOIN [$CategoryDatabase].sys.foreign_key_columns fc ON fc.constraint_object_id=fk.object_id
 JOIN [$CategoryDatabase].sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
 JOIN [$CategoryDatabase].sys.tables rt ON rt.object_id=fc.referenced_object_id
 JOIN [$CategoryDatabase].sys.schemas rs ON rs.schema_id=rt.schema_id
 JOIN [$CategoryDatabase].sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id
 WHERE fk.parent_object_id=OBJECT_ID(N'[$CategoryDatabase].dbo.$grantTable') AND fk.is_disabled=0 AND fk.is_not_trusted=0
 AND pc.name=expected.SourceColumn AND rs.name='dbo' AND rt.name=expected.TargetTable AND rc.name=expected.TargetColumn
 AND (SELECT COUNT(*) FROM [$CategoryDatabase].sys.foreign_key_columns otherColumn WHERE otherColumn.constraint_object_id=fk.object_id)=1);
END;
SELECT * FROM @Issues ORDER BY CheckName,DatabaseName,ObjectName;
SELECT (SELECT COUNT(*) FROM @Expected) ExpectedFunctionsAndProcedures,(SELECT COUNT(*) FROM @Indexes) ExpectedIndexes,(SELECT COUNT(*) FROM @Labels) ExpectedMessageLabels,(SELECT COUNT(*) FROM @Issues) Failures;
IF EXISTS(SELECT 1 FROM @Issues) THROW 50124,'Deployment verification failed. Inspect the preceding issue rows.',1;
SELECT 'PASS' VerificationStatus,'Metadata/text match this release. Runtime permissions and HTTP acceptance still required.' Detail;
"@)
$encoding=New-Object Text.UTF8Encoding($true)
[IO.File]::WriteAllText([IO.Path]::GetFullPath($PreflightPath),($preflight -join "`r`n"),$encoding)
[IO.File]::WriteAllText([IO.Path]::GetFullPath($VerifyPath),($verify -join "`r`n"),$encoding)
Write-Output ('Generated '+$PreflightPath+' and '+$VerifyPath+'; contracts='+$objects.Count+'; indexes='+$indexes.Count+'; labels='+$labels.Count)

$inventory=[ordered]@{ categoryDatabase=$CategoryDatabase; reportDatabase=$ReportDatabase; objectCount=$objects.Count; indexCoverageCount=$indexes.Count; labelCount=$labels.Count;
 roleSettings=@($roles | Sort-Object { [int]$_.id } | ForEach-Object { [ordered]@{key=$_.key; id=[int]$_.id; scope=$_.scope; industryEditorTarget=($_.industryEditorTarget -eq 'true')} });
 tables=@([ordered]@{database=$CategoryDatabase;name='Report_UserBusinessIndustryPermissions';action='create if missing; preserve grant rows'},[ordered]@{database=$CategoryDatabase;name='Report_RoleMappings';action='create if missing; synchronize release mapping only'});
 objects=@($objects.Values | Sort-Object database,name | ForEach-Object { [ordered]@{database=$_.database; name=$_.name; type=$_.type} });
 indexes=@($indexes | ForEach-Object { [ordered]@{database=$_.database; name=$_.name; table=$_.table; keys=$_.keys; includes=$_.includes} }) }
[IO.File]::WriteAllText((Join-Path (Split-Path ([IO.Path]::GetFullPath($VerifyPath))) 'sql-object-manifest.json'),(ConvertTo-Json -InputObject $inventory -Depth 6))
