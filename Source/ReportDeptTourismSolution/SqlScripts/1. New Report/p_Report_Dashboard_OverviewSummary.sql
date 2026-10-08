-- Review/deploy manually to baocaosct.khanhhoa.gov.vn. Persistent source data is read only.
ALTER PROCEDURE dbo.p_Report_Dashboard_OverviewSummary @ForMonth date,
 @WardId int=NULL,@EconomicSectorId int=NULL,@IndustryId int=NULL,@EnterpriseId int=NULL,@GroupBy varchar(10)=NULL
AS BEGIN SET NOCOUNT ON;
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
)
 SELECT CASE WHEN @GroupBy='ward' THEN WardId ELSE EconomicSectorId END DimensionId,
 COALESCE(CASE WHEN @GroupBy='ward' THEN WardName ELSE EconomicSectorName END,N'Chưa phân loại') DimensionName,
 SUM(CASE WHEN ','+REPLACE(ISNULL(TypeBusiness,''),' ','')+',' LIKE '%,1,%' THEN 1 ELSE 0 END) Type1Expected,
 SUM(CASE WHEN ','+REPLACE(ISNULL(TypeBusiness,''),' ','')+',' LIKE '%,2,%' THEN 1 ELSE 0 END) Type2Expected,
 SUM(CASE WHEN ','+REPLACE(ISNULL(TypeBusiness,''),' ','')+',' LIKE '%,3,%' THEN 1 ELSE 0 END) Type3Expected
 FROM Cohort GROUP BY CASE WHEN @GroupBy='ward' THEN WardId ELSE EconomicSectorId END,
 COALESCE(CASE WHEN @GroupBy='ward' THEN WardName ELSE EconomicSectorName END,N'Chưa phân loại');
 RETURN; END;
 ;WITH Cohort AS (
 SELECT e.EnterpriseId, e.BusinessName, e.TaxCode, e.WardId, COALESCE(w.WardName,CASE WHEN e.WardId IS NULL THEN N'Chưa phân loại' ELSE N'Mã địa bàn '+CONVERT(nvarchar(20),e.WardId) END) WardName,
 e.TypeBusiness,b.EconomicSectorId, s.Name EconomicSectorName, b.IndustryIds,
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
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e OUTER APPLY (
 SELECT COUNT(*) BusinessRows,MAX(CASE WHEN NULLIF(LTRIM(RTRIM(IndustryIds)),'') IS NOT NULL THEN 1 ELSE 0 END) HasIndustry
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise WHERE EnterpriseId=e.EnterpriseId) b WHERE e.IsActive=1 AND e.IsDeleted=0
 ) SELECT Registry.*,Expected.*,
 (SELECT COUNT(*) FROM dbo.Report_DataImports WHERE IsDeleted=0 AND (TypeReport IS NULL OR TypeReport NOT IN (1,2,3)) AND ForMonth>=@MonthStart AND ForMonth<@NextMonth) TypeZeroRows,
 (SELECT COUNT(*) FROM dbo.Report_DataImports WHERE IsDeleted=0 AND ForMonth>=DATEADD(month,1,DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1))) FutureDatedRows,
 (SELECT COUNT(DISTINCT r.EnterpriseId) FROM dbo.Report_DataImports r LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e ON e.EnterpriseId=r.EnterpriseId
 WHERE r.IsDeleted=0 AND r.ForMonth>=@MonthStart AND r.ForMonth<@NextMonth
 AND (e.EnterpriseId IS NULL OR e.IsActive<>1 OR e.IsDeleted<>0 OR r.TypeReport IS NULL OR r.TypeReport NOT IN (1,2,3)
 OR ','+REPLACE(ISNULL(e.TypeBusiness,''),' ','')+',' NOT LIKE '%,'+CONVERT(varchar(11),r.TypeReport)+',%')) OutsideCohortEnterprises
 FROM Registry CROSS JOIN Expected;
END
