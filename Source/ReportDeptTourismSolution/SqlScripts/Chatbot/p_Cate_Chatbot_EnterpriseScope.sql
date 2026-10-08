-- Deploy in BaseApp after both scope functions.
CREATE PROCEDURE dbo.p_Cate_Chatbot_EnterpriseScope
 @ChatbotUserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500),@Mode varchar(20),@EnterpriseId int=NULL
AS BEGIN
 SET NOCOUNT ON;
 SELECT * INTO #ChatbotScope FROM dbo.f_Chatbot_UserScope(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds);

 IF @Mode NOT IN('access','assigned','detail') THROW 50111,'Invalid scope query',1;
 IF @Mode='access' BEGIN
  SELECT s.*, STUFF((SELECT '|' + m.SemanticKey + ':' + CONVERT(varchar(11),m.RoleId) + ':' + m.ScopeMode + ':' + CONVERT(varchar(1),m.IsIndustryEditorTarget) FROM dbo.Report_RoleMappings m ORDER BY m.RoleId FOR XML PATH(''),TYPE).value('.','varchar(max)'),1,1,'') AS RoleMappingSignature, CAST(CASE WHEN EXISTS(SELECT 1 FROM dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,1)) THEN 1 ELSE 0 END AS bit) HasAuthorizedEnterprises
  FROM #ChatbotScope s; RETURN;
 END;
 IF @Mode='detail' AND NOT EXISTS(SELECT 1 FROM #ChatbotScope
 WHERE CanReadDashboard=1 AND CanReadRegistryDetail=1) THROW 50112,'Registry detail access denied',1;

 CREATE TABLE #ChatbotEnterprises(EnterpriseId int NOT NULL PRIMARY KEY);
 INSERT #ChatbotEnterprises(EnterpriseId)
 SELECT authorized.EnterpriseId FROM dbo.f_Chatbot_AuthorizedEnterprises(@ChatbotUserId,@ProvinceRoleIds,@EnterpriseRoleIds,CASE WHEN @Mode='detail' THEN 1 ELSE 0 END) authorized
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
END
