-- Deployment proposal only. Review and run manually; no report data is modified.
CREATE PROCEDURE dbo.p_Report_Chatbot_Metadata
 @ChatbotUserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500),
 @Kind varchar(20),@TypeReport int=NULL,@Search nvarchar(250)=NULL,@Offset int=0,@Limit int=10
AS BEGIN
 SET NOCOUNT ON;
 SELECT * INTO #ChatbotScope FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_UserScope(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds);

IF NOT EXISTS(SELECT 1 FROM #ChatbotScope WHERE CanReadDashboard=1) THROW 50110,'Chatbot dashboard access denied',1;

 IF @Kind NOT IN('catalog','policy','capabilities') OR @Offset<0 OR @Offset>100000 OR @Limit<1 OR @Limit>50
 OR (@TypeReport IS NOT NULL AND @TypeReport NOT IN(1,2,3)) THROW 50104,'Invalid metadata query',1;

IF @Kind='policy' BEGIN
 SELECT ConfigKey,ConfigValue,ConfigDesc FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Configs
 WHERE IsDeleted=0 AND ConfigKey IN('Day_Deadline_Send_Report','Day_Deadline_Send_Late_Report'); RETURN;
 END;
 CREATE TABLE #ChatbotEnterprises(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ChatbotEnterprises(EnterpriseId)
 SELECT authorized.EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,1) authorized
 OPTION (RECOMPILE);
 IF @Kind='capabilities' BEGIN
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
 SELECT TypeReport,Code,Targets,Unit,'observed' SourceKind,SourceRows,SuppliedRows,
 FirstSourcePeriod,LastSourcePeriod,CAST(NULL AS nvarchar(50)) ParentCode FROM Observed
 UNION ALL
 SELECT TypeReport,Code,Targets,Unit,'configured',0,0,NULL,NULL,ParentCode FROM dbo.ReportTargetConfig
 UNION ALL
 SELECT TypeReport,CodePattern,CAST(N'Quy tắc nhóm động' AS nvarchar(1500)),NULL,'dynamic_rule',0,0,NULL,NULL,ParentCode FROM dbo.ReportDynamicGroupRule
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
END
