-- Post-deployment metadata/text checks only; no persistent writes. Run with VIEW DEFINITION in both databases.
:ON ERROR EXIT
SET NOCOUNT ON;
IF DB_ID(N'baocaosct.khanhhoa.gov.vn.cate') IS NULL OR DB_ID(N'baocaosct.khanhhoa.gov.vn') IS NULL
 THROW 50120,'Both existing application databases are required; this is not an empty-database bootstrap.',1;
USE [baocaosct.khanhhoa.gov.vn];
IF EXISTS(SELECT 1 FROM sys.databases WHERE name IN(N'baocaosct.khanhhoa.gov.vn.cate',N'baocaosct.khanhhoa.gov.vn') AND compatibility_level<110)
 THROW 50121,'Compatibility level 110 or higher is required.',1;
DECLARE @RoleMap TABLE(SemanticKey varchar(80),RoleId int,ScopeMode varchar(10),IsIndustryEditorTarget bit);
INSERT @RoleMap VALUES ('SystemAdministrator',1,'all',1),
('ReportingRole2',2,'industry',1),
('ReportingRole3',3,'industry',1),
('ReportingRole4',4,'industry',1),
('Enterprise',5,'enterprise',0),
('IndustryAdministrator',6,'industry',1);
IF EXISTS(SELECT 1 FROM @RoleMap m LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Roles r ON r.RoleId=m.RoleId WHERE r.RoleId IS NULL OR r.IsDeleted<>0)
 THROW 50124,'Configured role is missing, deleted or inaccessible.',1;
IF NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Functions WHERE Area='Report' AND Name='Dashboard' AND IsDeleted=0)
 OR NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Functions WHERE Area='Report' AND Name='Import' AND IsDeleted=0)
 OR NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Functions WHERE Area='Cate' AND Name='Enterprise' AND IsDeleted=0)
 THROW 50124,'Required reporting/registry functions are missing or deleted.',1;
-- Province mapping is eligibility only: existing function permissions still decide actual access.
IF EXISTS(SELECT 1 FROM @RoleMap m JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Permissions p ON p.RoleId=m.RoleId
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
 WHERE m.ScopeMode='enterprise' AND f.Area='Sys' AND f.Name='User' AND p.Action IN('Add','Edit','Delete'))
 THROW 50124,'Enterprise role has forbidden user-management permissions.',1;
IF NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Permissions p JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
 JOIN @RoleMap m ON m.RoleId=p.RoleId WHERE m.SemanticKey='SystemAdministrator' AND f.Area='Sys' AND f.Name='User' AND p.Action='Edit')
 THROW 50124,'System administrator requires Sys/User/Edit.',1;
IF OBJECT_ID(N'[baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings','U') IS NULL
 THROW 50124,'Role mapping table missing.',1;
IF EXISTS(SELECT * FROM @RoleMap EXCEPT SELECT SemanticKey,RoleId,ScopeMode,IsIndustryEditorTarget FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings)
 OR EXISTS(SELECT SemanticKey,RoleId,ScopeMode,IsIndustryEditorTarget FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings EXCEPT SELECT * FROM @RoleMap)
 THROW 50124,'Deployed role mapping differs from application release mapping.',1;
DECLARE @Issues TABLE(CheckName nvarchar(80),DatabaseName sysname,ObjectName sysname,Detail nvarchar(500));
DECLARE @Expected TABLE(DatabaseName sysname,ObjectName sysname,ObjectType varchar(2),Definition nvarchar(max));
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'f_Report_DataImportEnterprises',N'IF',N'FUNCTION dbo.f_Report_DataImportEnterprises(@UserName varchar(255)) RETURNS TABLE AS RETURN (
 SELECT e.*,CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_UserRoles ur
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m ON m.RoleId=ur.RoleId
 WHERE ur.UserId=u.UserId AND m.SemanticKey IN(''SystemAdministrator'',''IndustryAdministrator'')) OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions p WHERE p.ForUser=u.UserName AND p.EnterpriseId=e.EnterpriseId) THEN 1 ELSE 0 END) CanManageAllRecords
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users u ON u.UserName=@UserName
 WHERE u.IsActive=1 AND u.IsDeleted=0 AND ISNULL(u.IsLocked,0)=0
 AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_UserRoles rightsRole
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Roles liveRole ON liveRole.RoleId=rightsRole.RoleId AND liveRole.IsDeleted=0
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Permissions rightsPermission ON rightsPermission.RoleId=rightsRole.RoleId
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Functions rightsFunction ON rightsFunction.FunctionId=rightsPermission.FunctionId AND rightsFunction.IsDeleted=0
 WHERE rightsRole.UserId=u.UserId AND rightsFunction.Area=''Report'' AND rightsFunction.Name=''Import''
 AND rightsPermission.Action IN(''View'',''Add'',''Edit'',''Delete''))
 AND NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m
  LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Roles r ON r.RoleId=m.RoleId WHERE r.RoleId IS NULL OR r.IsDeleted<>0)
 AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings WHERE SemanticKey=''SystemAdministrator'')
 AND (
 EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_UserRoles ur
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m ON m.RoleId=ur.RoleId
 WHERE ur.UserId=u.UserId AND m.SemanticKey IN(''SystemAdministrator'',''IndustryAdministrator''))
 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions p WHERE p.ForUser=u.UserName AND p.EnterpriseId=e.EnterpriseId)
 OR (NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions p WHERE p.ForUser=u.UserName)
 AND EXISTS(SELECT 1 FROM dbo.Report_DataImports r WHERE r.EnterpriseId=e.EnterpriseId AND r.CreatedBy=u.UserName AND r.IsDeleted=0))
 ))');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'f_Report_IndustryDataImports',N'IF',N'FUNCTION dbo.f_Report_IndustryDataImports(@UserName varchar(255)) RETURNS TABLE AS RETURN (SELECT r.* FROM dbo.Report_DataImports r WHERE EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@UserName) e WHERE e.EnterpriseId=r.EnterpriseId))');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'f_Report_IndustryExtendInfos',N'IF',N'FUNCTION dbo.f_Report_IndustryExtendInfos(@UserName varchar(255)) RETURNS TABLE AS RETURN (SELECT r.* FROM dbo.Report_ExtendInfos r WHERE EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@UserName) u WHERE u.IsRestricted=0))');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'f_Report_IndustryReportFiles',N'IF',N'FUNCTION dbo.f_Report_IndustryReportFiles(@UserName varchar(255)) RETURNS TABLE AS RETURN (SELECT r.* FROM dbo.Report_ReportFiles r WHERE EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@UserName) e WHERE e.EnterpriseId=r.EnterpriseId))');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Chatbot_FilterOptions',N'P',N'PROCEDURE dbo.p_Report_Chatbot_FilterOptions @ChatbotUserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500), @OptionKind varchar(20),@TypeReport int=NULL,
 @Search nvarchar(250)=NULL,@Page int=1,@PageSize int=50
AS BEGIN SET NOCOUNT ON;
 SELECT * INTO #ChatbotScope FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_UserScope(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds);

IF NOT EXISTS(SELECT 1 FROM #ChatbotScope WHERE CanReadDashboard=1) THROW 50110,''Chatbot dashboard access denied'',1;

IF @OptionKind NOT IN (''year'',''latest'',''ward'',''sector'',''industry'',''enterprise'') THROW 50006,''Unsupported option kind'',1;
 IF @TypeReport IS NOT NULL AND @TypeReport NOT IN (1,2,3) THROW 50001,''Unsupported report type'',1;
 IF @Page<1 OR @PageSize<1 OR @PageSize>100 THROW 50004,''Invalid page'',1;
 DECLARE @WardId int=NULL,@EconomicSectorId int=NULL,@IndustryId int=NULL,@EnterpriseId int=NULL;

 CREATE TABLE #ChatbotEnterprises(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ChatbotEnterprises(EnterpriseId)
 SELECT authorized.EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,1) authorized
 OPTION (RECOMPILE);
 -- Industry options start with the small business registry, not every enterprise.
 IF @OptionKind=''industry'' BEGIN
 ;WITH Options AS (
 SELECT DISTINCT CONVERT(varchar(20),i.IndustryId) Value,CONVERT(nvarchar(250),i.IndustryName) Text
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e ON e.EnterpriseId=b.EnterpriseId
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
  ON '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),i.IndustryId)+'',%''
 WHERE e.IsActive=1 AND e.IsDeleted=0 AND i.IsActive=1 AND i.IsDeleted=0
 AND EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=e.EnterpriseId)
 AND (@TypeReport IS NULL OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@TypeReport)+'',%'')
 ), Filtered AS (SELECT * FROM Options WHERE @Search IS NULL OR @Search='''' OR CHARINDEX(@Search,Text)>0 OR Value=@Search),
 Ranked AS (SELECT *,ROW_NUMBER() OVER(ORDER BY Text,Value) RowNo FROM Filtered),Total AS (SELECT COUNT(*) TotalRow FROM Filtered)
 SELECT t.TotalRow,r.Value,r.Text FROM Total t OUTER APPLY
 (SELECT Value,Text FROM Ranked WHERE RowNo>CONVERT(bigint,@Page-1)*@PageSize AND RowNo<=CONVERT(bigint,@Page)*@PageSize) r OPTION (RECOMPILE);
 RETURN; END;

;WITH Cohort AS (
 SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N''Chưa phân loại'' ELSE N''Mã địa bàn ''+CONVERT(nvarchar(20),e.WardId) END) WardName,
 b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N'', '' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),i.IndustryId)+'',%''
 ORDER BY i.IndustryId FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,''''),''''),N''Chưa phân ngành'') IndustryName
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=e.EnterpriseId)
 AND (@TypeReport IS NULL OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@TypeReport)+'',%'')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@IndustryId)+'',%'')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
), Options AS (
 SELECT DISTINCT CONVERT(varchar(20),YEAR(r.ForMonth)) Value,CONVERT(nvarchar(250),YEAR(r.ForMonth)) Text
 FROM dbo.Report_DataImports r WHERE EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=r.EnterpriseId) AND @OptionKind=''year'' AND r.IsDeleted=0 AND (@TypeReport IS NULL OR r.TypeReport=@TypeReport)
 UNION SELECT DISTINCT CONVERT(varchar(20),YEAR(f.ForMonth)),CONVERT(nvarchar(250),YEAR(f.ForMonth)) FROM dbo.Report_ReportFiles f WHERE EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=f.EnterpriseId) AND @OptionKind=''year'' AND f.IsDeleted=0
 UNION SELECT CONVERT(varchar(20),YEAR(GETDATE())),CONVERT(nvarchar(250),YEAR(GETDATE())) WHERE @OptionKind=''year''
 UNION SELECT CONVERT(varchar(20),MAX(ForMonth),23),CONVERT(nvarchar(250),MAX(ForMonth),23) FROM dbo.Report_DataImports
 WHERE EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=dbo.Report_DataImports.EnterpriseId) AND @OptionKind=''latest'' AND IsDeleted=0 AND TypeReport IN (1,2,3) AND ForMonth<DATEADD(month,1,DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1)) HAVING MAX(ForMonth) IS NOT NULL
 UNION SELECT DISTINCT CONVERT(varchar(20),WardId),CONVERT(nvarchar(250),WardName) FROM Cohort WHERE @OptionKind=''ward'' AND WardId IS NOT NULL
 UNION SELECT DISTINCT CONVERT(varchar(20),EconomicSectorId),CONVERT(nvarchar(250),EconomicSectorName) FROM Cohort WHERE @OptionKind=''sector'' AND EconomicSectorId IS NOT NULL
 UNION SELECT CONVERT(varchar(20),EnterpriseId),CONVERT(nvarchar(250),COALESCE(BusinessName,N'''')+CASE WHEN NULLIF(TaxCode,'''') IS NULL THEN N'''' ELSE N'' · ''+TaxCode END)
 FROM Cohort WHERE @OptionKind=''enterprise''
 )
SELECT * INTO #ChatbotPageSource FROM (
SELECT * FROM Options WHERE @Search IS NULL OR @Search='''' OR CHARINDEX(@Search,Text)>0 OR Value=@Search
) materialized OPTION (RECOMPILE);
;WITH Ranked AS (SELECT *,ROW_NUMBER() OVER(ORDER BY CASE WHEN @OptionKind IN (''year'',''latest'') THEN Value END DESC,Text,Value) RowNo FROM #ChatbotPageSource),
 Total AS (SELECT COUNT(*) TotalRow FROM #ChatbotPageSource)
 SELECT t.TotalRow,r.Value,r.Text FROM Total t OUTER APPLY
 (SELECT Value,Text FROM Ranked WHERE RowNo>CONVERT(bigint,@Page-1)*@PageSize AND RowNo<=CONVERT(bigint,@Page)*@PageSize) r;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Chatbot_IndicatorData',N'P',N'PROCEDURE dbo.p_Report_Chatbot_IndicatorData
 @ChatbotUserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500),
 @FromMonth date,@ToMonth date,@TypeReport int=NULL,@EnterpriseId int=NULL,@WardId int=NULL,
 @EconomicSectorId int=NULL,@IndustryId int=NULL,@Code varchar(50)=NULL,@CodePrefix varchar(50)=NULL,
 @Search nvarchar(250)=NULL,@Offset int=0,@Limit int=10
AS BEGIN
 SET NOCOUNT ON;
 SELECT * INTO #ChatbotScope FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_UserScope(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds);

IF NOT EXISTS(SELECT 1 FROM #ChatbotScope WHERE CanReadDashboard=1) THROW 50110,''Chatbot dashboard access denied'',1;

 IF @FromMonth IS NULL OR @ToMonth IS NULL OR DAY(@FromMonth)<>1 OR DAY(@ToMonth)<>1
 OR @FromMonth<CONVERT(date,''20000101'') OR @ToMonth<@FromMonth OR DATEDIFF(month,@FromMonth,@ToMonth)>11
 OR @ToMonth>DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1)
 OR @Offset<0 OR @Offset>100000 OR @Limit<1 OR @Limit>50
 OR (@TypeReport IS NOT NULL AND @TypeReport NOT IN(1,2,3)) THROW 50102,''Invalid indicator query'',1;

 CREATE TABLE #ChatbotEnterprises(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ChatbotEnterprises(EnterpriseId)
 SELECT authorized.EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,1) authorized
 WHERE @EnterpriseId IS NULL OR authorized.EnterpriseId=@EnterpriseId
 OPTION (RECOMPILE);
;WITH Source AS (
 SELECT r.ReportId,r.EnterpriseId,e.BusinessName,e.TaxCode,e.WardId,
 DATEFROMPARTS(YEAR(r.ForMonth),MONTH(r.ForMonth),1) ReportMonth,r.ForMonth SourcePeriod,
 r.TypeReport,r.TypeReportName,r.[Index],r.[Level],r.Code,r.Targets,r.Unit,
 r.PerformPreviousPeriod,r.PerformInPeriod,r.AccumulatedBeginingOfYear,r.ComparedSamePeriodLastYear,
 r.IsLate,r.CreatedDate,r.LastModifiedDate,
 COUNT(*) OVER(PARTITION BY r.EnterpriseId,YEAR(r.ForMonth),MONTH(r.ForMonth),r.TypeReport,r.Code) ExactCodeRows
 FROM dbo.Report_DataImports r
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e ON e.EnterpriseId=r.EnterpriseId AND e.IsActive=1 AND e.IsDeleted=0
 WHERE EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=r.EnterpriseId) AND r.IsDeleted=0 AND r.TypeReport IN(1,2,3)
 AND r.ForMonth>=@FromMonth AND r.ForMonth<DATEADD(month,1,@ToMonth)
 AND (@TypeReport IS NULL OR r.TypeReport=@TypeReport)
 AND (@EnterpriseId IS NULL OR r.EnterpriseId=@EnterpriseId)
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND ((@EconomicSectorId IS NULL AND @IndustryId IS NULL) OR EXISTS(
 SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b WHERE b.EnterpriseId=e.EnterpriseId
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@IndustryId)+'',%'')))
 )
SELECT * INTO #ChatbotPageSource FROM (
SELECT * FROM Source
 WHERE (@Code IS NULL OR Code=@Code)
 AND (@CodePrefix IS NULL OR LEFT(Code,LEN(@CodePrefix))=@CodePrefix)
 AND (@Search IS NULL OR CHARINDEX(@Search,Targets)>0 OR CHARINDEX(@Search,Code)>0)
) materialized OPTION (RECOMPILE);
;WITH Ranked AS (SELECT *,ROW_NUMBER() OVER(ORDER BY ReportMonth DESC,EnterpriseId,TypeReport,[Index],ReportId) RowNo FROM #ChatbotPageSource),
 Total AS(SELECT COUNT(*) TotalRow FROM #ChatbotPageSource)
 SELECT t.TotalRow,r.ReportId,r.EnterpriseId,r.BusinessName,r.TaxCode,r.WardId,r.ReportMonth,r.SourcePeriod,
 r.TypeReport,r.TypeReportName,r.[Index],r.[Level],r.Code,r.Targets,r.Unit,r.PerformPreviousPeriod,
 r.PerformInPeriod,r.AccumulatedBeginingOfYear,r.ComparedSamePeriodLastYear,r.IsLate,r.CreatedDate,r.LastModifiedDate,r.ExactCodeRows
 FROM Total t OUTER APPLY(SELECT * FROM Ranked WHERE RowNo>@Offset AND RowNo<=CONVERT(bigint,@Offset)+@Limit) r;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Chatbot_Metadata',N'P',N'PROCEDURE dbo.p_Report_Chatbot_Metadata
 @ChatbotUserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500),
 @Kind varchar(20),@TypeReport int=NULL,@Search nvarchar(250)=NULL,@Offset int=0,@Limit int=10
AS BEGIN
 SET NOCOUNT ON;
 SELECT * INTO #ChatbotScope FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_UserScope(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds);

IF NOT EXISTS(SELECT 1 FROM #ChatbotScope WHERE CanReadDashboard=1) THROW 50110,''Chatbot dashboard access denied'',1;

 IF @Kind NOT IN(''catalog'',''policy'',''capabilities'') OR @Offset<0 OR @Offset>100000 OR @Limit<1 OR @Limit>50
 OR (@TypeReport IS NOT NULL AND @TypeReport NOT IN(1,2,3)) THROW 50104,''Invalid metadata query'',1;

IF @Kind=''policy'' BEGIN
 SELECT ConfigKey,ConfigValue,ConfigDesc FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Configs
 WHERE IsDeleted=0 AND ConfigKey IN(''Day_Deadline_Send_Report'',''Day_Deadline_Send_Late_Report''); RETURN;
 END;
 CREATE TABLE #ChatbotEnterprises(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ChatbotEnterprises(EnterpriseId)
 SELECT authorized.EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,1) authorized
 OPTION (RECOMPILE);
 IF @Kind=''capabilities'' BEGIN
 SELECT COUNT(*) ActiveIndicatorRows,COUNT(DISTINCT r.EnterpriseId) ObservedEnterpriseIds,
 MIN(ForMonth) FirstSourcePeriod,MAX(ForMonth) LastSourcePeriod,
 COUNT(DISTINCT YEAR(ForMonth)*100+MONTH(ForMonth)) ObservedMonths,
 CASE WHEN EXISTS(SELECT 1 FROM #ChatbotScope WHERE CanReadProvince=1 AND IsIndustryRestricted=0) THEN SUM(CASE WHEN e.EnterpriseId IS NULL THEN 1 ELSE 0 END) ELSE NULL END OrphanIndicatorRows
 FROM dbo.Report_DataImports r LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e ON e.EnterpriseId=r.EnterpriseId
 WHERE (EXISTS(SELECT 1 FROM #ChatbotScope WHERE CanReadProvince=1 AND IsIndustryRestricted=0) OR EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=r.EnterpriseId)) AND r.IsDeleted=0 AND r.TypeReport IN(1,2,3) AND r.ForMonth<DATEADD(month,1,DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1)); RETURN;
 END;
 ;WITH Observed AS (
 SELECT TypeReport,Code,Targets,Unit,COUNT(*) SourceRows,COUNT(PerformInPeriod) SuppliedRows,
 MIN(ForMonth) FirstSourcePeriod,MAX(ForMonth) LastSourcePeriod
 FROM dbo.Report_DataImports WHERE EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=dbo.Report_DataImports.EnterpriseId) AND IsDeleted=0 AND TypeReport IN(1,2,3)
 GROUP BY TypeReport,Code,Targets,Unit
 ), Source AS (
 SELECT TypeReport,Code,Targets,Unit,''observed'' SourceKind,SourceRows,SuppliedRows,
 FirstSourcePeriod,LastSourcePeriod,CAST(NULL AS nvarchar(50)) ParentCode FROM Observed
 UNION ALL
 SELECT TypeReport,Code,Targets,Unit,''configured'',0,0,NULL,NULL,ParentCode FROM dbo.ReportTargetConfig
 UNION ALL
 SELECT TypeReport,CodePattern,CAST(N''Quy tắc nhóm động'' AS nvarchar(1500)),NULL,''dynamic_rule'',0,0,NULL,NULL,ParentCode FROM dbo.ReportDynamicGroupRule
 )
SELECT * INTO #ChatbotPageSource FROM (
SELECT * FROM Source WHERE (@TypeReport IS NULL OR TypeReport=@TypeReport)
 AND (@Search IS NULL OR CHARINDEX(@Search,Targets)>0 OR CHARINDEX(@Search,Code)>0)
) materialized OPTION (RECOMPILE);
;WITH Ranked AS(SELECT *,ROW_NUMBER() OVER(ORDER BY TypeReport,Code,SourceKind,Targets,Unit) RowNo FROM #ChatbotPageSource),
 Total AS(SELECT COUNT(*) TotalRow FROM #ChatbotPageSource)
 SELECT t.TotalRow,r.TypeReport,r.Code,r.Targets,r.Unit,r.SourceKind,r.SourceRows,r.SuppliedRows,
 r.FirstSourcePeriod,r.LastSourcePeriod,r.ParentCode
 FROM Total t OUTER APPLY(SELECT * FROM Ranked WHERE RowNo>@Offset AND RowNo<=CONVERT(bigint,@Offset)+@Limit) r;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Chatbot_ProgressDetails',N'P',N'PROCEDURE dbo.p_Report_Chatbot_ProgressDetails @ChatbotUserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500), @ForMonth date, @TypeReport int,
 @WardId int=NULL, @EconomicSectorId int=NULL, @IndustryId int=NULL, @EnterpriseId int=NULL,
 @Status varchar(20)=''all'',@Page int=1,@PageSize int=50,@Search nvarchar(250)=NULL
AS BEGIN
 SET NOCOUNT ON;
 SELECT * INTO #ChatbotScope FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_UserScope(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds);

 IF NOT EXISTS(SELECT 1 FROM #ChatbotScope WHERE CanReadDashboard=1) THROW 50110,''Chatbot dashboard access denied'',1;
 IF @TypeReport NOT IN (1,2,3) OR @TypeReport IS NULL THROW 50001,''Unsupported report type'',1;
 IF @ForMonth IS NULL THROW 50002,''Report month is required'',1;
 IF @Status NOT IN (''all'',''missing'',''incomplete'',''complete'',''conflict'',''file-late'') THROW 50003,''Unsupported status'',1;
 IF @Page<1 OR @PageSize<1 OR @PageSize>100 THROW 50004,''Invalid page'',1;
 DECLARE @Start date=DATEFROMPARTS(YEAR(@ForMonth),MONTH(@ForMonth),1),@End date;
 SET @End=DATEADD(month,1,@Start);

 CREATE TABLE #ChatbotEnterprises(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ChatbotEnterprises(EnterpriseId)
 SELECT authorized.EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,1) authorized
 WHERE @EnterpriseId IS NULL OR authorized.EnterpriseId=@EnterpriseId
 OPTION (RECOMPILE);
SELECT * INTO #DashboardCohort FROM (
SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N''Chưa phân loại'' ELSE N''Mã địa bàn ''+CONVERT(nvarchar(20),e.WardId) END) WardName,
 b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N'', '' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),i.IndustryId)+'',%''
 ORDER BY i.IndustryId FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,''''),''''),N''Chưa phân ngành'') IndustryName
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=e.EnterpriseId)
 AND (@TypeReport IS NULL OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@TypeReport)+'',%'')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@IndustryId)+'',%'')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
) materialized OPTION (RECOMPILE);
CREATE CLUSTERED INDEX IX_DashboardCohort ON #DashboardCohort(EnterpriseId);
SELECT * INTO #DashboardImports FROM (
SELECT r.EnterpriseId, DATEFROMPARTS(YEAR(r.ForMonth),MONTH(r.ForMonth),1) ForMonth,
 LTRIM(RTRIM(r.[Level])) IndicatorLevel,r.PerformInPeriod,r.IsLate,r.CreatedDate,r.LastModifiedDate,
 LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(r.Unit,''''),'' '',''''),''.'',''''),CHAR(13),''''),CHAR(10),''''),CHAR(9),'''')) NormalUnit
 FROM dbo.Report_DataImports r WHERE r.IsDeleted=0 AND r.TypeReport=@TypeReport
 AND r.ForMonth>=@Start AND r.ForMonth<@End
 AND EXISTS(SELECT 1 FROM #DashboardCohort c WHERE c.EnterpriseId=r.EnterpriseId)
) materialized OPTION (RECOMPILE);
CREATE CLUSTERED INDEX IX_DashboardImports ON #DashboardImports(EnterpriseId,ForMonth);
;WITH Presence AS (
 SELECT EnterpriseId,ForMonth,CAST(1 AS bit) DataImported,MAX(CAST(IsLate AS int)) ImportLate,
 MIN(CreatedDate) FirstImportedAt,MAX(COALESCE(LastModifiedDate,CreatedDate)) LastImportedAt
 FROM #DashboardImports GROUP BY EnterpriseId,ForMonth
), Mapped AS (
 SELECT *, CASE
 -- TypeReport + Level identifies the fixed template totals across old/new Code formats.
 -- Index moves with product rows. Exact levels exclude product/country/retail detail rows.
 -- Type 1 primary is industrial revenue (1.1), not total enterprise revenue (1).
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN ''1.1'' WHEN 2 THEN ''1'' ELSE ''0'' END THEN ''primary''
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN ''6'' WHEN 2 THEN ''2'' ELSE ''1'' END THEN ''secondary''
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN ''7'' WHEN 2 THEN ''1.1'' ELSE ''2'' END THEN ''tertiary'' END Metric
 FROM #DashboardImports
), MetricGroups AS (
 SELECT EnterpriseId,ForMonth,Metric,COUNT(*) SourceRows,
 MAX(CASE WHEN (@TypeReport=1 AND Metric=''primary'' AND NormalUnit=N''tỷđồng'')
 OR (@TypeReport=1 AND Metric<>''primary'' AND NormalUnit=''1000usd'')
 OR (@TypeReport=2 AND NormalUnit=N''triệuđồng'')
 OR (@TypeReport=3 AND NormalUnit=''usd'') THEN 0 ELSE 1 END) InvalidUnit,
 MAX(CASE WHEN PerformInPeriod IS NOT NULL AND TRY_CONVERT(decimal(28,4),PerformInPeriod) IS NULL THEN 1 ELSE 0 END) InvalidNumber,
 MAX(TRY_CONVERT(decimal(28,4),PerformInPeriod)) SingleValue
 FROM Mapped WHERE Metric IS NOT NULL GROUP BY EnterpriseId,ForMonth,Metric
), Metrics AS (
 SELECT EnterpriseId,ForMonth,
 MAX(CASE WHEN Metric=''primary'' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) PrimaryValue,
 MAX(CASE WHEN Metric=''secondary'' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) SecondaryValue,
 MAX(CASE WHEN Metric=''tertiary'' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) TertiaryValue,
 MAX(CASE WHEN Metric=''primary'' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) PrimaryConflict,
 MAX(CASE WHEN Metric=''secondary'' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) SecondaryConflict,
 MAX(CASE WHEN Metric=''tertiary'' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) TertiaryConflict,
 MAX(CASE WHEN SourceRows>1 THEN 1 ELSE 0 END) DuplicateMetric,
 MAX(InvalidUnit) InvalidUnit,MAX(InvalidNumber) InvalidNumber
 FROM MetricGroups GROUP BY EnterpriseId,ForMonth
), FileRows AS (
 SELECT f.*,DATEFROMPARTS(YEAR(f.ForMonth),MONTH(f.ForMonth),1) ReportMonth,
 ROW_NUMBER() OVER(PARTITION BY EnterpriseId,YEAR(ForMonth),MONTH(ForMonth)
 ORDER BY COALESCE(LastModifiedDate,CreatedDate) DESC,ForMonth DESC) RowNo,
 MAX(CAST(IsLate AS int)) OVER(PARTITION BY EnterpriseId,YEAR(ForMonth),MONTH(ForMonth)) FileLate
 FROM dbo.Report_ReportFiles f WHERE IsDeleted=0 AND ForMonth>=@Start AND ForMonth<@End
 AND EXISTS(SELECT 1 FROM #DashboardCohort c WHERE c.EnterpriseId=f.EnterpriseId)
), Files AS (SELECT * FROM FileRows WHERE RowNo=1), States AS (
 SELECT c.*,CAST(ISNULL(p.DataImported,0) AS bit) DataImported,
 CAST(CASE WHEN f.EnterpriseId IS NULL THEN 0 ELSE 1 END AS bit) FileSubmittedAnyType,
 CAST(ISNULL(p.ImportLate,0) AS bit) ImportLate,CAST(ISNULL(f.FileLate,0) AS bit) FileLate,
 p.FirstImportedAt,p.LastImportedAt,f.CreatedDate FileCreatedAt,f.Reason,
 v.PrimaryValue,v.SecondaryValue,v.TertiaryValue,
 CAST(ISNULL(v.PrimaryConflict,0) AS bit) PrimaryConflict,
 CAST(ISNULL(v.SecondaryConflict,0) AS bit) SecondaryConflict,
 CAST(ISNULL(v.TertiaryConflict,0) AS bit) TertiaryConflict,
 CAST(ISNULL(v.DuplicateMetric,0) AS bit) DuplicateMetric,
 CAST(ISNULL(v.InvalidUnit,0) AS bit) InvalidUnit,CAST(ISNULL(v.InvalidNumber,0) AS bit) InvalidNumber,
 CAST(CASE WHEN ISNULL(v.PrimaryConflict,0)+ISNULL(v.SecondaryConflict,0)+ISNULL(v.TertiaryConflict,0)>0 THEN 1 ELSE 0 END AS bit) MetricConflict
 FROM #DashboardCohort c LEFT JOIN Presence p ON p.EnterpriseId=c.EnterpriseId AND p.ForMonth=@Start
 LEFT JOIN Metrics v ON v.EnterpriseId=c.EnterpriseId AND v.ForMonth=@Start
 LEFT JOIN Files f ON f.EnterpriseId=c.EnterpriseId AND f.ReportMonth=@Start
 )
SELECT * INTO #DashboardFiltered FROM (
SELECT * FROM States WHERE @Status=''all''
 OR (@Status=''missing'' AND DataImported=0)
 OR (@Status=''incomplete'' AND DataImported=1 AND (PrimaryValue IS NULL OR SecondaryValue IS NULL OR TertiaryValue IS NULL))
 OR (@Status=''complete'' AND PrimaryValue IS NOT NULL AND SecondaryValue IS NOT NULL AND TertiaryValue IS NOT NULL)
 OR (@Status=''conflict'' AND MetricConflict=1)
 OR (@Status=''file-late'' AND FileLate=1)
) materialized OPTION (RECOMPILE);
CREATE CLUSTERED INDEX IX_DashboardFiltered ON #DashboardFiltered(EnterpriseId);
;WITH SearchFiltered AS (
 SELECT * FROM #DashboardFiltered WHERE (@Search IS NULL OR CHARINDEX(@Search COLLATE Latin1_General_100_CI_AI,BusinessName COLLATE Latin1_General_100_CI_AI)>0
 OR CHARINDEX(@Search COLLATE Latin1_General_100_CI_AI,TaxCode COLLATE Latin1_General_100_CI_AI)>0
 OR CHARINDEX(@Search COLLATE Latin1_General_100_CI_AI,WardName COLLATE Latin1_General_100_CI_AI)>0)
), Ranked AS (
 SELECT *,ROW_NUMBER() OVER(ORDER BY MetricConflict DESC,DataImported,
 CASE WHEN PrimaryValue IS NULL OR SecondaryValue IS NULL OR TertiaryValue IS NULL THEN 0 ELSE 1 END,BusinessName,EnterpriseId) RowNo FROM SearchFiltered
 ), Total AS (SELECT COUNT(*) TotalRow,(SELECT COUNT(*) FROM #DashboardFiltered) TotalUnfiltered FROM SearchFiltered)
 SELECT t.TotalRow,t.TotalUnfiltered,r.* FROM Total t OUTER APPLY
 (SELECT * FROM Ranked WHERE RowNo>CONVERT(bigint,@Page-1)*@PageSize AND RowNo<=CONVERT(bigint,@Page)*@PageSize) r
 ORDER BY r.RowNo;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Chatbot_ReportFiles',N'P',N'PROCEDURE dbo.p_Report_Chatbot_ReportFiles
 @ChatbotUserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500),
 @EnterpriseId int,@FromMonth date,@ToMonth date,@Offset int=0,@Limit int=10
AS BEGIN
 SET NOCOUNT ON;
 SELECT * INTO #ChatbotScope FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_UserScope(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds);

IF NOT EXISTS(SELECT 1 FROM #ChatbotScope WHERE CanReadDashboard=1) THROW 50110,''Chatbot dashboard access denied'',1;

 IF @EnterpriseId IS NULL OR @FromMonth IS NULL OR @ToMonth IS NULL OR DAY(@FromMonth)<>1 OR DAY(@ToMonth)<>1
 OR @FromMonth<CONVERT(date,''20000101'') OR @ToMonth<@FromMonth OR DATEDIFF(month,@FromMonth,@ToMonth)>11
 OR @ToMonth>DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1)
 OR @Offset<0 OR @Offset>100000 OR @Limit<1 OR @Limit>50 THROW 50103,''Invalid submission query'',1;

 CREATE TABLE #ChatbotEnterprises(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ChatbotEnterprises(EnterpriseId)
 SELECT authorized.EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,1) authorized
 WHERE @EnterpriseId IS NULL OR authorized.EnterpriseId=@EnterpriseId
 OPTION (RECOMPILE);
SELECT * INTO #ChatbotPageSource FROM (
SELECT f.EnterpriseId,e.BusinessName,DATEFROMPARTS(YEAR(f.ForMonth),MONTH(f.ForMonth),1) ReportMonth,
 f.ForMonth SourcePeriod,f.IsDeleted,f.IsLate,f.Reason,f.CreatedDate,f.LastModifiedDate
 FROM dbo.Report_ReportFiles f
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e ON e.EnterpriseId=f.EnterpriseId AND e.IsActive=1 AND e.IsDeleted=0
 WHERE EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=f.EnterpriseId) AND f.EnterpriseId=@EnterpriseId AND f.ForMonth>=@FromMonth AND f.ForMonth<DATEADD(month,1,@ToMonth)
) materialized OPTION (RECOMPILE);
;WITH Ranked AS(SELECT *,ROW_NUMBER() OVER(ORDER BY ReportMonth DESC,SourcePeriod DESC,CreatedDate DESC) RowNo FROM #ChatbotPageSource),
 Total AS(SELECT COUNT(*) TotalRow FROM #ChatbotPageSource)
 SELECT t.TotalRow,r.EnterpriseId,r.BusinessName,r.ReportMonth,r.SourcePeriod,r.IsDeleted,r.IsLate,r.Reason,r.CreatedDate,r.LastModifiedDate
 FROM Total t OUTER APPLY(SELECT * FROM Ranked WHERE RowNo>@Offset AND RowNo<=CONVERT(bigint,@Offset)+@Limit) r;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Chatbot_Snapshot',N'P',N'PROCEDURE dbo.p_Report_Chatbot_Snapshot @ChatbotUserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500), @ForMonth date, @TypeReport int,
 @WardId int=NULL, @EconomicSectorId int=NULL, @IndustryId int=NULL, @EnterpriseId int=NULL
AS BEGIN
 SET NOCOUNT ON;
 SELECT * INTO #ChatbotScope FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_UserScope(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds);

 IF NOT EXISTS(SELECT 1 FROM #ChatbotScope WHERE CanReadDashboard=1) THROW 50110,''Chatbot dashboard access denied'',1;
 IF @TypeReport NOT IN (1,2,3) OR @TypeReport IS NULL THROW 50001,''Unsupported report type'',1;
 IF @ForMonth IS NULL THROW 50002,''Report month is required'',1;
 DECLARE @Start date=DATEFROMPARTS(YEAR(@ForMonth)-1,1,1);
 DECLARE @End date=DATEADD(month,1,DATEFROMPARTS(YEAR(@ForMonth),MONTH(@ForMonth),1));

 CREATE TABLE #ChatbotEnterprises(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ChatbotEnterprises(EnterpriseId)
 SELECT authorized.EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,1) authorized
 WHERE @EnterpriseId IS NULL OR authorized.EnterpriseId=@EnterpriseId
 OPTION (RECOMPILE);
SELECT * INTO #DashboardCohort FROM (
SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N''Chưa phân loại'' ELSE N''Mã địa bàn ''+CONVERT(nvarchar(20),e.WardId) END) WardName,
 b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N'', '' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),i.IndustryId)+'',%''
 ORDER BY i.IndustryId FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,''''),''''),N''Chưa phân ngành'') IndustryName
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=e.EnterpriseId)
 AND (@TypeReport IS NULL OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@TypeReport)+'',%'')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@IndustryId)+'',%'')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
) materialized OPTION (RECOMPILE);
CREATE CLUSTERED INDEX IX_DashboardCohort ON #DashboardCohort(EnterpriseId);
SELECT * INTO #DashboardImports FROM (
SELECT r.EnterpriseId, DATEFROMPARTS(YEAR(r.ForMonth),MONTH(r.ForMonth),1) ForMonth,
 LTRIM(RTRIM(r.[Level])) IndicatorLevel,r.PerformInPeriod,r.IsLate,r.CreatedDate,r.LastModifiedDate,
 LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(r.Unit,''''),'' '',''''),''.'',''''),CHAR(13),''''),CHAR(10),''''),CHAR(9),'''')) NormalUnit
 FROM dbo.Report_DataImports r WHERE r.IsDeleted=0 AND r.TypeReport=@TypeReport
 AND r.ForMonth>=@Start AND r.ForMonth<@End
 AND EXISTS(SELECT 1 FROM #DashboardCohort c WHERE c.EnterpriseId=r.EnterpriseId)
) materialized OPTION (RECOMPILE);
CREATE CLUSTERED INDEX IX_DashboardImports ON #DashboardImports(EnterpriseId,ForMonth);
;WITH Presence AS (
 SELECT EnterpriseId,ForMonth,CAST(1 AS bit) DataImported,MAX(CAST(IsLate AS int)) ImportLate,
 MIN(CreatedDate) FirstImportedAt,MAX(COALESCE(LastModifiedDate,CreatedDate)) LastImportedAt
 FROM #DashboardImports GROUP BY EnterpriseId,ForMonth
), Mapped AS (
 SELECT *, CASE
 -- TypeReport + Level identifies the fixed template totals across old/new Code formats.
 -- Index moves with product rows. Exact levels exclude product/country/retail detail rows.
 -- Type 1 primary is industrial revenue (1.1), not total enterprise revenue (1).
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN ''1.1'' WHEN 2 THEN ''1'' ELSE ''0'' END THEN ''primary''
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN ''6'' WHEN 2 THEN ''2'' ELSE ''1'' END THEN ''secondary''
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN ''7'' WHEN 2 THEN ''1.1'' ELSE ''2'' END THEN ''tertiary'' END Metric
 FROM #DashboardImports
), MetricGroups AS (
 SELECT EnterpriseId,ForMonth,Metric,COUNT(*) SourceRows,
 MAX(CASE WHEN (@TypeReport=1 AND Metric=''primary'' AND NormalUnit=N''tỷđồng'')
 OR (@TypeReport=1 AND Metric<>''primary'' AND NormalUnit=''1000usd'')
 OR (@TypeReport=2 AND NormalUnit=N''triệuđồng'')
 OR (@TypeReport=3 AND NormalUnit=''usd'') THEN 0 ELSE 1 END) InvalidUnit,
 MAX(CASE WHEN PerformInPeriod IS NOT NULL AND TRY_CONVERT(decimal(28,4),PerformInPeriod) IS NULL THEN 1 ELSE 0 END) InvalidNumber,
 MAX(TRY_CONVERT(decimal(28,4),PerformInPeriod)) SingleValue
 FROM Mapped WHERE Metric IS NOT NULL GROUP BY EnterpriseId,ForMonth,Metric
), Metrics AS (
 SELECT EnterpriseId,ForMonth,
 MAX(CASE WHEN Metric=''primary'' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) PrimaryValue,
 MAX(CASE WHEN Metric=''secondary'' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) SecondaryValue,
 MAX(CASE WHEN Metric=''tertiary'' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) TertiaryValue,
 MAX(CASE WHEN Metric=''primary'' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) PrimaryConflict,
 MAX(CASE WHEN Metric=''secondary'' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) SecondaryConflict,
 MAX(CASE WHEN Metric=''tertiary'' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) TertiaryConflict,
 MAX(CASE WHEN SourceRows>1 THEN 1 ELSE 0 END) DuplicateMetric,
 MAX(InvalidUnit) InvalidUnit,MAX(InvalidNumber) InvalidNumber
 FROM MetricGroups GROUP BY EnterpriseId,ForMonth
), FileRows AS (
 SELECT f.*,DATEFROMPARTS(YEAR(f.ForMonth),MONTH(f.ForMonth),1) ReportMonth,
 ROW_NUMBER() OVER(PARTITION BY EnterpriseId,YEAR(ForMonth),MONTH(ForMonth)
 ORDER BY COALESCE(LastModifiedDate,CreatedDate) DESC,ForMonth DESC) RowNo,
 MAX(CAST(IsLate AS int)) OVER(PARTITION BY EnterpriseId,YEAR(ForMonth),MONTH(ForMonth)) FileLate
 FROM dbo.Report_ReportFiles f WHERE IsDeleted=0 AND ForMonth>=@Start AND ForMonth<@End
 AND EXISTS(SELECT 1 FROM #DashboardCohort c WHERE c.EnterpriseId=f.EnterpriseId)
), Files AS (SELECT * FROM FileRows WHERE RowNo=1), ObservedMonths AS (
 SELECT EnterpriseId,ForMonth FROM Presence UNION SELECT EnterpriseId,ReportMonth FROM Files
 )
 SELECT m.ForMonth,@TypeReport TypeReport,c.*,CAST(ISNULL(p.DataImported,0) AS bit) DataImported,
 CAST(CASE WHEN f.EnterpriseId IS NULL THEN 0 ELSE 1 END AS bit) FileSubmittedAnyType,
 CAST(ISNULL(p.ImportLate,0) AS bit) ImportLate,CAST(ISNULL(f.FileLate,0) AS bit) FileLate,
 p.FirstImportedAt,p.LastImportedAt,f.CreatedDate FileCreatedAt,f.Reason,
 v.PrimaryValue,v.SecondaryValue,v.TertiaryValue,
 CAST(ISNULL(v.PrimaryConflict,0) AS bit) PrimaryConflict,
 CAST(ISNULL(v.SecondaryConflict,0) AS bit) SecondaryConflict,
 CAST(ISNULL(v.TertiaryConflict,0) AS bit) TertiaryConflict,
 CAST(ISNULL(v.DuplicateMetric,0) AS bit) DuplicateMetric,
 CAST(ISNULL(v.InvalidUnit,0) AS bit) InvalidUnit,CAST(ISNULL(v.InvalidNumber,0) AS bit) InvalidNumber,
 CAST(CASE WHEN ISNULL(v.PrimaryConflict,0)+ISNULL(v.SecondaryConflict,0)+ISNULL(v.TertiaryConflict,0)>0 THEN 1 ELSE 0 END AS bit) MetricConflict
 FROM #DashboardCohort c JOIN ObservedMonths m ON m.EnterpriseId=c.EnterpriseId
 LEFT JOIN Presence p ON p.EnterpriseId=c.EnterpriseId AND p.ForMonth=m.ForMonth
 LEFT JOIN Metrics v ON v.EnterpriseId=c.EnterpriseId AND v.ForMonth=m.ForMonth
 LEFT JOIN Files f ON f.EnterpriseId=c.EnterpriseId AND f.ReportMonth=m.ForMonth
 ORDER BY m.ForMonth,c.EnterpriseId;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Chatbot_Summary',N'P',N'PROCEDURE dbo.p_Report_Chatbot_Summary @ChatbotUserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500), @ForMonth date,
 @WardId int=NULL,@EconomicSectorId int=NULL,@IndustryId int=NULL,@EnterpriseId int=NULL,@GroupBy varchar(10)=NULL
AS BEGIN SET NOCOUNT ON;
 SELECT * INTO #ChatbotScope FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_UserScope(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds);

IF NOT EXISTS(SELECT 1 FROM #ChatbotScope WHERE CanReadDashboard=1) THROW 50110,''Chatbot dashboard access denied'',1;

IF @ForMonth IS NULL THROW 50002,''Report month is required'',1;
 IF @GroupBy IS NOT NULL AND @GroupBy NOT IN (''ward'',''sector'') THROW 50005,''Unsupported group'',1;
 DECLARE @TypeReport int=NULL,@MonthStart date=DATEFROMPARTS(YEAR(@ForMonth),MONTH(@ForMonth),1);
 DECLARE @NextMonth date=DATEADD(month,1,@MonthStart);

 CREATE TABLE #ChatbotEnterprises(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ChatbotEnterprises(EnterpriseId)
 SELECT authorized.EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,1) authorized
 OPTION (RECOMPILE);
IF @GroupBy IS NOT NULL BEGIN
 ;WITH Cohort AS (
 SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N''Chưa phân loại'' ELSE N''Mã địa bàn ''+CONVERT(nvarchar(20),e.WardId) END) WardName,
 e.TypeBusiness,b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N'', '' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),i.IndustryId)+'',%''
 ORDER BY i.IndustryId FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,''''),''''),N''Chưa phân ngành'') IndustryName
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=e.EnterpriseId)
 AND (@TypeReport IS NULL OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@TypeReport)+'',%'')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@IndustryId)+'',%'')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
)
 SELECT CASE WHEN @GroupBy=''ward'' THEN WardId ELSE EconomicSectorId END DimensionId,
 COALESCE(CASE WHEN @GroupBy=''ward'' THEN WardName ELSE EconomicSectorName END,N''Chưa phân loại'') DimensionName,
 SUM(CASE WHEN '',''+REPLACE(ISNULL(TypeBusiness,''''),'' '','''')+'','' LIKE ''%,1,%'' THEN 1 ELSE 0 END) Type1Expected,
 SUM(CASE WHEN '',''+REPLACE(ISNULL(TypeBusiness,''''),'' '','''')+'','' LIKE ''%,2,%'' THEN 1 ELSE 0 END) Type2Expected,
 SUM(CASE WHEN '',''+REPLACE(ISNULL(TypeBusiness,''''),'' '','''')+'','' LIKE ''%,3,%'' THEN 1 ELSE 0 END) Type3Expected
 FROM Cohort GROUP BY CASE WHEN @GroupBy=''ward'' THEN WardId ELSE EconomicSectorId END,
 COALESCE(CASE WHEN @GroupBy=''ward'' THEN WardName ELSE EconomicSectorName END,N''Chưa phân loại'');
 RETURN; END;
 ;WITH Cohort AS (
 SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N''Chưa phân loại'' ELSE N''Mã địa bàn ''+CONVERT(nvarchar(20),e.WardId) END) WardName,
 e.TypeBusiness,b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N'', '' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),i.IndustryId)+'',%''
 ORDER BY i.IndustryId FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,''''),''''),N''Chưa phân ngành'') IndustryName
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=e.EnterpriseId)
 AND (@TypeReport IS NULL OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@TypeReport)+'',%'')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@IndustryId)+'',%'')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
), Expected AS (
 SELECT COALESCE(SUM(CASE WHEN '',''+REPLACE(ISNULL(TypeBusiness,''''),'' '','''')+'','' LIKE ''%,1,%'' THEN 1 ELSE 0 END),0) Type1Expected,
 COALESCE(SUM(CASE WHEN '',''+REPLACE(ISNULL(TypeBusiness,''''),'' '','''')+'','' LIKE ''%,2,%'' THEN 1 ELSE 0 END),0) Type2Expected,
 COALESCE(SUM(CASE WHEN '',''+REPLACE(ISNULL(TypeBusiness,''''),'' '','''')+'','' LIKE ''%,3,%'' THEN 1 ELSE 0 END),0) Type3Expected FROM Cohort
 ), Registry AS (
 SELECT COUNT(*) ActiveEnterprises,
 COALESCE(SUM(CASE WHEN b.HasIndustry=1 AND ('',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,1,%'' OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,2,%'' OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,3,%'') THEN 1 ELSE 0 END),0) ConfiguredEnterprises,
 COALESCE(SUM(CASE WHEN b.BusinessRows=0 THEN 1 ELSE 0 END),0) MissingBusinessRow,
 COALESCE(SUM(CASE WHEN ISNULL(b.HasIndustry,0)=0 THEN 1 ELSE 0 END),0) MissingIndustry,
 COALESCE(SUM(CASE WHEN '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' NOT LIKE ''%,1,%'' AND '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' NOT LIKE ''%,2,%'' AND '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' NOT LIKE ''%,3,%'' THEN 1 ELSE 0 END),0) MissingReportType
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e OUTER APPLY (
 SELECT COUNT(*) BusinessRows,MAX(CASE WHEN NULLIF(LTRIM(RTRIM(IndustryIds)),'''') IS NOT NULL THEN 1 ELSE 0 END) HasIndustry
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise WHERE EnterpriseId=e.EnterpriseId) b WHERE e.IsActive=1 AND e.IsDeleted=0
 AND EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=e.EnterpriseId)
 ) SELECT Registry.*,Expected.*,
 (SELECT COUNT(*) FROM dbo.Report_DataImports WHERE EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=dbo.Report_DataImports.EnterpriseId) AND IsDeleted=0 AND (TypeReport IS NULL OR TypeReport NOT IN (1,2,3)) AND ForMonth>=@MonthStart AND ForMonth<@NextMonth) TypeZeroRows,
 (SELECT COUNT(*) FROM dbo.Report_DataImports WHERE EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=dbo.Report_DataImports.EnterpriseId) AND IsDeleted=0 AND ForMonth>=DATEADD(month,1,DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1))) FutureDatedRows,
 (SELECT COUNT(DISTINCT r.EnterpriseId) FROM dbo.Report_DataImports r LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e ON e.EnterpriseId=r.EnterpriseId
 WHERE (EXISTS(SELECT 1 FROM #ChatbotScope WHERE CanReadProvince=1 AND IsIndustryRestricted=0) OR EXISTS(SELECT 1 FROM #ChatbotEnterprises a WHERE a.EnterpriseId=r.EnterpriseId)) AND r.IsDeleted=0 AND r.ForMonth>=@MonthStart AND r.ForMonth<@NextMonth
 AND (e.EnterpriseId IS NULL OR e.IsActive<>1 OR e.IsDeleted<>0 OR r.TypeReport IS NULL OR r.TypeReport NOT IN (1,2,3)
 OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' NOT LIKE ''%,''+CONVERT(varchar(11),r.TypeReport)+'',%'')) OutsideCohortEnterprises
 FROM Registry CROSS JOIN Expected;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Dashboard_FilterOptions_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Dashboard_FilterOptions_IndustryScope @OptionKind varchar(20),@TypeReport int=NULL,
 @Search nvarchar(250)=NULL,@Page int=1,@PageSize int=50,
 @IndustryUserName varchar(255)

AS BEGIN SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,''Report scope unavailable'',1;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 IF @ReportScopeRestricted=1
  INSERT #ReportScope(EnterpriseId)
  SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);

IF @OptionKind NOT IN (''year'',''latest'',''ward'',''sector'',''industry'',''enterprise'') THROW 50006,''Unsupported option kind'',1;
 IF @TypeReport IS NOT NULL AND @TypeReport NOT IN (1,2,3) THROW 50001,''Unsupported report type'',1;
 IF @Page<1 OR @PageSize<1 OR @PageSize>100 THROW 50004,''Invalid page'',1;
 DECLARE @WardId int=NULL,@EconomicSectorId int=NULL,@IndustryId int=NULL,@EnterpriseId int=NULL;
 -- Industry options start with the small business registry, not every enterprise.
 IF @OptionKind=''industry'' BEGIN
 ;WITH Options AS (
 SELECT DISTINCT CONVERT(varchar(20),i.IndustryId) Value,CONVERT(nvarchar(250),i.IndustryName) Text
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e ON e.EnterpriseId=b.EnterpriseId
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
  ON '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),i.IndustryId)+'',%''
 WHERE e.IsActive=1 AND e.IsDeleted=0 AND i.IsActive=1 AND i.IsDeleted=0
 AND (@ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope a WHERE a.EnterpriseId=e.EnterpriseId))
 AND (@TypeReport IS NULL OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@TypeReport)+'',%'')
 ), Filtered AS (SELECT * FROM Options WHERE @Search IS NULL OR @Search='''' OR CHARINDEX(@Search,Text)>0 OR Value=@Search),
 Ranked AS (SELECT *,ROW_NUMBER() OVER(ORDER BY Text,Value) RowNo FROM Filtered),Total AS (SELECT COUNT(*) TotalRow FROM Filtered)
 SELECT t.TotalRow,r.Value,r.Text FROM Total t OUTER APPLY
 (SELECT Value,Text FROM Ranked WHERE RowNo>CONVERT(bigint,@Page-1)*@PageSize AND RowNo<=CONVERT(bigint,@Page)*@PageSize) r OPTION (RECOMPILE);
 RETURN; END;

 ;WITH Cohort AS (
 SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N''Chưa phân loại'' ELSE N''Mã địa bàn ''+CONVERT(nvarchar(20),e.WardId) END) WardName,
 b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N'', '' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),i.IndustryId)+'',%''
 ORDER BY i.IndustryId FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,''''),''''),N''Chưa phân ngành'') IndustryName
 FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND (@TypeReport IS NULL OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@TypeReport)+'',%'')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@IndustryId)+'',%'')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
), Options AS (
 SELECT DISTINCT CONVERT(varchar(20),YEAR(r.ForMonth)) Value,CONVERT(nvarchar(250),YEAR(r.ForMonth)) Text
 FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) r WHERE @OptionKind=''year'' AND r.IsDeleted=0 AND (@TypeReport IS NULL OR r.TypeReport=@TypeReport)
 UNION SELECT DISTINCT CONVERT(varchar(20),YEAR(f.ForMonth)),CONVERT(nvarchar(250),YEAR(f.ForMonth)) FROM (SELECT scope_r.* FROM dbo.Report_ReportFiles scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) f WHERE @OptionKind=''year'' AND f.IsDeleted=0
 UNION SELECT CONVERT(varchar(20),YEAR(GETDATE())),CONVERT(nvarchar(250),YEAR(GETDATE())) WHERE @OptionKind=''year''
 UNION SELECT CONVERT(varchar(20),MAX(ForMonth),23),CONVERT(nvarchar(250),MAX(ForMonth),23) FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) scope_source
 WHERE @OptionKind=''latest'' AND IsDeleted=0 AND TypeReport IN (1,2,3) AND ForMonth<DATEADD(month,1,DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1)) HAVING MAX(ForMonth) IS NOT NULL
 UNION SELECT DISTINCT CONVERT(varchar(20),WardId),CONVERT(nvarchar(250),WardName) FROM Cohort WHERE @OptionKind=''ward'' AND WardId IS NOT NULL
 UNION SELECT DISTINCT CONVERT(varchar(20),EconomicSectorId),CONVERT(nvarchar(250),EconomicSectorName) FROM Cohort WHERE @OptionKind=''sector'' AND EconomicSectorId IS NOT NULL
 UNION SELECT CONVERT(varchar(20),EnterpriseId),CONVERT(nvarchar(250),COALESCE(BusinessName,N'''')+CASE WHEN NULLIF(TaxCode,'''') IS NULL THEN N'''' ELSE N'' · ''+TaxCode END)
 FROM Cohort WHERE @OptionKind=''enterprise''
 ), Filtered AS (SELECT * FROM Options WHERE @Search IS NULL OR @Search='''' OR CHARINDEX(@Search,Text)>0 OR Value=@Search),
 Ranked AS (SELECT *,ROW_NUMBER() OVER(ORDER BY CASE WHEN @OptionKind IN (''year'',''latest'') THEN Value END DESC,Text,Value) RowNo FROM Filtered),
 Total AS (SELECT COUNT(*) TotalRow FROM Filtered)
 SELECT t.TotalRow,r.Value,r.Text FROM Total t OUTER APPLY
 (SELECT Value,Text FROM Ranked WHERE RowNo>CONVERT(bigint,@Page-1)*@PageSize AND RowNo<=CONVERT(bigint,@Page)*@PageSize) r OPTION (RECOMPILE);
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Dashboard_IndustrialSnapshot_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Dashboard_IndustrialSnapshot_IndustryScope @ForMonth date, @TypeReport int,
 @WardId int=NULL, @EconomicSectorId int=NULL, @IndustryId int=NULL, @EnterpriseId int=NULL,
 @IndustryUserName varchar(255)

AS BEGIN
 SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,''Report scope unavailable'',1;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 IF @ReportScopeRestricted=1
  INSERT #ReportScope(EnterpriseId)
  SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);

 IF @TypeReport NOT IN (1,2,3) OR @TypeReport IS NULL THROW 50001,''Unsupported report type'',1;
 IF @ForMonth IS NULL THROW 50002,''Report month is required'',1;
 DECLARE @Start date=DATEFROMPARTS(YEAR(@ForMonth)-1,1,1);
 DECLARE @End date=DATEADD(month,1,DATEFROMPARTS(YEAR(@ForMonth),MONTH(@ForMonth),1));
 SELECT * INTO #DashboardCohort FROM (
SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N''Chưa phân loại'' ELSE N''Mã địa bàn ''+CONVERT(nvarchar(20),e.WardId) END) WardName,
 b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N'', '' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),i.IndustryId)+'',%''
 ORDER BY i.IndustryId FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,''''),''''),N''Chưa phân ngành'') IndustryName
 FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND (@TypeReport IS NULL OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@TypeReport)+'',%'')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@IndustryId)+'',%'')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
) materialized OPTION (RECOMPILE);
CREATE CLUSTERED INDEX IX_DashboardCohort ON #DashboardCohort(EnterpriseId);
SELECT * INTO #DashboardImports FROM (
SELECT r.EnterpriseId, DATEFROMPARTS(YEAR(r.ForMonth),MONTH(r.ForMonth),1) ForMonth,
 LTRIM(RTRIM(r.[Level])) IndicatorLevel,r.PerformInPeriod,r.IsLate,r.CreatedDate,r.LastModifiedDate,
 LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(r.Unit,''''),'' '',''''),''.'',''''),CHAR(13),''''),CHAR(10),''''),CHAR(9),'''')) NormalUnit
 FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) r WHERE r.IsDeleted=0 AND r.TypeReport=@TypeReport
 AND r.ForMonth>=@Start AND r.ForMonth<@End
 AND EXISTS(SELECT 1 FROM #DashboardCohort c WHERE c.EnterpriseId=r.EnterpriseId)
) materialized OPTION (RECOMPILE);
CREATE CLUSTERED INDEX IX_DashboardImports ON #DashboardImports(EnterpriseId,ForMonth);
;WITH Presence AS (
 SELECT EnterpriseId,ForMonth,CAST(1 AS bit) DataImported,MAX(CAST(IsLate AS int)) ImportLate,
 MIN(CreatedDate) FirstImportedAt,MAX(COALESCE(LastModifiedDate,CreatedDate)) LastImportedAt
 FROM #DashboardImports GROUP BY EnterpriseId,ForMonth
), Mapped AS (
 SELECT *, CASE
 -- TypeReport + Level identifies the fixed template totals across old/new Code formats.
 -- Index moves with product rows. Exact levels exclude product/country/retail detail rows.
 -- Type 1 primary is industrial revenue (1.1), not total enterprise revenue (1).
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN ''1.1'' WHEN 2 THEN ''1'' ELSE ''0'' END THEN ''primary''
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN ''6'' WHEN 2 THEN ''2'' ELSE ''1'' END THEN ''secondary''
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN ''7'' WHEN 2 THEN ''1.1'' ELSE ''2'' END THEN ''tertiary'' END Metric
 FROM #DashboardImports
), MetricGroups AS (
 SELECT EnterpriseId,ForMonth,Metric,COUNT(*) SourceRows,
 MAX(CASE WHEN (@TypeReport=1 AND Metric=''primary'' AND NormalUnit=N''tỷđồng'')
 OR (@TypeReport=1 AND Metric<>''primary'' AND NormalUnit=''1000usd'')
 OR (@TypeReport=2 AND NormalUnit=N''triệuđồng'')
 OR (@TypeReport=3 AND NormalUnit=''usd'') THEN 0 ELSE 1 END) InvalidUnit,
 MAX(CASE WHEN PerformInPeriod IS NOT NULL AND TRY_CONVERT(decimal(28,4),PerformInPeriod) IS NULL THEN 1 ELSE 0 END) InvalidNumber,
 MAX(TRY_CONVERT(decimal(28,4),PerformInPeriod)) SingleValue
 FROM Mapped WHERE Metric IS NOT NULL GROUP BY EnterpriseId,ForMonth,Metric
), Metrics AS (
 SELECT EnterpriseId,ForMonth,
 MAX(CASE WHEN Metric=''primary'' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) PrimaryValue,
 MAX(CASE WHEN Metric=''secondary'' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) SecondaryValue,
 MAX(CASE WHEN Metric=''tertiary'' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) TertiaryValue,
 MAX(CASE WHEN Metric=''primary'' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) PrimaryConflict,
 MAX(CASE WHEN Metric=''secondary'' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) SecondaryConflict,
 MAX(CASE WHEN Metric=''tertiary'' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) TertiaryConflict,
 MAX(CASE WHEN SourceRows>1 THEN 1 ELSE 0 END) DuplicateMetric,
 MAX(InvalidUnit) InvalidUnit,MAX(InvalidNumber) InvalidNumber
 FROM MetricGroups GROUP BY EnterpriseId,ForMonth
), FileRows AS (
 SELECT f.*,DATEFROMPARTS(YEAR(f.ForMonth),MONTH(f.ForMonth),1) ReportMonth,
 ROW_NUMBER() OVER(PARTITION BY EnterpriseId,YEAR(ForMonth),MONTH(ForMonth)
 ORDER BY COALESCE(LastModifiedDate,CreatedDate) DESC,ForMonth DESC) RowNo,
 MAX(CAST(IsLate AS int)) OVER(PARTITION BY EnterpriseId,YEAR(ForMonth),MONTH(ForMonth)) FileLate
 FROM (SELECT scope_r.* FROM dbo.Report_ReportFiles scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) f WHERE IsDeleted=0 AND ForMonth>=@Start AND ForMonth<@End
 AND EXISTS(SELECT 1 FROM #DashboardCohort c WHERE c.EnterpriseId=f.EnterpriseId)
), Files AS (SELECT * FROM FileRows WHERE RowNo=1), ObservedMonths AS (
 SELECT EnterpriseId,ForMonth FROM Presence UNION SELECT EnterpriseId,ReportMonth FROM Files
 )
 SELECT m.ForMonth,@TypeReport TypeReport,c.*,CAST(ISNULL(p.DataImported,0) AS bit) DataImported,
 CAST(CASE WHEN f.EnterpriseId IS NULL THEN 0 ELSE 1 END AS bit) FileSubmittedAnyType,
 CAST(ISNULL(p.ImportLate,0) AS bit) ImportLate,CAST(ISNULL(f.FileLate,0) AS bit) FileLate,
 p.FirstImportedAt,p.LastImportedAt,f.CreatedDate FileCreatedAt,f.Reason,
 v.PrimaryValue,v.SecondaryValue,v.TertiaryValue,
 CAST(ISNULL(v.PrimaryConflict,0) AS bit) PrimaryConflict,
 CAST(ISNULL(v.SecondaryConflict,0) AS bit) SecondaryConflict,
 CAST(ISNULL(v.TertiaryConflict,0) AS bit) TertiaryConflict,
 CAST(ISNULL(v.DuplicateMetric,0) AS bit) DuplicateMetric,
 CAST(ISNULL(v.InvalidUnit,0) AS bit) InvalidUnit,CAST(ISNULL(v.InvalidNumber,0) AS bit) InvalidNumber,
 CAST(CASE WHEN ISNULL(v.PrimaryConflict,0)+ISNULL(v.SecondaryConflict,0)+ISNULL(v.TertiaryConflict,0)>0 THEN 1 ELSE 0 END AS bit) MetricConflict
 FROM #DashboardCohort c JOIN ObservedMonths m ON m.EnterpriseId=c.EnterpriseId
 LEFT JOIN Presence p ON p.EnterpriseId=c.EnterpriseId AND p.ForMonth=m.ForMonth
 LEFT JOIN Metrics v ON v.EnterpriseId=c.EnterpriseId AND v.ForMonth=m.ForMonth
 LEFT JOIN Files f ON f.EnterpriseId=c.EnterpriseId AND f.ReportMonth=m.ForMonth
 ORDER BY m.ForMonth,c.EnterpriseId OPTION (RECOMPILE);
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Dashboard_OverviewSummary_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Dashboard_OverviewSummary_IndustryScope @ForMonth date,
 @WardId int=NULL,@EconomicSectorId int=NULL,@IndustryId int=NULL,@EnterpriseId int=NULL,@GroupBy varchar(10)=NULL,
 @IndustryUserName varchar(255)

AS BEGIN SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,''Report scope unavailable'',1;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 IF @ReportScopeRestricted=1
  INSERT #ReportScope(EnterpriseId)
  SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);

IF @ForMonth IS NULL THROW 50002,''Report month is required'',1;
 IF @GroupBy IS NOT NULL AND @GroupBy NOT IN (''ward'',''sector'') THROW 50005,''Unsupported group'',1;
 DECLARE @TypeReport int=NULL,@MonthStart date=DATEFROMPARTS(YEAR(@ForMonth),MONTH(@ForMonth),1);
 DECLARE @NextMonth date=DATEADD(month,1,@MonthStart);
 IF @GroupBy IS NOT NULL BEGIN
 ;WITH Cohort AS (
 SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N''Chưa phân loại'' ELSE N''Mã địa bàn ''+CONVERT(nvarchar(20),e.WardId) END) WardName,
 e.TypeBusiness,b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N'', '' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),i.IndustryId)+'',%''
 ORDER BY i.IndustryId FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,''''),''''),N''Chưa phân ngành'') IndustryName
 FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND (@TypeReport IS NULL OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@TypeReport)+'',%'')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@IndustryId)+'',%'')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
)
 SELECT CASE WHEN @GroupBy=''ward'' THEN WardId ELSE EconomicSectorId END DimensionId,
 COALESCE(CASE WHEN @GroupBy=''ward'' THEN WardName ELSE EconomicSectorName END,N''Chưa phân loại'') DimensionName,
 SUM(CASE WHEN '',''+REPLACE(ISNULL(TypeBusiness,''''),'' '','''')+'','' LIKE ''%,1,%'' THEN 1 ELSE 0 END) Type1Expected,
 SUM(CASE WHEN '',''+REPLACE(ISNULL(TypeBusiness,''''),'' '','''')+'','' LIKE ''%,2,%'' THEN 1 ELSE 0 END) Type2Expected,
 SUM(CASE WHEN '',''+REPLACE(ISNULL(TypeBusiness,''''),'' '','''')+'','' LIKE ''%,3,%'' THEN 1 ELSE 0 END) Type3Expected
 FROM Cohort GROUP BY CASE WHEN @GroupBy=''ward'' THEN WardId ELSE EconomicSectorId END,
 COALESCE(CASE WHEN @GroupBy=''ward'' THEN WardName ELSE EconomicSectorName END,N''Chưa phân loại'') OPTION (RECOMPILE);
 RETURN; END;
 ;WITH Cohort AS (
 SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N''Chưa phân loại'' ELSE N''Mã địa bàn ''+CONVERT(nvarchar(20),e.WardId) END) WardName,
 e.TypeBusiness,b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N'', '' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),i.IndustryId)+'',%''
 ORDER BY i.IndustryId FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,''''),''''),N''Chưa phân ngành'') IndustryName
 FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND (@TypeReport IS NULL OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@TypeReport)+'',%'')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@IndustryId)+'',%'')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
), Expected AS (
 SELECT COALESCE(SUM(CASE WHEN '',''+REPLACE(ISNULL(TypeBusiness,''''),'' '','''')+'','' LIKE ''%,1,%'' THEN 1 ELSE 0 END),0) Type1Expected,
 COALESCE(SUM(CASE WHEN '',''+REPLACE(ISNULL(TypeBusiness,''''),'' '','''')+'','' LIKE ''%,2,%'' THEN 1 ELSE 0 END),0) Type2Expected,
 COALESCE(SUM(CASE WHEN '',''+REPLACE(ISNULL(TypeBusiness,''''),'' '','''')+'','' LIKE ''%,3,%'' THEN 1 ELSE 0 END),0) Type3Expected FROM Cohort
 ), Registry AS (
 SELECT COUNT(*) ActiveEnterprises,
 COALESCE(SUM(CASE WHEN b.HasIndustry=1 AND ('',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,1,%'' OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,2,%'' OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,3,%'') THEN 1 ELSE 0 END),0) ConfiguredEnterprises,
 COALESCE(SUM(CASE WHEN b.BusinessRows=0 THEN 1 ELSE 0 END),0) MissingBusinessRow,
 COALESCE(SUM(CASE WHEN ISNULL(b.HasIndustry,0)=0 THEN 1 ELSE 0 END),0) MissingIndustry,
 COALESCE(SUM(CASE WHEN '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' NOT LIKE ''%,1,%'' AND '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' NOT LIKE ''%,2,%'' AND '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' NOT LIKE ''%,3,%'' THEN 1 ELSE 0 END),0) MissingReportType
 FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e OUTER APPLY (
 SELECT COUNT(*) BusinessRows,MAX(CASE WHEN NULLIF(LTRIM(RTRIM(IndustryIds)),'''') IS NOT NULL THEN 1 ELSE 0 END) HasIndustry
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise WHERE EnterpriseId=e.EnterpriseId) b WHERE e.IsActive=1 AND e.IsDeleted=0
 ) SELECT Registry.*,Expected.*,
 (SELECT COUNT(*) FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) scope_source WHERE IsDeleted=0 AND (TypeReport IS NULL OR TypeReport NOT IN (1,2,3)) AND ForMonth>=@MonthStart AND ForMonth<@NextMonth) TypeZeroRows,
 (SELECT COUNT(*) FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) scope_source WHERE IsDeleted=0 AND ForMonth>=DATEADD(month,1,DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1))) FutureDatedRows,
 (SELECT COUNT(DISTINCT r.EnterpriseId) FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) r LEFT JOIN (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e ON e.EnterpriseId=r.EnterpriseId
 WHERE r.IsDeleted=0 AND r.ForMonth>=@MonthStart AND r.ForMonth<@NextMonth
 AND (e.EnterpriseId IS NULL OR e.IsActive<>1 OR e.IsDeleted<>0 OR r.TypeReport IS NULL OR r.TypeReport NOT IN (1,2,3)
 OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' NOT LIKE ''%,''+CONVERT(varchar(11),r.TypeReport)+'',%'')) OutsideCohortEnterprises
 FROM Registry CROSS JOIN Expected OPTION (RECOMPILE);
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Dashboard_ProgressDetails_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Dashboard_ProgressDetails_IndustryScope @ForMonth date, @TypeReport int,
 @WardId int=NULL, @EconomicSectorId int=NULL, @IndustryId int=NULL, @EnterpriseId int=NULL,
 @Status varchar(20)=''all'',@Page int=1,@PageSize int=50,@Search nvarchar(250)=NULL,
 @IndustryUserName varchar(255)

AS BEGIN
 SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,''Report scope unavailable'',1;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 IF @ReportScopeRestricted=1
  INSERT #ReportScope(EnterpriseId)
  SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);

 IF @TypeReport NOT IN (1,2,3) OR @TypeReport IS NULL THROW 50001,''Unsupported report type'',1;
 IF @ForMonth IS NULL THROW 50002,''Report month is required'',1;
 IF @Status NOT IN (''all'',''missing'',''incomplete'',''complete'',''conflict'',''file-late'') THROW 50003,''Unsupported status'',1;
 IF @Page<1 OR @PageSize<1 OR @PageSize>100 THROW 50004,''Invalid page'',1;
 DECLARE @Start date=DATEFROMPARTS(YEAR(@ForMonth),MONTH(@ForMonth),1),@End date;
 SET @End=DATEADD(month,1,@Start);
 SELECT * INTO #DashboardCohort FROM (
SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N''Chưa phân loại'' ELSE N''Mã địa bàn ''+CONVERT(nvarchar(20),e.WardId) END) WardName,
 b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N'', '' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),i.IndustryId)+'',%''
 ORDER BY i.IndustryId FOR XML PATH(''''),TYPE).value(''.'',''nvarchar(max)''),1,2,''''),''''),N''Chưa phân ngành'') IndustryName
 FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND (@TypeReport IS NULL OR '',''+REPLACE(ISNULL(e.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@TypeReport)+'',%'')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR '',''+REPLACE(ISNULL(b.IndustryIds,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),@IndustryId)+'',%'')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
) materialized OPTION (RECOMPILE);
CREATE CLUSTERED INDEX IX_DashboardCohort ON #DashboardCohort(EnterpriseId);
SELECT * INTO #DashboardImports FROM (
SELECT r.EnterpriseId, DATEFROMPARTS(YEAR(r.ForMonth),MONTH(r.ForMonth),1) ForMonth,
 LTRIM(RTRIM(r.[Level])) IndicatorLevel,r.PerformInPeriod,r.IsLate,r.CreatedDate,r.LastModifiedDate,
 LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(r.Unit,''''),'' '',''''),''.'',''''),CHAR(13),''''),CHAR(10),''''),CHAR(9),'''')) NormalUnit
 FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) r WHERE r.IsDeleted=0 AND r.TypeReport=@TypeReport
 AND r.ForMonth>=@Start AND r.ForMonth<@End
 AND EXISTS(SELECT 1 FROM #DashboardCohort c WHERE c.EnterpriseId=r.EnterpriseId)
) materialized OPTION (RECOMPILE);
CREATE CLUSTERED INDEX IX_DashboardImports ON #DashboardImports(EnterpriseId,ForMonth);
;WITH Presence AS (
 SELECT EnterpriseId,ForMonth,CAST(1 AS bit) DataImported,MAX(CAST(IsLate AS int)) ImportLate,
 MIN(CreatedDate) FirstImportedAt,MAX(COALESCE(LastModifiedDate,CreatedDate)) LastImportedAt
 FROM #DashboardImports GROUP BY EnterpriseId,ForMonth
), Mapped AS (
 SELECT *, CASE
 -- TypeReport + Level identifies the fixed template totals across old/new Code formats.
 -- Index moves with product rows. Exact levels exclude product/country/retail detail rows.
 -- Type 1 primary is industrial revenue (1.1), not total enterprise revenue (1).
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN ''1.1'' WHEN 2 THEN ''1'' ELSE ''0'' END THEN ''primary''
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN ''6'' WHEN 2 THEN ''2'' ELSE ''1'' END THEN ''secondary''
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN ''7'' WHEN 2 THEN ''1.1'' ELSE ''2'' END THEN ''tertiary'' END Metric
 FROM #DashboardImports
), MetricGroups AS (
 SELECT EnterpriseId,ForMonth,Metric,COUNT(*) SourceRows,
 MAX(CASE WHEN (@TypeReport=1 AND Metric=''primary'' AND NormalUnit=N''tỷđồng'')
 OR (@TypeReport=1 AND Metric<>''primary'' AND NormalUnit=''1000usd'')
 OR (@TypeReport=2 AND NormalUnit=N''triệuđồng'')
 OR (@TypeReport=3 AND NormalUnit=''usd'') THEN 0 ELSE 1 END) InvalidUnit,
 MAX(CASE WHEN PerformInPeriod IS NOT NULL AND TRY_CONVERT(decimal(28,4),PerformInPeriod) IS NULL THEN 1 ELSE 0 END) InvalidNumber,
 MAX(TRY_CONVERT(decimal(28,4),PerformInPeriod)) SingleValue
 FROM Mapped WHERE Metric IS NOT NULL GROUP BY EnterpriseId,ForMonth,Metric
), Metrics AS (
 SELECT EnterpriseId,ForMonth,
 MAX(CASE WHEN Metric=''primary'' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) PrimaryValue,
 MAX(CASE WHEN Metric=''secondary'' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) SecondaryValue,
 MAX(CASE WHEN Metric=''tertiary'' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) TertiaryValue,
 MAX(CASE WHEN Metric=''primary'' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) PrimaryConflict,
 MAX(CASE WHEN Metric=''secondary'' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) SecondaryConflict,
 MAX(CASE WHEN Metric=''tertiary'' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) TertiaryConflict,
 MAX(CASE WHEN SourceRows>1 THEN 1 ELSE 0 END) DuplicateMetric,
 MAX(InvalidUnit) InvalidUnit,MAX(InvalidNumber) InvalidNumber
 FROM MetricGroups GROUP BY EnterpriseId,ForMonth
), FileRows AS (
 SELECT f.*,DATEFROMPARTS(YEAR(f.ForMonth),MONTH(f.ForMonth),1) ReportMonth,
 ROW_NUMBER() OVER(PARTITION BY EnterpriseId,YEAR(ForMonth),MONTH(ForMonth)
 ORDER BY COALESCE(LastModifiedDate,CreatedDate) DESC,ForMonth DESC) RowNo,
 MAX(CAST(IsLate AS int)) OVER(PARTITION BY EnterpriseId,YEAR(ForMonth),MONTH(ForMonth)) FileLate
 FROM (SELECT scope_r.* FROM dbo.Report_ReportFiles scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) f WHERE IsDeleted=0 AND ForMonth>=@Start AND ForMonth<@End
 AND EXISTS(SELECT 1 FROM #DashboardCohort c WHERE c.EnterpriseId=f.EnterpriseId)
), Files AS (SELECT * FROM FileRows WHERE RowNo=1), States AS (
 SELECT c.*,CAST(ISNULL(p.DataImported,0) AS bit) DataImported,
 CAST(CASE WHEN f.EnterpriseId IS NULL THEN 0 ELSE 1 END AS bit) FileSubmittedAnyType,
 CAST(ISNULL(p.ImportLate,0) AS bit) ImportLate,CAST(ISNULL(f.FileLate,0) AS bit) FileLate,
 p.FirstImportedAt,p.LastImportedAt,f.CreatedDate FileCreatedAt,f.Reason,
 v.PrimaryValue,v.SecondaryValue,v.TertiaryValue,
 CAST(ISNULL(v.PrimaryConflict,0) AS bit) PrimaryConflict,
 CAST(ISNULL(v.SecondaryConflict,0) AS bit) SecondaryConflict,
 CAST(ISNULL(v.TertiaryConflict,0) AS bit) TertiaryConflict,
 CAST(ISNULL(v.DuplicateMetric,0) AS bit) DuplicateMetric,
 CAST(ISNULL(v.InvalidUnit,0) AS bit) InvalidUnit,CAST(ISNULL(v.InvalidNumber,0) AS bit) InvalidNumber,
 CAST(CASE WHEN ISNULL(v.PrimaryConflict,0)+ISNULL(v.SecondaryConflict,0)+ISNULL(v.TertiaryConflict,0)>0 THEN 1 ELSE 0 END AS bit) MetricConflict
 FROM #DashboardCohort c LEFT JOIN Presence p ON p.EnterpriseId=c.EnterpriseId AND p.ForMonth=@Start
 LEFT JOIN Metrics v ON v.EnterpriseId=c.EnterpriseId AND v.ForMonth=@Start
 LEFT JOIN Files f ON f.EnterpriseId=c.EnterpriseId AND f.ReportMonth=@Start
 )
SELECT * INTO #DashboardFiltered FROM (
SELECT * FROM States WHERE @Status=''all''
 OR (@Status=''missing'' AND DataImported=0)
 OR (@Status=''incomplete'' AND DataImported=1 AND (PrimaryValue IS NULL OR SecondaryValue IS NULL OR TertiaryValue IS NULL))
 OR (@Status=''complete'' AND PrimaryValue IS NOT NULL AND SecondaryValue IS NOT NULL AND TertiaryValue IS NOT NULL)
 OR (@Status=''conflict'' AND MetricConflict=1)
 OR (@Status=''file-late'' AND FileLate=1)
) materialized OPTION (RECOMPILE);
CREATE CLUSTERED INDEX IX_DashboardFiltered ON #DashboardFiltered(EnterpriseId);
;WITH SearchFiltered AS (
 SELECT * FROM #DashboardFiltered WHERE (@Search IS NULL OR CHARINDEX(@Search COLLATE Latin1_General_100_CI_AI,BusinessName COLLATE Latin1_General_100_CI_AI)>0
 OR CHARINDEX(@Search COLLATE Latin1_General_100_CI_AI,TaxCode COLLATE Latin1_General_100_CI_AI)>0
 OR CHARINDEX(@Search COLLATE Latin1_General_100_CI_AI,WardName COLLATE Latin1_General_100_CI_AI)>0)
), Ranked AS (
 SELECT *,ROW_NUMBER() OVER(ORDER BY MetricConflict DESC,DataImported,
 CASE WHEN PrimaryValue IS NULL OR SecondaryValue IS NULL OR TertiaryValue IS NULL THEN 0 ELSE 1 END,BusinessName,EnterpriseId) RowNo FROM SearchFiltered
 ), Total AS (SELECT COUNT(*) TotalRow,(SELECT COUNT(*) FROM #DashboardFiltered) TotalUnfiltered FROM SearchFiltered)
 SELECT t.TotalRow,t.TotalUnfiltered,r.* FROM Total t OUTER APPLY
 (SELECT * FROM Ranked WHERE RowNo>CONVERT(bigint,@Page-1)*@PageSize AND RowNo<=CONVERT(bigint,@Page)*@PageSize) r
 ORDER BY r.RowNo;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Dashboard_StatisticEnterprise_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Dashboard_StatisticEnterprise_IndustryScope

	@OnMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,''Report scope unavailable'',1;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 IF @ReportScopeRestricted=1
  INSERT #ReportScope(EnterpriseId)
  SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);

	DECLARE @TotalEnterpriseSubmitReportLate INT,
	        @TotalEnterpriseNotSubmitReportYet INT,
	        @TotalReportSubmited     INT,
	        @TotalEnterprise         INT;
	WITH Enterprise_Late AS (
	    SELECT DISTINCT rdi.EnterpriseId
	    FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) AS rdi
	    WHERE  (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@OnMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@OnMonth)+1,0))
	           AND rdi.IsLate = 1
	),
	Enterprise_Not_SumitReport AS (
	    SELECT DISTINCT ce.EnterpriseId
	    FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) AS ce
	    WHERE  NOT EXISTS (
	               SELECT 1
	               FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) AS rdi
	               WHERE  (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@OnMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@OnMonth)+1,0))
	                      AND rdi.EnterpriseId = ce.EnterpriseId
	           )
	           AND ce.IsDeleted = 0
	           AND ce.IsActive = 1
	),
	Total_Report AS (
	    SELECT DISTINCT rdi.EnterpriseId
	    FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) AS rdi
	    WHERE  (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@OnMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@OnMonth)+1,0))
	),
	Total_Enterprise AS (
	    SELECT DISTINCT ce.EnterpriseId
	    FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) AS ce
	    WHERE  ce.IsDeleted = 0
	           AND ce.IsActive = 1
	)

	SELECT @OnMonth  AS OnMonth,
	       (
	           SELECT COUNT(*)
	           FROM   Enterprise_Late
	       )         AS TotalEnterpriseSubmitReportLate,
	       (
	           SELECT COUNT(*)
	           FROM   Enterprise_Not_SumitReport
	       )         AS TotalEnterpriseNotSubmitReportYet,
	       (
	           SELECT COUNT(*)
	           FROM   Total_Report
	       )         AS TotalReportSubmited,
	       (
	           SELECT COUNT(*)
	           FROM   Total_Enterprise
	       )         AS TotalEnterprise OPTION (RECOMPILE)
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Dashboard_StatisticIncome_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Dashboard_StatisticIncome_IndustryScope

	@OnMonth DATETIME,
	@TypeStatistic INT,
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);












	WITH Months(MonthNum)
	AS
	(
	    SELECT DATEADD(yy, DATEDIFF(yy, 0, @OnMonth), 0)
	    UNION ALL
	    SELECT DATEADD(MONTH, 1, MonthNum)
	    FROM   Months
	    WHERE  DATEADD(MONTH, 1, MonthNum) <= DATEADD(yy, DATEDIFF(yy, 0, @OnMonth) + 1, -1)
	)










	, PeriodMonths(MonthNum) AS
	(
	    SELECT DATEADD(yy, DATEDIFF(yy, 0, DATEADD(YEAR, -1, @OnMonth)), 0)
	    UNION ALL
	    SELECT DATEADD(MONTH, 1, MonthNum)
	    FROM   PeriodMonths
	    WHERE  DATEADD(MONTH, 1, MonthNum) <= DATEADD(yy, DATEDIFF(yy, 0, DATEADD(YEAR, -1, @OnMonth)) + 1, -1)
	)











	, DataIncome AS(
	    SELECT m.MonthNum  AS OnMonth,
	           CAST(ISNULL(SUM(rdi.PerformInPeriod), 0) AS FLOAT) AS TotalIncome

	    FROM   Months      AS m
	           LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	                ON  (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,m.MonthNum),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,m.MonthNum)+1,0))

	                AND (
	                        (
	                            @TypeStatistic = 1
	                            AND rdi.Code IN (''31'', ''32'', ''33'', ''11'', ''12'', ''13'')
	                        )
	                        OR (
	                               @TypeStatistic = 2
	                               AND rdi.Code IN (''A21'', ''A22'', ''A23'', ''18'', ''19'', ''20'')
	                           )

	                        OR (
	                               @TypeStatistic = 3
	                               AND (
	                                       (
	                                           rdi.Code IN (''31'', ''32'', ''33'', ''11'', ''12'', ''13'')
	                                           AND rdi.TypeReport = 1
	                                       )
	                                       OR (
	                                              rdi.Code IN (''A21'', ''A22'', ''A23'', ''18'', ''19'', ''20'')
	                                              AND rdi.TypeReport = 2
	                                          )
	                                       OR (rdi.Code IN (''03'', ''04'', ''05'') AND rdi.TypeReport = 3)
	                                   )
	                           )
	                    )
	    GROUP BY
	           m.MonthNum
	)
	, DataPeriodIncome AS(
	    SELECT m.MonthNum    AS OnMonth,
	           CAST(ISNULL(SUM(rdi.PerformInPeriod), 0) AS FLOAT) AS TotalIncome

	    FROM   PeriodMonths  AS m
	           LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	                ON  (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,m.MonthNum),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,m.MonthNum)+1,0))

	                AND (
	                        (
	                            @TypeStatistic = 1
	                            AND rdi.Code IN (''31'', ''32'', ''33'', ''11'', ''12'', ''13'')
	                        )
	                        OR (
	                               @TypeStatistic = 2
	                               AND rdi.Code IN (''A21'', ''A22'', ''A23'', ''18'', ''19'', ''20'')
	                           )

	                        OR (
	                               @TypeStatistic = 3
	                               AND (
	                                       (
	                                           rdi.Code IN (''31'', ''32'', ''33'', ''11'', ''12'', ''13'')
	                                           AND rdi.TypeReport = 1
	                                       )
	                                       OR (
	                                              rdi.Code IN (''A21'', ''A22'', ''A23'', ''18'', ''19'', ''20'')
	                                              AND rdi.TypeReport = 2
	                                          )
	                                       OR (rdi.Code IN (''03'', ''04'', ''05'') AND rdi.TypeReport = 3)
	                                   )
	                           )
	                    )
	    GROUP BY
	           m.MonthNum
	)

	SELECT dpi.OnMonth                 AS OnPeriodMonth,
	       di.OnMonth,
	       dpi.TotalIncome             AS TotalIncomePeriod,
	       di.TotalIncome
	FROM   DataIncome                  AS di
	       LEFT JOIN DataPeriodIncome  AS dpi
	            ON  MONTH(dpi.OnMonth) = MONTH(di.OnMonth)
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Dashboard_StatisticMapVisitor_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Dashboard_StatisticMapVisitor_IndustryScope

	@OnMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	SELECT cn.NationalCodeAlpha2 AS NationalCode,

	       CAST(ISNULL(SUM(rdi.PerformInPeriod), 0) AS INT) AS TotalVisitor

	FROM   [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Nationals AS cn
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	            ON  cn.NationalCode = rdi.Code
	            AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@OnMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@OnMonth)+1,0))




	WHERE cn.NationalCodeAlpha2 IS NOT NULL
	GROUP BY
	       cn.NationalCodeAlpha2

END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Dashboard_StatisticTypeBusiness_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Dashboard_StatisticTypeBusiness_IndustryScope
	@OnMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,''Report scope unavailable'',1;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 IF @ReportScopeRestricted=1
  INSERT #ReportScope(EnterpriseId)
  SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	WITH TypeBusiness AS (
	    SELECT 1                    AS TypeBusiness,
	           N''Lĩnh vực Lưu trú''  AS TypeBusinessName,
	           ''primary''            AS MainColor
	    UNION
	    SELECT 2                    AS TypeBusiness,
	           N''Lĩnh vực Lữ hành''  AS TypeBusinessName,
	           ''success''            AS MainColor
	    UNION
	    SELECT 3       AS TypeBusiness,
	           N''Lĩnh vực Vận chuyển hành khách'' AS TypeBusinessName,
	           ''info''  AS MainColor
	    UNION
	    SELECT 4          AS TypeBusiness,
	           N''Lĩnh vực Địa điểm/Khu du lịch'' AS TypeBusinessName,
	           ''warning''  AS MainColor
	    UNION
	    SELECT 5         AS TypeBusiness,
	           N''Lĩnh vực Phục vụ khách du lịch'' AS TypeBusinessName,
	           ''danger''  AS MainColor
	)
	,Total_Enterprise AS (
	    SELECT DISTINCT ce.EnterpriseId
	    FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) AS ce
	    WHERE  ce.IsDeleted = 0
	           AND ce.IsActive = 1
	)
	SELECT tb.TypeBusiness,
	       tb.TypeBusinessName,
	       tb.MainColor,
	       COUNT(DISTINCT ce.EnterpriseId) AS TotalEnterpiseViaType,
	       (
	           SELECT COUNT(*)
	           FROM   Total_Enterprise
	       )             AS TotalEnterpise
	FROM   TypeBusiness  AS tb
	       LEFT OUTER JOIN (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) AS ce
	            ON  '',''+REPLACE(ISNULL(ce.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+CONVERT(varchar(11),tb.TypeBusiness)+'',%''
	            AND ce.IsDeleted = 0
	            AND ce.IsActive = 1
	GROUP BY
	       tb.TypeBusiness,
	       tb.TypeBusinessName,
	       tb.MainColor OPTION (RECOMPILE)
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Dashboard_StatisticVisitor_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Dashboard_StatisticVisitor_IndustryScope

	@OnMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);













	WITH Months(MonthNum)
     AS
     (
         SELECT DATEADD(yy, DATEDIFF(yy, 0, @OnMonth), 0)
         UNION ALL
         SELECT DATEADD(MONTH, 1, MonthNum)
         FROM   Months
         WHERE  DATEADD(MONTH, 1, MonthNum) <= DATEADD(yy, DATEDIFF(yy, 0, @OnMonth) + 1, -1)
     )

	SELECT m.MonthNum  AS OnMonth,
	       CAST(ISNULL(SUM(rdi.PerformInPeriod), 0) AS INT) AS TotalVisitor
	FROM   Months      AS m
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	            ON  (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,m.MonthNum),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,m.MonthNum)+1,0))
	            AND rdi.Code IN (''1G1'', ''05'')
	GROUP BY
	       m.MonthNum
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_DataImports_CheckOwnership',N'P',N'PROCEDURE dbo.p_Report_DataImports_CheckOwnership
 @EnterpriseId int,@ForMonth datetime,@TypeReport int,@Operation varchar(10),@UserName varchar(255)
AS BEGIN
 SET NOCOUNT ON;
 IF @Operation NOT IN(''Import'',''Delete'') THROW 50112,''Invalid operational write kind'',1;
 DECLARE @Manage bit;
 SELECT @Manage=CanManageAllRecords FROM dbo.f_Report_DataImportEnterprises(@UserName) WHERE EnterpriseId=@EnterpriseId;
 SELECT CONVERT(bit,CASE WHEN @Manage=1 THEN 1
 WHEN @Manage=0 AND @ForMonth IS NOT NULL
 AND EXISTS(SELECT 1 FROM dbo.Report_DataImports r WHERE r.EnterpriseId=@EnterpriseId
  AND r.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND r.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0)
  AND (@Operation=''Delete'' OR @TypeReport IS NULL OR @TypeReport=0 OR r.TypeReport=@TypeReport))
 AND NOT EXISTS(SELECT 1 FROM dbo.Report_DataImports r WHERE r.EnterpriseId=@EnterpriseId
  AND r.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND r.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0)
  AND (@Operation=''Delete'' OR @TypeReport IS NULL OR @TypeReport=0 OR r.TypeReport=@TypeReport)
  AND (r.CreatedBy IS NULL OR r.CreatedBy<>@UserName))
 AND (@Operation=''Delete'' OR NOT EXISTS(SELECT 1 FROM dbo.Report_ReportFiles f WHERE f.EnterpriseId=@EnterpriseId
  AND f.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND f.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0)
  AND (f.CreatedBy IS NULL OR f.CreatedBy<>@UserName)))
 THEN 1 ELSE 0 END) CanWrite;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_DataImports_Enterprises_SearchSelect2',N'P',N'PROCEDURE dbo.p_Report_DataImports_Enterprises_SearchSelect2
 @Keyword nvarchar(250)=NULL,@TypeBusiness varchar(50)=NULL,
 @PageIndex int=0,@PageSize int=20,@IndustryUserName varchar(255)
AS
BEGIN
 SET NOCOUNT ON;
 SET @PageIndex=CASE WHEN ISNULL(@PageIndex,0)<0 THEN 0 ELSE ISNULL(@PageIndex,0) END;
 SET @PageSize=CASE WHEN ISNULL(@PageSize,20)<1 THEN 20 WHEN @PageSize>100 THEN 100 ELSE ISNULL(@PageSize,20) END;
 SET @Keyword=NULLIF(LTRIM(RTRIM(@Keyword)),N'''');
 SET @TypeBusiness=NULLIF(LTRIM(RTRIM(@TypeBusiness)),'''');
 ;WITH Paged AS (
  SELECT ce.EnterpriseId,ce.BusinessName,ce.TaxCode,ce.TypeBusiness,
   ROW_NUMBER() OVER(ORDER BY ce.BusinessName,ce.EnterpriseId) RowNum,COUNT(*) OVER() TotalRow
  FROM dbo.f_Report_DataImportEnterprises(@IndustryUserName) ce
  WHERE ce.IsApproved=1
   AND (@TypeBusiness IS NULL OR '',''+REPLACE(ISNULL(ce.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+@TypeBusiness+'',%'')
   AND (@Keyword IS NULL OR ce.BusinessName LIKE N''%''+@Keyword+N''%'' OR ce.TaxCode LIKE N''%''+@Keyword+N''%'')
 )
 SELECT EnterpriseId,BusinessName,TaxCode,TypeBusiness,TotalRow FROM Paged
 WHERE RowNum>CONVERT(bigint,@PageIndex)*@PageSize AND RowNum<=(CONVERT(bigint,@PageIndex)+1)*@PageSize
 ORDER BY RowNum;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_DataImports_GenerateSaleOfTourism_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_DataImports_GenerateSaleOfTourism_IndustryScope

	@ForMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @temp TABLE([Targets] NVARCHAR(1500),Unit NVARCHAR(1500),PerformPreviousPeriod FLOAT, PerformInPeriod FLOAT, SamePeriodRateOfPerform FLOAT, AccumulatedBeginingOfYear FLOAT, SamePeriodRateOfAccumulated FLOAT, [Level] VARCHAR(10));
	INSERT INTO @temp([Targets],Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear,SamePeriodRateOfAccumulated,[Level])
	VALUES(N''1. Về cơ sở lưu trú du lịch'',''-'', NULL,NULL,NULL,NULL,NULL,''1'')

	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_Sum_IndustryScope @Title=N''1.1 Tổng số lượt khách phục vụ'', @ForMonth=@ForMonth, @Code1=N''1G1'', @Code2=N''1G2'', @Code3='''', @Level=''1.1'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N''- Khách quốc tế'', @ForMonth=@ForMonth, @Code=N''1G1'', @Level=''1.1.1'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N''- Khách nội địa'', @ForMonth=@ForMonth, @Code=N''1G2'', @Level=''1.1.2'', @IndustryUserName=@IndustryUserName;


	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_Sum_IndustryScope @Title=N''1.2 Tổng số ngày khách lưu trú'', @ForMonth=@ForMonth, @Code1=N''1D1'', @Code2=N''1D2'', @Code3='''', @Level=''1.2'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N''- Ngày khách quốc tế'', @ForMonth=@ForMonth, @Code=N''1D1'', @Level=''1.2.1'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N''- Ngày khách nội địa'', @ForMonth=@ForMonth, @Code=N''1D2'', @Level=''1.2.2'', @IndustryUserName=@IndustryUserName;



	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForAVG_IndustryScope @Title=N''1.4 Công suất sử dụng phòng bình quân'', @ForMonth=@ForMonth, @Unit=N''%'', @Level=''1.4'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope @Title=N''- Hạng cơ sở lưu trú 5 sao'', @ForMonth=@ForMonth, @Unit=N''%'', @Class=5, @Level=''1.4.1'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope @Title=N''- Hạng cơ sở lưu trú 4 sao'', @ForMonth=@ForMonth, @Unit=N''%'', @Class=4, @Level=''1.4.2'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope @Title=N''- Hạng cơ sở lưu trú 3 sao'', @ForMonth=@ForMonth, @Unit=N''%'', @Class=3, @Level=''1.4.3'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope @Title=N''- Hạng cơ sở lưu trú 2 sao'', @ForMonth=@ForMonth, @Unit=N''%'', @Class=2, @Level=''1.4.4'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope @Title=N''- Hạng cơ sở lưu trú 1 sao'', @ForMonth=@ForMonth, @Unit=N''%'', @Class=1, @Level=''1.4.5'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForOther_IndustryScope @Title=N''- Khác'', @ForMonth=@ForMonth, @Unit=N''%'', @Level=''1.4.6'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumAmount_IndustryScope @Title=N''1.5 Tổng doanh thu các cơ sở lưu trú'', @ForMonth=@ForMonth, @Unit=N''Đồng'', @Code = ''3%'',@Level=''1.5'', @IndustryUserName=@IndustryUserName;

	INSERT INTO @temp([Targets],Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear,SamePeriodRateOfAccumulated,[Level])
	VALUES(N''2. Về doanh nghiệp lữ hành, vận chuyển khách du lịch'',''-'', NULL,NULL,NULL,NULL,NULL,''2'')

	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_Sum_IndustryScope @Title=N''2.1 Tổng số lượt khách phục vụ'', @ForMonth=@ForMonth, @Code1=N''A11'', @Code2=''A12'', @Code3=''A13'',@Level=''2.1'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N''- Khách quốc tế đến'', @ForMonth=@ForMonth, @Code=N''A11'', @Level=''2.1.1'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N''- Khách nội địa'',@ForMonth=@ForMonth, @Code=N''A12'', @Level=''2.1.2'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N''- Khách Việt Nam đi nước ngoài'', @ForMonth=@ForMonth, @Code=N''A13'', @Level=''2.1.3'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_Sum_IndustryScope @Title=N''2.2 Tổng doanh thu từ doanh nghiệp lữ hành, vận chuyển khách du lịch'', @ForMonth=@ForMonth, @Code1=N''A21'', @Code2=''A22'', @Code3=''A23'', @Level=''2.2'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N''- Khách quốc tế đến'', @ForMonth=@ForMonth, @Code=N''A21'', @Level=''2.2.1'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N''- Khách nội địa'', @ForMonth=@ForMonth, @Code=N''A22'', @Level=''2.2.2'', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N''- Khách Việt Nam đi nước ngoài'', @ForMonth=@ForMonth, @Code=N''A23'', @Level=''2.2.3'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope @Title=N''2.3 Khách du lịch đến Khánh Hòa bằng tàu biển'', @ForMonth=@ForMonth, @Level=N''2.3'', @IndustryUserName=@IndustryUserName;

	INSERT INTO @temp (	Targets,Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear, SamePeriodRateOfAccumulated,[Level])
	SELECT N''1.3 Ngày khách lưu trú bình quân'',N''Ngày'', ISNULL((SELECT isnull(t12.PerformPreviousPeriod,0) FROM @temp t12 WHERE t12.[Level]=''1.2'')/(SELECT nullif(t11.PerformPreviousPeriod,0) FROM @temp t11 WHERE t11.[Level]=''1.1''),0),
														ISNULL((SELECT isnull(t12.PerformInPeriod,0) FROM @temp t12 WHERE t12.[Level]=''1.2'')/(SELECT nullif(t11.PerformInPeriod,0) FROM @temp t11 WHERE t11.[Level]=''1.1''),0),
														ISNULL((SELECT isnull(t12.SamePeriodRateOfPerform,0) FROM @temp t12 WHERE t12.[Level]=''1.2'')/(SELECT nullif(t11.SamePeriodRateOfPerform,0) FROM @temp t11 WHERE t11.[Level]=''1.1''),0),
														ISNULL((SELECT isnull(t12.AccumulatedBeginingOfYear,0) FROM @temp t12 WHERE t12.[Level]=''1.2'')/(SELECT nullif(t11.AccumulatedBeginingOfYear,0) FROM @temp t11 WHERE t11.[Level]=''1.1''),0),
														ISNULL((SELECT isnull(t12.SamePeriodRateOfAccumulated,0) FROM @temp t12 WHERE t12.[Level]=''1.2'')/(SELECT nullif(t11.SamePeriodRateOfAccumulated,0) FROM @temp t11 WHERE t11.[Level]=''1.1''),0),
														''1.3''

	INSERT INTO @temp (	Targets,Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear, SamePeriodRateOfAccumulated,[Level])
	SELECT N''- Khách quốc tế'',N''Ngày'', ISNULL((SELECT isnull(t12.PerformPreviousPeriod,0) FROM @temp t12 WHERE t12.[Level]=''1.2.1'')/(SELECT nullif(t11.PerformPreviousPeriod,0) FROM @temp t11 WHERE t11.[Level]=''1.1.1''),0),
														ISNULL((SELECT isnull(t12.PerformInPeriod,0) FROM @temp t12 WHERE t12.[Level]=''1.2.1'')/(SELECT nullif(t11.PerformInPeriod,0) FROM @temp t11 WHERE t11.[Level]=''1.1.1''),0),
														ISNULL((SELECT isnull(t12.SamePeriodRateOfPerform,0) FROM @temp t12 WHERE t12.[Level]=''1.2.1'')/(SELECT nullif(t11.SamePeriodRateOfPerform,0) FROM @temp t11 WHERE t11.[Level]=''1.1.1''),0),
														ISNULL((SELECT isnull(t12.AccumulatedBeginingOfYear,0) FROM @temp t12 WHERE t12.[Level]=''1.2.1'')/(SELECT nullif(t11.AccumulatedBeginingOfYear,0) FROM @temp t11 WHERE t11.[Level]=''1.1.1''),0),
														ISNULL((SELECT isnull(t12.SamePeriodRateOfAccumulated,0) FROM @temp t12 WHERE t12.[Level]=''1.2.1'')/(SELECT nullif(t11.SamePeriodRateOfAccumulated,0) FROM @temp t11 WHERE t11.[Level]=''1.1.1''),0),
														''1.3.1''
	INSERT INTO @temp (	Targets,Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear, SamePeriodRateOfAccumulated,[Level])
	SELECT N''- Khách nội địa'',N''Ngày'', ISNULL((SELECT isnull(t12.PerformPreviousPeriod,0) FROM @temp t12 WHERE t12.[Level]=''1.2.2'')/(SELECT nullif(t11.PerformPreviousPeriod,0) FROM @temp t11 WHERE t11.[Level]=''1.1.2''),0),
														ISNULL((SELECT isnull(t12.PerformInPeriod,0) FROM @temp t12 WHERE t12.[Level]=''1.2.2'')/(SELECT nullif(t11.PerformInPeriod,0) FROM @temp t11 WHERE t11.[Level]=''1.1.2''),0),
														ISNULL((SELECT isnull(t12.SamePeriodRateOfPerform,0) FROM @temp t12 WHERE t12.[Level]=''1.2.2'')/(SELECT nullif(t11.SamePeriodRateOfPerform,0) FROM @temp t11 WHERE t11.[Level]=''1.1.2''),0),
														ISNULL((SELECT isnull(t12.AccumulatedBeginingOfYear,0) FROM @temp t12 WHERE t12.[Level]=''1.2.2'')/(SELECT nullif(t11.AccumulatedBeginingOfYear,0) FROM @temp t11 WHERE t11.[Level]=''1.1.2''),0),
														ISNULL((SELECT isnull(t12.SamePeriodRateOfAccumulated,0) FROM @temp t12 WHERE t12.[Level]=''1.2.2'')/(SELECT nullif(t11.SamePeriodRateOfAccumulated,0) FROM @temp t11 WHERE t11.[Level]=''1.1.2''),0),
														''1.3.2''

	INSERT @temp Exec dbo.p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope @Title=N''3. Lượt khách tham quan du lịch'', @ForMonth=@ForMonth, @Code1=N''A11'',@Code2=N''A12'',@Code3='''', @Level=''3'', @IndustryUserName=@IndustryUserName;


	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope @Title=N''4. Tổng thu từ khách du lịch trên địa bàn tỉnh Khánh Hòa'',@ForMonth=@ForMonth, @Unit=N''Đồng'', @Code1=N''1D1'', @Code2=N''1D2'', @Level=''4'', @IndustryUserName=@IndustryUserName;
	SELECT t.[Targets], t.Unit, t.PerformPreviousPeriod,t.PerformInPeriod, ROUND(t.SamePeriodRateOfPerform,2) AS SamePeriodRateOfPerform ,t.AccumulatedBeginingOfYear, ROUND(t.SamePeriodRateOfAccumulated,2) AS SamePeriodRateOfAccumulated
	FROM @temp t
	ORDER BY t.[Level]
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_DataImports_Get_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_DataImports_Get_IndustryScope
	@ForEmp VARCHAR(500),
	@EnterpriseIds VARCHAR(500),
	@FromMonth DATETIME,
	@ToMonth DATETIME,
	@TypeBusinessIds VARCHAR(500),
	@Search NVARCHAR(250),
	@Order VARCHAR(3),
	@OrderDir VARCHAR(10),
	@PageIndex INT,
	@PageSize INT,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);

 IF @ForEmp<>@IndustryUserName OR @ForEmp IS NULL THROW 50112,''Report subject mismatch'',1;


	SET @Order = ISNULL(@Order, ''0'')
	SET @OrderDir = ISNULL(@OrderDir, ''ASC'')
	SET @PageIndex = ISNULL(@PageIndex, 0)
	SET @PageSize = ISNULL(@PageSize, 10)

	DECLARE @DayDeadlineSendReportLate INT;
	SELECT @DayDeadlineSendReportLate = CAST(ISNULL(sc.ConfigValue, 0) AS INT)
	FROM   [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Configs AS sc
	WHERE  sc.ConfigKey = ''Day_Deadline_Send_Late_Report''
	       AND sc.IsDeleted = 0


;WITH D AS (
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
	           INNER JOIN (SELECT enterprise.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises enterprise JOIN #ReportScope scope ON scope.EnterpriseId=enterprise.EnterpriseId) AS ce
	                ON  ce.EnterpriseId = rdi.EnterpriseId
	           LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions AS cep
	                ON  cep.EnterpriseId = ce.EnterpriseId
	                AND cep.ForUser = @ForEmp
	           LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users AS su
	                ON  rdi.CreatedBy = su.UserName
	    WHERE  rdi.IsDeleted = 0
	           AND (
	                   @EnterpriseIds IS NULL OR @EnterpriseIds = ''''
	                   OR EXISTS (
	                          SELECT 1
	                          FROM   dbo.fnSplit(@EnterpriseIds, '','') AS t
	                          WHERE  CAST(t.Name AS INT) = rdi.EnterpriseId
	                      )
	               )
	           AND (
	                   @FromMonth IS NULL
	                   OR rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@FromMonth),0)
	               )
	           AND (
	                   @ToMonth IS NULL
	                   OR rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ToMonth)+1,0)
	               )
	           AND (
	                   @Search IS NULL OR @Search = ''''
	                   OR ce.BusinessName LIKE N''%'' + @Search + ''%''
	                   OR rdi.TypeReportName LIKE N''%'' + @Search + ''%''
	               )
	           AND (
	                   @TypeBusinessIds IS NULL OR @TypeBusinessIds = ''''
	                   OR EXISTS (
	                          SELECT 1
	                          FROM   dbo.fnSplit(@TypeBusinessIds, '','') AS t
	                          WHERE  CAST(t.Name AS INT) = rdi.TypeReport
	                      )
	               )
	    GROUP BY
	           rdi.EnterpriseId,
	           ce.BusinessName,
	           rdi.ForMonth,
	           rdi.TypeReport,
	           rdi.TypeReportName,
	           rdi.IsLate,
	           su.FullName,
	           rdi.CreatedDate
	),
	T AS (
	    SELECT ROW_NUMBER() OVER(
	               ORDER BY
	                    CASE WHEN @Order = ''0'' THEN nt.CreatedDate END ASC,
	                    CASE WHEN @Order = ''1'' THEN nt.EnterpriseName END ASC,
	                    CASE WHEN @Order = ''2'' THEN nt.ForMonth END ASC,
	                    CASE WHEN @Order = ''3'' THEN nt.TypeReportName END ASC,
	                    CASE WHEN @Order = ''4'' THEN nt.CreatedBy END ASC
	           ) AS RowIndex,
	           nt.EnterpriseId,
	           nt.EnterpriseName,
	           nt.ForMonth,
	           nt.TypeReport,
	           nt.TypeReportName,
	           nt.IsLate,
	           nt.CanDelete,
	           nt.CreatedBy,
	           nt.CreatedDate
	    FROM   D  AS nt
	    WHERE  UPPER(@OrderDir) = ''ASC''
	    UNION ALL
	    SELECT ROW_NUMBER() OVER(
	               ORDER BY
	                    CASE WHEN @Order = ''0'' THEN nt.CreatedDate END DESC,
	                    CASE WHEN @Order = ''1'' THEN nt.EnterpriseName END DESC,
	                    CASE WHEN @Order = ''2'' THEN nt.ForMonth END DESC,
	                    CASE WHEN @Order = ''3'' THEN nt.TypeReportName END DESC,
	                    CASE WHEN @Order = ''4'' THEN nt.CreatedBy END DESC
	           ) AS RowIndex,
	           nt.EnterpriseId,
	           nt.EnterpriseName,
	           nt.ForMonth,
	           nt.TypeReport,
	           nt.TypeReportName,
	           nt.IsLate,
	           nt.CanDelete,
	           nt.CreatedBy,
	           nt.CreatedDate
	    FROM   D  AS nt
	    WHERE  UPPER(@OrderDir) = ''DESC''
	)
	SELECT T.*,
	       (
	           SELECT COUNT(RowIndex)
	           FROM   T
	       ) AS TotalRow
	FROM   T
	WHERE  (
	           @PageSize > 0
	           AND T.RowIndex BETWEEN @PageIndex + 1 AND @PageIndex + @PageSize
	       )
	       OR  @PageSize <= 0 OPTION (RECOMPILE)
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_DataImports_Get_Operational',N'P',N'PROCEDURE dbo.p_Report_DataImports_Get_Operational
	@ForEmp VARCHAR(500),
	@EnterpriseIds VARCHAR(500),
	@FromMonth DATETIME,
	@ToMonth DATETIME,
	@TypeBusinessIds VARCHAR(500),
	@Search NVARCHAR(250),
	@Order VARCHAR(3),
	@OrderDir VARCHAR(10),
	@PageIndex INT,
	@PageSize INT,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY,CanManageAllRecords bit NOT NULL);
 INSERT #ReportScope SELECT EnterpriseId,CanManageAllRecords FROM dbo.f_Report_DataImportEnterprises(@IndustryUserName);

 IF @ForEmp<>@IndustryUserName OR @ForEmp IS NULL THROW 50112,''Report subject mismatch'',1;


	SET @Order = ISNULL(@Order, ''0'')
	SET @OrderDir = ISNULL(@OrderDir, ''ASC'')
	SET @PageIndex = ISNULL(@PageIndex, 0)
	SET @PageSize = ISNULL(@PageSize, 10)

	DECLARE @DayDeadlineSendReportLate INT;
	SELECT @DayDeadlineSendReportLate = CAST(ISNULL(sc.ConfigValue, 0) AS INT)
	FROM   [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Configs AS sc
	WHERE  sc.ConfigKey = ''Day_Deadline_Send_Late_Report''
	       AND sc.IsDeleted = 0


;WITH D AS (
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
	           INNER JOIN (SELECT enterprise.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises enterprise JOIN #ReportScope scope ON scope.EnterpriseId=enterprise.EnterpriseId) AS ce
	                ON  ce.EnterpriseId = rdi.EnterpriseId
	           LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions AS cep
	                ON  cep.EnterpriseId = ce.EnterpriseId
	                AND cep.ForUser = @ForEmp
	           LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users AS su
	                ON  rdi.CreatedBy = su.UserName
	    WHERE  rdi.IsDeleted = 0
	           AND (
	                   @EnterpriseIds IS NULL OR @EnterpriseIds = ''''
	                   OR EXISTS (
	                          SELECT 1
	                          FROM   dbo.fnSplit(@EnterpriseIds, '','') AS t
	                          WHERE  CAST(t.Name AS INT) = rdi.EnterpriseId
	                      )
	               )
	           AND (
	                   @FromMonth IS NULL
	                   OR rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@FromMonth),0)
	               )
	           AND (
	                   @ToMonth IS NULL
	                   OR rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ToMonth)+1,0)
	               )
	           AND (
	                   @Search IS NULL OR @Search = ''''
	                   OR ce.BusinessName LIKE N''%'' + @Search + ''%''
	                   OR rdi.TypeReportName LIKE N''%'' + @Search + ''%''
	               )
	           AND (
	                   @TypeBusinessIds IS NULL OR @TypeBusinessIds = ''''
	                   OR EXISTS (
	                          SELECT 1
	                          FROM   dbo.fnSplit(@TypeBusinessIds, '','') AS t
	                          WHERE  CAST(t.Name AS INT) = rdi.TypeReport
	                      )
	               )
	    GROUP BY
	           rdi.EnterpriseId,
	           ce.BusinessName,
	           rdi.ForMonth,
	           rdi.TypeReport,
	           rdi.TypeReportName,
	           rdi.IsLate,
	           su.FullName,
	           rdi.CreatedDate
	),
	T AS (
	    SELECT ROW_NUMBER() OVER(
	               ORDER BY
	                    CASE WHEN @Order = ''0'' THEN nt.CreatedDate END ASC,
	                    CASE WHEN @Order = ''1'' THEN nt.EnterpriseName END ASC,
	                    CASE WHEN @Order = ''2'' THEN nt.ForMonth END ASC,
	                    CASE WHEN @Order = ''3'' THEN nt.TypeReportName END ASC,
	                    CASE WHEN @Order = ''4'' THEN nt.CreatedBy END ASC
	           ) AS RowIndex,
	           nt.EnterpriseId,
	           nt.EnterpriseName,
	           nt.ForMonth,
	           nt.TypeReport,
	           nt.TypeReportName,
	           nt.IsLate,
	           nt.CanDelete,
	           nt.CreatedBy,
	           nt.CreatedDate
	    FROM   D  AS nt
	    WHERE  UPPER(@OrderDir) = ''ASC''
	    UNION ALL
	    SELECT ROW_NUMBER() OVER(
	               ORDER BY
	                    CASE WHEN @Order = ''0'' THEN nt.CreatedDate END DESC,
	                    CASE WHEN @Order = ''1'' THEN nt.EnterpriseName END DESC,
	                    CASE WHEN @Order = ''2'' THEN nt.ForMonth END DESC,
	                    CASE WHEN @Order = ''3'' THEN nt.TypeReportName END DESC,
	                    CASE WHEN @Order = ''4'' THEN nt.CreatedBy END DESC
	           ) AS RowIndex,
	           nt.EnterpriseId,
	           nt.EnterpriseName,
	           nt.ForMonth,
	           nt.TypeReport,
	           nt.TypeReportName,
	           nt.IsLate,
	           nt.CanDelete,
	           nt.CreatedBy,
	           nt.CreatedDate
	    FROM   D  AS nt
	    WHERE  UPPER(@OrderDir) = ''DESC''
	)
	SELECT T.*,
	       (
	           SELECT COUNT(RowIndex)
	           FROM   T
	       ) AS TotalRow
	FROM   T
	WHERE  (
	           @PageSize > 0
	           AND T.RowIndex BETWEEN @PageIndex + 1 AND @PageIndex + @PageSize
	       )
	       OR  @PageSize <= 0 OPTION (RECOMPILE)
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_DataImports_GetDataImport_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_DataImports_GetDataImport_IndustryScope

	@EnterpriseId INT,
	@ForMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




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
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	       INNER JOIN (SELECT enterprise.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises enterprise JOIN #ReportScope scope ON scope.EnterpriseId=enterprise.EnterpriseId) AS ce
	            ON  ce.EnterpriseId = rdi.EnterpriseId
	       LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users AS su
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
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_DataImports_GetDataImport_Operational',N'P',N'PROCEDURE dbo.p_Report_DataImports_GetDataImport_Operational

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
	       INNER JOIN (SELECT enterprise.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises enterprise JOIN #ReportScope scope ON scope.EnterpriseId=enterprise.EnterpriseId) AS ce
	            ON  ce.EnterpriseId = rdi.EnterpriseId
	       LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users AS su
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
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_DataImports_GetForUserOnMonth_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_DataImports_GetForUserOnMonth_IndustryScope
	@ForUser VARCHAR(500),
	@OnMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);

 IF @ForUser<>@IndustryUserName OR @ForUser IS NULL THROW 50112,''Report subject mismatch'',1;



	DECLARE @DayDeadlineSendReportLate INT;

	SELECT @DayDeadlineSendReportLate = CAST(ISNULL(sc.ConfigValue, 0) AS INT)
	FROM   [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Configs AS sc
	WHERE  sc.ConfigKey = ''Day_Deadline_Send_Late_Report''
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
	       INNER JOIN (SELECT enterprise.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises enterprise JOIN #ReportScope scope ON scope.EnterpriseId=enterprise.EnterpriseId) AS ce
	            ON  ce.EnterpriseId = rdi.EnterpriseId
	       LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions AS cep
	            ON  cep.EnterpriseId = ce.EnterpriseId
	            AND cep.ForUser = @ForUser
	       LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users AS su
	            ON  rdi.CreatedBy = su.UserName
	WHERE  rdi.IsDeleted = 0
           AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions assignment
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
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_DataImports_GetForUserOnMonth_Operational',N'P',N'PROCEDURE dbo.p_Report_DataImports_GetForUserOnMonth_Operational
	@ForUser VARCHAR(500),
	@OnMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY,CanManageAllRecords bit NOT NULL);
 INSERT #ReportScope SELECT EnterpriseId,CanManageAllRecords FROM dbo.f_Report_DataImportEnterprises(@IndustryUserName);

 IF @ForUser<>@IndustryUserName OR @ForUser IS NULL THROW 50112,''Report subject mismatch'',1;



	DECLARE @DayDeadlineSendReportLate INT;

	SELECT @DayDeadlineSendReportLate = CAST(ISNULL(sc.ConfigValue, 0) AS INT)
	FROM   [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Configs AS sc
	WHERE  sc.ConfigKey = ''Day_Deadline_Send_Late_Report''
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
	       INNER JOIN (SELECT enterprise.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises enterprise JOIN #ReportScope scope ON scope.EnterpriseId=enterprise.EnterpriseId) AS ce
	            ON  ce.EnterpriseId = rdi.EnterpriseId
	       LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions AS cep
	            ON  cep.EnterpriseId = ce.EnterpriseId
	            AND cep.ForUser = @ForUser
	       LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users AS su
	            ON  rdi.CreatedBy = su.UserName
	WHERE  rdi.IsDeleted = 0
           AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions assignment
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
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_DataImports_GetViaEnterpriseOnMonth_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_DataImports_GetViaEnterpriseOnMonth_IndustryScope

	@EnterpriseId INT,
	@ForMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);





	DECLARE @DayDeadlineSendReportLate INT;

	SELECT @DayDeadlineSendReportLate = CAST(ISNULL(sc.ConfigValue, 0) AS INT)
	FROM   [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Configs AS sc
	WHERE  sc.ConfigKey = ''Day_Deadline_Send_Late_Report''
	       AND sc.IsDeleted = 0


	SELECT rdi.EnterpriseId,
	       ce.BusinessName     AS EnterpriseName,
	       rdi.ForMonth,
	       rdi.TypeReport,
	       rdi.TypeReportName,
	       rdi.IsLate,
	       CAST(
	           CASE
	                WHEN DAY(GETDATE()) > @DayDeadlineSendReportLate THEN 0
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
	       INNER JOIN (SELECT enterprise.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises enterprise JOIN #ReportScope scope ON scope.EnterpriseId=enterprise.EnterpriseId) AS ce
	            ON  ce.EnterpriseId = rdi.EnterpriseId
	       LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users AS su
	            ON  rdi.CreatedBy = su.UserName
	WHERE  rdi.IsDeleted = 0
	       AND rdi.EnterpriseId = @EnterpriseId
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
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
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_DataImports_GetViaEnterpriseOnMonth_Operational',N'P',N'PROCEDURE dbo.p_Report_DataImports_GetViaEnterpriseOnMonth_Operational

	@EnterpriseId INT,
	@ForMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY,CanManageAllRecords bit NOT NULL);
 INSERT #ReportScope SELECT EnterpriseId,CanManageAllRecords FROM dbo.f_Report_DataImportEnterprises(@IndustryUserName);





	DECLARE @DayDeadlineSendReportLate INT;

	SELECT @DayDeadlineSendReportLate = CAST(ISNULL(sc.ConfigValue, 0) AS INT)
	FROM   [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Configs AS sc
	WHERE  sc.ConfigKey = ''Day_Deadline_Send_Late_Report''
	       AND sc.IsDeleted = 0


	SELECT rdi.EnterpriseId,
	       ce.BusinessName     AS EnterpriseName,
	       rdi.ForMonth,
	       rdi.TypeReport,
	       rdi.TypeReportName,
	       rdi.IsLate,
	       CAST(
	           CASE
	                WHEN DAY(GETDATE()) > @DayDeadlineSendReportLate THEN 0
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
	       INNER JOIN (SELECT enterprise.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises enterprise JOIN #ReportScope scope ON scope.EnterpriseId=enterprise.EnterpriseId) AS ce
	            ON  ce.EnterpriseId = rdi.EnterpriseId
	       LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users AS su
	            ON  rdi.CreatedBy = su.UserName
	WHERE  rdi.IsDeleted = 0
	       AND rdi.EnterpriseId = @EnterpriseId
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
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
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_DataImports_OperationalScope',N'P',N'PROCEDURE dbo.p_Report_DataImports_OperationalScope @ForUser varchar(255)
AS BEGIN
 SET NOCOUNT ON;
 SELECT e.EnterpriseId,e.BusinessName,e.TaxCode,e.TypeBusiness,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users u
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_UserRoles ur ON ur.UserId=u.UserId
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m ON m.RoleId=ur.RoleId
 WHERE u.UserName=@ForUser AND m.ScopeMode=''enterprise'')
 AND NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users u
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_UserRoles ur ON ur.UserId=u.UserId
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m ON m.RoleId=ur.RoleId
 WHERE u.UserName=@ForUser AND m.ScopeMode IN(''all'',''industry'')) THEN 1 ELSE 0 END) IsEnterpriseUser,
 STUFF((SELECT ''|'' + m.SemanticKey + '':'' + CONVERT(varchar(11),m.RoleId) + '':'' + m.ScopeMode + '':'' + CONVERT(varchar(1),m.IsIndustryEditorTarget)
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m ORDER BY m.RoleId FOR XML PATH(''''),TYPE).value(''.'',''varchar(max)''),1,1,'''') RoleMappingSignature,e.CanManageAllRecords
 FROM dbo.f_Report_DataImportEnterprises(@ForUser) e;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_GenerateSaleOfTourism_ByCode_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope

	@Title NVARCHAR(1500),
	@ForMonth DATETIME,
	@Code VARCHAR(50),
	@Level VARCHAR(10),
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	SELECT @Title,
	       ISNULL(rdi.Unit, '''')  AS Unit,
	       SUM(
	           ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	       ) * 1.0               AS PerformPreviousPeriod,
	       SUM(ISNULL(rdi.PerformInPeriod, 0)) * 1.0 AS PerformInPeriod,
	       CAST(
	           (
	               SUM(rdi.PerformInPeriod) / (
	                   SELECT SUM(ISNULL(rdi1.PerformInPeriod, 0))
	                   FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi1
	                   WHERE  rdi1.IsDeleted = 0
	                          AND (
	                                  MONTH(@ForMonth) = MONTH(rdi1.ForMonth)
	                                  AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi1.ForMonth)
	                              )
	                          AND rdi1.Code = rdi.Code
	                          AND rdi1.Unit = rdi.Unit
	               ) * 100
	           ) AS FLOAT
	       )                     AS SamePeriodRateOfPerform,
	       SUM(ISNULL(rdi.AccumulatedBeginingOfYear, 0)) * 1.0 AS AccumulatedBeginingOfYear,
	       CAST(
	           ISNULL(
	               (
	                   SUM(rdi.AccumulatedBeginingOfYear) / (
	                       SELECT SUM(ISNULL(rdi2.AccumulatedBeginingOfYear, 0))
	                       FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       WHERE  rdi2.IsDeleted = 0
	                              AND (
	                                      MONTH(@ForMonth) = MONTH(rdi2.ForMonth)
	                                      AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi2.ForMonth)
	                                  )
	                              AND rdi2.Code = rdi.Code
	                              AND rdi2.Unit = rdi.Unit
	                   ) * 100
	               ),
	               0
	           ) AS FLOAT
	       )                     AS SamePeriodRateOfAccumulated,
	       ISNULL(@Level, '''')    AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)    AS rdi
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Targets = rdi.Targets
	            AND rdi2.Unit = rdi.Unit
	            AND rdi2.Code = rdi.Code
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)-1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+0,0))
	WHERE  rdi.Code = @Code
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))




	GROUP BY
	       rdi.Targets,
	       rdi.Code,
	       rdi.Unit
	ORDER BY
	       rdi.Code
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_GenerateSaleOfTourism_Sum_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_GenerateSaleOfTourism_Sum_IndustryScope

	@Title NVARCHAR(1500),
	@ForMonth DATETIME,
	@Code1 VARCHAR(50),
	@Code2 VARCHAR(50),
	@Code3 VARCHAR(50),
	@Level VARCHAR(10),
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	DECLARE @PerformPreviousPeriod         FLOAT = 0,
	        @AccumulatedBeginingOfYear     FLOAT = 0

	SELECT @PerformPreviousPeriod = SUM(ISNULL(rdi1.PerformPreviousPeriod, 0))
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi1
	WHERE  rdi1.IsDeleted = 0
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi1.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi1.ForMonth)
	           )
	       AND (
	               rdi1.Code = @Code1
	               OR rdi1.Code = @Code2
	               OR rdi1.Code = @Code3
	           )

	SELECT @AccumulatedBeginingOfYear = SUM(ISNULL(rdi2.AccumulatedBeginingOfYear, 0))
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	WHERE  rdi2.IsDeleted = 0
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi2.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi2.ForMonth)
	           )
	       AND (
	               rdi2.Code = @Code1
	               OR rdi2.Code = @Code2
	               OR rdi2.Code = @Code3
	           )

	SELECT @Title,
	       ISNULL(rdi.Unit, '''')  AS Unit,
	       SUM(
	           ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	       ) * 1.0               AS PerformPreviousPeriod,
	       SUM(ISNULL(rdi.PerformInPeriod, 0)) * 1.0 AS PerformInPeriod,
	       ISNULL(
	           CASE
	                WHEN @PerformPreviousPeriod = 0 THEN 0
	                ELSE SUM(ISNULL(rdi.PerformInPeriod, 0)) * 1.0 / @PerformPreviousPeriod
	           END,
	           0
	       )                     AS SamePeriodRateOfPerform,
	       SUM(ISNULL(rdi.AccumulatedBeginingOfYear, 0)) * 1.0 AS AccumulatedBeginingOfYear,
	       ISNULL(
	           CASE
	                WHEN @AccumulatedBeginingOfYear = 0 THEN 0
	                ELSE SUM(ISNULL(rdi.AccumulatedBeginingOfYear, 0)) * 1.0 / @AccumulatedBeginingOfYear
	           END,
	           0
	       )                     AS SamePeriodRateOfAccumulated,
	       ISNULL(@Level, '''')    AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)    AS rdi
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Targets = rdi.Targets
	            AND rdi2.Unit = rdi.Unit
	            AND rdi2.Code = rdi.Code
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)-1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+0,0))
	WHERE  (
	           rdi.Code = @Code1
	           OR rdi.Code = @Code2
	           OR rdi.Code = @Code3
	       )
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	GROUP BY
	       rdi.Unit
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_GenerateSaleOfTourism_SumAmount_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumAmount_IndustryScope

	@Title NVARCHAR(1500),
	@ForMonth DATETIME,
	@Unit NVARCHAR(500),
	@Code VARCHAR(10),
	@Level VARCHAR(10),
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);



	DECLARE @SamePeriod               DATETIME,
	        @PerformInSamePeriod      FLOAT,
	        @PerformFromStartYear     FLOAT,
	        @PerformFromStartYearSamePeriod FLOAT;

	SET @SamePeriod = DATEADD(MONTH, 0, DATEADD(YEAR, -1, @ForMonth))


	SELECT @PerformInSamePeriod = a.PerformPreviousPeriod
	FROM   (
	           SELECT SUM(
	                      CASE
	                           WHEN FLOOR(rdi.PerformPreviousPeriod) <> CEILING(rdi.PerformPreviousPeriod) THEN CAST(
	                                    ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0)) * 1000000 AS
	                                    DECIMAL
	                                )
	                                * 1.0
	                           ELSE ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	                      END
	                  )                   AS PerformPreviousPeriod
	           FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	                  LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       ON  rdi2.Code = rdi.Code
	                       AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@SamePeriod)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@SamePeriod)+2,0))
	           WHERE  (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@SamePeriod),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@SamePeriod)+1,0))
	                  AND rdi.TypeReport = 1
	                  AND rdi.Code LIKE @Code
	       ) AS a

	SELECT @PerformFromStartYear = SUM(
	           CASE
	                WHEN FLOOR(rdi.PerformPreviousPeriod) <> CEILING(rdi.PerformPreviousPeriod) THEN CAST(ISNULL(rdi.PerformPreviousPeriod, 0) * 1000000 AS DECIMAL)
	                     * 1.0
	                ELSE ISNULL(rdi.PerformPreviousPeriod, 0)
	           END
	       )
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	WHERE  DATEDIFF(YEAR, @ForMonth, rdi.ForMonth) = 0
	       AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0)
	       AND rdi.TypeReport = 1
	       AND rdi.Code LIKE ''3%''

	SELECT @PerformFromStartYearSamePeriod = SUM(
	           CASE
	                WHEN FLOOR(rdi.PerformPreviousPeriod) <> CEILING(rdi.PerformPreviousPeriod) THEN CAST(ISNULL(rdi.PerformPreviousPeriod, 0) * 1000000 AS DECIMAL)
	                     * 1.0
	                ELSE ISNULL(rdi.PerformPreviousPeriod, 0)
	           END
	       )
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	WHERE  DATEDIFF(YEAR, @SamePeriod, rdi.ForMonth) = 0
	       AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,DATEADD(MONTH, 1, @SamePeriod))+1,0)
	       AND rdi.TypeReport = 1
	       AND rdi.Code LIKE ''3%''


	SELECT @Title,
	       @Unit,
	       a.PerformPreviousPeriod,
	       a.PerformInPeriod,
	       CASE
	            WHEN @PerformInSamePeriod = 0 THEN 0
	            ELSE a.PerformInPeriod / @PerformInSamePeriod
	       END  AS RateSamePeriod,
	       @PerformFromStartYear + a.PerformInPeriod AS PerformFromStartYear,
	       CASE
	            WHEN @PerformFromStartYearSamePeriod = 0 THEN 0
	            ELSE (@PerformFromStartYear + a.PerformInPeriod) / @PerformFromStartYearSamePeriod
	       END  AS PerformFromStartYearSamePeriod,
	       @Level
	FROM   (
	           SELECT SUM(
	                      CASE
	                           WHEN FLOOR(rdi.PerformPreviousPeriod) <> CEILING(rdi.PerformPreviousPeriod) THEN CAST(
	                                    ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0)) * 1000000 AS
	                                    DECIMAL
	                                )
	                                * 1.0
	                           ELSE ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	                      END
	                  )                   AS PerformPreviousPeriod,
	                  SUM(
	                      CASE
	                           WHEN FLOOR(rdi.PerformInPeriod) <> CEILING(rdi.PerformInPeriod) THEN CAST(ISNULL(rdi.PerformInPeriod, 0) * 1000000 AS DECIMAL)
	                                * 1.0
	                           ELSE ISNULL(rdi.PerformInPeriod, 0)
	                      END
	                  )                   AS PerformInPeriod
	           FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	                  LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       ON  rdi2.Code = rdi.Code
	                       AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@SamePeriod)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@SamePeriod)+2,0))
	                       AND rdi2.IsDeleted = 0
	           WHERE  (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	                  AND rdi.TypeReport = 1
	                  AND rdi.IsDeleted = 0
	                  AND rdi.Code LIKE ''3%''
	       )    AS a
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope

	@Title NVARCHAR(1500),
	@ForMonth DATETIME,
	@Code1 VARCHAR(50),
	@Code2 VARCHAR(50),
	@Code3 VARCHAR(50),
	@Level VARCHAR(10),
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	SELECT @Title                AS Targets,
	       ISNULL(rdi.Unit, '''')  AS Unit,
	       SUM(
	           ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	       )                     AS PerformPreviousPeriod,
	       SUM(ISNULL(rdi.PerformInPeriod, 0)) AS PerformInPeriod,
	       CAST(
	           CASE
	                WHEN SUM(
	                         ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	                     ) = 0 THEN 0
	                ELSE SUM(ISNULL(rdi.PerformInPeriod, 0)) / SUM(
	                         ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	                     )
	           END AS FLOAT
	       )                     AS SamePeriodRateOfPerform,
	       0                     AS AccumulatedBeginingOfYear,
	       0                     AS SamePeriodRateOfAccumulated,
	       ISNULL(@Level, '''')    AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)    AS rdi
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Code = rdi.Code
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+2,0))
	            AND rdi2.IsDeleted = 0
	WHERE  (
	           rdi.Code = @Code1
	           OR rdi.Code = @Code2
	           OR rdi.Code = @Code3
	       )
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	GROUP BY
	       rdi.Unit
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_GenerateSaleOfTourism_SumPercentForAVG_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumPercentForAVG_IndustryScope
	@Title NVARCHAR(1500),
	@ForMonth DATETIME,
	@Unit NVARCHAR(500),
	@Level VARCHAR(10),
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	DECLARE @PreAccumulatedBeginingOfYear FLOAT

	SELECT @PreAccumulatedBeginingOfYear = ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             ISNULL(
	                                 (
	                                     CASE
	                                          WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                          ELSE rdi.AccumulatedBeginingOfYear / b2.AccumulatedBeginingOfYear
	                                     END
	                                 ),
	                                 0
	                             )
	                         ) / COUNT(1)
	               END
	           ),
	           0
	       )
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	       INNER JOIN (
	                SELECT rdi2.AccumulatedBeginingOfYear,
	                       rdi2.EnterpriseId
	                FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                WHERE  rdi2.Code = ''22''
	                       AND rdi2.IsDeleted = 0
	                       AND (
	                               MONTH(@ForMonth) = MONTH(rdi2.ForMonth)
	                               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi2.ForMonth)
	                           )
	            ) b2
	            ON  b2.EnterpriseId = rdi.EnterpriseId
	WHERE  rdi.Code = ''21''
	       AND rdi.IsDeleted = 0
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi.ForMonth)
	           )


	SELECT @Title,
	       ISNULL(@Unit, '''')   AS Unit,
	       ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             CASE
	                                  WHEN ISNULL(b2.PerformPreviousPeriod, 0) = 0 THEN 0
	                                  ELSE ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0)) /
	                                       b2.PerformPreviousPeriod
	                             END
	                         ) / ISNULL(COUNT(1), 0)
	               END
	           ) * 100,
	           0
	       ),
	       ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             CASE
	                                  WHEN ISNULL(b2.PerformInPeriod, 0) = 0 THEN 0
	                                  ELSE rdi.PerformInPeriod / b2.PerformInPeriod
	                             END
	                         ) / COUNT(1)
	               END
	           ) * 100,
	           0
	       ),
	       0,
	       ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             ISNULL(
	                                 (
	                                     CASE
	                                          WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                          ELSE rdi.AccumulatedBeginingOfYear / b2.AccumulatedBeginingOfYear
	                                     END
	                                 ),
	                                 0
	                             )
	                         ) / COUNT(1)
	               END
	           ) * 100,
	           0
	       ),
	       (
	           ISNULL(
	               CASE
	                    WHEN ISNULL(@PreAccumulatedBeginingOfYear, 0) = 0 THEN 0
	                    ELSE (
	                             CASE
	                                  WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                                  ELSE SUM(
	                                           ISNULL(
	                                               (
	                                                   CASE
	                                                        WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                                        ELSE rdi.AccumulatedBeginingOfYear /
	                                                             b2.AccumulatedBeginingOfYear
	                                                   END
	                                               ),
	                                               0
	                                           )
	                                       ) / COUNT(1)
	                             END
	                         ) / @PreAccumulatedBeginingOfYear
	               END,
	               0
	           ) * 100
	       ) * 100,
	       ISNULL(@Level, '''')  AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	       INNER JOIN (
	                SELECT ISNULL(rdi2.PerformPreviousPeriod, rdi3.PerformInPeriod) AS PerformPreviousPeriod,
	                       rdi2.PerformInPeriod,
	                       rdi2.AccumulatedBeginingOfYear,
	                       rdi2.EnterpriseId
	                FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi3
	                            ON  rdi3.Code = rdi2.Code
	                            AND rdi3.IsDeleted = 0
	                            AND (rdi3.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0) AND rdi3.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+2,0))
	                WHERE  rdi2.Code = ''22''
	                       AND rdi2.IsDeleted = 0




	                       AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	            ) b2
	            ON  b2.EnterpriseId = rdi.EnterpriseId
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Code = rdi.Code
	            AND rdi2.IsDeleted = 0
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+2,0))
	WHERE  rdi.Code = ''21''
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))




END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_GenerateSaleOfTourism_SumPercentForOther_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumPercentForOther_IndustryScope

	@Title NVARCHAR(1500),
	@ForMonth DATETIME,
	@Unit NVARCHAR(500),
	@Level VARCHAR(10),
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	DECLARE @PreAccumulatedBeginingOfYear FLOAT

	SELECT @PreAccumulatedBeginingOfYear = CASE
	                                            WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                                            ELSE SUM(
	                                                     ISNULL(
	                                                         CASE
	                                                              WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN
	                                                                   0
	                                                              ELSE rdi.AccumulatedBeginingOfYear / ISNULL(b2.AccumulatedBeginingOfYear, 0)
	                                                         END,
	                                                         0
	                                                     )
	                                                 ) / ISNULL(COUNT(1), 0)
	                                       END
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	       INNER JOIN (
	                SELECT rdi2.*
	                FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas1
	                            ON  cas1.EnterpriseId = rdi2.EnterpriseId
	                WHERE  (
	                           cas1.AccommodationClass <> 1
	                           AND cas1.AccommodationClass <> 2
	                           AND cas1.AccommodationClass <> 3
	                           AND cas1.AccommodationClass <> 4
	                           AND cas1.AccommodationClass <> 5
	                       )
	                       AND rdi2.Code = ''22''
	                       AND rdi2.IsDeleted = 0
	                       AND (
	                               MONTH(@ForMonth) = MONTH(rdi2.ForMonth)
	                               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi2.ForMonth)
	                           )
	            ) b2
	            ON  b2.EnterpriseId = rdi.EnterpriseId
	       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas
	            ON  cas.EnterpriseId = rdi.EnterpriseId
	WHERE  (
	           cas.AccommodationClass <> 1
	           AND cas.AccommodationClass <> 2
	           AND cas.AccommodationClass <> 3
	           AND cas.AccommodationClass <> 4
	           AND cas.AccommodationClass <> 5
	       )
	       AND rdi.Code = ''21''
	       AND rdi.IsDeleted = 0
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi.ForMonth)
	           )


	SELECT @Title,
	       ISNULL(@Unit, '''')   AS Unit,
	       (
	           CASE
	                WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                ELSE SUM(
	                         CASE
	                              WHEN ISNULL(b2.PerformPreviousPeriod, 0) = 0 THEN 0
	                              ELSE ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0)) / ISNULL(b2.PerformPreviousPeriod, 0)
	                         END
	                     ) / ISNULL(COUNT(1), 0)
	           END
	       ) * 100,
	       (
	           CASE
	                WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                ELSE SUM(
	                         CASE
	                              WHEN ISNULL(b2.PerformInPeriod, 0) = 0 THEN 0
	                              ELSE rdi.PerformInPeriod / ISNULL(b2.PerformInPeriod, 0)
	                         END
	                     ) / ISNULL(COUNT(1), 0)
	           END
	       ) * 100,
	       0,
	       (
	           CASE
	                WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                ELSE SUM(
	                         CASE
	                              WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                              ELSE ISNULL(
	                                       rdi.AccumulatedBeginingOfYear / ISNULL(b2.AccumulatedBeginingOfYear, 0),
	                                       0
	                                   )
	                         END
	                     ) / ISNULL(COUNT(1), 0)
	           END
	       ) * 100,
	       (
	           ISNULL(
	               CASE
	                    WHEN ISNULL(@PreAccumulatedBeginingOfYear, 0) = 0 THEN 0
	                    ELSE (
	                             CASE
	                                  WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                                  ELSE SUM(
	                                           CASE
	                                                WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                                ELSE ISNULL(
	                                                         rdi.AccumulatedBeginingOfYear / ISNULL(b2.AccumulatedBeginingOfYear, 0),
	                                                         0
	                                                     )
	                                           END
	                                       ) / ISNULL(COUNT(1), 0)
	                             END
	                         ) / ISNULL(@PreAccumulatedBeginingOfYear, 0)
	               END,
	               0
	           ) * 100
	       ) * 100,
	       ISNULL(@Level, '''')  AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	       INNER JOIN (
	                SELECT rdi2.*
	                FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas1
	                            ON  cas1.EnterpriseId = rdi2.EnterpriseId
	                WHERE  (
	                           cas1.AccommodationClass <> 1
	                           AND cas1.AccommodationClass <> 2
	                           AND cas1.AccommodationClass <> 3
	                           AND cas1.AccommodationClass <> 4
	                           AND cas1.AccommodationClass <> 5
	                       )
	                       AND rdi2.Code = ''22''
	                       AND rdi2.IsDeleted = 0
	                       AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))




	            ) b2
	            ON  b2.EnterpriseId = rdi.EnterpriseId
	       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas
	            ON  cas.EnterpriseId = rdi.EnterpriseId
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Code = rdi.Code
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+2,0))
	            AND rdi2.IsDeleted = 0
	WHERE  (
	           cas.AccommodationClass <> 1
	           AND cas.AccommodationClass <> 2
	           AND cas.AccommodationClass <> 3
	           AND cas.AccommodationClass <> 4
	           AND cas.AccommodationClass <> 5
	       )
	       AND rdi.Code = ''21''
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))




END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope

	@Title NVARCHAR(1500),
	@ForMonth DATETIME,
	@Unit NVARCHAR(500),
	@Class INT,
	@Level VARCHAR(10),
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	DECLARE @PreAccumulatedBeginingOfYear FLOAT

	SELECT @PreAccumulatedBeginingOfYear = CASE
	                                            WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                                            ELSE SUM(
	                                                     CASE
	                                                          WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                                          ELSE ISNULL(
	                                                                   rdi.AccumulatedBeginingOfYear / ISNULL(b2.AccumulatedBeginingOfYear, 0),
	                                                                   0
	                                                               )
	                                                     END
	                                                 ) / ISNULL(COUNT(1), 0)
	                                       END
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	       INNER JOIN (
	                SELECT rdi2.*
	                FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas1
	                            ON  cas1.EnterpriseId = rdi2.EnterpriseId
	                WHERE  cas1.AccommodationClass = @Class
	                       AND rdi2.Code = ''22''
	                       AND rdi2.IsDeleted = 0
	                       AND (
	                               MONTH(@ForMonth) = MONTH(rdi2.ForMonth)
	                               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi2.ForMonth)
	                           )
	            ) b2
	            ON  b2.EnterpriseId = rdi.EnterpriseId
	       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas
	            ON  cas.EnterpriseId = rdi.EnterpriseId
	WHERE  cas.AccommodationClass = @Class
	       AND rdi.Code = ''21''
	       AND rdi.IsDeleted = 0
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi.ForMonth)
	           )


	SELECT @Title,
	       ISNULL(@Unit, '''')   AS Unit,
	       ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             CASE
	                                  WHEN ISNULL(b2.PerformPreviousPeriod, 0) = 0 THEN 0
	                                  ELSE ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0)) / ISNULL(b2.PerformPreviousPeriod, 0)
	                             END
	                         ) / ISNULL(COUNT(1), 0)
	               END
	           ) * 100,
	           0
	       ),
	       ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             CASE
	                                  WHEN ISNULL(b2.PerformInPeriod, 0) = 0 THEN 0
	                                  ELSE rdi.PerformInPeriod / ISNULL(b2.PerformInPeriod, 0)
	                             END
	                         ) / ISNULL(COUNT(1), 0)
	               END
	           ) * 100,
	           0
	       ),
	       0,
	       ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             CASE
	                                  WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                  ELSE ISNULL(
	                                           rdi.AccumulatedBeginingOfYear / ISNULL(b2.AccumulatedBeginingOfYear, 0),
	                                           0
	                                       )
	                             END
	                         ) / ISNULL(COUNT(1), 0)
	               END
	           ) * 100,
	           0
	       ),
	       (
	           CASE
	                WHEN ISNULL(@PreAccumulatedBeginingOfYear, 0) = 0 THEN 0
	                ELSE ISNULL(
	                         (
	                             CASE
	                                  WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                                  ELSE SUM(
	                                           CASE
	                                                WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                                ELSE ISNULL(
	                                                         rdi.AccumulatedBeginingOfYear / ISNULL(b2.AccumulatedBeginingOfYear, 0),
	                                                         0
	                                                     )
	                                           END
	                                       ) / ISNULL(COUNT(1), 0)
	                             END
	                         ) / ISNULL(@PreAccumulatedBeginingOfYear, 0),
	                         0
	                     ) * 100
	           END
	       ) * 100,
	       ISNULL(@Level, '''')  AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	       INNER JOIN (
	                SELECT rdi2.*
	                FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas1
	                            ON  cas1.EnterpriseId = rdi2.EnterpriseId
	                WHERE  cas1.AccommodationClass = @Class
	                       AND rdi2.Code = ''22''
	                       AND rdi2.IsDeleted = 0
	                       AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))




	            ) b2
	            ON  b2.EnterpriseId = rdi.EnterpriseId
	       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas
	            ON  cas.EnterpriseId = rdi.EnterpriseId
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Code = rdi.Code
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+2,0))
	            AND rdi2.IsDeleted = 0
	WHERE  cas.AccommodationClass = @Class
	       AND rdi.Code = ''21''
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))




END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope

	@Title NVARCHAR(1500),
	@ForMonth DATETIME,
	@Unit NVARCHAR(500),
	@Code1 VARCHAR(50),
	@Code2 VARCHAR(50),
	@Level VARCHAR(10),
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	DECLARE @PerformPreviousPeriod_Code_1 FLOAT,
	        @PerformPreviousPeriod_Code_2 FLOAT,
	        @PerformPreviousPeriod         FLOAT,
	        @PerformInPeriod_Code_1        FLOAT,
	        @PerformInPeriod_Code_2        FLOAT,
	        @PerformInPeriod               FLOAT,
	        @AccumulatedBeginingOfYear_Code_1 FLOAT,
	        @AccumulatedBeginingOfYear_Code_2 FLOAT,
	        @AccumulatedBeginingOfYear     FLOAT,
	        @AccumulatedBeginingOfYear_LastYear_Code_1 FLOAT,
	        @AccumulatedBeginingOfYear_LastYear_Code_2 FLOAT,
	        @AccumulatedBeginingOfYear_LastYear FLOAT;


	SELECT @PerformPreviousPeriod_Code_1 = SUM(
	           ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	       ) * 1.0
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Code = rdi.Code
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+2,0))
	            AND rdi2.IsDeleted = 0
	WHERE  rdi.Code = @Code1
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))

	SELECT @PerformPreviousPeriod_Code_2 = SUM(
	           ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	       ) * 1.0
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Code = rdi.Code
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+2,0))
	            AND rdi2.IsDeleted = 0
	WHERE  rdi.Code = @Code2
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))


	SET @PerformPreviousPeriod = @PerformPreviousPeriod_Code_1 * 2020000 + @PerformPreviousPeriod_Code_2 * 1680000





	SELECT @PerformInPeriod_Code_1 = SUM(ISNULL(rdi.PerformInPeriod, 0)) * 1.0
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	WHERE  rdi.Code = @Code1
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))


	SELECT @PerformInPeriod_Code_2 = SUM(ISNULL(rdi.PerformInPeriod, 0)) * 1.0
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	WHERE  rdi.Code = @Code2
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))


	SET @PerformInPeriod = @PerformInPeriod_Code_1 * 2020000 + @PerformInPeriod_Code_2 * 1680000





	SELECT @AccumulatedBeginingOfYear_Code_1 = SUM(ISNULL(rdi.AccumulatedBeginingOfYear, 0)) * 1.0
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	WHERE  rdi.Code = @Code1
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))


	SELECT @AccumulatedBeginingOfYear_Code_2 = SUM(ISNULL(rdi.AccumulatedBeginingOfYear, 0)) * 1.0
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	WHERE  rdi.Code = @Code2
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))

	SET @AccumulatedBeginingOfYear = @AccumulatedBeginingOfYear_Code_1 * 2020000 + @AccumulatedBeginingOfYear_Code_2 *
	    1680000





	SELECT @AccumulatedBeginingOfYear_LastYear_Code_1 = SUM(ISNULL(rdi.AccumulatedBeginingOfYear, 0)) * 1.0
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	WHERE  rdi.Code = @Code1
	       AND rdi.IsDeleted = 0
	       AND DATEDIFF(MONTH, DATEADD(YEAR, -1, @ForMonth), rdi.ForMonth) = 0


	SELECT @AccumulatedBeginingOfYear_LastYear_Code_2 = SUM(ISNULL(rdi.AccumulatedBeginingOfYear, 0)) * 1.0
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	WHERE  rdi.Code = @Code2
	       AND rdi.IsDeleted = 0
	       AND DATEDIFF(MONTH, DATEADD(YEAR, -1, @ForMonth), rdi.ForMonth) = 0

	SET @AccumulatedBeginingOfYear_LastYear = @AccumulatedBeginingOfYear_LastYear_Code_1 * 2020000 +
	    @AccumulatedBeginingOfYear_LastYear_Code_2 *
	    1680000




	SELECT @Title,
	       ISNULL(@Unit, '''')           AS Unit,
	       @PerformPreviousPeriod      AS PerformPreviousPeriod,
	       @PerformInPeriod            AS PerformInPeriod,
	       CASE
	            WHEN ISNULL(@PerformPreviousPeriod, 0) = 0 THEN 0
	            ELSE ISNULL(@PerformInPeriod, 0) / ISNULL(@PerformPreviousPeriod, 0) * 100
	       END                         AS SamePeriodRateOfPerform,
	       @AccumulatedBeginingOfYear  AS AccumulatedBeginingOfYear,
	       CAST(
	           CASE
	                WHEN ISNULL(@AccumulatedBeginingOfYear_LastYear, 0) = 0 THEN 0
	                ELSE ISNULL(@AccumulatedBeginingOfYear, 0) / ISNULL(@AccumulatedBeginingOfYear_LastYear, 0) * 100
	           END
	           AS FLOAT
	       )                           AS SamePeriodRateOfAccumulated,
	       ISNULL(@Level, '''')          AS [Level]
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope

	@Title NVARCHAR(1500),
	@ForMonth DATETIME,
	@Level VARCHAR(10),
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;


	DECLARE @TotalGuestViaShip_LastMonth     INT,
	        @TotalGuestViaShip_LastYear      INT,
	        @AccumulatedBeginingOfYear       INT,
	        @AccumulatedBeginingOfYear_LastYear INT;

	SELECT @TotalGuestViaShip_LastMonth = ISNULL(rei.TotalGuestViaShip, 0)
	FROM dbo.f_Report_IndustryExtendInfos(@IndustryUserName) AS rei
	WHERE  (rei.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)-1,0) AND rei.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+0,0))

	SELECT @TotalGuestViaShip_LastYear = ISNULL(rei.TotalGuestViaShip, 0)
	FROM dbo.f_Report_IndustryExtendInfos(@IndustryUserName) AS rei
	WHERE  DATEDIFF(YEAR, rei.ForMonth, @ForMonth) = 1








	SELECT @AccumulatedBeginingOfYear = SUM(ISNULL(rei.TotalGuestViaShip, 0))
	FROM dbo.f_Report_IndustryExtendInfos(@IndustryUserName) AS rei
	WHERE  rei.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0)
	       AND YEAR(@ForMonth) = YEAR(rei.ForMonth)




	SELECT @AccumulatedBeginingOfYear_LastYear = SUM(ISNULL(rei.TotalGuestViaShip, 0))
	FROM dbo.f_Report_IndustryExtendInfos(@IndustryUserName) AS rei
	WHERE  DATEDIFF(YEAR, rei.ForMonth, @ForMonth) = 1
	       AND MONTH(rei.ForMonth) <= MONTH(@ForMonth)







	SELECT @Title              AS Title,
	       N''Lượt''             AS Unit,
	       ISNULL(@TotalGuestViaShip_LastMonth, 0) AS PerformPreviousPeriod,
	       ISNULL(rdi.TotalGuestViaShip, 0) AS PerformInPeriod,
	       CASE
	            WHEN @TotalGuestViaShip_LastYear = 0 THEN 0
	            ELSE ISNULL(rdi.TotalGuestViaShip, 0) / @TotalGuestViaShip_LastYear
	       END                 AS SamePeriodRateOfPerform,
	       ISNULL(@AccumulatedBeginingOfYear, 0) AS AccumulatedBeginingOfYear,
	       CASE
	            WHEN @AccumulatedBeginingOfYear_LastYear = 0 THEN 0
	            ELSE @AccumulatedBeginingOfYear / @AccumulatedBeginingOfYear_LastYear * 1.0
	       END                 AS SamePeriodRateOfAccumulated,
	       ISNULL(@Level, '''')  AS [Level]
	FROM dbo.f_Report_IndustryExtendInfos(@IndustryUserName)  AS rdi
	WHERE  1 = 1
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))





END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Industry_Enterprises_SearchSelect2',N'P',N'PROCEDURE dbo.p_Report_Industry_Enterprises_SearchSelect2
 @Keyword nvarchar(250)=NULL,@TypeBusiness varchar(50)=NULL,
 @PageIndex int=0,@PageSize int=20,@IndustryUserName varchar(255)
AS
BEGIN
 SET NOCOUNT ON;
 SET @PageIndex=CASE WHEN ISNULL(@PageIndex,0)<0 THEN 0 ELSE ISNULL(@PageIndex,0) END;
 SET @PageSize=CASE WHEN ISNULL(@PageSize,20)<1 THEN 20 WHEN @PageSize>100 THEN 100 ELSE ISNULL(@PageSize,20) END;
 SET @Keyword=NULLIF(LTRIM(RTRIM(@Keyword)),N'''');
 SET @TypeBusiness=NULLIF(LTRIM(RTRIM(@TypeBusiness)),'''');
 ;WITH Paged AS (
  SELECT ce.EnterpriseId,ce.BusinessName,ce.TaxCode,ce.TypeBusiness,
   ROW_NUMBER() OVER(ORDER BY ce.BusinessName,ce.EnterpriseId) RowNum,COUNT(*) OVER() TotalRow
  FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName) ce
  WHERE ce.IsApproved=1
   AND (@TypeBusiness IS NULL OR '',''+REPLACE(ISNULL(ce.TypeBusiness,''''),'' '','''')+'','' LIKE ''%,''+@TypeBusiness+'',%'')
   AND (@Keyword IS NULL OR ce.BusinessName LIKE N''%''+@Keyword+N''%'' OR ce.TaxCode LIKE N''%''+@Keyword+N''%'')
 )
 SELECT EnterpriseId,BusinessName,TaxCode,TypeBusiness,TotalRow FROM Paged
 WHERE RowNum>CONVERT(bigint,@PageIndex)*@PageSize AND RowNum<=(CONVERT(bigint,@PageIndex)+1)*@PageSize
 ORDER BY RowNum;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_IndustryPermissions_Enterprises',N'P',N'PROCEDURE dbo.p_Report_IndustryPermissions_Enterprises @UserName varchar(255) AS BEGIN SET NOCOUNT ON; SELECT e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@UserName) e; END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_IndustryPermissions_Scope',N'P',N'PROCEDURE dbo.p_Report_IndustryPermissions_Scope @UserName varchar(255) AS BEGIN SET NOCOUNT ON; SELECT s.*, STUFF((SELECT ''|'' + m.SemanticKey + '':'' + CONVERT(varchar(11),m.RoleId) + '':'' + m.ScopeMode + '':'' + CONVERT(varchar(1),m.IsIndustryEditorTarget) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m ORDER BY m.RoleId FOR XML PATH(''''),TYPE).value(''.'',''varchar(max)''),1,1,'''') AS RoleMappingSignature FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@UserName) s; END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Reports_01_UocKetQuaHoatDongKinhDoanh_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Reports_01_UocKetQuaHoatDongKinhDoanh_IndustryScope

	@ForMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @MappingReportCode TABLE (OCode VARCHAR(500), NCode VARCHAR(500));
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''1G'',''4'')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''1G1'',''5'')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''1G2'',''6'')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''1D'',''7'')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''1D1'',''8'')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''1D2'',''9'')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''A1'',''1'')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''A11'',''2'')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''A12'',''3'')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''A13'',''4'')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''A21'',''18'')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''A22'',''19'')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES(''A23'',''20'')

	DECLARE
		@PerformPreviousPeriod_11 FLOAT,
		@PerformPreviousPeriod_12 FLOAT,

		@PerformInPeriod_11 FLOAT,
		@PerformInPeriod_12 FLOAT,

		@SamePeriodRateOfPerform_11 FLOAT,
		@SamePeriodRateOfPerform_12 FLOAT,

		@AccumulatedBeginingOfYear_11 FLOAT,
		@AccumulatedBeginingOfYear_12 FLOAT,

		@SamePeriodRateOfAccumulated_11 FLOAT,
		@SamePeriodRateOfAccumulated_12 FLOAT;

	DECLARE @temp TABLE([Targets] NVARCHAR(1500),Unit NVARCHAR(1500),PerformPreviousPeriod FLOAT, PerformInPeriod FLOAT, SamePeriodRateOfPerform FLOAT, AccumulatedBeginingOfYear FLOAT, SamePeriodRateOfAccumulated FLOAT, [Level] VARCHAR(10));
	INSERT INTO @temp([Targets],Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear,SamePeriodRateOfAccumulated,[Level])
	VALUES(N''1. Về cơ sở lưu trú du lịch'',''-'', NULL,NULL,NULL,NULL,NULL,''1'')


	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_IndustryScope @Title=N''1.1 Tổng số lượt khách phục vụ'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''1G1;1G2;5;6'', @Level=''1.1'',@TypeReports = ''1;4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N''- Khách quốc tế'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''1G1;5'', @Level=''1.1.1'',@TypeReports = ''1;4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N''- Khách nội địa'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''1G2;6'', @Level=''1.1.2'',@TypeReports = ''1;4'', @IndustryUserName=@IndustryUserName;


	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_IndustryScope @Title=N''1.2 Tổng số ngày khách lưu trú'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''1D1;1D2;8;9'', @Level=''1.2'',@TypeReports = ''1;4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N''- Ngày khách quốc tế'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''1D1;8'', @Level=''1.2.1'',@TypeReports = ''1;4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N''- Ngày khách nội địa'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''1D2;9'', @Level=''1.2.2'',@TypeReports = ''1;4'', @IndustryUserName=@IndustryUserName;




	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_TrungBinh_IndustryScope @Title=N''1.4 Công suất sử dụng phòng bình quân'', @ForMonth=@ForMonth, @Unit=N''%'', @BaseListCodes=''21'', @SellListCodes=''22'', @Level=''1.4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope @Title=N''- Hạng cơ sở lưu trú 5 sao'', @ForMonth=@ForMonth, @Unit=N''%'', @Class=''5'', @BaseListCodes=''21'', @SellListCodes=''22'', @Level=''1.4.1'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope @Title=N''- Hạng cơ sở lưu trú 4 sao'', @ForMonth=@ForMonth, @Unit=N''%'', @Class=''4'', @BaseListCodes=''21'', @SellListCodes=''22'', @Level=''1.4.2'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope @Title=N''- Hạng cơ sở lưu trú 3 sao'', @ForMonth=@ForMonth, @Unit=N''%'', @Class=''3'', @BaseListCodes=''21'', @SellListCodes=''22'', @Level=''1.4.3'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope @Title=N''- Hạng cơ sở lưu trú 2 sao'', @ForMonth=@ForMonth, @Unit=N''%'', @Class=''2'', @BaseListCodes=''21'', @SellListCodes=''22'', @Level=''1.4.4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope @Title=N''- Hạng cơ sở lưu trú 1 sao'', @ForMonth=@ForMonth, @Unit=N''%'', @Class=''1'', @BaseListCodes=''21'', @SellListCodes=''22'', @Level=''1.4.5'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope @Title=N''- Khác'', @ForMonth=@ForMonth, @Unit=N''%'', @Class=NULL, @BaseListCodes=''21'', @SellListCodes=''22'', @Level=''1.4.6'', @IndustryUserName=@IndustryUserName;


	INSERT @temp  Exec dbo.p_Report_ThongKe_TongDoanhThu_IndustryScope @Title=N''1.5 Tổng doanh thu các cơ sở lưu trú'', @ForMonth=@ForMonth, @Unit=N''Đồng'', @ListCodes = ''31;32;33'',@Level=''1.5'', @IndustryUserName=@IndustryUserName;

	INSERT INTO @temp([Targets],Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear,SamePeriodRateOfAccumulated,[Level])
	VALUES(N''2. Về doanh nghiệp lữ hành, vận chuyển khách du lịch'',''-'', NULL,NULL,NULL,NULL,NULL,''2'')


	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_IndustryScope @Title=N''2.1 Tổng số lượt khách phục vụ'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''A11;A12;A13'',@Level=''2.1'',@TypeReports = ''2;3;4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N''- Khách quốc tế đến'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''A11'', @Level=''2.1.1'',@TypeReports = ''2;3;4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N''- Khách nội địa'',@Unit = N''Lượt'',@ForMonth=@ForMonth, @ListCodes=N''A12'', @Level=''2.1.2'',@TypeReports = ''2;3;4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N''- Khách Việt Nam đi nước ngoài'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''A13'', @Level=''2.1.3'',@TypeReports = ''2;3;4'', @IndustryUserName=@IndustryUserName;


	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_IndustryScope @Title=N''2.2 Tổng doanh thu từ doanh nghiệp lữ hành, vận chuyển khách du lịch'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''A21;A22;A23'', @Level=''2.2'',@TypeReports = ''2;3;4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N''- Khách quốc tế đến'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''A21'', @Level=''2.2.1'',@TypeReports = ''2;3;4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N''- Khách nội địa'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''A22'', @Level=''2.2.2'',@TypeReports = ''2;3;4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N''- Khách Việt Nam đi nước ngoài'',@Unit = N''Lượt'', @ForMonth=@ForMonth, @ListCodes=N''A23'', @Level=''2.2.3'',@TypeReports = ''2;3;4'', @IndustryUserName=@IndustryUserName;

	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope @Title=N''2.3 Khách du lịch đến Khánh Hòa bằng tàu biển'', @ForMonth=@ForMonth, @Level=N''2.3'', @IndustryUserName=@IndustryUserName;

	SELECT @PerformPreviousPeriod_12 = isnull(t12.PerformPreviousPeriod,0) FROM @temp t12 WHERE t12.[Level]=''1.2''
	SELECT @PerformPreviousPeriod_11 = isnull(t11.PerformPreviousPeriod,0) FROM @temp t11 WHERE t11.[Level]=''1.1''

	SELECT @PerformInPeriod_12 = isnull(t12.PerformInPeriod,0) FROM @temp t12 WHERE t12.[Level]=''1.2''
	SELECT @PerformInPeriod_11 = isnull(t11.PerformInPeriod,0) FROM @temp t11 WHERE t11.[Level]=''1.1''

	SELECT @SamePeriodRateOfPerform_12 = isnull(t12.SamePeriodRateOfPerform,0) FROM @temp t12 WHERE t12.[Level]=''1.2''
	SELECT @SamePeriodRateOfPerform_11 = isnull(t11.SamePeriodRateOfPerform,0) FROM @temp t11 WHERE t11.[Level]=''1.1''

	SELECT @AccumulatedBeginingOfYear_12 = isnull(t12.AccumulatedBeginingOfYear,0) FROM @temp t12 WHERE t12.[Level]=''1.2''
	SELECT @AccumulatedBeginingOfYear_11 = isnull(t11.AccumulatedBeginingOfYear,0) FROM @temp t11 WHERE t11.[Level]=''1.1''

	SELECT @SamePeriodRateOfAccumulated_12 = isnull(t12.SamePeriodRateOfAccumulated,0) FROM @temp t12 WHERE t12.[Level]=''1.2''
	SELECT @SamePeriodRateOfAccumulated_11 = isnull(t11.SamePeriodRateOfAccumulated,0) FROM @temp t11 WHERE t11.[Level]=''1.1''

	INSERT INTO @temp (	Targets,Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear, SamePeriodRateOfAccumulated,[Level])
	SELECT N''1.3 Ngày khách lưu trú bình quân'',N''Ngày'', ISNULL(CASE WHEN @PerformPreviousPeriod_11 = 0 THEN 0 ELSE @PerformPreviousPeriod_12/@PerformPreviousPeriod_11 END,0),
														ISNULL(CASE WHEN @PerformInPeriod_11 = 0 THEN 0 ELSE @PerformInPeriod_12/@PerformInPeriod_11 END,0),
														ISNULL(CASE WHEN @SamePeriodRateOfPerform_11 = 0 THEN 0 ELSE @SamePeriodRateOfPerform_12/@SamePeriodRateOfPerform_11 END,0),
														ISNULL(CASE WHEN @AccumulatedBeginingOfYear_11 = 0 THEN 0 ELSE @AccumulatedBeginingOfYear_12/@AccumulatedBeginingOfYear_11 END,0),
														ISNULL(CASE WHEN @SamePeriodRateOfAccumulated_11 = 0 THEN 0 ELSE @SamePeriodRateOfAccumulated_12/@SamePeriodRateOfAccumulated_11 END,0),




														''1.3''
	DECLARE
		@PerformPreviousPeriod_111 FLOAT,
		@PerformPreviousPeriod_121 FLOAT,

		@PerformInPeriod_111 FLOAT,
		@PerformInPeriod_121 FLOAT,

		@SamePeriodRateOfPerform_111 FLOAT,
		@SamePeriodRateOfPerform_121 FLOAT,

		@AccumulatedBeginingOfYear_111 FLOAT,
		@AccumulatedBeginingOfYear_121 FLOAT,

		@SamePeriodRateOfAccumulated_111 FLOAT,
		@SamePeriodRateOfAccumulated_121 FLOAT;

	SELECT @PerformPreviousPeriod_121 = isnull(t121.PerformPreviousPeriod,0) FROM @temp t121 WHERE t121.[Level]=''1.2.1''
	SELECT @PerformPreviousPeriod_111 = isnull(t111.PerformPreviousPeriod,0) FROM @temp t111 WHERE t111.[Level]=''1.1.1''

	SELECT @PerformInPeriod_121 = isnull(t121.PerformInPeriod,0) FROM @temp t121 WHERE t121.[Level]=''1.2.1''
	SELECT @PerformInPeriod_111 = isnull(t111.PerformInPeriod,0) FROM @temp t111 WHERE t111.[Level]=''1.1.1''

	SELECT @SamePeriodRateOfPerform_121 = isnull(t121.SamePeriodRateOfPerform,0) FROM @temp t121 WHERE t121.[Level]=''1.2.1''
	SELECT @SamePeriodRateOfPerform_111 = isnull(t111.SamePeriodRateOfPerform,0) FROM @temp t111 WHERE t111.[Level]=''1.1.1''

	SELECT @AccumulatedBeginingOfYear_121 = isnull(t121.AccumulatedBeginingOfYear,0) FROM @temp t121 WHERE t121.[Level]=''1.2.1''
	SELECT @AccumulatedBeginingOfYear_111 = isnull(t111.AccumulatedBeginingOfYear,0) FROM @temp t111 WHERE t111.[Level]=''1.1.1''

	SELECT @SamePeriodRateOfAccumulated_121 = isnull(t121.SamePeriodRateOfAccumulated,0) FROM @temp t121 WHERE t121.[Level]=''1.2.1''
	SELECT @SamePeriodRateOfAccumulated_111 = isnull(t111.SamePeriodRateOfAccumulated,0) FROM @temp t111 WHERE t111.[Level]=''1.1.1''

	INSERT INTO @temp (	Targets,Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear, SamePeriodRateOfAccumulated,[Level])
	SELECT N''- Khách quốc tế'',N''Ngày'',
										ISNULL(CASE WHEN @PerformPreviousPeriod_111 = 0 THEN 0 ELSE @PerformPreviousPeriod_121/@PerformPreviousPeriod_111 END,0),
										ISNULL(CASE WHEN @PerformInPeriod_111 = 0 THEN 0 ELSE @PerformInPeriod_121/@PerformInPeriod_111 END,0),
										ISNULL(CASE WHEN @SamePeriodRateOfPerform_111 = 0 THEN 0 ELSE @SamePeriodRateOfPerform_121/@SamePeriodRateOfPerform_111 END,0),
										ISNULL(CASE WHEN @AccumulatedBeginingOfYear_111 = 0 THEN 0 ELSE @AccumulatedBeginingOfYear_121/@AccumulatedBeginingOfYear_111 END,0),
										ISNULL(CASE WHEN @SamePeriodRateOfAccumulated_111 = 0 THEN 0 ELSE @SamePeriodRateOfAccumulated_121/@SamePeriodRateOfAccumulated_111 END,0),





														''1.3.1''

	DECLARE
		@PerformPreviousPeriod_112 FLOAT,
		@PerformPreviousPeriod_122 FLOAT,

		@PerformInPeriod_112 FLOAT,
		@PerformInPeriod_122 FLOAT,

		@SamePeriodRateOfPerform_112 FLOAT,
		@SamePeriodRateOfPerform_122 FLOAT,

		@AccumulatedBeginingOfYear_112 FLOAT,
		@AccumulatedBeginingOfYear_122 FLOAT,

		@SamePeriodRateOfAccumulated_112 FLOAT,
		@SamePeriodRateOfAccumulated_122 FLOAT;

	SELECT @PerformPreviousPeriod_122 = isnull(t122.PerformPreviousPeriod,0) FROM @temp t122 WHERE t122.[Level]=''1.2.2''
	SELECT @PerformPreviousPeriod_112 = isnull(t112.PerformPreviousPeriod,0) FROM @temp t112 WHERE t112.[Level]=''1.1.2''

	SELECT @PerformInPeriod_122 = isnull(t122.PerformInPeriod,0) FROM @temp t122 WHERE t122.[Level]=''1.2.2''
	SELECT @PerformInPeriod_112 = isnull(t112.PerformInPeriod,0) FROM @temp t112 WHERE t112.[Level]=''1.1.2''

	SELECT @SamePeriodRateOfPerform_122 = isnull(t122.SamePeriodRateOfPerform,0) FROM @temp t122 WHERE t122.[Level]=''1.2.2''
	SELECT @SamePeriodRateOfPerform_112 = isnull(t112.SamePeriodRateOfPerform,0) FROM @temp t112 WHERE t112.[Level]=''1.1.2''

	SELECT @AccumulatedBeginingOfYear_122 = isnull(t122.AccumulatedBeginingOfYear,0) FROM @temp t122 WHERE t122.[Level]=''1.2.2''
	SELECT @AccumulatedBeginingOfYear_112 = isnull(t112.AccumulatedBeginingOfYear,0) FROM @temp t112 WHERE t112.[Level]=''1.1.2''

	SELECT @SamePeriodRateOfAccumulated_122 = isnull(t122.SamePeriodRateOfAccumulated,0) FROM @temp t122 WHERE t122.[Level]=''1.2.2''
	SELECT @SamePeriodRateOfAccumulated_112 = isnull(t112.SamePeriodRateOfAccumulated,0) FROM @temp t112 WHERE t112.[Level]=''1.1.2''

	INSERT INTO @temp (	Targets,Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear, SamePeriodRateOfAccumulated,[Level])
	SELECT N''- Khách nội địa'',N''Ngày'',
										ISNULL(CASE WHEN @PerformPreviousPeriod_112 = 0 THEN 0 ELSE @PerformPreviousPeriod_122/@PerformPreviousPeriod_112 END,0),
										ISNULL(CASE WHEN @PerformInPeriod_112 = 0 THEN 0 ELSE @PerformInPeriod_122/@PerformInPeriod_112 END,0),
										ISNULL(CASE WHEN @SamePeriodRateOfPerform_112 = 0 THEN 0 ELSE @SamePeriodRateOfPerform_122/@SamePeriodRateOfPerform_112 END,0),
										ISNULL(CASE WHEN @AccumulatedBeginingOfYear_112 = 0 THEN 0 ELSE @AccumulatedBeginingOfYear_122/@AccumulatedBeginingOfYear_112 END,0),
										ISNULL(CASE WHEN @SamePeriodRateOfAccumulated_112 = 0 THEN 0 ELSE @SamePeriodRateOfAccumulated_122/@SamePeriodRateOfAccumulated_112 END,0),





														''1.3.2''

	INSERT @temp Exec dbo.p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope @Title=N''3. Lượt khách tham quan du lịch'', @ForMonth=@ForMonth, @Code1=N''A11'',@Code2=N''A12'',@Code3=NULL, @Level=''3'', @IndustryUserName=@IndustryUserName;


	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope @Title=N''4. Tổng thu từ khách du lịch trên địa bàn tỉnh Khánh Hòa'',@ForMonth=@ForMonth, @Unit=N''Đồng'', @Code1=N''1D1'', @Code2=N''1D2'', @Level=''4'', @IndustryUserName=@IndustryUserName;
	SELECT t.[Targets], t.Unit, t.PerformPreviousPeriod,t.PerformInPeriod, ROUND(t.SamePeriodRateOfPerform,2) AS SamePeriodRateOfPerform ,t.AccumulatedBeginingOfYear, ROUND(t.SamePeriodRateOfAccumulated,2) AS SamePeriodRateOfAccumulated
	FROM @temp t
	ORDER BY t.[Level]
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Reports_02_ThongKeQuocTichKhachDuLich_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Reports_02_ThongKeQuocTichKhachDuLich_IndustryScope

	@ForMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);



	DECLARE @Period         DATETIME,
	        @SamePeriod     DATETIME;

	SET @SamePeriod = DATEADD(YEAR, -1, @Period);

	WITH DATA_CURRENT_MONTH AS (
	    SELECT cn.ContinentName,
	           cn.NationalCode,
	           cn.NationalName,
	           @ForMonth           AS ForMonth,
	           rdi.Unit,
	           SUM(ISNULL(rdi.PerformPreviousPeriod, 0)) AS PerformPreviousPeriod,
	           SUM(ISNULL(rdi.PerformInPeriod, 0)) AS PerformInPeriod,
	           ROW_NUMBER() OVER(
	               PARTITION BY cn.ContinentName ORDER BY cn.NationalName DESC
	           )                   AS RowIndex
	    FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	           INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Nationals AS cn
	                ON  cn.NationalCode = rdi.Code
	                AND cn.IsDeleted = 0
	    WHERE  rdi.TypeReport = 1
	           AND rdi.Code IS NOT NULL
	           AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	    GROUP BY
	           cn.ContinentName,
	           cn.NationalCode,
	           cn.NationalName,
	           rdi.Unit
	),
	DATA_FROM_START_YEAR AS (
	    SELECT cn.ContinentName,
	           cn.NationalCode,
	           cn.NationalName,
	           rdi.Unit,
	           SUM(ISNULL(rdi.PerformPreviousPeriod, 0)) AS PerformPreviousPeriod,
	           SUM(ISNULL(rdi.PerformInPeriod, 0)) AS PerformInPeriod,
	           ROW_NUMBER() OVER(
	               PARTITION BY cn.ContinentName ORDER BY cn.NationalName DESC
	           )                   AS RowIndex
	    FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	           INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Nationals AS cn
	                ON  cn.NationalCode = rdi.Code
	                AND cn.IsDeleted = 0
	    WHERE  rdi.TypeReport = 1
	           AND rdi.Code IS NOT NULL
	           AND DATEDIFF(YEAR, @ForMonth, rdi.ForMonth) = 0
	           AND DATEDIFF(MONTH, @ForMonth, rdi.ForMonth) <= 0
	    GROUP BY
	           cn.ContinentName,
	           cn.NationalCode,
	           cn.NationalName,
	           rdi.Unit
	),
	DATA_SAME_PERIOD AS (
	    SELECT cn.ContinentName,
	           cn.NationalCode,
	           cn.NationalName,
	           DATEADD(YEAR, -1, @ForMonth) AS ForMonth,
	           rdi.Unit,
	           SUM(ISNULL(rdi.PerformPreviousPeriod, 0)) AS PerformPreviousPeriod,
	           SUM(ISNULL(rdi.PerformInPeriod, 0)) AS PerformInPeriod,
	           ROW_NUMBER() OVER(PARTITION BY cn.ContinentName ORDER BY cn.NationalName ASC) AS RowIndex
	    FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	           INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Nationals AS cn
	                ON  cn.NationalCode = rdi.Code
	                AND cn.IsDeleted = 0
	    WHERE  rdi.TypeReport = 1
	           AND rdi.Code IS NOT NULL
	           AND DATEDIFF(MONTH, @SamePeriod, rdi.ForMonth) <= 0
	    GROUP BY
	           cn.ContinentName,
	           cn.NationalCode,
	           cn.NationalName,
	           rdi.Unit
	),
	DATA_FROM_START_YEAR_SAME_PERIOD AS (
	    SELECT cn.ContinentName,
	           cn.NationalCode,
	           cn.NationalName,
	           rdi.Unit,
	           SUM(ISNULL(rdi.PerformPreviousPeriod, 0)) AS PerformPreviousPeriod,
	           SUM(ISNULL(rdi.PerformInPeriod, 0)) AS PerformInPeriod,
	           ROW_NUMBER() OVER(PARTITION BY cn.ContinentName ORDER BY cn.NationalName ASC) AS RowIndex
	    FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	           INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Nationals AS cn
	                ON  cn.NationalCode = rdi.Code
	                AND cn.IsDeleted = 0
	    WHERE  rdi.TypeReport = 1
	           AND rdi.Code IS NOT NULL
	           AND DATEDIFF(YEAR, @SamePeriod, rdi.ForMonth) = 0
	           AND DATEDIFF(MONTH, @SamePeriod, rdi.ForMonth) <= 0
	    GROUP BY
	           cn.ContinentName,
	           cn.NationalCode,
	           cn.NationalName,
	           rdi.Unit
	)
	, GROUP_NATIONAL AS (
	    SELECT c.RowIndex,
	           c.ContinentName,
	           c.NationalCode,
	           c.NationalName,
	           c.Unit,
	           c.ForMonth,
	           l.PerformPreviousPeriod   AS DataOnPeriod,
	           c.PerformPreviousPeriod   AS DataOnMonth,
	           cs.PerformPreviousPeriod  AS StartToMonth,
	           ls.PerformPreviousPeriod  AS StartToPeriod

	    FROM   DATA_CURRENT_MONTH        AS c
	           LEFT OUTER JOIN DATA_FROM_START_YEAR AS cs
	                ON  c.ContinentName = cs.ContinentName
	                AND c.NationalCode = cs.NationalCode
	           LEFT OUTER JOIN DATA_SAME_PERIOD AS l
	                ON  c.ContinentName = l.ContinentName
	                AND c.NationalCode = l.NationalCode
	           LEFT OUTER JOIN DATA_FROM_START_YEAR_SAME_PERIOD AS ls
	                ON  c.ContinentName = ls.ContinentName
	                AND c.NationalCode = ls.NationalCode
	)
	, DATA AS (
	    SELECT D.RowIndex,
	           D.ContinentName,
	           D.NationalCode,
	           D.NationalName,
	           D.Unit,
	           D.ForMonth,
	           D.DataOnPeriod,
	           D.DataOnMonth,
	           D.StartToMonth,
	           D.StartToPeriod
	    FROM   GROUP_NATIONAL AS D
	    WHERE  D.RowIndex <= 12

	    UNION

	    SELECT 13                    AS RowIndex,
	           D.ContinentName,
	           ''''                    AS NationalCode,
	           N''Các nước khác thuộc '' + D.ContinentName AS NationalName,
	           D.Unit,
	           D.ForMonth,
	           SUM(D.DataOnPeriod)   AS DataOnPeriod,
	           SUM(D.DataOnMonth)    AS DataOnMonth,
	           SUM(D.StartToMonth)   AS StartToMonth,
	           SUM(D.StartToPeriod)  AS StartToPeriod
	    FROM   GROUP_NATIONAL        AS D
	    WHERE  D.RowIndex > 12
	    GROUP BY
	           D.ContinentName,
	           D.Unit,
	           D.ForMonth
	)

	SELECT *
	FROM   DATA
	ORDER BY
	       ContinentName,
	       RowIndex
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope
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
	FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName) AS ce
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
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope
    @ForMonth DATETIME,
    @EnterpriseId INT = NULL,
 @IndustryUserName varchar(255)

AS
BEGIN
    SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




    ;WITH CurrentData AS
    (
        SELECT TypeReport, Code, Targets, Unit,
               SUM(ISNULL(PerformPreviousPeriod, 0)) AS PreviousMonth,
               SUM(ISNULL(PerformInPeriod, 0)) AS CurrentMonth,
               SUM(ISNULL(AccumulatedBeginingOfYear, 0)) AS CurrentAccumulated
        FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) scope_source
        WHERE IsDeleted = 0
          AND ForMonth = CAST(@ForMonth AS DATE)
          AND NULLIF(LTRIM(RTRIM(Code)), '''') IS NOT NULL
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
          AND NULLIF(LTRIM(RTRIM(Code)), '''') IS NOT NULL
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
        AND p.Targets = c.Targets AND ISNULL(p.Unit, '''') = ISNULL(c.Unit, '''')
    ORDER BY c.TypeReport, c.Code, c.Targets OPTION (RECOMPILE);
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope
	@Title NVARCHAR(1500),
	@ForMonth DATETIME,
	@Unit NVARCHAR(500),
	@Class VARCHAR(10),
	@BaseListCodes VARCHAR(500),
	@SellListCodes VARCHAR(500),
	@Level VARCHAR(10),
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	DECLARE @PreAccumulatedBeginingOfYear FLOAT

	SELECT @PreAccumulatedBeginingOfYear = CASE
	                                            WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                                            ELSE SUM(
	                                                     CASE
	                                                          WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                                          ELSE ISNULL(
	                                                                   rdi.AccumulatedBeginingOfYear / ISNULL(b2.AccumulatedBeginingOfYear, 0),
	                                                                   0
	                                                               )
	                                                     END
	                                                 ) / ISNULL(COUNT(1), 0)
	                                       END
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	       INNER JOIN (
	                SELECT rdi2.*
	                FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas1
	                            ON  cas1.EnterpriseId = rdi2.EnterpriseId
	                       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_PublicCates AS cpc
	                            ON  cas1.AccommodationClass = cpc.CateId
	                            AND cpc.CateTypeId = 500
	                            AND cpc.IsDeleted = 0
	                WHERE  (
	                           (@Class IS NULL AND cpc.CateName NOT LIKE N''% sao'')
	                           OR cpc.CateName LIKE N''%'' + @Class + N'' sao''
	                       )
	                       AND rdi2.TypeReport = 1
	                       AND rdi2.IsDeleted = 0
	                       AND (
	                               MONTH(@ForMonth) = MONTH(rdi2.ForMonth)
	                               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi2.ForMonth)
	                           )
	                       AND EXISTS(
	                               SELECT 1
	                               FROM   dbo.fnSplit(@BaseListCodes, '';'') AS fs
	                               WHERE  fs.Name = rdi2.Code
	                           )
	            ) b2
	            ON  b2.EnterpriseId = rdi.EnterpriseId
	       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas
	            ON  cas.EnterpriseId = rdi.EnterpriseId
	       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_PublicCates AS cpc
	            ON  cas.AccommodationClass = cpc.CateId
	            AND cpc.CateTypeId = 500
	            AND cpc.IsDeleted = 0
	WHERE  (
	           (@Class IS NULL AND cpc.CateName NOT LIKE N''% sao'')
	           OR cpc.CateName LIKE N''%'' + @Class + N'' sao''
	       )
	       AND rdi.IsDeleted = 0
	       AND rdi.TypeReport = 1
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi.ForMonth)
	           )
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@SellListCodes, '';'') AS fs
	               WHERE  fs.Name = rdi.Code
	           )

	SELECT @Title,
	       ISNULL(@Unit, '''')   AS Unit,
	       ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             CASE
	                                  WHEN ISNULL(b2.PerformPreviousPeriod, 0) = 0 THEN 0
	                                  ELSE ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0)) / ISNULL(b2.PerformPreviousPeriod, 0)
	                             END
	                         ) / ISNULL(COUNT(1), 0)
	               END
	           ) * 100,
	           0
	       ),
	       ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             CASE
	                                  WHEN ISNULL(b2.PerformInPeriod, 0) = 0 THEN 0
	                                  ELSE rdi.PerformInPeriod / ISNULL(b2.PerformInPeriod, 0)
	                             END
	                         ) / ISNULL(COUNT(1), 0)
	               END
	           ) * 100,
	           0
	       ),
	       0,
	       ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             CASE
	                                  WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                  ELSE ISNULL(
	                                           rdi.AccumulatedBeginingOfYear / ISNULL(b2.AccumulatedBeginingOfYear, 0),
	                                           0
	                                       )
	                             END
	                         ) / ISNULL(COUNT(1), 0)
	               END
	           ) * 100,
	           0
	       ),
	       (
	           CASE
	                WHEN ISNULL(@PreAccumulatedBeginingOfYear, 0) = 0 THEN 0
	                ELSE ISNULL(
	                         (
	                             CASE
	                                  WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                                  ELSE SUM(
	                                           CASE
	                                                WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                                ELSE ISNULL(
	                                                         rdi.AccumulatedBeginingOfYear / ISNULL(b2.AccumulatedBeginingOfYear, 0),
	                                                         0
	                                                     )
	                                           END
	                                       ) / ISNULL(COUNT(1), 0)
	                             END
	                         ) / ISNULL(@PreAccumulatedBeginingOfYear, 0),
	                         0
	                     ) * 100
	           END
	       ) * 100,
	       ISNULL(@Level, '''')  AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	       INNER JOIN (
	                SELECT rdi2.*
	                FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas1
	                            ON  cas1.EnterpriseId = rdi2.EnterpriseId
	                       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_PublicCates AS cpc
	                            ON  cas1.AccommodationClass = cpc.CateId
	                            AND cpc.CateTypeId = 500
	                            AND cpc.IsDeleted = 0
	                WHERE  (
	                           (@Class IS NULL AND cpc.CateName NOT LIKE N''% sao'')
	                           OR cpc.CateName LIKE N''%'' + @Class + N'' sao''
	                       )
	                       AND rdi2.TypeReport = 1
	                       AND rdi2.IsDeleted = 0
	                       AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	                       AND EXISTS(
	                               SELECT 1
	                               FROM   dbo.fnSplit(@BaseListCodes, '';'') AS fs
	                               WHERE  fs.Name = rdi2.Code
	                           )
	            ) b2
	            ON  b2.EnterpriseId = rdi.EnterpriseId
	       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas
	            ON  cas.EnterpriseId = rdi.EnterpriseId
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Code = rdi.Code
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+2,0))
	            AND rdi2.IsDeleted = 0
	            AND rdi2.TypeReport = 1
	       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_PublicCates AS cpc
	            ON  cas.AccommodationClass = cpc.CateId
	            AND cpc.CateTypeId = 500
	            AND cpc.IsDeleted = 0
	WHERE  (
	           (@Class IS NULL AND cpc.CateName NOT LIKE N''% sao'')
	           OR cpc.CateName LIKE N''%'' + @Class + N'' sao''
	       )
	       AND rdi.IsDeleted = 0
	       AND rdi.TypeReport = 1
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@SellListCodes, '';'') AS fs
	               WHERE  fs.Name = rdi.Code
	           )
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_ThongKe_CongSuatPhong_TrungBinh_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_ThongKe_CongSuatPhong_TrungBinh_IndustryScope
	@Title NVARCHAR(1500),
	@ForMonth DATETIME,
	@Unit NVARCHAR(500),
	@BaseListCodes VARCHAR(500),
	@SellListCodes VARCHAR(500),
	@Level VARCHAR(10),
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	DECLARE @PreAccumulatedBeginingOfYear FLOAT

	SELECT @PreAccumulatedBeginingOfYear = ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             ISNULL(
	                                 (
	                                     CASE
	                                          WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                          ELSE rdi.AccumulatedBeginingOfYear / b2.AccumulatedBeginingOfYear
	                                     END
	                                 ),
	                                 0
	                             )
	                         ) / COUNT(1)
	               END
	           ),
	           0
	       )
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	       INNER JOIN (
	                SELECT rdi2.AccumulatedBeginingOfYear,
	                       rdi2.EnterpriseId
	                FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                WHERE  rdi2.IsDeleted = 0
	                       AND rdi2.TypeReport = 1
	                       AND (
	                               MONTH(@ForMonth) = MONTH(rdi2.ForMonth)
	                               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi2.ForMonth)
	                           )
	                       AND EXISTS(
	                               SELECT 1
	                               FROM   dbo.fnSplit(@BaseListCodes, '';'') AS fs
	                               WHERE  fs.Name = rdi2.Code
	                           )
	            ) b2
	            ON  b2.EnterpriseId = rdi.EnterpriseId
	WHERE  rdi.IsDeleted = 0
	       AND rdi.TypeReport = 1
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi.ForMonth)
	           )
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@SellListCodes, '';'') AS fs
	               WHERE  fs.Name = rdi.Code
	           )

	SELECT @Title,
	       ISNULL(@Unit, '''')   AS Unit,
	       ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             CASE
	                                  WHEN ISNULL(b2.PerformPreviousPeriod, 0) = 0 THEN 0
	                                  ELSE ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0)) /
	                                       b2.PerformPreviousPeriod
	                             END
	                         ) / ISNULL(COUNT(1), 0)
	               END
	           ) * 100,
	           0
	       ),
	       ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             CASE
	                                  WHEN ISNULL(b2.PerformInPeriod, 0) = 0 THEN 0
	                                  ELSE rdi.PerformInPeriod / b2.PerformInPeriod
	                             END
	                         ) / COUNT(1)
	               END
	           ) * 100,
	           0
	       ),
	       0,
	       ISNULL(
	           (
	               CASE
	                    WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                    ELSE SUM(
	                             ISNULL(
	                                 (
	                                     CASE
	                                          WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                          ELSE rdi.AccumulatedBeginingOfYear / b2.AccumulatedBeginingOfYear
	                                     END
	                                 ),
	                                 0
	                             )
	                         ) / COUNT(1)
	               END
	           ) * 100,
	           0
	       ),
	       (
	           ISNULL(
	               CASE
	                    WHEN ISNULL(@PreAccumulatedBeginingOfYear, 0) = 0 THEN 0
	                    ELSE (
	                             CASE
	                                  WHEN ISNULL(COUNT(1), 0) = 0 THEN 0
	                                  ELSE SUM(
	                                           ISNULL(
	                                               (
	                                                   CASE
	                                                        WHEN ISNULL(b2.AccumulatedBeginingOfYear, 0) = 0 THEN 0
	                                                        ELSE rdi.AccumulatedBeginingOfYear /
	                                                             b2.AccumulatedBeginingOfYear
	                                                   END
	                                               ),
	                                               0
	                                           )
	                                       ) / COUNT(1)
	                             END
	                         ) / @PreAccumulatedBeginingOfYear
	               END,
	               0
	           ) * 100
	       ) * 100,
	       ISNULL(@Level, '''')  AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	       INNER JOIN (
	                SELECT ISNULL(rdi2.PerformPreviousPeriod, rdi3.PerformInPeriod) AS PerformPreviousPeriod,
	                       rdi2.PerformInPeriod,
	                       rdi2.AccumulatedBeginingOfYear,
	                       rdi2.EnterpriseId
	                FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi3
	                            ON  rdi3.Code = rdi2.Code
	                            AND rdi3.IsDeleted = 0
	                            AND (rdi3.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0) AND rdi3.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+2,0))
	                WHERE  rdi2.IsDeleted = 0
	                       AND rdi2.TypeReport = 1
	                       AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	                       AND EXISTS(
	                               SELECT 1
	                               FROM   dbo.fnSplit(@BaseListCodes, '';'') AS fs
	                               WHERE  fs.Name = rdi2.Code
	                           )
	            ) b2
	            ON  b2.EnterpriseId = rdi.EnterpriseId
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Code = rdi.Code
	            AND rdi2.IsDeleted = 0
	            AND rdi2.TypeReport = 1
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+2,0))
	WHERE  rdi.IsDeleted = 0
	       AND rdi.TypeReport = 1
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@SellListCodes, '';'') AS fs
	               WHERE  fs.Name = rdi.Code
	           )
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_ThongKe_TongDoanhThu_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_ThongKe_TongDoanhThu_IndustryScope

	@Title NVARCHAR(1500),
	@ForMonth DATETIME,
	@Unit NVARCHAR(500),
	@ListCodes VARCHAR(500),
	@Level VARCHAR(10),
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);



	DECLARE @SamePeriod               DATETIME,
	        @PerformInSamePeriod      FLOAT,
	        @PerformFromStartYear     FLOAT,
	        @PerformFromStartYearSamePeriod FLOAT;

	SET @SamePeriod = DATEADD(MONTH, 0, DATEADD(YEAR, -1, @ForMonth))


	SELECT @PerformInSamePeriod = a.PerformPreviousPeriod
	FROM   (
	           SELECT SUM(
	                      CASE
	                           WHEN FLOOR(rdi.PerformPreviousPeriod) <> CEILING(rdi.PerformPreviousPeriod) THEN CAST(
	                                    ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0)) * 1000000 AS
	                                    DECIMAL
	                                )
	                                * 1.0
	                           ELSE ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	                      END
	                  )                   AS PerformPreviousPeriod
	           FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	                  LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       ON  rdi2.Code = rdi.Code
	                       AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@SamePeriod)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@SamePeriod)+2,0))
	           WHERE  (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@SamePeriod),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@SamePeriod)+1,0))
	                  AND rdi.TypeReport = 1
	                  AND EXISTS(
	                          SELECT 1
	                          FROM   dbo.fnSplit(@ListCodes, '';'') AS fs
	                          WHERE  fs.Name = rdi.Code
	                      )

	       ) AS a

	SELECT @PerformFromStartYear = SUM(
	           CASE
	                WHEN FLOOR(rdi.PerformPreviousPeriod) <> CEILING(rdi.PerformPreviousPeriod) THEN CAST(ISNULL(rdi.PerformPreviousPeriod, 0) * 1000000 AS DECIMAL)
	                     * 1.0
	                ELSE ISNULL(rdi.PerformPreviousPeriod, 0)
	           END
	       )
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	WHERE  DATEDIFF(YEAR, @ForMonth, rdi.ForMonth) = 0
	       AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0)
	       AND rdi.TypeReport = 1
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@ListCodes, '';'') AS fs
	               WHERE  fs.Name = rdi.Code
	           )



	SELECT @PerformFromStartYearSamePeriod = SUM(
	           CASE
	                WHEN FLOOR(rdi.PerformPreviousPeriod) <> CEILING(rdi.PerformPreviousPeriod) THEN CAST(ISNULL(rdi.PerformPreviousPeriod, 0) * 1000000 AS DECIMAL)
	                     * 1.0
	                ELSE ISNULL(rdi.PerformPreviousPeriod, 0)
	           END
	       )
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi
	WHERE  DATEDIFF(YEAR, @SamePeriod, rdi.ForMonth) = 0
	       AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,DATEADD(MONTH, 1, @SamePeriod))+1,0)
	       AND rdi.TypeReport = 1
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@ListCodes, '';'') AS fs
	               WHERE  fs.Name = rdi.Code
	           )



	SELECT @Title,
	       @Unit,
	       a.PerformPreviousPeriod,
	       a.PerformInPeriod,
	       CASE
	            WHEN @PerformInSamePeriod = 0 THEN 0
	            ELSE a.PerformInPeriod / @PerformInSamePeriod
	       END  AS RateSamePeriod,
	       @PerformFromStartYear + a.PerformInPeriod AS PerformFromStartYear,
	       CASE
	            WHEN @PerformFromStartYearSamePeriod = 0 THEN 0
	            ELSE (@PerformFromStartYear + a.PerformInPeriod) / @PerformFromStartYearSamePeriod
	       END  AS PerformFromStartYearSamePeriod,
	       @Level
	FROM   (
	           SELECT SUM(
	                      CASE
	                           WHEN FLOOR(rdi.PerformPreviousPeriod) <> CEILING(rdi.PerformPreviousPeriod) THEN CAST(
	                                    ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0)) * 1000000 AS
	                                    DECIMAL
	                                )
	                                * 1.0
	                           ELSE ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	                      END
	                  )                   AS PerformPreviousPeriod,
	                  SUM(
	                      CASE
	                           WHEN FLOOR(rdi.PerformInPeriod) <> CEILING(rdi.PerformInPeriod) THEN CAST(ISNULL(rdi.PerformInPeriod, 0) * 1000000 AS DECIMAL)
	                                * 1.0
	                           ELSE ISNULL(rdi.PerformInPeriod, 0)
	                      END
	                  )                   AS PerformInPeriod
	           FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	                  LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       ON  rdi2.Code = rdi.Code
	                       AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@SamePeriod)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@SamePeriod)+2,0))
	                       AND rdi2.IsDeleted = 0
	           WHERE  (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	                  AND rdi.TypeReport = 1
	                  AND rdi.IsDeleted = 0
	                  AND EXISTS(
	                          SELECT 1
	                          FROM   dbo.fnSplit(@ListCodes, '';'') AS fs
	                          WHERE  fs.Name = rdi.Code
	                      )

	       )    AS a
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope

	@Title NVARCHAR(1500),
	@Unit NVARCHAR(1500),
	@ForMonth DATETIME,
	@ListCodes VARCHAR(500),
	@Level VARCHAR(10),
	@TypeReports VARCHAR(500),
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	SELECT @Title              AS Title,
	       @Unit               AS Unit,
	       SUM(
	           ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	       ) * 1.0             AS PerformPreviousPeriod,
	       SUM(ISNULL(rdi.PerformInPeriod, 0)) * 1.0 AS PerformInPeriod,
	       CAST(
	           (
	               SUM(rdi.PerformInPeriod) / (
	                   SELECT SUM(ISNULL(rdi1.PerformInPeriod, 0))
	                   FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi1
	                   WHERE  rdi1.IsDeleted = 0
	                          AND (
	                                  MONTH(@ForMonth) = MONTH(rdi1.ForMonth)
	                                  AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi1.ForMonth)
	                              )
	                          AND rdi1.Code = rdi.Code
	                          AND EXISTS(
	                                  SELECT 1
	                                  FROM   dbo.fnSplit(@TypeReports, '';'') AS fs
	                                  WHERE  CAST(fs.Name AS INT) = rdi1.TypeReport
	                              )

	               ) * 100
	           ) AS FLOAT
	       )                   AS SamePeriodRateOfPerform,
	       SUM(ISNULL(rdi.AccumulatedBeginingOfYear, 0)) * 1.0 AS AccumulatedBeginingOfYear,
	       CAST(
	           ISNULL(
	               (
	                   SUM(rdi.AccumulatedBeginingOfYear) / (
	                       SELECT SUM(ISNULL(rdi2.AccumulatedBeginingOfYear, 0))
	                       FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       WHERE  rdi2.IsDeleted = 0
	                              AND (
	                                      MONTH(@ForMonth) = MONTH(rdi2.ForMonth)
	                                      AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi2.ForMonth)
	                                  )
	                              AND rdi2.Code = rdi.Code
	                              AND EXISTS(
	                                      SELECT 1
	                                      FROM   dbo.fnSplit(@TypeReports, '';'') AS fs
	                                      WHERE  CAST(fs.Name AS INT) = rdi2.TypeReport
	                                  )

	                   ) * 100
	               ),
	               0
	           ) AS FLOAT
	       )                   AS SamePeriodRateOfAccumulated,
	       ISNULL(@Level, '''')  AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Targets = rdi.Targets
	            AND rdi2.Unit = rdi.Unit
	            AND rdi2.Code = rdi.Code
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)-1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+0,0))
	            AND EXISTS(
	                    SELECT 1
	                    FROM   dbo.fnSplit(@TypeReports, '';'') AS fs
	                    WHERE  CAST(fs.Name AS INT) = rdi2.TypeReport
	                )

	WHERE  rdi.IsDeleted = 0

	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@TypeReports, '';'') AS fs
	               WHERE  CAST(fs.Name AS INT) = rdi.TypeReport
	           )
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@ListCodes, '';'') AS fs
	               WHERE  fs.Name = rdi.Code
	           )
	GROUP BY
	       rdi.Code
	ORDER BY
	       rdi.Code
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn',N'p_Report_ThongKe_TongKhachDuLich_IndustryScope',N'P',N'PROCEDURE dbo.p_Report_ThongKe_TongKhachDuLich_IndustryScope

	@Title NVARCHAR(1500),
	@Unit NVARCHAR(1500),
	@ForMonth DATETIME,
	@ListCodes VARCHAR(500),
	@Level VARCHAR(10),
	@TypeReports VARCHAR(500),
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);




	DECLARE @PerformPreviousPeriod         FLOAT = 0,
	        @AccumulatedBeginingOfYear     FLOAT = 0;



	SELECT @PerformPreviousPeriod = SUM(ISNULL(rdi1.PerformPreviousPeriod, 0))
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi1
	WHERE  rdi1.IsDeleted = 0
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi1.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi1.ForMonth)
	           )
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@ListCodes, '';'') AS fs
	               WHERE  fs.Name = rdi1.Code
	           )
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@TypeReports, '';'') AS fs
	               WHERE  CAST(fs.Name AS INT) = rdi1.TypeReport
	           )


	SELECT @AccumulatedBeginingOfYear = SUM(ISNULL(rdi2.AccumulatedBeginingOfYear, 0))
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	WHERE  rdi2.IsDeleted = 0
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi2.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi2.ForMonth)
	           )
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@ListCodes, '';'') AS fs
	               WHERE  fs.Name = rdi2.Code
	       )
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@TypeReports, '';'') AS fs
	               WHERE  CAST(fs.Name AS INT) = rdi2.TypeReport
	           )


	SELECT @Title              AS Title,
	       @Unit               AS Unit,
	       SUM(
	           ISNULL(rdi.PerformPreviousPeriod, ISNULL(rdi2.PerformInPeriod, 0))
	       ) * 1.0             AS PerformPreviousPeriod,
	       SUM(ISNULL(rdi.PerformInPeriod, 0)) * 1.0 AS PerformInPeriod,
	       ISNULL(
	           CASE
	                WHEN @PerformPreviousPeriod = 0 THEN 0
	                ELSE SUM(ISNULL(rdi.PerformInPeriod, 0)) * 1.0 / @PerformPreviousPeriod
	           END,
	           0
	       )                   AS SamePeriodRateOfPerform,
	       SUM(ISNULL(rdi.AccumulatedBeginingOfYear, 0)) * 1.0 AS AccumulatedBeginingOfYear,
	       ISNULL(
	           CASE
	                WHEN @AccumulatedBeginingOfYear = 0 THEN 0
	                ELSE SUM(ISNULL(rdi.AccumulatedBeginingOfYear, 0)) * 1.0 / @AccumulatedBeginingOfYear
	           END,
	           0
	       )                   AS SamePeriodRateOfAccumulated,
	       ISNULL(@Level, '''')  AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Targets = rdi.Targets
	            AND rdi2.Unit = rdi.Unit
	            AND rdi2.Code = rdi.Code
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)-1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+0,0))

	            AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@TypeReports, '';'') AS fs
	               WHERE  CAST(fs.Name AS INT) = rdi2.TypeReport
	           )
	WHERE  rdi.IsDeleted = 0

	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@TypeReports, '';'') AS fs
	               WHERE  CAST(fs.Name AS INT) = rdi.TypeReport
	           )
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@ListCodes, '';'') AS fs
	               WHERE  fs.Name = rdi.Code
	           )
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn.cate',N'f_Chatbot_AuthorizedEnterprises',N'IF',N'FUNCTION dbo.f_Chatbot_AuthorizedEnterprises(@UserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500),@AllowProvince bit)
RETURNS TABLE AS RETURN (
 SELECT e.EnterpriseId FROM dbo.Sys_Users actor
 CROSS APPLY dbo.f_Chatbot_UserScope(@UserId,@ProvinceRoleIds,@EnterpriseRoleIds) validated
 CROSS APPLY dbo.f_Report_IndustryEnterprises(actor.UserName) e
 WHERE actor.UserId=@UserId
 AND (@AllowProvince=1 OR (e.IsApproved=1 AND EXISTS(
 SELECT 1 FROM dbo.Cate_EnterprisePermissions p WHERE p.ForUser=actor.UserName AND p.EnterpriseId=e.EnterpriseId)))
)');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn.cate',N'f_Chatbot_UserScope',N'IF',N'FUNCTION dbo.f_Chatbot_UserScope(@UserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500))
RETURNS TABLE AS RETURN (
SELECT Flags.*,
 CAST(CASE WHEN HasFullAccess=1 OR HasIndustryRole=1 THEN 1 ELSE 0 END AS bit) HasProvinceRole,
 CAST(CASE WHEN (HasFullAccess=1 OR HasEnterpriseRole=0) AND EXISTS(
 SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Sys_Permissions p ON p.RoleId=ur.RoleId JOIN dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
 WHERE ur.UserId=Flags.UserId AND f.Area=''Report'' AND f.Name=''Dashboard'' AND p.Action=''View'') THEN 1 ELSE 0 END AS bit) CanReadDashboard,
 CAST(CASE WHEN EXISTS(
 SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Sys_Permissions p ON p.RoleId=ur.RoleId JOIN dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
 WHERE ur.UserId=Flags.UserId AND f.Area=''Report'' AND f.Name=''Import'' AND p.Action=''View'') THEN 1 ELSE 0 END AS bit) CanReadImports,
 CAST(CASE WHEN (HasFullAccess=1 OR HasEnterpriseRole=0) AND EXISTS(
 SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Sys_Permissions p ON p.RoleId=ur.RoleId JOIN dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
 WHERE ur.UserId=Flags.UserId AND f.Area=''Cate'' AND f.Name=''Enterprise'' AND p.Action=''View'') THEN 1 ELSE 0 END AS bit) CanReadRegistryDetail
 FROM dbo.Sys_Users actor CROSS APPLY dbo.f_Report_IndustryUserScope(actor.UserName) Flags
 WHERE actor.UserId=@UserId
 -- Application mapping must agree with deployed SQL; disagreement fails closed.
 AND NOT EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m WHERE
  (m.ScopeMode IN(''all'',''industry'') AND CHARINDEX('',''+CONVERT(varchar(11),m.RoleId)+'','','',''+ISNULL(@ProvinceRoleIds,'''')+'','')=0)
  OR (m.ScopeMode=''enterprise'' AND CHARINDEX('',''+CONVERT(varchar(11),m.RoleId)+'','','',''+ISNULL(@EnterpriseRoleIds,'''')+'','')=0))
 AND NOT EXISTS(SELECT 1 FROM dbo.fnSplit(@ProvinceRoleIds,'','') token WHERE NOT EXISTS(
  SELECT 1 FROM dbo.Report_RoleMappings m WHERE m.ScopeMode IN(''all'',''industry'') AND m.RoleId=TRY_CONVERT(int,token.Name)))
 AND NOT EXISTS(SELECT 1 FROM dbo.fnSplit(@EnterpriseRoleIds,'','') token WHERE NOT EXISTS(
  SELECT 1 FROM dbo.Report_RoleMappings m WHERE m.ScopeMode=''enterprise'' AND m.RoleId=TRY_CONVERT(int,token.Name)))

)');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn.cate',N'f_Report_IndustryEnterprises',N'IF',N'FUNCTION dbo.f_Report_IndustryEnterprises(@UserName varchar(255))
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
  SELECT 1 FROM dbo.Cate_BusinessEnterprise b CROSS APPLY dbo.fnSplit(b.IndustryIds,'','') token
  JOIN dbo.Report_UserBusinessIndustryPermissions p ON p.UserId=u.UserId AND p.IndustryId=TRY_CONVERT(int,LTRIM(RTRIM(token.Name)))
  WHERE b.EnterpriseId=e.EnterpriseId))
)');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn.cate',N'f_Report_IndustryUserScope',N'IF',N'FUNCTION dbo.f_Report_IndustryUserScope(@UserName varchar(255))
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
 JOIN dbo.Report_RoleMappings m ON m.RoleId=r.RoleId WHERE ur.UserId=u.UserId AND m.ScopeMode=''all'') THEN 1 ELSE 0 END) HasFullAccess,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Report_RoleMappings m ON m.RoleId=r.RoleId WHERE ur.UserId=u.UserId AND m.ScopeMode=''industry'') THEN 1 ELSE 0 END) HasIndustryRole,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Report_RoleMappings m ON m.RoleId=r.RoleId WHERE ur.UserId=u.UserId AND m.ScopeMode=''enterprise'') THEN 1 ELSE 0 END) HasEnterpriseRole
 FROM dbo.Sys_Users u WHERE u.UserName=@UserName AND u.IsActive=1 AND u.IsDeleted=0 AND ISNULL(u.IsLocked,0)=0
 AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings WHERE SemanticKey=''SystemAdministrator'' AND ScopeMode=''all'')
 AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings WHERE SemanticKey=''Enterprise'' AND ScopeMode=''enterprise'')
 AND NOT EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m LEFT JOIN dbo.Sys_Roles r ON r.RoleId=m.RoleId WHERE r.RoleId IS NULL OR r.IsDeleted<>0)
 ) flags
)');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn.cate',N'p_Cate_Chatbot_EnterpriseProducts',N'P',N'PROCEDURE dbo.p_Cate_Chatbot_EnterpriseProducts
 @ChatbotUserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500),
 @EnterpriseId int, @Offset int=0, @Limit int=10
AS BEGIN
 SET NOCOUNT ON;
 SELECT * INTO #ChatbotScope FROM dbo.f_Chatbot_UserScope(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds);


 CREATE TABLE #ChatbotEnterprises(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ChatbotEnterprises(EnterpriseId)
 SELECT authorized.EnterpriseId FROM dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,1) authorized
 WHERE @EnterpriseId IS NULL OR authorized.EnterpriseId=@EnterpriseId
 OPTION (RECOMPILE);
IF NOT EXISTS(SELECT 1 FROM #ChatbotEnterprises a
 WHERE a.EnterpriseId=@EnterpriseId) THROW 50113,''Enterprise access denied'',1;

 IF @EnterpriseId IS NULL OR @Offset<0 OR @Offset>100000 OR @Limit<1 OR @Limit>50 THROW 50101,''Invalid product query'',1;
 SELECT * INTO #ChatbotPageSource FROM (
SELECT DISTINCT p.ProductId,p.ProductCode,p.ProductName,p.Unit,p.IndustryId,i.IndustryName,
 a.IsMainProduct,a.DisplayOrder
 FROM dbo.Cate_BusinessEnterpriseProduct a
 JOIN dbo.Cate_BusinessProduct p ON p.ProductId=a.ProductId AND p.IsDeleted=0 AND p.IsActive=1
 LEFT JOIN dbo.Cate_BusinessIndustry i ON i.IndustryId=p.IndustryId AND i.IsDeleted=0
 JOIN dbo.Cate_Enterprises e ON e.EnterpriseId=a.EnterpriseId AND e.IsDeleted=0 AND e.IsActive=1
 WHERE a.EnterpriseId=@EnterpriseId
) materialized OPTION (RECOMPILE);
;WITH Ranked AS (SELECT *,ROW_NUMBER() OVER(ORDER BY DisplayOrder,ProductId) RowNo FROM #ChatbotPageSource),
 Total AS (SELECT COUNT(*) TotalRow FROM #ChatbotPageSource)
 SELECT t.TotalRow,r.ProductId,r.ProductCode,r.ProductName,r.Unit,r.IndustryId,r.IndustryName,r.IsMainProduct,r.DisplayOrder
 FROM Total t OUTER APPLY (SELECT * FROM Ranked WHERE RowNo>@Offset AND RowNo<=CONVERT(bigint,@Offset)+@Limit) r;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn.cate',N'p_Cate_Chatbot_EnterpriseScope',N'P',N'PROCEDURE dbo.p_Cate_Chatbot_EnterpriseScope
 @ChatbotUserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500),@Mode varchar(20),@EnterpriseId int=NULL
AS BEGIN
 SET NOCOUNT ON;
 SELECT * INTO #ChatbotScope FROM dbo.f_Chatbot_UserScope(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds);

 IF @Mode NOT IN(''access'',''assigned'',''detail'') THROW 50111,''Invalid scope query'',1;
 IF @Mode=''access'' BEGIN
  SELECT s.*, STUFF((SELECT ''|'' + m.SemanticKey + '':'' + CONVERT(varchar(11),m.RoleId) + '':'' + m.ScopeMode + '':'' + CONVERT(varchar(1),m.IsIndustryEditorTarget) FROM dbo.Report_RoleMappings m ORDER BY m.RoleId FOR XML PATH(''''),TYPE).value(''.'',''varchar(max)''),1,1,'''') AS RoleMappingSignature, CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,1)) THEN 1 ELSE 0 END AS bit) HasAuthorizedEnterprises
  FROM #ChatbotScope s; RETURN;
 END;
 IF @Mode=''detail'' AND NOT EXISTS(SELECT 1 FROM #ChatbotScope
 WHERE CanReadDashboard=1 AND CanReadRegistryDetail=1) THROW 50112,''Registry detail access denied'',1;

 CREATE TABLE #ChatbotEnterprises(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ChatbotEnterprises(EnterpriseId)
 SELECT authorized.EnterpriseId FROM dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,CASE WHEN @Mode=''detail'' THEN 1 ELSE 0 END) authorized
 WHERE @EnterpriseId IS NULL OR authorized.EnterpriseId=@EnterpriseId
 OPTION (RECOMPILE);
SELECT e.EnterpriseId,e.BusinessName,e.TaxCode,e.BusinessAddress,e.WardId,e.WardName,e.ProvinceId,e.ProvinceName,e.TypeBusiness,
 b.IndustryIds,b.EnterpriseTypeId,t.Name EnterpriseTypeName,b.EconomicSectorId,s.Name EconomicSectorName,
 b.EnterpriseStatusId,es.Name EnterpriseStatusName,e.IsActive,e.IsDeleted
 FROM dbo.Cate_Enterprises e
 JOIN #ChatbotEnterprises a ON a.EnterpriseId=e.EnterpriseId
 LEFT JOIN dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN dbo.Cate_EnterpriseType t ON t.EnterpriseTypeId=b.EnterpriseTypeId
 LEFT JOIN dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 LEFT JOIN dbo.Cate_EnterpriseStatus es ON es.EnterpriseStatusId=b.EnterpriseStatusId
 WHERE @EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn.cate',N'p_Report_IndustryPermissions_Get',N'P',N'PROCEDURE dbo.p_Report_IndustryPermissions_Get @UserId int,@RequestedBy varchar(255)
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.Sys_Users actor
  JOIN dbo.Sys_UserRoles ur ON ur.UserId=actor.UserId
  JOIN dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
  JOIN dbo.Sys_Permissions p ON p.RoleId=role.RoleId
  JOIN dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
  WHERE actor.UserName=@RequestedBy AND actor.IsActive=1 AND actor.IsDeleted=0
   AND ISNULL(actor.IsLocked,0)=0 AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m WHERE m.RoleId=ur.RoleId AND m.SemanticKey=''SystemAdministrator'' AND m.ScopeMode<>''enterprise'') AND f.Area=''Sys'' AND f.Name=''User'' AND p.Action=''Edit'')
  THROW 50113,''Configured system administrator and user management Edit permission are required.'',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Sys_Users target WHERE target.UserId=@UserId AND target.IsActive=1 AND target.IsDeleted=0
  AND EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
   WHERE ur.UserId=target.UserId AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m WHERE m.RoleId=ur.RoleId AND m.IsIndustryEditorTarget=1)))
  THROW 50002,''Target user is inactive, unknown or has no eligible role.'',1;
 SELECT i.IndustryId,i.IndustryCode,i.IndustryName,
  CONVERT(bit,CASE WHEN i.IsActive=1 AND i.IsDeleted=0 THEN 1 ELSE 0 END) IsActive,
  CONVERT(bit,CASE WHEN p.UserId IS NULL THEN 0 ELSE 1 END) IsSelected
 FROM dbo.Cate_BusinessIndustry i
 LEFT JOIN dbo.Report_UserBusinessIndustryPermissions p ON p.IndustryId=i.IndustryId AND p.UserId=@UserId
 WHERE (i.IsActive=1 AND i.IsDeleted=0) OR p.UserId IS NOT NULL
 ORDER BY i.IndustryCode,i.IndustryName,i.IndustryId;
END');
INSERT @Expected VALUES(N'baocaosct.khanhhoa.gov.vn.cate',N'p_Report_IndustryPermissions_Save',N'P',N'PROCEDURE dbo.p_Report_IndustryPermissions_Save
 @UserId int,@IndustryIds varchar(max),@SavedBy varchar(255)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 SET @IndustryIds=LTRIM(RTRIM(ISNULL(@IndustryIds,'''')));
 IF LEN(@IndustryIds)>20000 OR @IndustryIds LIKE '',%'' OR @IndustryIds LIKE ''%,'' OR @IndustryIds LIKE ''%,,%''
  THROW 50001,''Invalid comma-separated industry IDs.'',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Sys_Users target WHERE target.UserId=@UserId AND target.IsActive=1 AND target.IsDeleted=0
  AND EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
   WHERE ur.UserId=target.UserId AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m WHERE m.RoleId=ur.RoleId AND m.IsIndustryEditorTarget=1)))
  THROW 50002,''Target user is inactive, unknown or has no eligible role.'',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Sys_Users WHERE UserName=@SavedBy AND IsActive=1 AND IsDeleted=0)
  THROW 50003,''Audit user is inactive or unknown.'',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Sys_Users actor
  JOIN dbo.Sys_UserRoles ur ON ur.UserId=actor.UserId
  JOIN dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
  JOIN dbo.Sys_Permissions p ON p.RoleId=role.RoleId
  JOIN dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
  WHERE actor.UserName=@SavedBy AND actor.IsActive=1 AND actor.IsDeleted=0
   AND ISNULL(actor.IsLocked,0)=0 AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m WHERE m.RoleId=ur.RoleId AND m.SemanticKey=''SystemAdministrator'' AND m.ScopeMode<>''enterprise'') AND f.Area=''Sys'' AND f.Name=''User'' AND p.Action=''Edit'')
  THROW 50113,''Configured system administrator and user management Edit permission are required.'',1;
 IF @IndustryIds<>'''' AND EXISTS(SELECT 1 FROM dbo.fnSplit(@IndustryIds,'','') token
  WHERE TRY_CONVERT(int,LTRIM(RTRIM(token.Name))) IS NULL OR NOT EXISTS(
   SELECT 1 FROM dbo.Cate_BusinessIndustry i WHERE i.IndustryId=TRY_CONVERT(int,LTRIM(RTRIM(token.Name))) AND i.IsActive=1 AND i.IsDeleted=0))
  THROW 50004,''One or more industry IDs are invalid or inactive.'',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @LockedUser int;
  SELECT @LockedUser=UserId FROM dbo.Sys_Users WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId;
  DELETE dbo.Report_UserBusinessIndustryPermissions WHERE UserId=@UserId;
  IF @IndustryIds<>'''' INSERT dbo.Report_UserBusinessIndustryPermissions(UserId,IndustryId,SavedBy)
   SELECT DISTINCT @UserId,TRY_CONVERT(int,LTRIM(RTRIM(Name))),@SavedBy FROM dbo.fnSplit(@IndustryIds,'','');
  COMMIT;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  THROW;
 END CATCH;
 RETURN @UserId;
END');
;WITH RawActual AS (
 SELECT N'baocaosct.khanhhoa.gov.vn.cate' DatabaseName,o.name COLLATE Latin1_General_100_BIN2 ObjectName,o.type COLLATE DATABASE_DEFAULT ObjectType,m.definition COLLATE Latin1_General_100_BIN2 Definition
 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.objects o JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.schemas s ON s.schema_id=o.schema_id LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.sql_modules m ON m.object_id=o.object_id WHERE s.name='dbo'
 UNION ALL
 SELECT N'baocaosct.khanhhoa.gov.vn',o.name COLLATE Latin1_General_100_BIN2,o.type COLLATE DATABASE_DEFAULT,m.definition COLLATE Latin1_General_100_BIN2
 FROM [baocaosct.khanhhoa.gov.vn].sys.objects o JOIN [baocaosct.khanhhoa.gov.vn].sys.schemas s ON s.schema_id=o.schema_id LEFT JOIN [baocaosct.khanhhoa.gov.vn].sys.sql_modules m ON m.object_id=o.object_id WHERE s.name='dbo'
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
INSERT @Indexes VALUES(N'baocaosct.khanhhoa.gov.vn',N'Report_DataImports',N'IX_ReportPerformance_Imports_Period',N'ForMonth,TypeReport,EnterpriseId',N'AccumulatedBeginingOfYear,Code,ComparedSamePeriodLastYear,CreatedDate,IsDeleted,IsLate,LastModifiedDate,PerformInPeriod,PerformPreviousPeriod,Unit');
INSERT @Indexes VALUES(N'baocaosct.khanhhoa.gov.vn',N'Report_DataImports',N'IX_ReportPerformance_Imports_EnterprisePeriod',N'EnterpriseId,ForMonth,TypeReport',N'Code,CreatedDate,IsDeleted,IsLate,LastModifiedDate,PerformInPeriod,Unit');
INSERT @Indexes VALUES(N'baocaosct.khanhhoa.gov.vn',N'Report_ReportFiles',N'IX_ReportPerformance_Files_Period',N'ForMonth,EnterpriseId',N'CreatedDate,IsDeleted,IsLate,LastModifiedDate');
INSERT @Indexes VALUES(N'baocaosct.khanhhoa.gov.vn.cate',N'Cate_Enterprises',N'IX_ReportPerformance_Enterprises_Id',N'EnterpriseId',N'BusinessName,IsActive,IsApproved,IsDeleted,TaxCode,TypeBusiness,WardId');
INSERT @Indexes VALUES(N'baocaosct.khanhhoa.gov.vn.cate',N'Cate_EnterprisePermissions',N'IX_ReportPerformance_Assignments_UserEnterprise',N'ForUser,EnterpriseId',N'');
INSERT @Indexes VALUES(N'baocaosct.khanhhoa.gov.vn.cate',N'Sys_Permissions',N'IX_ReportPerformance_Permissions_RoleFunction',N'RoleId,FunctionId',N'Action');
IF NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.indexes i WHERE i.object_id=OBJECT_ID(N'[baocaosct.khanhhoa.gov.vn].dbo.Report_DataImports') AND i.type IN(1,2) AND i.is_disabled=0 AND i.is_hypothetical=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=3 AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name=N'ForMonth') AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name=N'TypeReport') AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=3 AND k.is_descending_key=0 AND c.name=N'EnterpriseId') AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'AccumulatedBeginingOfYear')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'Code')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'ComparedSamePeriodLastYear')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'CreatedDate')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'IsDeleted')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'IsLate')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'LastModifiedDate')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'PerformInPeriod')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'PerformPreviousPeriod')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'Unit'))) INSERT @Issues VALUES('Index',N'baocaosct.khanhhoa.gov.vn',N'IX_ReportPerformance_Imports_Period','Missing enabled unfiltered equivalent covering index');
IF NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.indexes i WHERE i.object_id=OBJECT_ID(N'[baocaosct.khanhhoa.gov.vn].dbo.Report_DataImports') AND i.type IN(1,2) AND i.is_disabled=0 AND i.is_hypothetical=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=3 AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name=N'EnterpriseId') AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name=N'ForMonth') AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=3 AND k.is_descending_key=0 AND c.name=N'TypeReport') AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'Code')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'CreatedDate')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'IsDeleted')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'IsLate')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'LastModifiedDate')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'PerformInPeriod')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'Unit'))) INSERT @Issues VALUES('Index',N'baocaosct.khanhhoa.gov.vn',N'IX_ReportPerformance_Imports_EnterprisePeriod','Missing enabled unfiltered equivalent covering index');
IF NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.indexes i WHERE i.object_id=OBJECT_ID(N'[baocaosct.khanhhoa.gov.vn].dbo.Report_ReportFiles') AND i.type IN(1,2) AND i.is_disabled=0 AND i.is_hypothetical=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=2 AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name=N'ForMonth') AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name=N'EnterpriseId') AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'CreatedDate')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'IsDeleted')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'IsLate')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'LastModifiedDate'))) INSERT @Issues VALUES('Index',N'baocaosct.khanhhoa.gov.vn',N'IX_ReportPerformance_Files_Period','Missing enabled unfiltered equivalent covering index');
IF NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.indexes i WHERE i.object_id=OBJECT_ID(N'[baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises') AND i.type IN(1,2) AND i.is_disabled=0 AND i.is_hypothetical=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=1 AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name=N'EnterpriseId') AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'BusinessName')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'IsActive')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'IsApproved')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'IsDeleted')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'TaxCode')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'TypeBusiness')) AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'WardId'))) INSERT @Issues VALUES('Index',N'baocaosct.khanhhoa.gov.vn.cate',N'IX_ReportPerformance_Enterprises_Id','Missing enabled unfiltered equivalent covering index');
IF NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.indexes i WHERE i.object_id=OBJECT_ID(N'[baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions') AND i.type IN(1,2) AND i.is_disabled=0 AND i.is_hypothetical=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=2 AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name=N'ForUser') AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name=N'EnterpriseId')) INSERT @Issues VALUES('Index',N'baocaosct.khanhhoa.gov.vn.cate',N'IX_ReportPerformance_Assignments_UserEnterprise','Missing enabled unfiltered equivalent covering index');
IF NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.indexes i WHERE i.object_id=OBJECT_ID(N'[baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Permissions') AND i.type IN(1,2) AND i.is_disabled=0 AND i.is_hypothetical=0 AND i.has_filter=0 AND (SELECT COUNT(*) FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal>0)>=2 AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=1 AND k.is_descending_key=0 AND c.name=N'RoleId') AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND k.key_ordinal=2 AND k.is_descending_key=0 AND c.name=N'FunctionId') AND (i.type=1 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns k JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=k.object_id AND c.column_id=k.column_id WHERE k.object_id=i.object_id AND k.index_id=i.index_id AND c.name=N'Action'))) INSERT @Issues VALUES('Index',N'baocaosct.khanhhoa.gov.vn.cate',N'IX_ReportPerformance_Permissions_RoleFunction','Missing enabled unfiltered equivalent covering index');
DECLARE @Labels TABLE(LabelKey nvarchar(100),Message nvarchar(max));
INSERT @Labels VALUES(N'Dashboard_Showing',N'Hiển thị');
INSERT @Labels VALUES(N'Dashboard_SharesAllRows',N'Tỷ trọng tính trên tất cả các nhóm.');
INSERT @Labels VALUES(N'Dashboard_Breakdown',N'Cơ cấu');
INSERT @Labels VALUES(N'Dashboard_CoverageRate',N'Tỷ lệ DN có dữ liệu');
INSERT @Labels VALUES(N'Dashboard_ChartMode',N'Chế độ biểu đồ');
INSERT @Labels VALUES(N'Dashboard_CompleteThreeMetrics',N'Đủ 3 chỉ tiêu');
INSERT @Labels VALUES(N'Dashboard_CompleteMetrics',N'Đủ chỉ tiêu');
INSERT @Labels VALUES(N'Dashboard_FileLate',N'Tệp trễ');
INSERT @Labels VALUES(N'Dashboard_AllTypes',N'(mọi loại)');
INSERT @Labels VALUES(N'Dashboard_FilesAllTypes',N'Có tệp (mọi loại)');
INSERT @Labels VALUES(N'Dashboard_FileAnyTypeLabel',N'Tệp (mọi loại)');
INSERT @Labels VALUES(N'Dashboard_RateMode',N'Tỷ lệ %');
INSERT @Labels VALUES(N'Dashboard_EnterpriseFileCount',N'Số doanh nghiệp / tệp');
INSERT @Labels VALUES(N'Dashboard_EnterpriseCount',N'Số doanh nghiệp');
INSERT @Labels VALUES(N'Dashboard_CoverageTotal',N'Tỷ lệ / tổng DN');
INSERT @Labels VALUES(N'Dashboard_DataErrors',N'Lỗi dữ liệu');
INSERT @Labels VALUES(N'Dashboard_Reason',N'Giải trình');
INSERT @Labels VALUES(N'Dashboard_View',N'Xem');
INSERT @Labels VALUES(N'Dashboard_Retry',N'Thử lại');
INSERT @Labels VALUES(N'Dashboard_ProgressLoadFailed',N'Không tải được danh sách doanh nghiệp. Đang hiển thị kết quả của lần tải thành công gần nhất.');
INSERT @Labels VALUES(N'Dashboard_OutsideRegistry',N'Ngoài danh mục');
INSERT @Labels VALUES(N'Dashboard_IndustryScope',N'Ngành được phân quyền');
INSERT @Labels VALUES(N'Dashboard_ObservedEnterprises',N'DN có số liệu');
INSERT @Labels VALUES(N'Dashboard_Sector',N'Thành phần');
INSERT @Labels VALUES(N'Dashboard_NoEnterprisesOnPage',N'Trang này không có doanh nghiệp.');
INSERT @Labels VALUES(N'Dashboard_FirstPage',N'Về trang đầu');
INSERT @Labels VALUES(N'Dashboard_NoDeclineWarning',N'Không có cảnh báo giảm >10%.');
INSERT @Labels VALUES(N'Dashboard_WarningPagination',N'Phân trang doanh nghiệp cảnh báo');
INSERT @Labels VALUES(N'Dashboard_First',N'Đầu');
INSERT @Labels VALUES(N'Dashboard_Previous',N'Trước');
INSERT @Labels VALUES(N'Dashboard_Next',N'Sau');
INSERT @Labels VALUES(N'Dashboard_Last',N'Cuối');
INSERT @Labels VALUES(N'Dashboard_FullList',N'Xem danh sách đầy đủ');
INSERT @Labels VALUES(N'Dashboard_SkipFilters',N'Bỏ qua bộ lọc, đến nội dung báo cáo');
INSERT @Labels VALUES(N'Dashboard_ReportNavigation',N'Điều hướng báo cáo');
INSERT @Labels VALUES(N'Dashboard_Close',N'Đóng');
INSERT @Labels VALUES(N'Dashboard_EnterpriseIndicators',N'Chi tiết chỉ tiêu doanh nghiệp');
INSERT @Labels VALUES(N'Dashboard_Reset',N'Đặt lại');
INSERT @Labels VALUES(N'Dashboard_DataLabel',N'Số liệu');
INSERT @Labels VALUES(N'Dashboard_Months',N'tháng');
INSERT @Labels VALUES(N'Dashboard_DeclineTen',N'giảm >10%');
INSERT @Labels VALUES(N'Dashboard_InsufficientPeriod',N'Chưa đủ kỳ');
INSERT @Labels VALUES(N'Dashboard_DecliningEnterprises',N'doanh nghiệp giảm trên 10%');
INSERT @Labels VALUES(N'Dashboard_Page',N'Trang');
INSERT @Labels VALUES(N'Dashboard_NoEnterpriseIndicators',N'Chưa có dữ liệu chỉ tiêu cho doanh nghiệp, loại báo cáo và kỳ đã chọn.');
INSERT @Labels VALUES(N'Dashboard_RawValuesNote',N'Giá trị và đơn vị gốc do doanh nghiệp báo cáo. Các trường kỳ trước / kế hoạch là số khai báo, không thay thế dữ liệu lịch sử đã kiểm chứng.');
INSERT @Labels VALUES(N'Dashboard_Code',N'Mã');
INSERT @Labels VALUES(N'Dashboard_RawUnit',N'Đơn vị gốc');
INSERT @Labels VALUES(N'Dashboard_InPeriod',N'Trong kỳ');
INSERT @Labels VALUES(N'Dashboard_DeclaredPrevious',N'Kỳ trước khai báo');
INSERT @Labels VALUES(N'Dashboard_DeclaredAnnualPlan',N'Kế hoạch năm khai báo');
INSERT @Labels VALUES(N'Dashboard_IndustryGrantNote',N'Quyền ngành áp dụng cho toàn bộ doanh nghiệp có ít nhất một ngành được cấp; nhãn và chỉ tiêu có thể gồm các ngành khác của doanh nghiệp.');
INSERT @Labels VALUES(N'Dashboard_Overview_Title',N'Tổng quan');
INSERT @Labels VALUES(N'Dashboard_Analysis_Title',N'Phân tích');
INSERT @Labels VALUES(N'Dashboard_Warnings_Title',N'Cảnh báo');
INSERT @Labels VALUES(N'Dashboard_Progress_Title',N'Tiến độ');
INSERT @Labels VALUES(N'Dashboard_Nav_Overview',N'Tổng quan');
INSERT @Labels VALUES(N'Dashboard_Nav_Warnings',N'Cảnh báo');
INSERT @Labels VALUES(N'Dashboard_Type_Manufacturing',N'Sản xuất');
INSERT @Labels VALUES(N'Dashboard_Type_Trading',N'Thương mại');
INSERT @Labels VALUES(N'Dashboard_Type_ExportImport',N'Xuất nhập khẩu');
INSERT @Labels VALUES(N'Dashboard_Metric_IndustrialRevenue',N'Doanh thu CN');
INSERT @Labels VALUES(N'Dashboard_Metric_ExportValue',N'Xuất khẩu');
INSERT @Labels VALUES(N'Dashboard_Metric_ImportValue',N'Nhập khẩu');
INSERT @Labels VALUES(N'Dashboard_Metric_WholesaleRetailRevenue',N'Bán buôn, bán lẻ');
INSERT @Labels VALUES(N'Dashboard_Metric_VehicleRepairRevenue',N'Sửa chữa xe');
INSERT @Labels VALUES(N'Dashboard_Metric_RetailSubset',N'Bán lẻ');
INSERT @Labels VALUES(N'Dashboard_Metric_FobValue',N'Xuất khẩu FOB');
INSERT @Labels VALUES(N'Dashboard_Metric_DirectExport',N'Xuất khẩu trực tiếp');
INSERT @Labels VALUES(N'Dashboard_Metric_EntrustedExport',N'Xuất khẩu ủy thác');
INSERT @Labels VALUES(N'Dashboard_Unit_BillionVnd',N'Tỷ đồng');
INSERT @Labels VALUES(N'Dashboard_Unit_ThousandUsd',N'Nghìn USD');
INSERT @Labels VALUES(N'Dashboard_Unit_MillionVnd',N'Triệu đồng');
INSERT @Labels VALUES(N'Dashboard_Unit_Usd',N'USD');
INSERT @Labels VALUES(N'Dashboard_Filter_Period',N'Kỳ');
INSERT @Labels VALUES(N'Dashboard_Filter_Year',N'Năm');
INSERT @Labels VALUES(N'Dashboard_Filter_ReportType',N'Báo cáo');
INSERT @Labels VALUES(N'Dashboard_Filter_Metric',N'Chỉ tiêu');
INSERT @Labels VALUES(N'Dashboard_Filter_Advanced',N'Bộ lọc');
INSERT @Labels VALUES(N'Dashboard_Filter_ActiveCount',N'Bộ lọc đang áp dụng');
INSERT @Labels VALUES(N'Dashboard_Filter_Apply',N'Áp dụng');
INSERT @Labels VALUES(N'Dashboard_Filter_Ward',N'Phường / xã');
INSERT @Labels VALUES(N'Dashboard_Filter_EconomicSector',N'Khu vực');
INSERT @Labels VALUES(N'Dashboard_Filter_Industry',N'Ngành');
INSERT @Labels VALUES(N'Dashboard_Filter_IndustryNote',N'Lọc theo mã ngành doanh nghiệp.');
INSERT @Labels VALUES(N'Dashboard_Filter_AllIndustries',N'Tất cả');
INSERT @Labels VALUES(N'Dashboard_Filter_IndustryCode',N'Mã ngành');
INSERT @Labels VALUES(N'Dashboard_Filter_AllAreas',N'Tất cả');
INSERT @Labels VALUES(N'Dashboard_Filter_AllSectors',N'Tất cả');
INSERT @Labels VALUES(N'Dashboard_Filter_AllEnterprises',N'Tất cả');
INSERT @Labels VALUES(N'Dashboard_UnknownArea',N'Chưa xác định');
INSERT @Labels VALUES(N'Dashboard_UnknownSector',N'Chưa xác định');
INSERT @Labels VALUES(N'Dashboard_Month',N'Tháng');
INSERT @Labels VALUES(N'Dashboard_Months12',N'12 tháng');
INSERT @Labels VALUES(N'Dashboard_Enterprise',N'Doanh nghiệp');
INSERT @Labels VALUES(N'Dashboard_Enterprises',N'DN');
INSERT @Labels VALUES(N'Dashboard_Area',N'Địa bàn');
INSERT @Labels VALUES(N'Dashboard_Value',N'Giá trị');
INSERT @Labels VALUES(N'Dashboard_Change',N'Biến động');
INSERT @Labels VALUES(N'Dashboard_Rate',N'Tỷ lệ');
INSERT @Labels VALUES(N'Dashboard_PreviousPeriod',N'Kỳ trước');
INSERT @Labels VALUES(N'Dashboard_CurrentPeriod',N'Kỳ này');
INSERT @Labels VALUES(N'Dashboard_ChartValues',N'Xem số liệu');
INSERT @Labels VALUES(N'Dashboard_ChartEmpty',N'Chưa có dữ liệu.');
INSERT @Labels VALUES(N'Dashboard_ChartType1',N'Sản xuất');
INSERT @Labels VALUES(N'Dashboard_ChartType2',N'Thương mại');
INSERT @Labels VALUES(N'Dashboard_ChartType3',N'Xuất nhập khẩu');
INSERT @Labels VALUES(N'Dashboard_ChartDecliningEnterprises',N'Doanh nghiệp giảm');
INSERT @Labels VALUES(N'Dashboard_ChartReceived',N'Có dữ liệu');
INSERT @Labels VALUES(N'Dashboard_Overview_Subtitle',N'Tổng hợp theo loại báo cáo');
INSERT @Labels VALUES(N'Dashboard_Overview_Type',N'Loại');
INSERT @Labels VALUES(N'Dashboard_Overview_AnalyzeReport',N'Phân tích');
INSERT @Labels VALUES(N'Dashboard_Overview_ReceivedAnalyze',N'DN đã nhập');
INSERT @Labels VALUES(N'Dashboard_Overview_ReceivedTitle',N'DN đã nhập');
INSERT @Labels VALUES(N'Dashboard_Overview_TrendSubtitle',N'12 tháng');
INSERT @Labels VALUES(N'Dashboard_Overview_TrendAria',N'Xu hướng dữ liệu 12 tháng');
INSERT @Labels VALUES(N'Dashboard_Overview_Classification',N'Cần phân loại');
INSERT @Labels VALUES(N'Dashboard_Overview_ProvinceWide',N'Toàn tỉnh');
INSERT @Labels VALUES(N'Dashboard_Overview_NeedsClassification',N'DN');
INSERT @Labels VALUES(N'Dashboard_Overview_MissingBusiness',N'Thiếu hồ sơ');
INSERT @Labels VALUES(N'Dashboard_Overview_MissingIndustry',N'Thiếu ngành');
INSERT @Labels VALUES(N'Dashboard_Overview_MissingReportType',N'Thiếu loại báo cáo');
INSERT @Labels VALUES(N'Dashboard_Overview_ClassificationNote',N'Các nhóm có thể trùng nhau.');
INSERT @Labels VALUES(N'Dashboard_Overview_LargestChanges',N'Biến động');
INSERT @Labels VALUES(N'Dashboard_Overview_ViewAnalysis',N'Xem chi tiết');
INSERT @Labels VALUES(N'Dashboard_Overview_NoComparison',N'Chưa đủ kỳ so sánh.');
INSERT @Labels VALUES(N'Dashboard_Overview_ChangeSize',N'Mức độ');
INSERT @Labels VALUES(N'Dashboard_Overview_ReceiptNote',N'Dữ liệu nhập không đồng nghĩa đã nộp báo cáo.');
INSERT @Labels VALUES(N'Dashboard_Overview_FutureRows',N'Kỳ tương lai:');
INSERT @Labels VALUES(N'Dashboard_Analysis_CurrentPeriodCode',N'Kỳ hiện tại');
INSERT @Labels VALUES(N'Dashboard_Analysis_Mom',N'So tháng trước');
INSERT @Labels VALUES(N'Dashboard_Analysis_Yoy',N'So cùng kỳ');
INSERT @Labels VALUES(N'Dashboard_Analysis_ComparedCoverage',N'DN so sánh');
INSERT @Labels VALUES(N'Dashboard_Analysis_YtdTitle',N'Lũy kế');
INSERT @Labels VALUES(N'Dashboard_Analysis_YtdNote',N'tháng có dữ liệu');
INSERT @Labels VALUES(N'Dashboard_Analysis_Trend',N'Xu hướng');
INSERT @Labels VALUES(N'Dashboard_Analysis_TrendAria',N'Xu hướng 12 tháng');
INSERT @Labels VALUES(N'Dashboard_Analysis_TrendNote',N'Tháng chưa có dữ liệu để trống.');
INSERT @Labels VALUES(N'Dashboard_Analysis_NoData',N'Chưa có dữ liệu');
INSERT @Labels VALUES(N'Dashboard_Analysis_SectorTitle',N'Theo khu vực');
INSERT @Labels VALUES(N'Dashboard_Analysis_Share',N'Tỷ trọng');
INSERT @Labels VALUES(N'Dashboard_Analysis_NoSectorValue',N'Chưa có số liệu.');
INSERT @Labels VALUES(N'Dashboard_Analysis_LargestEnterpriseChanges',N'Biến động');
INSERT @Labels VALUES(N'Dashboard_Analysis_ComparableGroup',N'Đủ 2 kỳ');
INSERT @Labels VALUES(N'Dashboard_Analysis_NoComparison',N'Chưa đủ dữ liệu.');
INSERT @Labels VALUES(N'Dashboard_Analysis_ComparisonNote',N'MoM/YoY chỉ tính doanh nghiệp có đủ hai kỳ.');
INSERT @Labels VALUES(N'Dashboard_Warnings_Decline10',N'Giảm >10%');
INSERT @Labels VALUES(N'Dashboard_Warnings_Decline20',N'Giảm >20%');
INSERT @Labels VALUES(N'Dashboard_Warnings_Decline30',N'Giảm >30%');
INSERT @Labels VALUES(N'Dashboard_Warnings_LargestChange',N'Biến động lớn nhất');
INSERT @Labels VALUES(N'Dashboard_Warnings_DecliningEnterprises',N'DN giảm');
INSERT @Labels VALUES(N'Dashboard_Warnings_InLargestList',N'trong nhóm biến động lớn');
INSERT @Labels VALUES(N'Dashboard_Warnings_Trend',N'Xu hướng giảm');
INSERT @Labels VALUES(N'Dashboard_Warnings_DeclineOver10',N'Giảm >10%');
INSERT @Labels VALUES(N'Dashboard_Warnings_DeclineMom',N'Giảm so tháng trước');
INSERT @Labels VALUES(N'Dashboard_Warnings_TrendAria',N'Xu hướng doanh nghiệp giảm');
INSERT @Labels VALUES(N'Dashboard_Warnings_NoPairs',N'Chưa đủ dữ liệu');
INSERT @Labels VALUES(N'Dashboard_Warnings_Comparable',N'Có thể so sánh');
INSERT @Labels VALUES(N'Dashboard_Warnings_Conflict',N'Cần đối chiếu');
INSERT @Labels VALUES(N'Dashboard_Warnings_ConflictDescription',N'doanh nghiệp có mã trùng');
INSERT @Labels VALUES(N'Dashboard_Warnings_DeclineList',N'Giảm >10%');
INSERT @Labels VALUES(N'Dashboard_Warnings_ChangeList',N'Biến động theo doanh nghiệp');
INSERT @Labels VALUES(N'Dashboard_Warnings_NoChanges',N'Chưa có dữ liệu phù hợp.');
INSERT @Labels VALUES(N'Dashboard_Warnings_Note',N'Biến động chỉ mang tính cảnh báo dữ liệu.');
INSERT @Labels VALUES(N'Dashboard_Progress_CurrentClassification',N'theo phân loại hiện tại');
INSERT @Labels VALUES(N'Dashboard_Progress_ReceivedAssigned',N'Có dữ liệu / được phân loại');
INSERT @Labels VALUES(N'Dashboard_Progress_ObservedRatio',N'Tỷ lệ');
INSERT @Labels VALUES(N'Dashboard_Progress_PrimaryValues',N'Có chỉ tiêu chính');
INSERT @Labels VALUES(N'Dashboard_Progress_IncludingZero',N'Gồm giá trị 0');
INSERT @Labels VALUES(N'Dashboard_Progress_Duplicates',N'Mã trùng');
INSERT @Labels VALUES(N'Dashboard_Progress_NeedsReview',N'doanh nghiệp cần đối chiếu');
INSERT @Labels VALUES(N'Dashboard_Progress_FileAnyType',N'Có tệp');
INSERT @Labels VALUES(N'Dashboard_Progress_FileNote',N'Không đồng nghĩa đã nộp báo cáo');
INSERT @Labels VALUES(N'Dashboard_Progress_ReceiptTrend',N'Dữ liệu theo tháng');
INSERT @Labels VALUES(N'Dashboard_Progress_TrendAria',N'Xu hướng dữ liệu theo tháng');
INSERT @Labels VALUES(N'Dashboard_Progress_ReceivedEnterprise',N'DN đã nhập');
INSERT @Labels VALUES(N'Dashboard_Progress_MetricPresence',N'Độ phủ');
INSERT @Labels VALUES(N'Dashboard_Progress_MetricNote',N'Giá trị 0 vẫn được tính là có dữ liệu.');
INSERT @Labels VALUES(N'Dashboard_Progress_ReceivedAssignedShort',N'Đã nhập / tổng DN');
INSERT @Labels VALUES(N'Dashboard_Progress_NoAssigned',N'Không có DN.');
INSERT @Labels VALUES(N'Dashboard_Progress_ByArea',N'Theo địa bàn');
INSERT @Labels VALUES(N'Dashboard_Progress_Worklist',N'Doanh nghiệp');
INSERT @Labels VALUES(N'Dashboard_Progress_TypeData',N'Trạng thái');
INSERT @Labels VALUES(N'Dashboard_Progress_MissingCodes',N'Thiếu chỉ tiêu');
INSERT @Labels VALUES(N'Dashboard_Progress_DuplicateData',N'Dữ liệu trùng');
INSERT @Labels VALUES(N'Dashboard_Progress_HasData',N'Đã nhập');
INSERT @Labels VALUES(N'Dashboard_Progress_NoData',N'Chưa nhập');
INSERT @Labels VALUES(N'Dashboard_Progress_ThreeValues',N'Đủ');
INSERT @Labels VALUES(N'Dashboard_Progress_Review',N'Cần đối chiếu');
INSERT @Labels VALUES(N'Dashboard_Progress_First50',N'Hiển thị 50 doanh nghiệp đầu.');
INSERT @Labels VALUES(N'Dashboard_Progress_Note',N'Tỷ lệ phản ánh dữ liệu đã nhập, không phải tỷ lệ nộp báo cáo.');
INSERT @Labels VALUES(N'User_IndustryPermissions_Title',N'Phân quyền ngành báo cáo');
INSERT @Labels VALUES(N'User_IndustryPermissions_Industries',N'Ngành được phép xem');
INSERT @Labels VALUES(N'User_IndustryPermissions_ScopeHelp',N'Áp dụng cho dashboard, báo cáo và chatbot; vẫn giữ quyền chức năng và phân công doanh nghiệp.');
INSERT @Labels VALUES(N'User_IndustryPermissions_SelectionHelp',N'Giữ Ctrl hoặc Command để chọn nhiều ngành. Doanh nghiệp nhiều ngành chỉ tính một lần.');
INSERT @Labels VALUES(N'User_IndustryPermissions_RestoreWarning',N'Bỏ hết ngành sẽ khôi phục phạm vi trước đây, không chặn truy cập.');
INSERT @Labels VALUES(N'User_IndustryPermissions_RestoreConfirmation',N'Khôi phục phạm vi trước đây khi không chọn ngành.');
INSERT @Labels VALUES(N'User_IndustryPermissions_RestrictedHelp',N'Tài khoản giới hạn ngành không xem hoặc xuất thông tin bổ sung toàn tỉnh.');
INSERT @Labels VALUES(N'User_IndustryPermissions_InvalidSelection',N'Danh sách ngành không hợp lệ.');
INSERT @Labels VALUES(N'User_IndustryPermissions_InactiveSelection',N'Ngành không tồn tại hoặc đã ngừng hoạt động. Vui lòng bỏ chọn.');
INSERT @Labels VALUES(N'User_IndustryPermissions_RestoreRequired',N'Xác nhận khôi phục phạm vi trước đây khi bỏ hết ngành.');
INSERT @Labels VALUES(N'User_IndustryPermissions_DataChanged',N'Tài khoản hoặc ngành đã thay đổi. Đóng và mở lại biểu mẫu trước khi lưu.');
INSERT @Labels VALUES(N'User_IndustryPermissions_Saved',N'Đã lưu quyền ngành báo cáo.');
INSERT @Labels VALUES(N'User_IndustryPermissions_InactiveIndustry',N'(ngừng hoạt động; sẽ bỏ khi lưu)');
INSERT @Issues SELECT 'Dashboard label',N'baocaosct.khanhhoa.gov.vn.cate',e.LabelKey,'Missing or duplicate label'
FROM @Labels e WHERE (SELECT COUNT(*) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Messages m WHERE m.LangCode=N'vi-VN' AND m.LabelKey=e.LabelKey)<>1;
IF OBJECT_ID(N'[baocaosct.khanhhoa.gov.vn.cate].dbo.Report_UserBusinessIndustryPermissions','U') IS NULL
 INSERT @Issues VALUES('Grant table',N'baocaosct.khanhhoa.gov.vn.cate',N'Report_UserBusinessIndustryPermissions','Missing');
ELSE BEGIN
 INSERT @Issues SELECT 'Grant column',N'baocaosct.khanhhoa.gov.vn.cate',N'Report_UserBusinessIndustryPermissions','Missing or incompatible '+expected.Name
 FROM(VALUES('UserId',56,4),('IndustryId',56,4),('SavedBy',167,255),('SavedOn',61,8)) expected(Name,TypeId,MaxLength)
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=OBJECT_ID(N'[baocaosct.khanhhoa.gov.vn.cate].dbo.Report_UserBusinessIndustryPermissions') AND c.name=expected.Name
 WHERE c.name IS NULL OR c.system_type_id<>expected.TypeId OR c.max_length<>expected.MaxLength OR c.is_nullable<>0;
 IF NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.indexes i
 WHERE i.object_id=OBJECT_ID(N'[baocaosct.khanhhoa.gov.vn.cate].dbo.Report_UserBusinessIndustryPermissions') AND i.is_primary_key=1 AND i.is_disabled=0
 AND (SELECT COUNT(*) FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns ic WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal>0)=2
 AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns ic JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=1 AND c.name='UserId')
 AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.index_columns ic JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.key_ordinal=2 AND c.name='IndustryId'))
 INSERT @Issues VALUES('Grant primary key',N'baocaosct.khanhhoa.gov.vn.cate',N'Report_UserBusinessIndustryPermissions','Expected enabled primary key (UserId,IndustryId)');
 INSERT @Issues SELECT 'Grant foreign key',N'baocaosct.khanhhoa.gov.vn.cate',N'Report_UserBusinessIndustryPermissions','Missing/disabled/untrusted relationship to '+expected.TargetTable
 FROM(VALUES('UserId','Sys_Users','UserId'),('IndustryId','Cate_BusinessIndustry','IndustryId')) expected(SourceColumn,TargetTable,TargetColumn)
 WHERE NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].sys.foreign_keys fk
 JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.foreign_key_columns fc ON fc.constraint_object_id=fk.object_id
 JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
 JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.tables rt ON rt.object_id=fc.referenced_object_id
 JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.schemas rs ON rs.schema_id=rt.schema_id
 JOIN [baocaosct.khanhhoa.gov.vn.cate].sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id
 WHERE fk.parent_object_id=OBJECT_ID(N'[baocaosct.khanhhoa.gov.vn.cate].dbo.Report_UserBusinessIndustryPermissions') AND fk.is_disabled=0 AND fk.is_not_trusted=0
 AND pc.name=expected.SourceColumn AND rs.name='dbo' AND rt.name=expected.TargetTable AND rc.name=expected.TargetColumn
 AND (SELECT COUNT(*) FROM [baocaosct.khanhhoa.gov.vn.cate].sys.foreign_key_columns otherColumn WHERE otherColumn.constraint_object_id=fk.object_id)=1);
END;
SELECT * FROM @Issues ORDER BY CheckName,DatabaseName,ObjectName;
SELECT (SELECT COUNT(*) FROM @Expected) ExpectedFunctionsAndProcedures,(SELECT COUNT(*) FROM @Indexes) ExpectedIndexes,(SELECT COUNT(*) FROM @Labels) ExpectedMessageLabels,(SELECT COUNT(*) FROM @Issues) Failures;
IF EXISTS(SELECT 1 FROM @Issues) THROW 50124,'Deployment verification failed. Inspect the preceding issue rows.',1;
SELECT 'PASS' VerificationStatus,'Metadata/text match this release. Runtime permissions and HTTP acceptance still required.' Detail;