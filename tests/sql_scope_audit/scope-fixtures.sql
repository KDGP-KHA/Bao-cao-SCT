-- Run ONLY in an empty, disposable database named ScopeAuditFixture* (SQLCMD -b).
-- All fixture DDL/data are rolled back; no production connection or credentials are loaded.
:ON ERROR EXIT
IF DB_NAME() NOT LIKE N'ScopeAuditFixture%' THROW 51000,'Isolated ScopeAuditFixture database required',1;
IF EXISTS(SELECT 1 FROM sys.tables WHERE is_ms_shipped=0) THROW 51000,'Fixture database must be empty',1;
BEGIN TRANSACTION;
CREATE TABLE dbo.Sys_Users(UserId int PRIMARY KEY,UserName varchar(255),FullName nvarchar(250),Email varchar(250),IsActive bit,IsDeleted bit,IsLocked bit);
CREATE TABLE dbo.Sys_Roles(RoleId int PRIMARY KEY,Name nvarchar(100),IsDeleted bit);
CREATE TABLE dbo.Sys_UserRoles(UserId int,RoleId int);
CREATE TABLE dbo.Sys_Functions(FunctionId int,Area varchar(20),Name varchar(100),IsDeleted bit);
CREATE TABLE dbo.Sys_Permissions(RoleId int,FunctionId int,Action varchar(30));
CREATE TABLE dbo.Report_RoleMappings(SemanticKey varchar(80),RoleId int,ScopeMode varchar(10),IsIndustryEditorTarget bit);
CREATE TABLE dbo.Report_UserBusinessIndustryPermissions(UserId int,IndustryId int);
CREATE TABLE dbo.Cate_EnterprisePermissions(ForUser varchar(255),EnterpriseId int);
CREATE TABLE dbo.Cate_Enterprises(EnterpriseId int PRIMARY KEY,BusinessName nvarchar(250),TaxCode varchar(100),TypeBusiness varchar(50),IsActive bit,IsDeleted bit,IsApproved bit,WardId int,
 OwnerEnterpriseName nvarchar(250),BusinessAddress nvarchar(250),StreetName nvarchar(250),WardName nvarchar(100),DistrictName nvarchar(100),ProvinceName nvarchar(100),TypeBusinessName nvarchar(100),LegalRepresentationName nvarchar(100),LegalRepresentationPhone varchar(100),LegalRepresentationEmail varchar(100),Phone varchar(100),Website varchar(100),Email varchar(100),CreatedBy varchar(255));
CREATE TABLE dbo.Cate_BusinessEnterprise(EnterpriseId int,IndustryIds varchar(255),EconomicSectorId int);
CREATE TABLE dbo.Cate_BusinessIndustry(IndustryId int,IndustryName nvarchar(100),IsActive bit,IsDeleted bit);
CREATE TABLE dbo.Cate_Wards(WardId int,WardName nvarchar(100));
CREATE TABLE dbo.Cate_EconomicSector(EconomicSectorId int,Name nvarchar(100));
CREATE TABLE dbo.Sys_Configs(ConfigKey varchar(100),ConfigValue varchar(100),IsDeleted bit);
CREATE TABLE dbo.Report_DataImports(ReportId int,EnterpriseId int,ForMonth datetime,TypeReport int,TypeReportName nvarchar(100),IsLate bit,IsDeleted bit,CreatedBy varchar(255),CreatedDate datetime,Code varchar(20),Targets nvarchar(100),Unit nvarchar(20),PerformPreviousPeriod float,PerformInPeriod float,AccumulatedBeginingOfYear float,[Index] int,[Level] varchar(10),ComparedSamePeriodLastYear float);
CREATE TABLE dbo.Report_ReportFiles(EnterpriseId int,ForMonth datetime,IsDeleted bit,CreatedBy varchar(255));
CREATE TABLE dbo.Report_ExtendInfos(ForMonth datetime);
GO
-- Fixture-only CSV helper; deployed dbo.fnSplit must separately pass production-collation checks.
CREATE FUNCTION dbo.fnSplit(@s varchar(max),@sep char(1)) RETURNS @t TABLE(Name varchar(max)) AS BEGIN
 DECLARE @p int; WHILE LEN(ISNULL(@s,''))>0 BEGIN SET @p=CHARINDEX(@sep,@s); IF @p=0 SET @p=LEN(@s)+1; INSERT @t VALUES(SUBSTRING(@s,1,@p-1));SET @s=SUBSTRING(@s,@p+1,LEN(@s)); END; RETURN; END;
GO
CREATE FUNCTION dbo.f_Report_IndustryUserScope(@UserName varchar(255))
RETURNS TABLE AS RETURN (
 SELECT flags.*,
 CONVERT(bit,CASE WHEN HasFullAccess=0 THEN HasIndustryGrants ELSE 0 END) IsIndustryRestricted,
 CONVERT(bit,CASE WHEN HasFullAccess=1 THEN 0 ELSE 1 END) IsRestricted,
 CONVERT(bit,HasFullAccess) CanReadProvince
 FROM (
 SELECT u.UserId,u.UserName,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Report_UserBusinessIndustryPermissions p WHERE p.UserId=u.UserId) THEN 1 ELSE 0 END) HasIndustryGrants,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Cate_EnterprisePermissions p WHERE p.ForUser=u.UserName) THEN 1 ELSE 0 END) HasExplicitAssignments,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Report_RoleMappings m ON m.RoleId=r.RoleId WHERE ur.UserId=u.UserId AND m.ScopeMode='all') THEN 1 ELSE 0 END) HasFullAccess,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Report_RoleMappings m ON m.RoleId=r.RoleId WHERE ur.UserId=u.UserId AND m.ScopeMode='industry') THEN 1 ELSE 0 END) HasIndustryRole,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Report_RoleMappings m ON m.RoleId=r.RoleId WHERE ur.UserId=u.UserId AND m.ScopeMode='enterprise') THEN 1 ELSE 0 END) HasEnterpriseRole
 FROM dbo.Sys_Users u WHERE u.UserName=@UserName AND u.IsActive=1 AND u.IsDeleted=0 AND ISNULL(u.IsLocked,0)=0
 AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings WHERE SemanticKey='SystemAdministrator' AND ScopeMode='all')
 AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings WHERE SemanticKey='Enterprise' AND ScopeMode='enterprise')
 AND NOT EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m LEFT JOIN dbo.Sys_Roles r ON r.RoleId=m.RoleId WHERE r.RoleId IS NULL OR r.IsDeleted<>0)
 ) flags
);
GO
CREATE FUNCTION dbo.f_Report_IndustryEnterprises(@UserName varchar(255))
RETURNS TABLE AS RETURN (
 SELECT e.* FROM dbo.Cate_Enterprises e CROSS JOIN dbo.f_Report_IndustryUserScope(@UserName) u
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND (u.HasFullAccess=1
 OR (u.HasIndustryRole=1 AND u.HasIndustryGrants=1)
 OR ((u.HasIndustryRole=1 OR u.HasEnterpriseRole=1) AND e.IsApproved=1 AND EXISTS(
 SELECT 1 FROM dbo.Cate_EnterprisePermissions p WHERE p.ForUser=u.UserName AND p.EnterpriseId=e.EnterpriseId)))
 -- Full scope overrides restrictions. Industry scope with grants ignores assignments;
 -- without grants, management falls back to verified assignments. Enterprise scope intersects both.
 AND (u.IsIndustryRestricted=0 OR EXISTS(
  SELECT 1 FROM dbo.Cate_BusinessEnterprise b CROSS APPLY dbo.fnSplit(b.IndustryIds,',') token
  JOIN dbo.Report_UserBusinessIndustryPermissions p ON p.UserId=u.UserId AND p.IndustryId=TRY_CONVERT(int,LTRIM(RTRIM(token.Name)))
  WHERE b.EnterpriseId=e.EnterpriseId))
);
GO
CREATE FUNCTION dbo.f_Chatbot_UserScope(@UserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500))
RETURNS TABLE AS RETURN (
SELECT Flags.*,
 CAST(CASE WHEN HasFullAccess=1 OR HasIndustryRole=1 THEN 1 ELSE 0 END AS bit) HasProvinceRole,
 CAST(CASE WHEN (HasFullAccess=1 OR HasEnterpriseRole=0) AND EXISTS(
 SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Sys_Permissions p ON p.RoleId=ur.RoleId JOIN dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
 WHERE ur.UserId=Flags.UserId AND f.Area='Report' AND f.Name='Dashboard' AND p.Action='View') THEN 1 ELSE 0 END AS bit) CanReadDashboard,
 CAST(CASE WHEN EXISTS(
 SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Sys_Permissions p ON p.RoleId=ur.RoleId JOIN dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
 WHERE ur.UserId=Flags.UserId AND f.Area='Report' AND f.Name='Import' AND p.Action='View') THEN 1 ELSE 0 END AS bit) CanReadImports,
 CAST(CASE WHEN (HasFullAccess=1 OR HasEnterpriseRole=0) AND EXISTS(
 SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Sys_Permissions p ON p.RoleId=ur.RoleId JOIN dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
 WHERE ur.UserId=Flags.UserId AND f.Area='Cate' AND f.Name='Enterprise' AND p.Action='View') THEN 1 ELSE 0 END AS bit) CanReadRegistryDetail
 FROM dbo.Sys_Users actor CROSS APPLY dbo.f_Report_IndustryUserScope(actor.UserName) Flags
 WHERE actor.UserId=@UserId
 -- Application mapping must agree with deployed SQL; disagreement fails closed.
 AND NOT EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m WHERE
  (m.ScopeMode IN('all','industry') AND CHARINDEX(','+CONVERT(varchar(11),m.RoleId)+',',','+ISNULL(@ProvinceRoleIds,'')+',')=0)
  OR (m.ScopeMode='enterprise' AND CHARINDEX(','+CONVERT(varchar(11),m.RoleId)+',',','+ISNULL(@EnterpriseRoleIds,'')+',')=0))
 AND NOT EXISTS(SELECT 1 FROM dbo.fnSplit(@ProvinceRoleIds,',') token WHERE NOT EXISTS(
  SELECT 1 FROM dbo.Report_RoleMappings m WHERE m.ScopeMode IN('all','industry') AND m.RoleId=TRY_CONVERT(int,token.Name)))
 AND NOT EXISTS(SELECT 1 FROM dbo.fnSplit(@EnterpriseRoleIds,',') token WHERE NOT EXISTS(
  SELECT 1 FROM dbo.Report_RoleMappings m WHERE m.ScopeMode='enterprise' AND m.RoleId=TRY_CONVERT(int,token.Name)))

);
GO
CREATE FUNCTION dbo.f_Chatbot_AuthorizedEnterprises(@UserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500),@AllowProvince bit)
RETURNS TABLE AS RETURN (
 SELECT e.EnterpriseId FROM dbo.Sys_Users actor
 CROSS APPLY dbo.f_Chatbot_UserScope(@UserId,@ProvinceRoleIds,@EnterpriseRoleIds) validated
 CROSS APPLY dbo.f_Report_IndustryEnterprises(actor.UserName) e
 WHERE actor.UserId=@UserId
 AND (@AllowProvince=1 OR (e.IsApproved=1 AND EXISTS(
 SELECT 1 FROM dbo.Cate_EnterprisePermissions p WHERE p.ForUser=actor.UserName AND p.EnterpriseId=e.EnterpriseId)))
);
GO
CREATE FUNCTION dbo.f_Report_IndustryDataImports(@UserName varchar(255)) RETURNS TABLE AS RETURN (SELECT r.* FROM dbo.Report_DataImports r WHERE EXISTS(SELECT 1 FROM dbo.f_Report_IndustryEnterprises(@UserName) e WHERE e.EnterpriseId=r.EnterpriseId));
GO
CREATE FUNCTION dbo.f_Report_IndustryReportFiles(@UserName varchar(255)) RETURNS TABLE AS RETURN (SELECT r.* FROM dbo.Report_ReportFiles r WHERE EXISTS(SELECT 1 FROM dbo.f_Report_IndustryEnterprises(@UserName) e WHERE e.EnterpriseId=r.EnterpriseId));
GO
CREATE FUNCTION dbo.f_Report_IndustryExtendInfos(@UserName varchar(255)) RETURNS TABLE AS RETURN (SELECT r.* FROM dbo.Report_ExtendInfos r WHERE EXISTS(SELECT 1 FROM dbo.f_Report_IndustryUserScope(@UserName) u WHERE u.IsRestricted=0));
GO
CREATE FUNCTION dbo.f_Report_DataImportEnterprises(@UserName varchar(255)) RETURNS TABLE AS RETURN (
 SELECT e.*,CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur
 JOIN dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
 JOIN dbo.Report_RoleMappings m ON m.RoleId=ur.RoleId
 WHERE ur.UserId=u.UserId AND m.SemanticKey IN('SystemAdministrator','IndustryAdministrator')) OR EXISTS(SELECT 1 FROM dbo.Cate_EnterprisePermissions p WHERE p.ForUser=u.UserName AND p.EnterpriseId=e.EnterpriseId) THEN 1 ELSE 0 END) CanManageAllRecords
 FROM dbo.Cate_Enterprises e
 JOIN dbo.Sys_Users u ON u.UserName=@UserName
 WHERE u.IsActive=1 AND u.IsDeleted=0 AND ISNULL(u.IsLocked,0)=0
 AND EXISTS(SELECT 1 FROM dbo.Sys_UserRoles rightsRole
 JOIN dbo.Sys_Roles liveRole ON liveRole.RoleId=rightsRole.RoleId AND liveRole.IsDeleted=0
 JOIN dbo.Sys_Permissions rightsPermission ON rightsPermission.RoleId=rightsRole.RoleId
 JOIN dbo.Sys_Functions rightsFunction ON rightsFunction.FunctionId=rightsPermission.FunctionId AND rightsFunction.IsDeleted=0
 WHERE rightsRole.UserId=u.UserId AND rightsFunction.Area='Report' AND rightsFunction.Name='Import'
 AND rightsPermission.Action IN('View','Add','Edit','Delete'))
 AND NOT EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m
  LEFT JOIN dbo.Sys_Roles r ON r.RoleId=m.RoleId WHERE r.RoleId IS NULL OR r.IsDeleted<>0)
 AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings WHERE SemanticKey='SystemAdministrator')
 AND (
 EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur
 JOIN dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
 JOIN dbo.Report_RoleMappings m ON m.RoleId=ur.RoleId
 WHERE ur.UserId=u.UserId AND m.SemanticKey IN('SystemAdministrator','IndustryAdministrator'))
 OR EXISTS(SELECT 1 FROM dbo.Cate_EnterprisePermissions p WHERE p.ForUser=u.UserName AND p.EnterpriseId=e.EnterpriseId)
 OR (NOT EXISTS(SELECT 1 FROM dbo.Cate_EnterprisePermissions p WHERE p.ForUser=u.UserName)
 AND EXISTS(SELECT 1 FROM dbo.Report_DataImports r WHERE r.EnterpriseId=e.EnterpriseId AND r.CreatedBy=u.UserName AND r.IsDeleted=0))
 ));
GO
CREATE PROCEDURE dbo.p_Report_DataImports_OperationalScope @ForUser varchar(255)
AS BEGIN
 SET NOCOUNT ON;
 SELECT e.EnterpriseId,e.BusinessName,e.TaxCode,e.TypeBusiness,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Sys_Users u
 JOIN dbo.Sys_UserRoles ur ON ur.UserId=u.UserId
 JOIN dbo.Report_RoleMappings m ON m.RoleId=ur.RoleId
 WHERE u.UserName=@ForUser AND m.ScopeMode='enterprise')
 AND NOT EXISTS(SELECT 1 FROM dbo.Sys_Users u
 JOIN dbo.Sys_UserRoles ur ON ur.UserId=u.UserId
 JOIN dbo.Report_RoleMappings m ON m.RoleId=ur.RoleId
 WHERE u.UserName=@ForUser AND m.ScopeMode IN('all','industry')) THEN 1 ELSE 0 END) IsEnterpriseUser,
 STUFF((SELECT '|' + m.SemanticKey + ':' + CONVERT(varchar(11),m.RoleId) + ':' + m.ScopeMode + ':' + CONVERT(varchar(1),m.IsIndustryEditorTarget)
 FROM dbo.Report_RoleMappings m ORDER BY m.RoleId FOR XML PATH(''),TYPE).value('.','varchar(max)'),1,1,'') RoleMappingSignature,e.CanManageAllRecords
 FROM dbo.f_Report_DataImportEnterprises(@ForUser) e;
END;
GO
CREATE PROCEDURE dbo.p_Report_DataImports_CheckOwnership
 @EnterpriseId int,@ForMonth datetime,@TypeReport int,@Operation varchar(10),@UserName varchar(255)
AS BEGIN
 SET NOCOUNT ON;
 IF @Operation NOT IN('Import','Delete') THROW 50112,'Invalid operational write kind',1;
 DECLARE @Manage bit;
 SELECT @Manage=CanManageAllRecords FROM dbo.f_Report_DataImportEnterprises(@UserName) WHERE EnterpriseId=@EnterpriseId;
 SELECT CONVERT(bit,CASE WHEN @Manage=1 THEN 1
 WHEN @Manage=0 AND @ForMonth IS NOT NULL
 AND EXISTS(SELECT 1 FROM dbo.Report_DataImports r WHERE r.EnterpriseId=@EnterpriseId
  AND r.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND r.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0)
  AND (@Operation='Delete' OR @TypeReport IS NULL OR @TypeReport=0 OR r.TypeReport=@TypeReport))
 AND NOT EXISTS(SELECT 1 FROM dbo.Report_DataImports r WHERE r.EnterpriseId=@EnterpriseId
  AND r.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND r.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0)
  AND (@Operation='Delete' OR @TypeReport IS NULL OR @TypeReport=0 OR r.TypeReport=@TypeReport)
  AND (r.CreatedBy IS NULL OR r.CreatedBy<>@UserName))
 AND (@Operation='Delete' OR NOT EXISTS(SELECT 1 FROM dbo.Report_ReportFiles f WHERE f.EnterpriseId=@EnterpriseId
  AND f.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND f.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0)
  AND (f.CreatedBy IS NULL OR f.CreatedBy<>@UserName)))
 THEN 1 ELSE 0 END) CanWrite;
END;
GO
CREATE PROCEDURE dbo.p_Report_DataImports_GetDataImport_Operational

	@EnterpriseId INT,
	@ForMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY,CanManageAllRecords bit NOT NULL);
 INSERT #ReportScope SELECT EnterpriseId,CanManageAllRecords FROM dbo.f_Report_DataImportEnterprises(@IndustryUserName);




	SELECT rdi.EnterpriseId,
	       ce.BusinessName     AS EnterpriseName,
	       rdi.ForMonth,
	       rdi.TypeReport,
	       rdi.TypeReportName,
	       rdi.[Index],
	       rdi.[Level],
	       rdi.Targets,
	       rdi.Unit,
	       rdi.Code,
	       rdi.PerformPreviousPeriod,
	       rdi.PerformInPeriod,
	       rdi.AccumulatedBeginingOfYear,
	       rdi.ComparedSamePeriodLastYear,
	       su.FullName         AS CreatedBy,
	       DATEADD(
	           millisecond,
	           -DATEPART(millisecond, rdi.CreatedDate),
	           rdi.CreatedDate
	       )                   AS CreatedDate
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId WHERE scope.CanManageAllRecords=1 OR data.CreatedBy=@IndustryUserName)  AS rdi
	       INNER JOIN (SELECT enterprise.* FROM dbo.Cate_Enterprises enterprise JOIN #ReportScope scope ON scope.EnterpriseId=enterprise.EnterpriseId) AS ce
	            ON  ce.EnterpriseId = rdi.EnterpriseId
	       LEFT JOIN dbo.Sys_Users AS su
	            ON  rdi.CreatedBy = su.UserName
	WHERE  rdi.IsDeleted = 0
	       AND (@EnterpriseId IS NULL OR rdi.EnterpriseId = @EnterpriseId)
	       AND (
	               @ForMonth IS NULL
	               OR (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	           )
	ORDER BY
           rdi.[Index],
           rdi.ReportId OPTION (RECOMPILE)
END
GO
CREATE PROCEDURE dbo.p_Report_Dashboard_FilterOptions_IndustryScope @OptionKind varchar(20),@TypeReport int=NULL,
 @Search nvarchar(250)=NULL,@Page int=1,@PageSize int=50,
 @IndustryUserName varchar(255)

AS BEGIN SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,'Report scope unavailable',1;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 IF @ReportScopeRestricted=1
  INSERT #ReportScope(EnterpriseId)
  SELECT EnterpriseId FROM dbo.f_Report_IndustryEnterprises(@IndustryUserName);

IF @OptionKind NOT IN ('year','latest','ward','sector','industry','enterprise') THROW 50006,'Unsupported option kind',1;
 IF @TypeReport IS NOT NULL AND @TypeReport NOT IN (1,2,3) THROW 50001,'Unsupported report type',1;
 IF @Page<1 OR @PageSize<1 OR @PageSize>100 THROW 50004,'Invalid page',1;
 DECLARE @WardId int=NULL,@EconomicSectorId int=NULL,@IndustryId int=NULL,@EnterpriseId int=NULL;
 -- Industry options start with the small business registry, not every enterprise.
 IF @OptionKind='industry' BEGIN
 ;WITH Options AS (
 SELECT DISTINCT CONVERT(varchar(20),i.IndustryId) Value,CONVERT(nvarchar(250),i.IndustryName) Text
 FROM dbo.Cate_BusinessEnterprise b
 JOIN dbo.Cate_Enterprises e ON e.EnterpriseId=b.EnterpriseId
 JOIN dbo.Cate_BusinessIndustry i
  ON ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),i.IndustryId)+',%'
 WHERE e.IsActive=1 AND e.IsDeleted=0 AND i.IsActive=1 AND i.IsDeleted=0
 AND (@ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope a WHERE a.EnterpriseId=e.EnterpriseId))
 AND (@TypeReport IS NULL OR ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@TypeReport)+',%')
 ), Filtered AS (SELECT * FROM Options WHERE @Search IS NULL OR @Search='' OR CHARINDEX(@Search,Text)>0 OR Value=@Search),
 Ranked AS (SELECT *,ROW_NUMBER() OVER(ORDER BY Text,Value) RowNo FROM Filtered),Total AS (SELECT COUNT(*) TotalRow FROM Filtered)
 SELECT t.TotalRow,r.Value,r.Text FROM Total t OUTER APPLY
 (SELECT Value,Text FROM Ranked WHERE RowNo>CONVERT(bigint,@Page-1)*@PageSize AND RowNo<=CONVERT(bigint,@Page)*@PageSize) r OPTION (RECOMPILE);
 RETURN; END;

 ;WITH Cohort AS (
 SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N'Chưa phân loại' ELSE N'Mã địa bàn '+CONVERT(nvarchar(20),e.WardId) END) WardName,
 b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N', ' + i.IndustryName FROM dbo.Cate_BusinessIndustry i
 WHERE ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),i.IndustryId)+',%'
 ORDER BY i.IndustryId FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,''),''),N'Chưa phân ngành') IndustryName
 FROM (SELECT scope_e.* FROM dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e
 LEFT JOIN dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND (@TypeReport IS NULL OR ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@TypeReport)+',%')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@IndustryId)+',%')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
), Options AS (
 SELECT DISTINCT CONVERT(varchar(20),YEAR(r.ForMonth)) Value,CONVERT(nvarchar(250),YEAR(r.ForMonth)) Text
 FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) r WHERE @OptionKind='year' AND r.IsDeleted=0 AND (@TypeReport IS NULL OR r.TypeReport=@TypeReport)
 UNION SELECT DISTINCT CONVERT(varchar(20),YEAR(f.ForMonth)),CONVERT(nvarchar(250),YEAR(f.ForMonth)) FROM (SELECT scope_r.* FROM dbo.Report_ReportFiles scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) f WHERE @OptionKind='year' AND f.IsDeleted=0
 UNION SELECT CONVERT(varchar(20),YEAR(GETDATE())),CONVERT(nvarchar(250),YEAR(GETDATE())) WHERE @OptionKind='year'
 UNION SELECT CONVERT(varchar(20),MAX(ForMonth),23),CONVERT(nvarchar(250),MAX(ForMonth),23) FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) scope_source
 WHERE @OptionKind='latest' AND IsDeleted=0 AND TypeReport IN (1,2,3) AND ForMonth<DATEADD(month,1,DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1)) HAVING MAX(ForMonth) IS NOT NULL
 UNION SELECT DISTINCT CONVERT(varchar(20),WardId),CONVERT(nvarchar(250),WardName) FROM Cohort WHERE @OptionKind='ward' AND WardId IS NOT NULL
 UNION SELECT DISTINCT CONVERT(varchar(20),EconomicSectorId),CONVERT(nvarchar(250),EconomicSectorName) FROM Cohort WHERE @OptionKind='sector' AND EconomicSectorId IS NOT NULL
 UNION SELECT CONVERT(varchar(20),EnterpriseId),CONVERT(nvarchar(250),COALESCE(BusinessName,N'')+CASE WHEN NULLIF(TaxCode,'') IS NULL THEN N'' ELSE N' · '+TaxCode END)
 FROM Cohort WHERE @OptionKind='enterprise'
 ), Filtered AS (SELECT * FROM Options WHERE @Search IS NULL OR @Search='' OR CHARINDEX(@Search,Text)>0 OR Value=@Search),
 Ranked AS (SELECT *,ROW_NUMBER() OVER(ORDER BY CASE WHEN @OptionKind IN ('year','latest') THEN Value END DESC,Text,Value) RowNo FROM Filtered),
 Total AS (SELECT COUNT(*) TotalRow FROM Filtered)
 SELECT t.TotalRow,r.Value,r.Text FROM Total t OUTER APPLY
 (SELECT Value,Text FROM Ranked WHERE RowNo>CONVERT(bigint,@Page-1)*@PageSize AND RowNo<=CONVERT(bigint,@Page)*@PageSize) r OPTION (RECOMPILE);
END
GO
CREATE PROCEDURE dbo.p_Report_DataImports_GetForUserOnMonth_IndustryScope
	@ForUser VARCHAR(500),
	@OnMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM dbo.f_Report_IndustryEnterprises(@IndustryUserName);

 IF @ForUser<>@IndustryUserName OR @ForUser IS NULL THROW 50112,'Report subject mismatch',1;


	
	DECLARE @DayDeadlineSendReportLate INT;
	
	SELECT @DayDeadlineSendReportLate = CAST(ISNULL(sc.ConfigValue, 0) AS INT)
	FROM   dbo.Sys_Configs AS sc
	WHERE  sc.ConfigKey = 'Day_Deadline_Send_Late_Report'
	       AND sc.IsDeleted = 0

    
	SELECT rdi.EnterpriseId,
	       ce.BusinessName     AS EnterpriseName,
	       rdi.ForMonth,
	       rdi.TypeReport,
	       rdi.TypeReportName,
	       rdi.IsLate,
	       CAST(
	           CASE WHEN DAY(GETDATE()) > @DayDeadlineSendReportLate THEN 0
	                ELSE 1
	           END AS BIT
	       )                   AS CanDelete,
	       su.FullName         AS CreatedBy,
	       DATEADD(
	           millisecond,
	           -DATEPART(millisecond, rdi.CreatedDate),
	           rdi.CreatedDate
	       )                   AS CreatedDate
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	       INNER JOIN (SELECT enterprise.* FROM dbo.Cate_Enterprises enterprise JOIN #ReportScope scope ON scope.EnterpriseId=enterprise.EnterpriseId) AS ce
	            ON  ce.EnterpriseId = rdi.EnterpriseId
	       LEFT JOIN dbo.Cate_EnterprisePermissions AS cep
	            ON  cep.EnterpriseId = ce.EnterpriseId
	            AND cep.ForUser = @ForUser
	       LEFT JOIN dbo.Sys_Users AS su
	            ON  rdi.CreatedBy = su.UserName
	WHERE  rdi.IsDeleted = 0
           AND EXISTS(SELECT 1 FROM dbo.Cate_EnterprisePermissions assignment
                      WHERE assignment.ForUser=@ForUser AND assignment.EnterpriseId=rdi.EnterpriseId)
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@OnMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@OnMonth)+1,0))
	GROUP BY
	       rdi.EnterpriseId,
	       ce.BusinessName,
	       rdi.ForMonth,
	       rdi.TypeReport,
	       rdi.TypeReportName,
	       rdi.IsLate,
	       su.FullName,
	       DATEADD(
	           millisecond,
	           -DATEPART(millisecond, rdi.CreatedDate),
	           rdi.CreatedDate
	       ) OPTION (RECOMPILE)
END
GO
CREATE PROCEDURE dbo.p_Report_DataImports_GetForUserOnMonth_Operational
	@ForUser VARCHAR(500),
	@OnMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY,CanManageAllRecords bit NOT NULL);
 INSERT #ReportScope SELECT EnterpriseId,CanManageAllRecords FROM dbo.f_Report_DataImportEnterprises(@IndustryUserName);

 IF @ForUser<>@IndustryUserName OR @ForUser IS NULL THROW 50112,'Report subject mismatch',1;



	DECLARE @DayDeadlineSendReportLate INT;

	SELECT @DayDeadlineSendReportLate = CAST(ISNULL(sc.ConfigValue, 0) AS INT)
	FROM   dbo.Sys_Configs AS sc
	WHERE  sc.ConfigKey = 'Day_Deadline_Send_Late_Report'
	       AND sc.IsDeleted = 0


	SELECT rdi.EnterpriseId,
	       ce.BusinessName     AS EnterpriseName,
	       rdi.ForMonth,
	       rdi.TypeReport,
	       rdi.TypeReportName,
	       rdi.IsLate,
	       CAST(
	           CASE WHEN DAY(GETDATE()) > @DayDeadlineSendReportLate THEN 0
	                ELSE 1
	           END AS BIT
	       )                   AS CanDelete,
	       su.FullName         AS CreatedBy,
	       DATEADD(
	           millisecond,
	           -DATEPART(millisecond, rdi.CreatedDate),
	           rdi.CreatedDate
	       )                   AS CreatedDate
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId WHERE scope.CanManageAllRecords=1 OR data.CreatedBy=@IndustryUserName)  AS rdi
	       INNER JOIN (SELECT enterprise.* FROM dbo.Cate_Enterprises enterprise JOIN #ReportScope scope ON scope.EnterpriseId=enterprise.EnterpriseId) AS ce
	            ON  ce.EnterpriseId = rdi.EnterpriseId
	       LEFT JOIN dbo.Cate_EnterprisePermissions AS cep
	            ON  cep.EnterpriseId = ce.EnterpriseId
	            AND cep.ForUser = @ForUser
	       LEFT JOIN dbo.Sys_Users AS su
	            ON  rdi.CreatedBy = su.UserName
	WHERE  rdi.IsDeleted = 0
           AND EXISTS(SELECT 1 FROM dbo.Cate_EnterprisePermissions assignment
                      WHERE assignment.ForUser=@ForUser AND assignment.EnterpriseId=rdi.EnterpriseId)
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@OnMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@OnMonth)+1,0))
	GROUP BY
	       rdi.EnterpriseId,
	       ce.BusinessName,
	       rdi.ForMonth,
	       rdi.TypeReport,
	       rdi.TypeReportName,
	       rdi.IsLate,
	       su.FullName,
	       DATEADD(
	           millisecond,
	           -DATEPART(millisecond, rdi.CreatedDate),
	           rdi.CreatedDate
	       ) OPTION (RECOMPILE)
END
GO
CREATE PROCEDURE dbo.p_Report_Industry_Enterprises_SearchSelect2
 @Keyword nvarchar(250)=NULL,@TypeBusiness varchar(50)=NULL,
 @PageIndex int=0,@PageSize int=20,@IndustryUserName varchar(255)
AS
BEGIN
 SET NOCOUNT ON;
 SET @PageIndex=CASE WHEN ISNULL(@PageIndex,0)<0 THEN 0 ELSE ISNULL(@PageIndex,0) END;
 SET @PageSize=CASE WHEN ISNULL(@PageSize,20)<1 THEN 20 WHEN @PageSize>100 THEN 100 ELSE ISNULL(@PageSize,20) END;
 SET @Keyword=NULLIF(LTRIM(RTRIM(@Keyword)),N'');
 SET @TypeBusiness=NULLIF(LTRIM(RTRIM(@TypeBusiness)),'');
 ;WITH Paged AS (
  SELECT ce.EnterpriseId,ce.BusinessName,ce.TaxCode,ce.TypeBusiness,
   ROW_NUMBER() OVER(ORDER BY ce.BusinessName,ce.EnterpriseId) RowNum,COUNT(*) OVER() TotalRow
  FROM dbo.f_Report_IndustryEnterprises(@IndustryUserName) ce
  WHERE ce.IsApproved=1
   AND (@TypeBusiness IS NULL OR ','+REPLACE(ISNULL(ce.TypeBusiness,''),' ','')+',' LIKE '%,'+@TypeBusiness+',%')
   AND (@Keyword IS NULL OR ce.BusinessName LIKE N'%'+@Keyword+N'%' OR ce.TaxCode LIKE N'%'+@Keyword+N'%')
 )
 SELECT EnterpriseId,BusinessName,TaxCode,TypeBusiness,TotalRow FROM Paged
 WHERE RowNum>CONVERT(bigint,@PageIndex)*@PageSize AND RowNum<=(CONVERT(bigint,@PageIndex)+1)*@PageSize
 ORDER BY RowNum;
END
GO
CREATE PROCEDURE dbo.p_Report_DataImports_Enterprises_SearchSelect2
 @Keyword nvarchar(250)=NULL,@TypeBusiness varchar(50)=NULL,
 @PageIndex int=0,@PageSize int=20,@IndustryUserName varchar(255)
AS
BEGIN
 SET NOCOUNT ON;
 SET @PageIndex=CASE WHEN ISNULL(@PageIndex,0)<0 THEN 0 ELSE ISNULL(@PageIndex,0) END;
 SET @PageSize=CASE WHEN ISNULL(@PageSize,20)<1 THEN 20 WHEN @PageSize>100 THEN 100 ELSE ISNULL(@PageSize,20) END;
 SET @Keyword=NULLIF(LTRIM(RTRIM(@Keyword)),N'');
 SET @TypeBusiness=NULLIF(LTRIM(RTRIM(@TypeBusiness)),'');
 ;WITH Paged AS (
  SELECT ce.EnterpriseId,ce.BusinessName,ce.TaxCode,ce.TypeBusiness,
   ROW_NUMBER() OVER(ORDER BY ce.BusinessName,ce.EnterpriseId) RowNum,COUNT(*) OVER() TotalRow
  FROM dbo.f_Report_DataImportEnterprises(@IndustryUserName) ce
  WHERE ce.IsApproved=1
   AND (@TypeBusiness IS NULL OR ','+REPLACE(ISNULL(ce.TypeBusiness,''),' ','')+',' LIKE '%,'+@TypeBusiness+',%')
   AND (@Keyword IS NULL OR ce.BusinessName LIKE N'%'+@Keyword+N'%' OR ce.TaxCode LIKE N'%'+@Keyword+N'%')
 )
 SELECT EnterpriseId,BusinessName,TaxCode,TypeBusiness,TotalRow FROM Paged
 WHERE RowNum>CONVERT(bigint,@PageIndex)*@PageSize AND RowNum<=(CONVERT(bigint,@PageIndex)+1)*@PageSize
 ORDER BY RowNum;
END
GO
CREATE PROCEDURE dbo.p_Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope
	@ForMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;

    -- Submission membership is independent of the viewer; only the returned
    -- enterprise population is authorized below. Scan this period once rather
    -- than expanding the scoped import function for every enterprise.
    CREATE TABLE #SubmittedEnterprises (EnterpriseId int NOT NULL PRIMARY KEY);
    INSERT #SubmittedEnterprises(EnterpriseId)
    SELECT DISTINCT rdi.EnterpriseId
    FROM dbo.Report_DataImports rdi
    WHERE rdi.IsDeleted=0 AND rdi.EnterpriseId IS NOT NULL
      AND rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0)
      AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0);

	SELECT ce.OwnerEnterpriseName,
	       ce.BusinessName,
	       ce.TaxCode,
	       ce.BusinessAddress,
	       ce.StreetName,
	       ce.WardName,
	       ce.DistrictName,
	       ce.ProvinceName,
	       ce.TypeBusinessName,
	       ce.LegalRepresentationName,
	       ce.LegalRepresentationPhone,
	       ce.LegalRepresentationEmail,
	       ce.Phone,
	       ce.Website,
	       ce.Email
	FROM dbo.f_Report_IndustryEnterprises(@IndustryUserName) AS ce
	WHERE  NOT EXISTS (
	           SELECT 1
	           FROM #SubmittedEnterprises AS rdi
	           WHERE  rdi.EnterpriseId = ce.EnterpriseId
	       )
	       AND ce.IsDeleted = 0
	       AND ce.IsActive = 1
	ORDER BY
	       ce.OwnerEnterpriseName,
	       ce.BusinessName
END
GO
CREATE PROCEDURE dbo.p_Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope
    @ForMonth DATETIME,
    @EnterpriseId INT = NULL,
 @IndustryUserName varchar(255)

AS
BEGIN
    SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM dbo.f_Report_IndustryEnterprises(@IndustryUserName);




    ;WITH CurrentData AS
    (
        SELECT TypeReport, Code, Targets, Unit,
               SUM(ISNULL(PerformPreviousPeriod, 0)) AS PreviousMonth,
               SUM(ISNULL(PerformInPeriod, 0)) AS CurrentMonth,
               SUM(ISNULL(AccumulatedBeginingOfYear, 0)) AS CurrentAccumulated
        FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) scope_source
        WHERE IsDeleted = 0
          AND ForMonth = CAST(@ForMonth AS DATE)
          AND NULLIF(LTRIM(RTRIM(Code)), '') IS NOT NULL
          AND (@EnterpriseId IS NULL OR EnterpriseId = @EnterpriseId)
        GROUP BY TypeReport, Code, Targets, Unit
    ), PreviousYearData AS
    (
        SELECT TypeReport, Code, Targets, Unit,
               SUM(ISNULL(PerformInPeriod, 0)) AS PreviousYearMonth,
               SUM(ISNULL(AccumulatedBeginingOfYear, 0)) AS PreviousYearAccumulated
        FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) scope_source
        WHERE IsDeleted = 0
          AND ForMonth = DATEADD(YEAR, -1, CAST(@ForMonth AS DATE))
          AND NULLIF(LTRIM(RTRIM(Code)), '') IS NOT NULL
          AND (@EnterpriseId IS NULL OR EnterpriseId = @EnterpriseId)
        GROUP BY TypeReport, Code, Targets, Unit
    )
    SELECT ROW_NUMBER() OVER (ORDER BY c.TypeReport, c.Code, c.Targets) AS RowNo,
           c.Targets AS TargetName,
           c.Unit,
           CAST(NULL AS DECIMAL(18, 2)) AS YearPlan,
           CAST(ISNULL(p.PreviousYearMonth, 0) AS DECIMAL(18, 2)) AS PreviousYearMonth,
           CAST(ISNULL(p.PreviousYearAccumulated, 0) AS DECIMAL(18, 2)) AS PreviousYearAccumulated,
           CAST(c.PreviousMonth AS DECIMAL(18, 2)) AS PreviousMonth,
           CAST(c.CurrentMonth AS DECIMAL(18, 2)) AS EstimatedCurrentMonth,
           CAST(c.CurrentAccumulated AS DECIMAL(18, 2)) AS CurrentYearAccumulated,
           CAST(NULL AS DECIMAL(18, 2)) AS RateAccumulatedVsPlan,
           CAST(CASE WHEN ISNULL(p.PreviousYearAccumulated, 0) = 0 THEN NULL ELSE c.CurrentAccumulated * 100.0 / p.PreviousYearAccumulated END AS DECIMAL(18, 2)) AS RateAccumulatedVsPreviousYear,
           CAST(CASE WHEN ISNULL(p.PreviousYearMonth, 0) = 0 THEN NULL ELSE c.CurrentMonth * 100.0 / p.PreviousYearMonth END AS DECIMAL(18, 2)) AS RateCurrentMonthVsPreviousYear
    FROM CurrentData c
    LEFT JOIN PreviousYearData p ON p.TypeReport = c.TypeReport AND p.Code = c.Code
        AND p.Targets = c.Targets AND ISNULL(p.Unit, '') = ISNULL(c.Unit, '')
    ORDER BY c.TypeReport, c.Code, c.Targets OPTION (RECOMPILE);
END
GO

INSERT dbo.Sys_Roles VALUES(1,N'SpAdmin',0),(2,N'Management2',0),(3,N'Management3',0),(4,N'Management4',0),(5,N'Enterprise',0),(6,N'Management6',0);
INSERT dbo.Report_RoleMappings VALUES('SystemAdministrator',1,'all',1),('ReportingRole2',2,'industry',1),('ReportingRole3',3,'industry',1),('ReportingRole4',4,'industry',1),('Enterprise',5,'enterprise',0),('IndustryAdministrator',6,'industry',1);
INSERT dbo.Sys_Users(UserId,UserName,IsActive,IsDeleted,IsLocked) VALUES(1,'u1',1,0,0),(2,'u2',1,0,0),(3,'u3',1,0,0),(4,'u4',1,0,0),(5,'u5',1,0,0),(6,'u6',1,0,0),(7,'u7',0,0,0),(8,'u8',1,0,1),(9,'u9',1,1,0),(10,'u10',1,0,0),(11,'u11',1,0,0),(12,'u12',1,0,0),(13,'u13',1,0,0),(14,'u14',1,0,0);
INSERT dbo.Sys_UserRoles VALUES(1,1),(2,6),(3,6),(4,5),(5,5),(6,5),(6,6),(7,1),(8,1),(9,1),(10,6),(11,1),(12,2),(13,2),(14,5);
INSERT dbo.Sys_Functions VALUES(1,'Report','Dashboard',0),(2,'Report','Import',0),(3,'Cate','Enterprise',0);
INSERT dbo.Sys_Permissions VALUES(1,1,'View'),(1,2,'View'),(1,3,'View'),(6,1,'View'),(6,2,'View'),(5,2,'View'),(2,2,'Add');
INSERT dbo.Report_UserBusinessIndustryPermissions VALUES(2,10),(6,10),(10,99),(12,10);
INSERT dbo.Cate_EnterprisePermissions VALUES('u1',1),('u2',3),('u3',2),('u4',1),('u6',2),('u12',2);
INSERT dbo.Cate_Enterprises(EnterpriseId,BusinessName,TaxCode,TypeBusiness,IsActive,IsDeleted,IsApproved,WardId) VALUES(1,N'One','1','1',1,0,1,1),(2,N'Two','2','1',1,0,1,2),(3,N'Three','3','1',1,0,1,1),(4,N'Deleted','4','1',1,1,1,1),(5,N'Inactive','5','1',0,0,1,1),(6,N'Unapproved','6','1',1,0,0,1);
INSERT dbo.Cate_BusinessEnterprise VALUES(1,'10',1),(2,'20',2),(3,'10,20',1),(4,'10',1),(5,'10',1),(6,'10',1);
INSERT dbo.Cate_BusinessIndustry VALUES(10,N'Industry10',1,0),(20,N'Industry20',1,0),(99,N'EmptyIndustry',1,0);
INSERT dbo.Cate_Wards VALUES(1,N'Ward1'),(2,N'Ward2'); INSERT dbo.Cate_EconomicSector VALUES(1,N'Sector1'),(2,N'Sector2');
INSERT dbo.Sys_Configs VALUES('Day_Deadline_Send_Late_Report','31',0);
INSERT dbo.Report_DataImports(ReportId,EnterpriseId,ForMonth,TypeReport,TypeReportName,IsLate,IsDeleted,CreatedBy,CreatedDate,Code,Targets,Unit,PerformPreviousPeriod,PerformInPeriod,AccumulatedBeginingOfYear) VALUES(1,1,'20260901',1,N'Type1',0,0,'u4','20260902','A',N'A',N'VND',0,10,10),(2,1,'20260901',1,N'Type1',0,0,'u4','20260902','B',N'B',N'VND',0,5,5),(3,2,'20260901',1,N'Type1',0,0,'u3','20260902','A',N'A',N'VND',0,20,20),(4,3,'20260901',1,N'Type1',0,0,'u13','20260902','A',N'A',N'VND',0,30,30);
UPDATE dbo.Sys_Users SET FullName=N'One',Email='same@example.invalid' WHERE UserId=14;
UPDATE dbo.Cate_Enterprises SET Email='same@example.invalid' WHERE EnterpriseId=1;
DECLARE @Ownership TABLE(CanWrite bit);
INSERT @Ownership EXEC dbo.p_Report_DataImports_CheckOwnership 3,'20260901',1,'Import','u13';
IF NOT EXISTS(SELECT 1 FROM @Ownership WHERE CanWrite=1) THROW 51001,'Owned existing write incorrectly denied',1;
DELETE FROM @Ownership;
INSERT @Ownership EXEC dbo.p_Report_DataImports_CheckOwnership 3,'20261001',1,'Import','u13';
IF EXISTS(SELECT 1 FROM @Ownership WHERE CanWrite=1) THROW 51001,'Historical creator authorized unrelated new month',1;
INSERT dbo.Report_ReportFiles VALUES(3,'20260901',0,'someone-else');
DELETE FROM @Ownership;
INSERT @Ownership EXEC dbo.p_Report_DataImports_CheckOwnership 3,'20260901',1,'Import','u13';
IF EXISTS(SELECT 1 FROM @Ownership WHERE CanWrite=1) THROW 51001,'Creator overwrite of foreign report file allowed',1;
DELETE FROM dbo.Report_ReportFiles;
INSERT dbo.Report_DataImports(ReportId,EnterpriseId,ForMonth,TypeReport,TypeReportName,IsLate,IsDeleted,CreatedBy,CreatedDate,Code,Targets,Unit,PerformInPeriod) VALUES(5,3,'20260901',1,N'Type1',0,0,'u3','20260902','Z',N'Foreign',N'VND',99);
DECLARE @OwnedRows TABLE(EnterpriseId int,EnterpriseName nvarchar(250),ForMonth datetime,TypeReport int,TypeReportName nvarchar(100),[Index] int,[Level] varchar(10),Targets nvarchar(100),Unit nvarchar(20),Code varchar(20),PerformPreviousPeriod float,PerformInPeriod float,AccumulatedBeginingOfYear float,ComparedSamePeriodLastYear float,CreatedBy nvarchar(250),CreatedDate datetime);
INSERT @OwnedRows EXEC dbo.p_Report_DataImports_GetDataImport_Operational 3,'20260901','u13';
IF (SELECT COUNT(*) FROM @OwnedRows)<>1 OR EXISTS(SELECT 1 FROM @OwnedRows WHERE PerformInPeriod<>30) THROW 51001,'Creator-only read exposed another creator records',1;
DELETE FROM @Ownership;
INSERT @Ownership EXEC dbo.p_Report_DataImports_CheckOwnership 3,'20260901',1,'Import','u13';
IF EXISTS(SELECT 1 FROM @Ownership WHERE CanWrite=1) THROW 51001,'Creator update overwrites foreign target rows',1;
DELETE FROM @Ownership;
INSERT @Ownership EXEC dbo.p_Report_DataImports_CheckOwnership 3,'20260901',NULL,'Delete','u13';
IF EXISTS(SELECT 1 FROM @Ownership WHERE CanWrite=1) THROW 51001,'Creator delete removes foreign month rows',1;
DELETE FROM dbo.Report_DataImports WHERE ReportId=5;
DECLARE @Expected TABLE(UserName varchar(255),EnterpriseId int);
INSERT @Expected VALUES('u1',1),('u1',2),('u1',3),('u1',6),('u2',1),('u2',3),('u2',6),('u3',2),('u4',1),('u6',1),('u6',3),('u6',6),('u11',1),('u11',2),('u11',3),('u11',6),('u12',1),('u12',3),('u12',6);
DECLARE @OpModels TABLE(EnterpriseId int,BusinessName nvarchar(250),TaxCode varchar(100),TypeBusiness varchar(50),IsEnterpriseUser bit,RoleMappingSignature varchar(max),CanManageAllRecords bit);
INSERT @OpModels EXEC dbo.p_Report_DataImports_OperationalScope 'u6';
IF EXISTS(SELECT 1 FROM @OpModels WHERE IsEnterpriseUser<>0 OR RoleMappingSignature NOT LIKE 'SystemAdministrator:1:all:1|ReportingRole2:2:industry:1|%') THROW 51001,'Operational UI role classification or mapping signature changed',1;
DECLARE @Actual TABLE(UserName varchar(255),EnterpriseId int);
INSERT @Actual SELECT u.UserName,e.EnterpriseId FROM dbo.Sys_Users u CROSS APPLY dbo.f_Report_IndustryEnterprises(u.UserName) e;
IF EXISTS(SELECT * FROM @Actual EXCEPT SELECT * FROM @Expected) OR EXISTS(SELECT * FROM @Expected EXCEPT SELECT * FROM @Actual) THROW 51001,'R07 exact enterprise population mismatch',1;
IF EXISTS(SELECT 1 FROM dbo.f_Report_IndustryEnterprises('unknown')) THROW 51001,'Unknown user broadened',1;
IF NOT EXISTS(SELECT 1 FROM dbo.f_Report_DataImportEnterprises('u12') WHERE EnterpriseId=2) THROW 51001,'R01 operational assignment blocked by unrelated industry',1;
IF EXISTS(SELECT 1 FROM dbo.f_Report_DataImportEnterprises('u12') WHERE EnterpriseId=1) THROW 51001,'R01 unrelated enterprise allowed',1;
IF NOT EXISTS(SELECT 1 FROM dbo.f_Report_DataImportEnterprises('u13') WHERE EnterpriseId=3) THROW 51001,'Exact report creator relationship lost',1;
IF EXISTS(SELECT 1 FROM dbo.f_Report_DataImportEnterprises('u14')) THROW 51001,'Weak identity independently grants operational access',1;
IF (SELECT SUM(r.PerformInPeriod) FROM dbo.Report_DataImports r JOIN dbo.f_Report_IndustryEnterprises('u2') e ON e.EnterpriseId=r.EnterpriseId)<>45 THROW 51001,'R08 scoped total mismatch',1;
IF EXISTS(SELECT 1 FROM dbo.f_Chatbot_AuthorizedEnterprises(4,'1,2,3,4,6','5',1) WHERE EnterpriseId<>1) THROW 51001,'R05 allowProvince grants foreign enterprise',1;
IF EXISTS(SELECT 1 FROM dbo.f_Chatbot_AuthorizedEnterprises(1,'1','5',1)) THROW 51001,'R05 invalid role mapping accepted',1;
IF (SELECT COUNT(*) FROM dbo.f_Chatbot_AuthorizedEnterprises(1,'1,2,3,4,6','5',0))<>1 THROW 51001,'R05 assigned operation widened',1;
IF (SELECT COUNT(*) FROM dbo.f_Chatbot_AuthorizedEnterprises(1,'1,2,3,4,6','5',1))<>4 THROW 51001,'R05 full administrator narrowed',1;
DECLARE @Work TABLE(EnterpriseId int,EnterpriseName nvarchar(250),ForMonth datetime,TypeReport int,TypeReportName nvarchar(100),IsLate bit,CanDelete bit,CreatedBy nvarchar(250),CreatedDate datetime);
INSERT @Work EXEC dbo.p_Report_DataImports_GetForUserOnMonth_IndustryScope 'u1','20260901','u1';
IF (SELECT COUNT(*) FROM @Work)<>1 OR EXISTS(SELECT 1 FROM @Work WHERE EnterpriseId<>1) THROW 51001,'R02 admin worklist widened/duplicated',1;
DELETE FROM @Work;
INSERT @Work EXEC dbo.p_Report_DataImports_GetForUserOnMonth_Operational 'u12','20260901','u12';
IF (SELECT COUNT(*) FROM @Work)<>1 OR EXISTS(SELECT 1 FROM @Work WHERE EnterpriseId<>2) THROW 51001,'R02 operational worklist lost assigned enterprise',1;
DELETE FROM @Work;
INSERT @Work EXEC dbo.p_Report_DataImports_GetForUserOnMonth_IndustryScope 'u11','20260901','u11';
IF EXISTS(SELECT 1 FROM @Work) THROW 51001,'R02 unassigned admin personal worklist widened',1;
DECLARE @Options TABLE(TotalRow int,Value varchar(20),Text nvarchar(250));
INSERT @Options EXEC dbo.p_Report_Dashboard_FilterOptions_IndustryScope 'enterprise',NULL,NULL,1,50,'u10';
IF EXISTS(SELECT 1 FROM @Options WHERE Value IS NOT NULL OR TotalRow<>0) THROW 51001,'R03 empty scope widened',1;
DELETE FROM @Options;
INSERT @Options EXEC dbo.p_Report_Dashboard_FilterOptions_IndustryScope 'industry',NULL,NULL,1,50,'u3';
IF EXISTS(SELECT 1 FROM @Options WHERE Value IS NOT NULL AND Value<>'20') THROW 51001,'R03 unrelated industry disclosed',1;
BEGIN TRY EXEC dbo.p_Report_Dashboard_FilterOptions_IndustryScope 'year',NULL,NULL,1,50,'unknown'; THROW 51002,'R03 failed scope accepted',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>50112 THROW; END CATCH;
DECLARE @Search TABLE(EnterpriseId int,BusinessName nvarchar(250),TaxCode varchar(100),TypeBusiness varchar(50),TotalRow int);
INSERT @Search EXEC dbo.p_Report_Industry_Enterprises_SearchSelect2 NULL,NULL,0,1,'u2';
IF (SELECT COUNT(*) FROM @Search)<>1 OR EXISTS(SELECT 1 FROM @Search WHERE TotalRow<>2 OR EnterpriseId NOT IN(1,3)) THROW 51001,'R04 search pagination/approval mismatch',1;
DELETE FROM @Search;
INSERT @Search EXEC dbo.p_Report_DataImports_Enterprises_SearchSelect2 NULL,NULL,0,20,'u12';
IF (SELECT COUNT(*) FROM @Search)<>1 OR EXISTS(SELECT 1 FROM @Search WHERE EnterpriseId<>2) THROW 51001,'R04 operational picker unexpectedly industry-limited',1;
DELETE FROM @Search;
INSERT @Search EXEC dbo.p_Report_Industry_Enterprises_SearchSelect2 N'Three',NULL,0,20,'u2';
IF (SELECT COUNT(*) FROM @Search)<>1 OR EXISTS(SELECT 1 FROM @Search WHERE EnterpriseId<>3 OR TotalRow<>1) THROW 51001,'R04 keyword filtering mismatch',1;
DECLARE @Missing TABLE(OwnerEnterpriseName nvarchar(250),BusinessName nvarchar(250),TaxCode varchar(100),BusinessAddress nvarchar(250),StreetName nvarchar(250),WardName nvarchar(100),DistrictName nvarchar(100),ProvinceName nvarchar(100),TypeBusinessName nvarchar(100),LegalRepresentationName nvarchar(100),LegalRepresentationPhone varchar(100),LegalRepresentationEmail varchar(100),Phone varchar(100),Website varchar(100),Email varchar(100));
INSERT @Missing EXEC dbo.p_Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope '20260901','u1';
IF (SELECT COUNT(*) FROM @Missing)<>1 OR EXISTS(SELECT 1 FROM @Missing WHERE BusinessName<>N'Unapproved') THROW 51001,'R06 missing-report denominator/submission mismatch',1;
DECLARE @Metrics TABLE(RowNo bigint,TargetName nvarchar(100),Unit nvarchar(20),YearPlan decimal(18,2),PreviousYearMonth decimal(18,2),PreviousYearAccumulated decimal(18,2),PreviousMonth decimal(18,2),EstimatedCurrentMonth decimal(18,2),CurrentYearAccumulated decimal(18,2),RateAccumulatedVsPlan decimal(18,2),RateAccumulatedVsPreviousYear decimal(18,2),RateCurrentMonthVsPreviousYear decimal(18,2));
INSERT @Metrics EXEC dbo.p_Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope '20260901',NULL,'u2';
IF (SELECT SUM(EstimatedCurrentMonth) FROM @Metrics)<>45 THROW 51001,'R08 report aggregate does not reconcile to scoped raw data',1;
INSERT dbo.Report_UserBusinessIndustryPermissions VALUES(2,20),(2,10);
IF (SELECT COUNT(*) FROM dbo.f_Report_IndustryEnterprises('u2'))<>4 THROW 51001,'R07 multiple/duplicate industry grants duplicate enterprises',1;
DELETE FROM dbo.Report_UserBusinessIndustryPermissions WHERE UserId=6;
IF (SELECT COUNT(*) FROM dbo.f_Report_IndustryEnterprises('u6'))<>1 OR NOT EXISTS(SELECT 1 FROM dbo.f_Report_IndustryEnterprises('u6') WHERE EnterpriseId=2) THROW 51001,'R07 mixed-role zero-grants fallback changed',1;
DELETE FROM dbo.Sys_Permissions WHERE RoleId=6 AND FunctionId=2;
IF EXISTS(SELECT 1 FROM dbo.f_Report_DataImportEnterprises('u2')) THROW 51001,'R04 selector grants operational data without Import operation rights',1;
UPDATE dbo.Report_RoleMappings SET RoleId=999 WHERE RoleId=6;
IF EXISTS(SELECT 1 FROM dbo.f_Report_IndustryEnterprises('u1')) THROW 51001,'R07 invalid mapping broadened',1;
ROLLBACK TRANSACTION;
SELECT 'PASS' FixtureStatus,'Exact row sets, worklist, isolation, mapping, pagination and scoped total assertions passed; no fixture data retained' Detail;
