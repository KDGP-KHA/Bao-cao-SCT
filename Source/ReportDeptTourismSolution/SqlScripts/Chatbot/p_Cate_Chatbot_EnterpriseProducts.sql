-- Deployment proposal only. Review and run manually; no report data is modified.
-- Deploy in the BaseApp/category database.
CREATE PROCEDURE dbo.p_Cate_Chatbot_EnterpriseProducts
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
 WHERE a.EnterpriseId=@EnterpriseId) THROW 50113,'Enterprise access denied',1;

 IF @EnterpriseId IS NULL OR @Offset<0 OR @Offset>100000 OR @Limit<1 OR @Limit>50 THROW 50101,'Invalid product query',1;
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
END
