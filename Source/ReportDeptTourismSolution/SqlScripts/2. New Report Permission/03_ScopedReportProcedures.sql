USE [baocaosct.khanhhoa.gov.vn];
GO
IF OBJECT_ID('dbo.p_Report_Dashboard_FilterOptions_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Dashboard_FilterOptions_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Dashboard_FilterOptions_IndustryScope @OptionKind varchar(20),@TypeReport int=NULL,
 @Search nvarchar(250)=NULL,@Page int=1,@PageSize int=50,
 @IndustryUserName varchar(255)

AS BEGIN SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,'Report scope unavailable',1;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 IF @ReportScopeRestricted=1
  INSERT #ReportScope(EnterpriseId)
  SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);

IF @OptionKind NOT IN ('year','latest','ward','sector','industry','enterprise') THROW 50006,'Unsupported option kind',1;
 IF @TypeReport IS NOT NULL AND @TypeReport NOT IN (1,2,3) THROW 50001,'Unsupported report type',1;
 IF @Page<1 OR @PageSize<1 OR @PageSize>100 THROW 50004,'Invalid page',1;
 DECLARE @WardId int=NULL,@EconomicSectorId int=NULL,@IndustryId int=NULL,@EnterpriseId int=NULL;
 -- Industry options start with the small business registry, not every enterprise.
 IF @OptionKind='industry' BEGIN
 ;WITH Options AS (
 SELECT DISTINCT CONVERT(varchar(20),i.IndustryId) Value,CONVERT(nvarchar(250),i.IndustryName) Text
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e ON e.EnterpriseId=b.EnterpriseId
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
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
 COALESCE(NULLIF(STUFF((SELECT N', ' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),i.IndustryId)+',%'
 ORDER BY i.IndustryId FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,''),''),N'Chưa phân ngành') IndustryName
 FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
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
IF OBJECT_ID('dbo.p_Report_Dashboard_IndustrialSnapshot_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Dashboard_IndustrialSnapshot_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Dashboard_IndustrialSnapshot_IndustryScope @ForMonth date, @TypeReport int,
 @WardId int=NULL, @EconomicSectorId int=NULL, @IndustryId int=NULL, @EnterpriseId int=NULL,
 @IndustryUserName varchar(255)

AS BEGIN
 SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,'Report scope unavailable',1;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 IF @ReportScopeRestricted=1
  INSERT #ReportScope(EnterpriseId)
  SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);

 IF @TypeReport NOT IN (1,2,3) OR @TypeReport IS NULL THROW 50001,'Unsupported report type',1;
 IF @ForMonth IS NULL THROW 50002,'Report month is required',1;
 DECLARE @Start date=DATEFROMPARTS(YEAR(@ForMonth)-1,1,1);
 DECLARE @End date=DATEADD(month,1,DATEFROMPARTS(YEAR(@ForMonth),MONTH(@ForMonth),1));
 SELECT * INTO #DashboardCohort FROM (
SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N'Chưa phân loại' ELSE N'Mã địa bàn '+CONVERT(nvarchar(20),e.WardId) END) WardName,
 b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N', ' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),i.IndustryId)+',%'
 ORDER BY i.IndustryId FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,''),''),N'Chưa phân ngành') IndustryName
 FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND (@TypeReport IS NULL OR ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@TypeReport)+',%')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@IndustryId)+',%')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
) materialized OPTION (RECOMPILE);
CREATE CLUSTERED INDEX IX_DashboardCohort ON #DashboardCohort(EnterpriseId);
SELECT * INTO #DashboardImports FROM (
SELECT r.EnterpriseId, DATEFROMPARTS(YEAR(r.ForMonth),MONTH(r.ForMonth),1) ForMonth,
 LTRIM(RTRIM(r.[Level])) IndicatorLevel,r.PerformInPeriod,r.IsLate,r.CreatedDate,r.LastModifiedDate,
 LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(r.Unit,''),' ',''),'.',''),CHAR(13),''),CHAR(10),''),CHAR(9),'')) NormalUnit
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
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN '1.1' WHEN 2 THEN '1' ELSE '0' END THEN 'primary'
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN '6' WHEN 2 THEN '2' ELSE '1' END THEN 'secondary'
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN '7' WHEN 2 THEN '1.1' ELSE '2' END THEN 'tertiary' END Metric
 FROM #DashboardImports
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
END
GO
IF OBJECT_ID('dbo.p_Report_Dashboard_OverviewSummary_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Dashboard_OverviewSummary_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Dashboard_OverviewSummary_IndustryScope @ForMonth date,
 @WardId int=NULL,@EconomicSectorId int=NULL,@IndustryId int=NULL,@EnterpriseId int=NULL,@GroupBy varchar(10)=NULL,
 @IndustryUserName varchar(255)

AS BEGIN SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,'Report scope unavailable',1;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 IF @ReportScopeRestricted=1
  INSERT #ReportScope(EnterpriseId)
  SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);

IF @ForMonth IS NULL THROW 50002,'Report month is required',1;
 IF @GroupBy IS NOT NULL AND @GroupBy NOT IN ('ward','sector') THROW 50005,'Unsupported group',1;
 DECLARE @TypeReport int=NULL,@MonthStart date=DATEFROMPARTS(YEAR(@ForMonth),MONTH(@ForMonth),1);
 DECLARE @NextMonth date=DATEADD(month,1,@MonthStart);
 IF @GroupBy IS NOT NULL BEGIN
 ;WITH Cohort AS (
 SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N'Chưa phân loại' ELSE N'Mã địa bàn '+CONVERT(nvarchar(20),e.WardId) END) WardName,
 e.TypeBusiness,b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N', ' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),i.IndustryId)+',%'
 ORDER BY i.IndustryId FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,''),''),N'Chưa phân ngành') IndustryName
 FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND (@TypeReport IS NULL OR ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@TypeReport)+',%')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@IndustryId)+',%')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
)
 SELECT CASE WHEN @GroupBy='ward' THEN WardId ELSE EconomicSectorId END DimensionId,
 COALESCE(CASE WHEN @GroupBy='ward' THEN WardName ELSE EconomicSectorName END,N'Chưa phân loại') DimensionName,
 SUM(CASE WHEN ','+REPLACE(ISNULL(TypeBusiness,''),' ','')+',' LIKE '%,1,%' THEN 1 ELSE 0 END) Type1Expected,
 SUM(CASE WHEN ','+REPLACE(ISNULL(TypeBusiness,''),' ','')+',' LIKE '%,2,%' THEN 1 ELSE 0 END) Type2Expected,
 SUM(CASE WHEN ','+REPLACE(ISNULL(TypeBusiness,''),' ','')+',' LIKE '%,3,%' THEN 1 ELSE 0 END) Type3Expected
 FROM Cohort GROUP BY CASE WHEN @GroupBy='ward' THEN WardId ELSE EconomicSectorId END,
 COALESCE(CASE WHEN @GroupBy='ward' THEN WardName ELSE EconomicSectorName END,N'Chưa phân loại') OPTION (RECOMPILE);
 RETURN; END;
 ;WITH Cohort AS (
 SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N'Chưa phân loại' ELSE N'Mã địa bàn '+CONVERT(nvarchar(20),e.WardId) END) WardName,
 e.TypeBusiness,b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N', ' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),i.IndustryId)+',%'
 ORDER BY i.IndustryId FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,''),''),N'Chưa phân ngành') IndustryName
 FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND (@TypeReport IS NULL OR ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@TypeReport)+',%')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@IndustryId)+',%')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
), Expected AS (
 SELECT COALESCE(SUM(CASE WHEN ','+REPLACE(ISNULL(TypeBusiness,''),' ','')+',' LIKE '%,1,%' THEN 1 ELSE 0 END),0) Type1Expected,
 COALESCE(SUM(CASE WHEN ','+REPLACE(ISNULL(TypeBusiness,''),' ','')+',' LIKE '%,2,%' THEN 1 ELSE 0 END),0) Type2Expected,
 COALESCE(SUM(CASE WHEN ','+REPLACE(ISNULL(TypeBusiness,''),' ','')+',' LIKE '%,3,%' THEN 1 ELSE 0 END),0) Type3Expected FROM Cohort
 ), Registry AS (
 SELECT COUNT(*) ActiveEnterprises,
 COALESCE(SUM(CASE WHEN b.HasIndustry=1 AND (','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' LIKE '%,1,%' OR ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' LIKE '%,2,%' OR ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' LIKE '%,3,%') THEN 1 ELSE 0 END),0) ConfiguredEnterprises,
 COALESCE(SUM(CASE WHEN b.BusinessRows=0 THEN 1 ELSE 0 END),0) MissingBusinessRow,
 COALESCE(SUM(CASE WHEN ISNULL(b.HasIndustry,0)=0 THEN 1 ELSE 0 END),0) MissingIndustry,
 COALESCE(SUM(CASE WHEN ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' NOT LIKE '%,1,%' AND ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' NOT LIKE '%,2,%' AND ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' NOT LIKE '%,3,%' THEN 1 ELSE 0 END),0) MissingReportType
 FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e OUTER APPLY (
 SELECT COUNT(*) BusinessRows,MAX(CASE WHEN NULLIF(LTRIM(RTRIM(IndustryIds)),'') IS NOT NULL THEN 1 ELSE 0 END) HasIndustry
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise WHERE EnterpriseId=e.EnterpriseId) b WHERE e.IsActive=1 AND e.IsDeleted=0
 ) SELECT Registry.*,Expected.*,
 (SELECT COUNT(*) FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) scope_source WHERE IsDeleted=0 AND (TypeReport IS NULL OR TypeReport NOT IN (1,2,3)) AND ForMonth>=@MonthStart AND ForMonth<@NextMonth) TypeZeroRows,
 (SELECT COUNT(*) FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) scope_source WHERE IsDeleted=0 AND ForMonth>=DATEADD(month,1,DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1))) FutureDatedRows,
 (SELECT COUNT(DISTINCT r.EnterpriseId) FROM (SELECT scope_r.* FROM dbo.Report_DataImports scope_r WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_r.EnterpriseId)) r LEFT JOIN (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e ON e.EnterpriseId=r.EnterpriseId
 WHERE r.IsDeleted=0 AND r.ForMonth>=@MonthStart AND r.ForMonth<@NextMonth
 AND (e.EnterpriseId IS NULL OR e.IsActive<>1 OR e.IsDeleted<>0 OR r.TypeReport IS NULL OR r.TypeReport NOT IN (1,2,3)
 OR ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' NOT LIKE '%,'+CONVERT(varchar(11),r.TypeReport)+',%')) OutsideCohortEnterprises
 FROM Registry CROSS JOIN Expected OPTION (RECOMPILE);
END
GO
IF OBJECT_ID('dbo.p_Report_Dashboard_ProgressDetails_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Dashboard_ProgressDetails_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Dashboard_ProgressDetails_IndustryScope @ForMonth date, @TypeReport int,
 @WardId int=NULL, @EconomicSectorId int=NULL, @IndustryId int=NULL, @EnterpriseId int=NULL,
 @Status varchar(20)='all',@Page int=1,@PageSize int=50,@Search nvarchar(250)=NULL,
 @IndustryUserName varchar(255)

AS BEGIN
 SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,'Report scope unavailable',1;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 IF @ReportScopeRestricted=1
  INSERT #ReportScope(EnterpriseId)
  SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);

 IF @TypeReport NOT IN (1,2,3) OR @TypeReport IS NULL THROW 50001,'Unsupported report type',1;
 IF @ForMonth IS NULL THROW 50002,'Report month is required',1;
 IF @Status NOT IN ('all','missing','incomplete','complete','conflict','file-late') THROW 50003,'Unsupported status',1;
 IF @Page<1 OR @PageSize<1 OR @PageSize>100 THROW 50004,'Invalid page',1;
 DECLARE @Start date=DATEFROMPARTS(YEAR(@ForMonth),MONTH(@ForMonth),1),@End date;
 SET @End=DATEADD(month,1,@Start);
 SELECT * INTO #DashboardCohort FROM (
SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N'Chưa phân loại' ELSE N'Mã địa bàn '+CONVERT(nvarchar(20),e.WardId) END) WardName,
 b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
 COALESCE(NULLIF(STUFF((SELECT N', ' + i.IndustryName FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),i.IndustryId)+',%'
 ORDER BY i.IndustryId FOR XML PATH(''),TYPE).value('.','nvarchar(max)'),1,2,''),''),N'Chưa phân ngành') IndustryName
 FROM (SELECT scope_e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises scope_e WHERE @ReportScopeRestricted=0 OR EXISTS(SELECT 1 FROM #ReportScope scope_p WHERE scope_p.EnterpriseId=scope_e.EnterpriseId)) e
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise b ON b.EnterpriseId=e.EnterpriseId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards w ON w.WardId=e.WardId
 LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector s ON s.EconomicSectorId=b.EconomicSectorId
 WHERE e.IsActive=1 AND e.IsDeleted=0
 AND (@TypeReport IS NULL OR ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@TypeReport)+',%')
 AND (@WardId IS NULL OR e.WardId=@WardId)
 AND (@EconomicSectorId IS NULL OR b.EconomicSectorId=@EconomicSectorId)
 AND (@IndustryId IS NULL OR ','+REPLACE(ISNULL(b.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),@IndustryId)+',%')
 AND (@EnterpriseId IS NULL OR e.EnterpriseId=@EnterpriseId)
) materialized OPTION (RECOMPILE);
CREATE CLUSTERED INDEX IX_DashboardCohort ON #DashboardCohort(EnterpriseId);
SELECT * INTO #DashboardImports FROM (
SELECT r.EnterpriseId, DATEFROMPARTS(YEAR(r.ForMonth),MONTH(r.ForMonth),1) ForMonth,
 LTRIM(RTRIM(r.[Level])) IndicatorLevel,r.PerformInPeriod,r.IsLate,r.CreatedDate,r.LastModifiedDate,
 LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(r.Unit,''),' ',''),'.',''),CHAR(13),''),CHAR(10),''),CHAR(9),'')) NormalUnit
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
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN '1.1' WHEN 2 THEN '1' ELSE '0' END THEN 'primary'
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN '6' WHEN 2 THEN '2' ELSE '1' END THEN 'secondary'
 WHEN IndicatorLevel=CASE @TypeReport WHEN 1 THEN '7' WHEN 2 THEN '1.1' ELSE '2' END THEN 'tertiary' END Metric
 FROM #DashboardImports
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
SELECT * FROM States WHERE @Status='all'
 OR (@Status='missing' AND DataImported=0)
 OR (@Status='incomplete' AND DataImported=1 AND (PrimaryValue IS NULL OR SecondaryValue IS NULL OR TertiaryValue IS NULL))
 OR (@Status='complete' AND PrimaryValue IS NOT NULL AND SecondaryValue IS NOT NULL AND TertiaryValue IS NOT NULL)
 OR (@Status='conflict' AND MetricConflict=1)
 OR (@Status='file-late' AND FileLate=1)
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
END
GO
IF OBJECT_ID('dbo.p_Report_Dashboard_StatisticEnterprise_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Dashboard_StatisticEnterprise_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Dashboard_StatisticEnterprise_IndustryScope 

	@OnMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	
	
	SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,'Report scope unavailable',1;
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
END
GO
IF OBJECT_ID('dbo.p_Report_Dashboard_StatisticIncome_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Dashboard_StatisticIncome_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Dashboard_StatisticIncome_IndustryScope 

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
	                            AND rdi.Code IN ('31', '32', '33', '11', '12', '13')
	                        ) 
	                        OR (
	                               @TypeStatistic = 2
	                               AND rdi.Code IN ('A21', 'A22', 'A23', '18', '19', '20')
	                           ) 
	                             
	                        OR (
	                               @TypeStatistic = 3
	                               AND (
	                                       (
	                                           rdi.Code IN ('31', '32', '33', '11', '12', '13')
	                                           AND rdi.TypeReport = 1
	                                       )
	                                       OR (
	                                              rdi.Code IN ('A21', 'A22', 'A23', '18', '19', '20')
	                                              AND rdi.TypeReport = 2
	                                          )
	                                       OR (rdi.Code IN ('03', '04', '05') AND rdi.TypeReport = 3)
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
	                            AND rdi.Code IN ('31', '32', '33', '11', '12', '13')
	                        ) 
	                        OR (
	                               @TypeStatistic = 2
	                               AND rdi.Code IN ('A21', 'A22', 'A23', '18', '19', '20')
	                           ) 
	                             
	                        OR (
	                               @TypeStatistic = 3
	                               AND (
	                                       (
	                                           rdi.Code IN ('31', '32', '33', '11', '12', '13')
	                                           AND rdi.TypeReport = 1
	                                       )
	                                       OR (
	                                              rdi.Code IN ('A21', 'A22', 'A23', '18', '19', '20')
	                                              AND rdi.TypeReport = 2
	                                          )
	                                       OR (rdi.Code IN ('03', '04', '05') AND rdi.TypeReport = 3)
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
END
GO
IF OBJECT_ID('dbo.p_Report_Dashboard_StatisticMapVisitor_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Dashboard_StatisticMapVisitor_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Dashboard_StatisticMapVisitor_IndustryScope 

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
	       
END
GO
IF OBJECT_ID('dbo.p_Report_Dashboard_StatisticTypeBusiness_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Dashboard_StatisticTypeBusiness_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Dashboard_StatisticTypeBusiness_IndustryScope
	@OnMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	
	
	SET NOCOUNT ON;
 -- Resolve permissions once per invocation; NULL scope fails closed.
 DECLARE @ReportScopeRestricted bit;
 SELECT @ReportScopeRestricted=CONVERT(bit,1) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@IndustryUserName);
 IF @ReportScopeRestricted IS NULL THROW 50112,'Report scope unavailable',1;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 IF @ReportScopeRestricted=1
  INSERT #ReportScope(EnterpriseId)
  SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);


	
	
	WITH TypeBusiness AS (
	    SELECT 1                    AS TypeBusiness,
	           N'Lĩnh vực Lưu trú'  AS TypeBusinessName,
	           'primary'            AS MainColor
	    UNION
	    SELECT 2                    AS TypeBusiness,
	           N'Lĩnh vực Lữ hành'  AS TypeBusinessName,
	           'success'            AS MainColor
	    UNION
	    SELECT 3       AS TypeBusiness,
	           N'Lĩnh vực Vận chuyển hành khách' AS TypeBusinessName,
	           'info'  AS MainColor
	    UNION
	    SELECT 4          AS TypeBusiness,
	           N'Lĩnh vực Địa điểm/Khu du lịch' AS TypeBusinessName,
	           'warning'  AS MainColor
	    UNION
	    SELECT 5         AS TypeBusiness,
	           N'Lĩnh vực Phục vụ khách du lịch' AS TypeBusinessName,
	           'danger'  AS MainColor
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
	            ON  ','+REPLACE(ISNULL(ce.TypeBusiness,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),tb.TypeBusiness)+',%'
	            AND ce.IsDeleted = 0
	            AND ce.IsActive = 1
	GROUP BY
	       tb.TypeBusiness,
	       tb.TypeBusinessName,
	       tb.MainColor OPTION (RECOMPILE)
END
GO
IF OBJECT_ID('dbo.p_Report_Dashboard_StatisticVisitor_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Dashboard_StatisticVisitor_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Dashboard_StatisticVisitor_IndustryScope 

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
	            AND rdi.Code IN ('1G1', '05')
	GROUP BY
	       m.MonthNum
END
GO
IF OBJECT_ID('dbo.p_Report_DataImports_GenerateSaleOfTourism_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_DataImports_GenerateSaleOfTourism_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_DataImports_GenerateSaleOfTourism_IndustryScope

	@ForMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @temp TABLE([Targets] NVARCHAR(1500),Unit NVARCHAR(1500),PerformPreviousPeriod FLOAT, PerformInPeriod FLOAT, SamePeriodRateOfPerform FLOAT, AccumulatedBeginingOfYear FLOAT, SamePeriodRateOfAccumulated FLOAT, [Level] VARCHAR(10));
	INSERT INTO @temp([Targets],Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear,SamePeriodRateOfAccumulated,[Level])
	VALUES(N'1. Về cơ sở lưu trú du lịch','-', NULL,NULL,NULL,NULL,NULL,'1')
	
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_Sum_IndustryScope @Title=N'1.1 Tổng số lượt khách phục vụ', @ForMonth=@ForMonth, @Code1=N'1G1', @Code2=N'1G2', @Code3='', @Level='1.1', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N'- Khách quốc tế', @ForMonth=@ForMonth, @Code=N'1G1', @Level='1.1.1', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N'- Khách nội địa', @ForMonth=@ForMonth, @Code=N'1G2', @Level='1.1.2', @IndustryUserName=@IndustryUserName;
	
	
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_Sum_IndustryScope @Title=N'1.2 Tổng số ngày khách lưu trú', @ForMonth=@ForMonth, @Code1=N'1D1', @Code2=N'1D2', @Code3='', @Level='1.2', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N'- Ngày khách quốc tế', @ForMonth=@ForMonth, @Code=N'1D1', @Level='1.2.1', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N'- Ngày khách nội địa', @ForMonth=@ForMonth, @Code=N'1D2', @Level='1.2.2', @IndustryUserName=@IndustryUserName;

	
	
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForAVG_IndustryScope @Title=N'1.4 Công suất sử dụng phòng bình quân', @ForMonth=@ForMonth, @Unit=N'%', @Level='1.4', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope @Title=N'- Hạng cơ sở lưu trú 5 sao', @ForMonth=@ForMonth, @Unit=N'%', @Class=5, @Level='1.4.1', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope @Title=N'- Hạng cơ sở lưu trú 4 sao', @ForMonth=@ForMonth, @Unit=N'%', @Class=4, @Level='1.4.2', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope @Title=N'- Hạng cơ sở lưu trú 3 sao', @ForMonth=@ForMonth, @Unit=N'%', @Class=3, @Level='1.4.3', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope @Title=N'- Hạng cơ sở lưu trú 2 sao', @ForMonth=@ForMonth, @Unit=N'%', @Class=2, @Level='1.4.4', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope @Title=N'- Hạng cơ sở lưu trú 1 sao', @ForMonth=@ForMonth, @Unit=N'%', @Class=1, @Level='1.4.5', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumPercentForOther_IndustryScope @Title=N'- Khác', @ForMonth=@ForMonth, @Unit=N'%', @Level='1.4.6', @IndustryUserName=@IndustryUserName;
		
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumAmount_IndustryScope @Title=N'1.5 Tổng doanh thu các cơ sở lưu trú', @ForMonth=@ForMonth, @Unit=N'Đồng', @Code = '3%',@Level='1.5', @IndustryUserName=@IndustryUserName;
		
	INSERT INTO @temp([Targets],Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear,SamePeriodRateOfAccumulated,[Level])
	VALUES(N'2. Về doanh nghiệp lữ hành, vận chuyển khách du lịch','-', NULL,NULL,NULL,NULL,NULL,'2')
	
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_Sum_IndustryScope @Title=N'2.1 Tổng số lượt khách phục vụ', @ForMonth=@ForMonth, @Code1=N'A11', @Code2='A12', @Code3='A13',@Level='2.1', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N'- Khách quốc tế đến', @ForMonth=@ForMonth, @Code=N'A11', @Level='2.1.1', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N'- Khách nội địa',@ForMonth=@ForMonth, @Code=N'A12', @Level='2.1.2', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N'- Khách Việt Nam đi nước ngoài', @ForMonth=@ForMonth, @Code=N'A13', @Level='2.1.3', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_Sum_IndustryScope @Title=N'2.2 Tổng doanh thu từ doanh nghiệp lữ hành, vận chuyển khách du lịch', @ForMonth=@ForMonth, @Code1=N'A21', @Code2='A22', @Code3='A23', @Level='2.2', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N'- Khách quốc tế đến', @ForMonth=@ForMonth, @Code=N'A21', @Level='2.2.1', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N'- Khách nội địa', @ForMonth=@ForMonth, @Code=N'A22', @Level='2.2.2', @IndustryUserName=@IndustryUserName;
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope @Title=N'- Khách Việt Nam đi nước ngoài', @ForMonth=@ForMonth, @Code=N'A23', @Level='2.2.3', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope @Title=N'2.3 Khách du lịch đến Khánh Hòa bằng tàu biển', @ForMonth=@ForMonth, @Level=N'2.3', @IndustryUserName=@IndustryUserName;
	
	INSERT INTO @temp (	Targets,Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear, SamePeriodRateOfAccumulated,[Level])
	SELECT N'1.3 Ngày khách lưu trú bình quân',N'Ngày', ISNULL((SELECT isnull(t12.PerformPreviousPeriod,0) FROM @temp t12 WHERE t12.[Level]='1.2')/(SELECT nullif(t11.PerformPreviousPeriod,0) FROM @temp t11 WHERE t11.[Level]='1.1'),0),
														ISNULL((SELECT isnull(t12.PerformInPeriod,0) FROM @temp t12 WHERE t12.[Level]='1.2')/(SELECT nullif(t11.PerformInPeriod,0) FROM @temp t11 WHERE t11.[Level]='1.1'),0),
														ISNULL((SELECT isnull(t12.SamePeriodRateOfPerform,0) FROM @temp t12 WHERE t12.[Level]='1.2')/(SELECT nullif(t11.SamePeriodRateOfPerform,0) FROM @temp t11 WHERE t11.[Level]='1.1'),0),
														ISNULL((SELECT isnull(t12.AccumulatedBeginingOfYear,0) FROM @temp t12 WHERE t12.[Level]='1.2')/(SELECT nullif(t11.AccumulatedBeginingOfYear,0) FROM @temp t11 WHERE t11.[Level]='1.1'),0),
														ISNULL((SELECT isnull(t12.SamePeriodRateOfAccumulated,0) FROM @temp t12 WHERE t12.[Level]='1.2')/(SELECT nullif(t11.SamePeriodRateOfAccumulated,0) FROM @temp t11 WHERE t11.[Level]='1.1'),0),
														'1.3'
														
	INSERT INTO @temp (	Targets,Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear, SamePeriodRateOfAccumulated,[Level])
	SELECT N'- Khách quốc tế',N'Ngày', ISNULL((SELECT isnull(t12.PerformPreviousPeriod,0) FROM @temp t12 WHERE t12.[Level]='1.2.1')/(SELECT nullif(t11.PerformPreviousPeriod,0) FROM @temp t11 WHERE t11.[Level]='1.1.1'),0),
														ISNULL((SELECT isnull(t12.PerformInPeriod,0) FROM @temp t12 WHERE t12.[Level]='1.2.1')/(SELECT nullif(t11.PerformInPeriod,0) FROM @temp t11 WHERE t11.[Level]='1.1.1'),0),
														ISNULL((SELECT isnull(t12.SamePeriodRateOfPerform,0) FROM @temp t12 WHERE t12.[Level]='1.2.1')/(SELECT nullif(t11.SamePeriodRateOfPerform,0) FROM @temp t11 WHERE t11.[Level]='1.1.1'),0),
														ISNULL((SELECT isnull(t12.AccumulatedBeginingOfYear,0) FROM @temp t12 WHERE t12.[Level]='1.2.1')/(SELECT nullif(t11.AccumulatedBeginingOfYear,0) FROM @temp t11 WHERE t11.[Level]='1.1.1'),0),
														ISNULL((SELECT isnull(t12.SamePeriodRateOfAccumulated,0) FROM @temp t12 WHERE t12.[Level]='1.2.1')/(SELECT nullif(t11.SamePeriodRateOfAccumulated,0) FROM @temp t11 WHERE t11.[Level]='1.1.1'),0),
														'1.3.1'
	INSERT INTO @temp (	Targets,Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear, SamePeriodRateOfAccumulated,[Level])
	SELECT N'- Khách nội địa',N'Ngày', ISNULL((SELECT isnull(t12.PerformPreviousPeriod,0) FROM @temp t12 WHERE t12.[Level]='1.2.2')/(SELECT nullif(t11.PerformPreviousPeriod,0) FROM @temp t11 WHERE t11.[Level]='1.1.2'),0),
														ISNULL((SELECT isnull(t12.PerformInPeriod,0) FROM @temp t12 WHERE t12.[Level]='1.2.2')/(SELECT nullif(t11.PerformInPeriod,0) FROM @temp t11 WHERE t11.[Level]='1.1.2'),0),
														ISNULL((SELECT isnull(t12.SamePeriodRateOfPerform,0) FROM @temp t12 WHERE t12.[Level]='1.2.2')/(SELECT nullif(t11.SamePeriodRateOfPerform,0) FROM @temp t11 WHERE t11.[Level]='1.1.2'),0),
														ISNULL((SELECT isnull(t12.AccumulatedBeginingOfYear,0) FROM @temp t12 WHERE t12.[Level]='1.2.2')/(SELECT nullif(t11.AccumulatedBeginingOfYear,0) FROM @temp t11 WHERE t11.[Level]='1.1.2'),0),
														ISNULL((SELECT isnull(t12.SamePeriodRateOfAccumulated,0) FROM @temp t12 WHERE t12.[Level]='1.2.2')/(SELECT nullif(t11.SamePeriodRateOfAccumulated,0) FROM @temp t11 WHERE t11.[Level]='1.1.2'),0),
														'1.3.2'	
	
	INSERT @temp Exec dbo.p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope @Title=N'3. Lượt khách tham quan du lịch', @ForMonth=@ForMonth, @Code1=N'A11',@Code2=N'A12',@Code3='', @Level='3', @IndustryUserName=@IndustryUserName;
						
	
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope @Title=N'4. Tổng thu từ khách du lịch trên địa bàn tỉnh Khánh Hòa',@ForMonth=@ForMonth, @Unit=N'Đồng', @Code1=N'1D1', @Code2=N'1D2', @Level='4', @IndustryUserName=@IndustryUserName;
	SELECT t.[Targets], t.Unit, t.PerformPreviousPeriod,t.PerformInPeriod, ROUND(t.SamePeriodRateOfPerform,2) AS SamePeriodRateOfPerform ,t.AccumulatedBeginingOfYear, ROUND(t.SamePeriodRateOfAccumulated,2) AS SamePeriodRateOfAccumulated
	FROM @temp t
	ORDER BY t.[Level]
END
GO
IF OBJECT_ID('dbo.p_Report_DataImports_Get_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_DataImports_Get_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_DataImports_Get_IndustryScope
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

 IF @ForEmp<>@IndustryUserName OR @ForEmp IS NULL THROW 50112,'Report subject mismatch',1;


	SET @Order = ISNULL(@Order, '0')
	SET @OrderDir = ISNULL(@OrderDir, 'ASC')
	SET @PageIndex = ISNULL(@PageIndex, 0)
	SET @PageSize = ISNULL(@PageSize, 10)

	DECLARE @DayDeadlineSendReportLate INT;
	SELECT @DayDeadlineSendReportLate = CAST(ISNULL(sc.ConfigValue, 0) AS INT)
	FROM   [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Configs AS sc
	WHERE  sc.ConfigKey = 'Day_Deadline_Send_Late_Report'
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
	                   @EnterpriseIds IS NULL OR @EnterpriseIds = ''
	                   OR EXISTS (
	                          SELECT 1
	                          FROM   dbo.fnSplit(@EnterpriseIds, ',') AS t
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
	                   @Search IS NULL OR @Search = ''
	                   OR ce.BusinessName LIKE N'%' + @Search + '%'
	                   OR rdi.TypeReportName LIKE N'%' + @Search + '%'
	               )
	           AND (
	                   @TypeBusinessIds IS NULL OR @TypeBusinessIds = ''
	                   OR EXISTS (
	                          SELECT 1
	                          FROM   dbo.fnSplit(@TypeBusinessIds, ',') AS t
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
	                    CASE WHEN @Order = '0' THEN nt.CreatedDate END ASC,
	                    CASE WHEN @Order = '1' THEN nt.EnterpriseName END ASC,
	                    CASE WHEN @Order = '2' THEN nt.ForMonth END ASC,
	                    CASE WHEN @Order = '3' THEN nt.TypeReportName END ASC,
	                    CASE WHEN @Order = '4' THEN nt.CreatedBy END ASC
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
	    WHERE  UPPER(@OrderDir) = 'ASC'
	    UNION ALL
	    SELECT ROW_NUMBER() OVER(
	               ORDER BY
	                    CASE WHEN @Order = '0' THEN nt.CreatedDate END DESC,
	                    CASE WHEN @Order = '1' THEN nt.EnterpriseName END DESC,
	                    CASE WHEN @Order = '2' THEN nt.ForMonth END DESC,
	                    CASE WHEN @Order = '3' THEN nt.TypeReportName END DESC,
	                    CASE WHEN @Order = '4' THEN nt.CreatedBy END DESC
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
	    WHERE  UPPER(@OrderDir) = 'DESC'
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
END
GO
IF OBJECT_ID('dbo.p_Report_DataImports_GetDataImport_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_DataImports_GetDataImport_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_DataImports_GetDataImport_IndustryScope

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
END
GO
IF OBJECT_ID('dbo.p_Report_DataImports_GetForUserOnMonth_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_DataImports_GetForUserOnMonth_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_DataImports_GetForUserOnMonth_IndustryScope
	@ForUser VARCHAR(500),
	@OnMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ReportScope SELECT EnterpriseId FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName);

 IF @ForUser<>@IndustryUserName OR @ForUser IS NULL THROW 50112,'Report subject mismatch',1;


	
	DECLARE @DayDeadlineSendReportLate INT;
	
	SELECT @DayDeadlineSendReportLate = CAST(ISNULL(sc.ConfigValue, 0) AS INT)
	FROM   [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Configs AS sc
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
END
GO
IF OBJECT_ID('dbo.p_Report_DataImports_GetViaEnterpriseOnMonth_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_DataImports_GetViaEnterpriseOnMonth_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_DataImports_GetViaEnterpriseOnMonth_IndustryScope

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
	WHERE  sc.ConfigKey = 'Day_Deadline_Send_Late_Report'
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
END
GO
IF OBJECT_ID('dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_GenerateSaleOfTourism_ByCode_IndustryScope

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
	       ISNULL(rdi.Unit, '')  AS Unit,
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
	       ISNULL(@Level, '')    AS LEVEL
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
END
GO
IF OBJECT_ID('dbo.p_Report_GenerateSaleOfTourism_Sum_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_GenerateSaleOfTourism_Sum_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_GenerateSaleOfTourism_Sum_IndustryScope

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
	       ISNULL(rdi.Unit, '')  AS Unit,
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
	       ISNULL(@Level, '')    AS LEVEL
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
END
GO
IF OBJECT_ID('dbo.p_Report_GenerateSaleOfTourism_SumAmount_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumAmount_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumAmount_IndustryScope 

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
	       AND rdi.Code LIKE '3%'
	
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
	       AND rdi.Code LIKE '3%'
	
	
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
	                  AND rdi.Code LIKE '3%'
	       )    AS a
END
GO
IF OBJECT_ID('dbo.p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope

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
	       ISNULL(rdi.Unit, '')  AS Unit,
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
	       ISNULL(@Level, '')    AS LEVEL
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
END
GO
IF OBJECT_ID('dbo.p_Report_GenerateSaleOfTourism_SumPercentForAVG_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumPercentForAVG_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumPercentForAVG_IndustryScope
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
	                WHERE  rdi2.Code = '22'
	                       AND rdi2.IsDeleted = 0
	                       AND (
	                               MONTH(@ForMonth) = MONTH(rdi2.ForMonth)
	                               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi2.ForMonth)
	                           )
	            ) b2
	            ON  b2.EnterpriseId = rdi.EnterpriseId
	WHERE  rdi.Code = '21'
	       AND rdi.IsDeleted = 0
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi.ForMonth)
	           )
	
	
	SELECT @Title,
	       ISNULL(@Unit, '')   AS Unit,
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
	       ISNULL(@Level, '')  AS LEVEL
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
	                WHERE  rdi2.Code = '22'
	                       AND rdi2.IsDeleted = 0
	                           
	                           
	                           
	                           
	                       AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	            ) b2
	            ON  b2.EnterpriseId = rdi.EnterpriseId
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Code = rdi.Code
	            AND rdi2.IsDeleted = 0
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+2,0))
	WHERE  rdi.Code = '21'
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	           
	           
	           
	           
END
GO
IF OBJECT_ID('dbo.p_Report_GenerateSaleOfTourism_SumPercentForOther_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumPercentForOther_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumPercentForOther_IndustryScope

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
	                       AND rdi2.Code = '22'
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
	       AND rdi.Code = '21'
	       AND rdi.IsDeleted = 0
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi.ForMonth)
	           )
	
	
	SELECT @Title,
	       ISNULL(@Unit, '')   AS Unit,
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
	       ISNULL(@Level, '')  AS LEVEL
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
	                       AND rdi2.Code = '22'
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
	       AND rdi.Code = '21'
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	           
	           
	           
	           
END
GO
IF OBJECT_ID('dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope

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
	                       AND rdi2.Code = '22'
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
	       AND rdi.Code = '21'
	       AND rdi.IsDeleted = 0
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi.ForMonth)
	           )
	
	
	SELECT @Title,
	       ISNULL(@Unit, '')   AS Unit,
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
	       ISNULL(@Level, '')  AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	       INNER JOIN (
	                SELECT rdi2.*
	                FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	                       INNER JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_AccommodationServices AS cas1
	                            ON  cas1.EnterpriseId = rdi2.EnterpriseId
	                WHERE  cas1.AccommodationClass = @Class
	                       AND rdi2.Code = '22'
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
	       AND rdi.Code = '21'
	       AND rdi.IsDeleted = 0
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	           
	           
	           
	           
END
GO
IF OBJECT_ID('dbo.p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope

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
	       ISNULL(@Unit, '')           AS Unit,
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
	       ISNULL(@Level, '')          AS [Level]
END
GO
IF OBJECT_ID('dbo.p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope

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
	       N'Lượt'             AS Unit,
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
	       ISNULL(@Level, '')  AS [Level]
	FROM dbo.f_Report_IndustryExtendInfos(@IndustryUserName)  AS rdi
	WHERE  1 = 1
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	           
	           
	           
	           
	           
END
GO
IF OBJECT_ID('dbo.p_Report_Industry_Enterprises_SearchSelect2') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Industry_Enterprises_SearchSelect2 AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Industry_Enterprises_SearchSelect2
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
  FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@IndustryUserName) ce
  WHERE ce.IsApproved=1
   AND (@TypeBusiness IS NULL OR ','+REPLACE(ISNULL(ce.TypeBusiness,''),' ','')+',' LIKE '%,'+@TypeBusiness+',%')
   AND (@Keyword IS NULL OR ce.BusinessName LIKE N'%'+@Keyword+N'%' OR ce.TaxCode LIKE N'%'+@Keyword+N'%')
 )
 SELECT EnterpriseId,BusinessName,TaxCode,TypeBusiness,TotalRow FROM Paged
 WHERE RowNum>CONVERT(bigint,@PageIndex)*@PageSize AND RowNum<=(CONVERT(bigint,@PageIndex)+1)*@PageSize
 ORDER BY RowNum;
END
GO
IF OBJECT_ID('dbo.p_Report_Reports_01_UocKetQuaHoatDongKinhDoanh_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Reports_01_UocKetQuaHoatDongKinhDoanh_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Reports_01_UocKetQuaHoatDongKinhDoanh_IndustryScope

	@ForMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
	
	DECLARE @MappingReportCode TABLE (OCode VARCHAR(500), NCode VARCHAR(500));
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('1G','4')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('1G1','5')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('1G2','6')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('1D','7')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('1D1','8')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('1D2','9')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('A1','1')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('A11','2')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('A12','3')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('A13','4')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('A21','18')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('A22','19')
	INSERT INTO @MappingReportCode(OCode,NCode)	VALUES('A23','20')
	
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
	VALUES(N'1. Về cơ sở lưu trú du lịch','-', NULL,NULL,NULL,NULL,NULL,'1')
	
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_IndustryScope @Title=N'1.1 Tổng số lượt khách phục vụ',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'1G1;1G2;5;6', @Level='1.1',@TypeReports = '1;4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N'- Khách quốc tế',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'1G1;5', @Level='1.1.1',@TypeReports = '1;4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N'- Khách nội địa',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'1G2;6', @Level='1.1.2',@TypeReports = '1;4', @IndustryUserName=@IndustryUserName;
	
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_IndustryScope @Title=N'1.2 Tổng số ngày khách lưu trú',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'1D1;1D2;8;9', @Level='1.2',@TypeReports = '1;4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N'- Ngày khách quốc tế',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'1D1;8', @Level='1.2.1',@TypeReports = '1;4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N'- Ngày khách nội địa',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'1D2;9', @Level='1.2.2',@TypeReports = '1;4', @IndustryUserName=@IndustryUserName;

	
	
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_TrungBinh_IndustryScope @Title=N'1.4 Công suất sử dụng phòng bình quân', @ForMonth=@ForMonth, @Unit=N'%', @BaseListCodes='21', @SellListCodes='22', @Level='1.4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope @Title=N'- Hạng cơ sở lưu trú 5 sao', @ForMonth=@ForMonth, @Unit=N'%', @Class='5', @BaseListCodes='21', @SellListCodes='22', @Level='1.4.1', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope @Title=N'- Hạng cơ sở lưu trú 4 sao', @ForMonth=@ForMonth, @Unit=N'%', @Class='4', @BaseListCodes='21', @SellListCodes='22', @Level='1.4.2', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope @Title=N'- Hạng cơ sở lưu trú 3 sao', @ForMonth=@ForMonth, @Unit=N'%', @Class='3', @BaseListCodes='21', @SellListCodes='22', @Level='1.4.3', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope @Title=N'- Hạng cơ sở lưu trú 2 sao', @ForMonth=@ForMonth, @Unit=N'%', @Class='2', @BaseListCodes='21', @SellListCodes='22', @Level='1.4.4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope @Title=N'- Hạng cơ sở lưu trú 1 sao', @ForMonth=@ForMonth, @Unit=N'%', @Class='1', @BaseListCodes='21', @SellListCodes='22', @Level='1.4.5', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope @Title=N'- Khác', @ForMonth=@ForMonth, @Unit=N'%', @Class=NULL, @BaseListCodes='21', @SellListCodes='22', @Level='1.4.6', @IndustryUserName=@IndustryUserName;
		
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongDoanhThu_IndustryScope @Title=N'1.5 Tổng doanh thu các cơ sở lưu trú', @ForMonth=@ForMonth, @Unit=N'Đồng', @ListCodes = '31;32;33',@Level='1.5', @IndustryUserName=@IndustryUserName;
		
	INSERT INTO @temp([Targets],Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear,SamePeriodRateOfAccumulated,[Level])
	VALUES(N'2. Về doanh nghiệp lữ hành, vận chuyển khách du lịch','-', NULL,NULL,NULL,NULL,NULL,'2')
	
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_IndustryScope @Title=N'2.1 Tổng số lượt khách phục vụ',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'A11;A12;A13',@Level='2.1',@TypeReports = '2;3;4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N'- Khách quốc tế đến',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'A11', @Level='2.1.1',@TypeReports = '2;3;4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N'- Khách nội địa',@Unit = N'Lượt',@ForMonth=@ForMonth, @ListCodes=N'A12', @Level='2.1.2',@TypeReports = '2;3;4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N'- Khách Việt Nam đi nước ngoài',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'A13', @Level='2.1.3',@TypeReports = '2;3;4', @IndustryUserName=@IndustryUserName;
	
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_IndustryScope @Title=N'2.2 Tổng doanh thu từ doanh nghiệp lữ hành, vận chuyển khách du lịch',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'A21;A22;A23', @Level='2.2',@TypeReports = '2;3;4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N'- Khách quốc tế đến',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'A21', @Level='2.2.1',@TypeReports = '2;3;4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N'- Khách nội địa',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'A22', @Level='2.2.2',@TypeReports = '2;3;4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope @Title=N'- Khách Việt Nam đi nước ngoài',@Unit = N'Lượt', @ForMonth=@ForMonth, @ListCodes=N'A23', @Level='2.2.3',@TypeReports = '2;3;4', @IndustryUserName=@IndustryUserName;
	
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope @Title=N'2.3 Khách du lịch đến Khánh Hòa bằng tàu biển', @ForMonth=@ForMonth, @Level=N'2.3', @IndustryUserName=@IndustryUserName;
	
	SELECT @PerformPreviousPeriod_12 = isnull(t12.PerformPreviousPeriod,0) FROM @temp t12 WHERE t12.[Level]='1.2'
	SELECT @PerformPreviousPeriod_11 = isnull(t11.PerformPreviousPeriod,0) FROM @temp t11 WHERE t11.[Level]='1.1'
	
	SELECT @PerformInPeriod_12 = isnull(t12.PerformInPeriod,0) FROM @temp t12 WHERE t12.[Level]='1.2'
	SELECT @PerformInPeriod_11 = isnull(t11.PerformInPeriod,0) FROM @temp t11 WHERE t11.[Level]='1.1'
	
	SELECT @SamePeriodRateOfPerform_12 = isnull(t12.SamePeriodRateOfPerform,0) FROM @temp t12 WHERE t12.[Level]='1.2'
	SELECT @SamePeriodRateOfPerform_11 = isnull(t11.SamePeriodRateOfPerform,0) FROM @temp t11 WHERE t11.[Level]='1.1'
	
	SELECT @AccumulatedBeginingOfYear_12 = isnull(t12.AccumulatedBeginingOfYear,0) FROM @temp t12 WHERE t12.[Level]='1.2'
	SELECT @AccumulatedBeginingOfYear_11 = isnull(t11.AccumulatedBeginingOfYear,0) FROM @temp t11 WHERE t11.[Level]='1.1'
	
	SELECT @SamePeriodRateOfAccumulated_12 = isnull(t12.SamePeriodRateOfAccumulated,0) FROM @temp t12 WHERE t12.[Level]='1.2'
	SELECT @SamePeriodRateOfAccumulated_11 = isnull(t11.SamePeriodRateOfAccumulated,0) FROM @temp t11 WHERE t11.[Level]='1.1'
	
	INSERT INTO @temp (	Targets,Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear, SamePeriodRateOfAccumulated,[Level])
	SELECT N'1.3 Ngày khách lưu trú bình quân',N'Ngày', ISNULL(CASE WHEN @PerformPreviousPeriod_11 = 0 THEN 0 ELSE @PerformPreviousPeriod_12/@PerformPreviousPeriod_11 END,0),
														ISNULL(CASE WHEN @PerformInPeriod_11 = 0 THEN 0 ELSE @PerformInPeriod_12/@PerformInPeriod_11 END,0),
														ISNULL(CASE WHEN @SamePeriodRateOfPerform_11 = 0 THEN 0 ELSE @SamePeriodRateOfPerform_12/@SamePeriodRateOfPerform_11 END,0),
														ISNULL(CASE WHEN @AccumulatedBeginingOfYear_11 = 0 THEN 0 ELSE @AccumulatedBeginingOfYear_12/@AccumulatedBeginingOfYear_11 END,0),
														ISNULL(CASE WHEN @SamePeriodRateOfAccumulated_11 = 0 THEN 0 ELSE @SamePeriodRateOfAccumulated_12/@SamePeriodRateOfAccumulated_11 END,0),
														
														
														
														
														'1.3'
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
		
	SELECT @PerformPreviousPeriod_121 = isnull(t121.PerformPreviousPeriod,0) FROM @temp t121 WHERE t121.[Level]='1.2.1'
	SELECT @PerformPreviousPeriod_111 = isnull(t111.PerformPreviousPeriod,0) FROM @temp t111 WHERE t111.[Level]='1.1.1'
	
	SELECT @PerformInPeriod_121 = isnull(t121.PerformInPeriod,0) FROM @temp t121 WHERE t121.[Level]='1.2.1'
	SELECT @PerformInPeriod_111 = isnull(t111.PerformInPeriod,0) FROM @temp t111 WHERE t111.[Level]='1.1.1'
	
	SELECT @SamePeriodRateOfPerform_121 = isnull(t121.SamePeriodRateOfPerform,0) FROM @temp t121 WHERE t121.[Level]='1.2.1'
	SELECT @SamePeriodRateOfPerform_111 = isnull(t111.SamePeriodRateOfPerform,0) FROM @temp t111 WHERE t111.[Level]='1.1.1'
	
	SELECT @AccumulatedBeginingOfYear_121 = isnull(t121.AccumulatedBeginingOfYear,0) FROM @temp t121 WHERE t121.[Level]='1.2.1'
	SELECT @AccumulatedBeginingOfYear_111 = isnull(t111.AccumulatedBeginingOfYear,0) FROM @temp t111 WHERE t111.[Level]='1.1.1'
	
	SELECT @SamePeriodRateOfAccumulated_121 = isnull(t121.SamePeriodRateOfAccumulated,0) FROM @temp t121 WHERE t121.[Level]='1.2.1'
	SELECT @SamePeriodRateOfAccumulated_111 = isnull(t111.SamePeriodRateOfAccumulated,0) FROM @temp t111 WHERE t111.[Level]='1.1.1'
														
	INSERT INTO @temp (	Targets,Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear, SamePeriodRateOfAccumulated,[Level])
	SELECT N'- Khách quốc tế',N'Ngày', 
										ISNULL(CASE WHEN @PerformPreviousPeriod_111 = 0 THEN 0 ELSE @PerformPreviousPeriod_121/@PerformPreviousPeriod_111 END,0),
										ISNULL(CASE WHEN @PerformInPeriod_111 = 0 THEN 0 ELSE @PerformInPeriod_121/@PerformInPeriod_111 END,0),
										ISNULL(CASE WHEN @SamePeriodRateOfPerform_111 = 0 THEN 0 ELSE @SamePeriodRateOfPerform_121/@SamePeriodRateOfPerform_111 END,0),
										ISNULL(CASE WHEN @AccumulatedBeginingOfYear_111 = 0 THEN 0 ELSE @AccumulatedBeginingOfYear_121/@AccumulatedBeginingOfYear_111 END,0),
										ISNULL(CASE WHEN @SamePeriodRateOfAccumulated_111 = 0 THEN 0 ELSE @SamePeriodRateOfAccumulated_121/@SamePeriodRateOfAccumulated_111 END,0),
														
														
														
														
														
														'1.3.1'
														
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
		
	SELECT @PerformPreviousPeriod_122 = isnull(t122.PerformPreviousPeriod,0) FROM @temp t122 WHERE t122.[Level]='1.2.2'
	SELECT @PerformPreviousPeriod_112 = isnull(t112.PerformPreviousPeriod,0) FROM @temp t112 WHERE t112.[Level]='1.1.2'
	
	SELECT @PerformInPeriod_122 = isnull(t122.PerformInPeriod,0) FROM @temp t122 WHERE t122.[Level]='1.2.2'
	SELECT @PerformInPeriod_112 = isnull(t112.PerformInPeriod,0) FROM @temp t112 WHERE t112.[Level]='1.1.2'
	
	SELECT @SamePeriodRateOfPerform_122 = isnull(t122.SamePeriodRateOfPerform,0) FROM @temp t122 WHERE t122.[Level]='1.2.2'
	SELECT @SamePeriodRateOfPerform_112 = isnull(t112.SamePeriodRateOfPerform,0) FROM @temp t112 WHERE t112.[Level]='1.1.2'
	
	SELECT @AccumulatedBeginingOfYear_122 = isnull(t122.AccumulatedBeginingOfYear,0) FROM @temp t122 WHERE t122.[Level]='1.2.2'
	SELECT @AccumulatedBeginingOfYear_112 = isnull(t112.AccumulatedBeginingOfYear,0) FROM @temp t112 WHERE t112.[Level]='1.1.2'
	
	SELECT @SamePeriodRateOfAccumulated_122 = isnull(t122.SamePeriodRateOfAccumulated,0) FROM @temp t122 WHERE t122.[Level]='1.2.2'
	SELECT @SamePeriodRateOfAccumulated_112 = isnull(t112.SamePeriodRateOfAccumulated,0) FROM @temp t112 WHERE t112.[Level]='1.1.2'
														
	INSERT INTO @temp (	Targets,Unit,PerformPreviousPeriod,PerformInPeriod,SamePeriodRateOfPerform,AccumulatedBeginingOfYear, SamePeriodRateOfAccumulated,[Level])
	SELECT N'- Khách nội địa',N'Ngày', 
										ISNULL(CASE WHEN @PerformPreviousPeriod_112 = 0 THEN 0 ELSE @PerformPreviousPeriod_122/@PerformPreviousPeriod_112 END,0),
										ISNULL(CASE WHEN @PerformInPeriod_112 = 0 THEN 0 ELSE @PerformInPeriod_122/@PerformInPeriod_112 END,0),
										ISNULL(CASE WHEN @SamePeriodRateOfPerform_112 = 0 THEN 0 ELSE @SamePeriodRateOfPerform_122/@SamePeriodRateOfPerform_112 END,0),
										ISNULL(CASE WHEN @AccumulatedBeginingOfYear_112 = 0 THEN 0 ELSE @AccumulatedBeginingOfYear_122/@AccumulatedBeginingOfYear_112 END,0),
										ISNULL(CASE WHEN @SamePeriodRateOfAccumulated_112 = 0 THEN 0 ELSE @SamePeriodRateOfAccumulated_122/@SamePeriodRateOfAccumulated_112 END,0),
														
														
														
														
														
														'1.3.2'	
	
	INSERT @temp Exec dbo.p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope @Title=N'3. Lượt khách tham quan du lịch', @ForMonth=@ForMonth, @Code1=N'A11',@Code2=N'A12',@Code3=NULL, @Level='3', @IndustryUserName=@IndustryUserName;
						
	
	INSERT @temp  Exec dbo.p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope @Title=N'4. Tổng thu từ khách du lịch trên địa bàn tỉnh Khánh Hòa',@ForMonth=@ForMonth, @Unit=N'Đồng', @Code1=N'1D1', @Code2=N'1D2', @Level='4', @IndustryUserName=@IndustryUserName;
	SELECT t.[Targets], t.Unit, t.PerformPreviousPeriod,t.PerformInPeriod, ROUND(t.SamePeriodRateOfPerform,2) AS SamePeriodRateOfPerform ,t.AccumulatedBeginingOfYear, ROUND(t.SamePeriodRateOfAccumulated,2) AS SamePeriodRateOfAccumulated
	FROM @temp t
	ORDER BY t.[Level]
END
GO
IF OBJECT_ID('dbo.p_Report_Reports_02_ThongKeQuocTichKhachDuLich_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Reports_02_ThongKeQuocTichKhachDuLich_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Reports_02_ThongKeQuocTichKhachDuLich_IndustryScope 

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
	           ''                    AS NationalCode,
	           N'Các nước khác thuộc ' + D.ContinentName AS NationalName,
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
END
GO
IF OBJECT_ID('dbo.p_Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope
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
END
GO
IF OBJECT_ID('dbo.p_Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope
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
IF OBJECT_ID('dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope
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
	                           (@Class IS NULL AND cpc.CateName NOT LIKE N'% sao')
	                           OR cpc.CateName LIKE N'%' + @Class + N' sao'
	                       )
	                       AND rdi2.TypeReport = 1
	                       AND rdi2.IsDeleted = 0
	                       AND (
	                               MONTH(@ForMonth) = MONTH(rdi2.ForMonth)
	                               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi2.ForMonth)
	                           )
	                       AND EXISTS(
	                               SELECT 1
	                               FROM   dbo.fnSplit(@BaseListCodes, ';') AS fs
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
	           (@Class IS NULL AND cpc.CateName NOT LIKE N'% sao')
	           OR cpc.CateName LIKE N'%' + @Class + N' sao'
	       )
	       AND rdi.IsDeleted = 0
	       AND rdi.TypeReport = 1
	       AND (
	               MONTH(@ForMonth) = MONTH(rdi.ForMonth)
	               AND YEAR(DATEADD(YEAR, -1, @ForMonth)) = YEAR(rdi.ForMonth)
	           )
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@SellListCodes, ';') AS fs
	               WHERE  fs.Name = rdi.Code
	           )
	
	SELECT @Title,
	       ISNULL(@Unit, '')   AS Unit,
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
	       ISNULL(@Level, '')  AS LEVEL
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
	                           (@Class IS NULL AND cpc.CateName NOT LIKE N'% sao')
	                           OR cpc.CateName LIKE N'%' + @Class + N' sao'
	                       )
	                       AND rdi2.TypeReport = 1
	                       AND rdi2.IsDeleted = 0
	                       AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	                       AND EXISTS(
	                               SELECT 1
	                               FROM   dbo.fnSplit(@BaseListCodes, ';') AS fs
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
	           (@Class IS NULL AND cpc.CateName NOT LIKE N'% sao')
	           OR cpc.CateName LIKE N'%' + @Class + N' sao'
	       )
	       AND rdi.IsDeleted = 0
	       AND rdi.TypeReport = 1
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@SellListCodes, ';') AS fs
	               WHERE  fs.Name = rdi.Code
	           )
END
GO
IF OBJECT_ID('dbo.p_Report_ThongKe_CongSuatPhong_TrungBinh_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_ThongKe_CongSuatPhong_TrungBinh_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_ThongKe_CongSuatPhong_TrungBinh_IndustryScope
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
	                               FROM   dbo.fnSplit(@BaseListCodes, ';') AS fs
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
	               FROM   dbo.fnSplit(@SellListCodes, ';') AS fs
	               WHERE  fs.Name = rdi.Code
	           )
	
	SELECT @Title,
	       ISNULL(@Unit, '')   AS Unit,
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
	       ISNULL(@Level, '')  AS LEVEL
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
	                               FROM   dbo.fnSplit(@BaseListCodes, ';') AS fs
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
	               FROM   dbo.fnSplit(@SellListCodes, ';') AS fs
	               WHERE  fs.Name = rdi.Code
	           )
END
GO
IF OBJECT_ID('dbo.p_Report_ThongKe_TongDoanhThu_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_ThongKe_TongDoanhThu_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_ThongKe_TongDoanhThu_IndustryScope 

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
	                          FROM   dbo.fnSplit(@ListCodes, ';') AS fs
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
	               FROM   dbo.fnSplit(@ListCodes, ';') AS fs
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
	               FROM   dbo.fnSplit(@ListCodes, ';') AS fs
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
	                          FROM   dbo.fnSplit(@ListCodes, ';') AS fs
	                          WHERE  fs.Name = rdi.Code
	                      )
	                      
	       )    AS a
END
GO
IF OBJECT_ID('dbo.p_Report_ThongKe_TongKhachDuLich_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_ThongKe_TongKhachDuLich_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_ThongKe_TongKhachDuLich_IndustryScope

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
	               FROM   dbo.fnSplit(@ListCodes, ';') AS fs
	               WHERE  fs.Name = rdi1.Code
	           )
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@TypeReports, ';') AS fs
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
	               FROM   dbo.fnSplit(@ListCodes, ';') AS fs
	               WHERE  fs.Name = rdi2.Code
	       )
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@TypeReports, ';') AS fs
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
	       ISNULL(@Level, '')  AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Targets = rdi.Targets
	            AND rdi2.Unit = rdi.Unit
	            AND rdi2.Code = rdi.Code
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)-1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+0,0))
	            
	            AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@TypeReports, ';') AS fs
	               WHERE  CAST(fs.Name AS INT) = rdi2.TypeReport
	           )
	WHERE  rdi.IsDeleted = 0
	       
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@TypeReports, ';') AS fs
	               WHERE  CAST(fs.Name AS INT) = rdi.TypeReport
	           )
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@ListCodes, ';') AS fs
	               WHERE  fs.Name = rdi.Code
	           )
END
GO
IF OBJECT_ID('dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope

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
	                                  FROM   dbo.fnSplit(@TypeReports, ';') AS fs
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
	                                      FROM   dbo.fnSplit(@TypeReports, ';') AS fs
	                                      WHERE  CAST(fs.Name AS INT) = rdi2.TypeReport
	                                  )
	                                  
	                   ) * 100
	               ),
	               0
	           ) AS FLOAT
	       )                   AS SamePeriodRateOfAccumulated,
	       ISNULL(@Level, '')  AS LEVEL
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId)  AS rdi
	       LEFT OUTER JOIN (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId) AS rdi2
	            ON  rdi2.Targets = rdi.Targets
	            AND rdi2.Unit = rdi.Unit
	            AND rdi2.Code = rdi.Code
	            AND (rdi2.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth)-1,0) AND rdi2.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+0,0))
	            AND EXISTS(
	                    SELECT 1
	                    FROM   dbo.fnSplit(@TypeReports, ';') AS fs
	                    WHERE  CAST(fs.Name AS INT) = rdi2.TypeReport
	                )
	                
	WHERE  rdi.IsDeleted = 0
	       
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@TypeReports, ';') AS fs
	               WHERE  CAST(fs.Name AS INT) = rdi.TypeReport
	           )
	       AND (rdi.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND rdi.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0))
	       AND EXISTS(
	               SELECT 1
	               FROM   dbo.fnSplit(@ListCodes, ';') AS fs
	               WHERE  fs.Name = rdi.Code
	           )
	GROUP BY
	       rdi.Code
	ORDER BY
	       rdi.Code
END

GO
