-- Review/deploy manually to baocaosct.khanhhoa.gov.vn. Persistent source data is read only.
CREATE PROCEDURE dbo.p_Report_Dashboard_ProgressDetails @ForMonth date, @TypeReport int,
 @WardId int=NULL, @EconomicSectorId int=NULL, @IndustryId int=NULL, @EnterpriseId int=NULL,
 @Status varchar(20)='all',@Page int=1,@PageSize int=50,@Search nvarchar(250)=NULL
AS BEGIN
 SET NOCOUNT ON;
 IF @TypeReport NOT IN (1,2,3) OR @TypeReport IS NULL THROW 50001,'Unsupported report type',1;
 IF @ForMonth IS NULL THROW 50002,'Report month is required',1;
 IF @Status NOT IN ('all','missing','incomplete','complete','conflict','file-late') THROW 50003,'Unsupported status',1;
 IF @Page<1 OR @PageSize<1 OR @PageSize>100 THROW 50004,'Invalid page',1;
 DECLARE @Start date=DATEFROMPARTS(YEAR(@ForMonth),MONTH(@ForMonth),1),@End date;
 SET @End=DATEADD(month,1,@Start);
 ;WITH Cohort AS (
 SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N'Chưa phân loại' ELSE N'Mã địa bàn '+CONVERT(nvarchar(20),e.WardId) END) WardName,
 b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N', ' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),i.IndustryId)+',%'
 ORDER BY i.IndustryId FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,''),''),N'Chưa phân ngành') IndustryName
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND (@TypeReport IS NULL OR ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@TypeReport)+',%')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@IndustryId)+',%')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
), Imports AS (
 SELECT r.EnterpriseId, DATEFROMPARTS(YEAR(r.ForMonth),MONTH(r.ForMonth),1) ForMonth,
 LTRIM(RTRIM(r.[Level])) IndicatorLevel,r.PerformInPeriod,r.IsLate,r.CreatedDate,r.LastModifiedDate,
 LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(r.Unit,''),' ',''),'.',''),CHAR(13),''),CHAR(10),''),CHAR(9),'')) NormalUnit
 FROM dbo.Report_DataImports r WHERE r.IsDeleted=0 AND r.TypeReport=@TypeReport
 AND r.ForMonth>=@Start AND r.ForMonth<@End
), Presence AS (
 SELECT EnterpriseId,ForMonth,CAST(1 AS bit) DataImported,MAX(CAST(IsLate AS int)) ImportLate,
 MIN(CreatedDate) FirstImportedAt,MAX(COALESCE(LastModifiedDate,CreatedDate)) LastImportedAt
 FROM Imports GROUP BY EnterpriseId,ForMonth
), Mapped AS (
 SELECT *, CASE
 -- TypeReport + Level identifies the fixed template totals across old/new Code formats.
 -- Index moves with product rows. Exact levels exclude product/country/retail detail rows.
 -- Type 1 primary is industrial revenue (1.1), not total enterprise revenue (1).
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN '1.1' WHEN 2 THEN '1' ELSE '0' END THEN 'primary'
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN '6' WHEN 2 THEN '2' ELSE '1' END THEN 'secondary'
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN '7' WHEN 2 THEN '1.1' ELSE '2' END THEN 'tertiary' END Metric
 FROM Imports
), MetricGroups AS (
 SELECT EnterpriseId,ForMonth,Metric,COUNT(*) SourceRows,
 MAX(CASE WHEN (@TypeReport=1 AND Metric='primary' AND NormalUnit=N'tỷđồng')
 OR (@TypeReport=1 AND Metric<>'primary' AND NormalUnit='1000usd')
 OR (@TypeReport=2 AND NormalUnit=N'triệuđồng')
 OR (@TypeReport=3 AND NormalUnit='usd') THEN 0 ELSE 1 END) InvalidUnit,
 MAX(CASE WHEN PerformInPeriod IS NOT NULL AND TRY_CONVERT(decimal(28,4),PerformInPeriod) IS NULL THEN 1 ELSE 0 END) InvalidNumber,
 MAX(TRY_CONVERT(decimal(28,4),PerformInPeriod)) SingleValue
 FROM Mapped WHERE Metric IS NOT NULL GROUP BY EnterpriseId,ForMonth,Metric
), Metrics AS (
 SELECT EnterpriseId,ForMonth,
 MAX(CASE WHEN Metric='primary' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) PrimaryValue,
 MAX(CASE WHEN Metric='secondary' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) SecondaryValue,
 MAX(CASE WHEN Metric='tertiary' AND SourceRows=1 AND InvalidUnit=0 AND InvalidNumber=0 THEN SingleValue END) TertiaryValue,
 MAX(CASE WHEN Metric='primary' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) PrimaryConflict,
 MAX(CASE WHEN Metric='secondary' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) SecondaryConflict,
 MAX(CASE WHEN Metric='tertiary' AND (SourceRows>1 OR InvalidUnit=1 OR InvalidNumber=1) THEN 1 ELSE 0 END) TertiaryConflict,
 MAX(CASE WHEN SourceRows>1 THEN 1 ELSE 0 END) DuplicateMetric,
 MAX(InvalidUnit) InvalidUnit,MAX(InvalidNumber) InvalidNumber
 FROM MetricGroups GROUP BY EnterpriseId,ForMonth
), FileRows AS (
 SELECT f.*,DATEFROMPARTS(YEAR(f.ForMonth),MONTH(f.ForMonth),1) ReportMonth,
 ROW_NUMBER() OVER(PARTITION BY EnterpriseId,YEAR(ForMonth),MONTH(ForMonth)
 ORDER BY COALESCE(LastModifiedDate,CreatedDate) DESC,ForMonth DESC) RowNo,
 MAX(CAST(IsLate AS int)) OVER(PARTITION BY EnterpriseId,YEAR(ForMonth),MONTH(ForMonth)) FileLate
 FROM dbo.Report_ReportFiles f WHERE IsDeleted=0 AND ForMonth>=@Start AND ForMonth<@End
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
 FROM Cohort c LEFT JOIN Presence p ON p.EnterpriseId=c.EnterpriseId AND p.ForMonth=@Start
 LEFT JOIN Metrics v ON v.EnterpriseId=c.EnterpriseId AND v.ForMonth=@Start
 LEFT JOIN Files f ON f.EnterpriseId=c.EnterpriseId AND f.ReportMonth=@Start
 ), Filtered AS (
 SELECT * FROM States WHERE @Status='all'
 OR (@Status='missing' AND DataImported=0)
 OR (@Status='incomplete' AND DataImported=1 AND (PrimaryValue IS NULL OR SecondaryValue IS NULL OR TertiaryValue IS NULL))
 OR (@Status='complete' AND PrimaryValue IS NOT NULL AND SecondaryValue IS NOT NULL AND TertiaryValue IS NOT NULL)
 OR (@Status='conflict' AND MetricConflict=1)
 OR (@Status='file-late' AND FileLate=1)
 ), SearchFiltered AS (
 SELECT * FROM Filtered WHERE (@Search IS NULL OR CHARINDEX(@Search COLLATE Latin1_General_100_CI_AI,BusinessName COLLATE Latin1_General_100_CI_AI)>0
 OR CHARINDEX(@Search COLLATE Latin1_General_100_CI_AI,TaxCode COLLATE Latin1_General_100_CI_AI)>0
 OR CHARINDEX(@Search COLLATE Latin1_General_100_CI_AI,WardName COLLATE Latin1_General_100_CI_AI)>0)
 ), Ranked AS (
 SELECT *,ROW_NUMBER() OVER(ORDER BY MetricConflict DESC,DataImported,
 CASE WHEN PrimaryValue IS NULL OR SecondaryValue IS NULL OR TertiaryValue IS NULL THEN 0 ELSE 1 END,BusinessName,EnterpriseId) RowNo FROM SearchFiltered
 ), Total AS (SELECT COUNT(*) TotalRow,(SELECT COUNT(*) FROM Filtered) TotalUnfiltered FROM SearchFiltered)
 SELECT t.TotalRow,t.TotalUnfiltered,r.* FROM Total t OUTER APPLY
 (SELECT * FROM Ranked WHERE RowNo>CONVERT(bigint,@Page-1)*@PageSize AND RowNo<=CONVERT(bigint,@Page)*@PageSize) r
 ORDER BY r.RowNo;
END
