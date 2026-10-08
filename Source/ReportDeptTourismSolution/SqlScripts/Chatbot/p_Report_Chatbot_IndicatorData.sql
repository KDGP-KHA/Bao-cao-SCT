-- Deployment proposal only. Review and run manually; no report data is modified.
-- Deploy in the ReportTourismDB/report database.
CREATE PROCEDURE dbo.p_Report_Chatbot_IndicatorData
 @ChatbotUserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500),
 @FromMonth date,@ToMonth date,@TypeReport int=NULL,@EnterpriseId int=NULL,@WardId int=NULL,
 @EconomicSectorId int=NULL,@IndustryId int=NULL,@Code varchar(50)=NULL,@CodePrefix varchar(50)=NULL,
 @Search nvarchar(250)=NULL,@Offset int=0,@Limit int=10
AS BEGIN
 SET NOCOUNT ON;
 SELECT * INTO #ChatbotScope FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Chatbot_UserScope(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds);

IF NOT EXISTS(SELECT 1 FROM #ChatbotScope WHERE CanReadDashboard=1) THROW 50110,'Chatbot dashboard access denied',1;

 IF @FromMonth IS NULL OR @ToMonth IS NULL OR DAY(@FromMonth)<>1 OR DAY(@ToMonth)<>1
 OR @FromMonth<CONVERT(date,'20000101') OR @ToMonth<@FromMonth OR DATEDIFF(month,@FromMonth,@ToMonth)>11
 OR @ToMonth>DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1)
 OR @Offset<0 OR @Offset>100000 OR @Limit<1 OR @Limit>50
 OR (@TypeReport IS NOT NULL AND @TypeReport NOT IN(1,2,3)) THROW 50102,'Invalid indicator query',1;

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
 AND (@IndustryId IS NULL OR ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@IndustryId)+',%')))
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
END
