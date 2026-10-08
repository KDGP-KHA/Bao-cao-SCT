-- Deploy in BaseApp. Account/role/permission state is read fresh; caller parameters are server-owned.
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
