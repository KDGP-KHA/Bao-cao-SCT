-- Review/deploy manually to baocaosct.khanhhoa.gov.vn. Persistent source data is read only.
CREATE PROCEDURE dbo.p_Report_Dashboard_FilterOptions @OptionKind varchar(20),@TypeReport int=NULL,
 @Search nvarchar(250)=NULL,@Page int=1,@PageSize int=50
AS BEGIN SET NOCOUNT ON;
IF @OptionKind NOT IN ('year','latest','ward','sector','industry','enterprise') THROW 50006,'Unsupported option kind',1;
 IF @TypeReport IS NOT NULL AND @TypeReport NOT IN (1,2,3) THROW 50001,'Unsupported report type',1;
 IF @Page<1 OR @PageSize<1 OR @PageSize>100 THROW 50004,'Invalid page',1;
 DECLARE @WardId int=NULL,@EconomicSectorId int=NULL,@IndustryId int=NULL,@EnterpriseId int=NULL;
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
), Options AS (
 SELECT DISTINCT CONVERT(varchar(20),YEAR(r.ForMonth)) Value,CONVERT(nvarchar(250),YEAR(r.ForMonth)) Text
 FROM dbo.Report_DataImports r WHERE @OptionKind='year' AND r.IsDeleted=0 AND (@TypeReport IS NULL OR r.TypeReport=@TypeReport)
 UNION SELECT DISTINCT CONVERT(varchar(20),YEAR(f.ForMonth)),CONVERT(nvarchar(250),YEAR(f.ForMonth)) FROM dbo.Report_ReportFiles f WHERE @OptionKind='year' AND f.IsDeleted=0
 UNION SELECT CONVERT(varchar(20),YEAR(GETDATE())),CONVERT(nvarchar(250),YEAR(GETDATE())) WHERE @OptionKind='year'
 UNION SELECT CONVERT(varchar(20),MAX(ForMonth),23),CONVERT(nvarchar(250),MAX(ForMonth),23) FROM dbo.Report_DataImports
 WHERE @OptionKind='latest' AND IsDeleted=0 AND TypeReport IN (1,2,3) AND ForMonth<DATEADD(month,1,DATEFROMPARTS(YEAR(GETDATE()),MONTH(GETDATE()),1)) HAVING MAX(ForMonth) IS NOT NULL
 UNION SELECT DISTINCT CONVERT(varchar(20),WardId),CONVERT(nvarchar(250),WardName) FROM Cohort WHERE @OptionKind='ward' AND WardId IS NOT NULL
 UNION SELECT DISTINCT CONVERT(varchar(20),EconomicSectorId),CONVERT(nvarchar(250),EconomicSectorName) FROM Cohort WHERE @OptionKind='sector' AND EconomicSectorId IS NOT NULL
 UNION SELECT DISTINCT CONVERT(varchar(20),i.IndustryId),CONVERT(nvarchar(250),i.IndustryName) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessIndustry i
 WHERE @OptionKind='industry' AND i.IsActive=1 AND i.IsDeleted=0 AND EXISTS(SELECT 1 FROM Cohort c WHERE ','+REPLACE(ISNULL(c.IndustryIds,''),' ','')+',' LIKE '%,'+CONVERT(varchar(11),i.IndustryId)+',%')
 UNION SELECT CONVERT(varchar(20),EnterpriseId),CONVERT(nvarchar(250),COALESCE(BusinessName,N'')+CASE WHEN NULLIF(TaxCode,'') IS NULL THEN N'' ELSE N' · '+TaxCode END)
 FROM Cohort WHERE @OptionKind='enterprise'
 ), Filtered AS (SELECT * FROM Options WHERE @Search IS NULL OR @Search='' OR CHARINDEX(@Search,Text)>0 OR Value=@Search),
 Ranked AS (SELECT *,ROW_NUMBER() OVER(ORDER BY CASE WHEN @OptionKind IN ('year','latest') THEN Value END DESC,Text,Value) RowNo FROM Filtered),
 Total AS (SELECT COUNT(*) TotalRow FROM Filtered)
 SELECT t.TotalRow,r.Value,r.Text FROM Total t OUTER APPLY
 (SELECT Value,Text FROM Ranked WHERE RowNo>CONVERT(bigint,@Page-1)*@PageSize AND RowNo<=CONVERT(bigint,@Page)*@PageSize) r;
END
