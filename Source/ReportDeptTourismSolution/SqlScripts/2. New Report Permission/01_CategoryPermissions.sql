-- Deploy in the category database first. SQL Server 2012.
USE [baocaosct.khanhhoa.gov.vn.cate];
GO
IF OBJECT_ID('dbo.Report_UserBusinessIndustryPermissions','U') IS NULL
 CREATE TABLE dbo.Report_UserBusinessIndustryPermissions (
  UserId int NOT NULL,
  IndustryId int NOT NULL,
  SavedBy varchar(255) NOT NULL,
  SavedOn datetime NOT NULL CONSTRAINT DF_ReportIndustryPermission_SavedOn DEFAULT GETDATE(),
  CONSTRAINT PK_Report_UserBusinessIndustryPermissions PRIMARY KEY(UserId,IndustryId),
  CONSTRAINT FK_ReportIndustryPermission_User FOREIGN KEY(UserId) REFERENCES dbo.Sys_Users(UserId),
  CONSTRAINT FK_ReportIndustryPermission_Industry FOREIGN KEY(IndustryId) REFERENCES dbo.Cate_BusinessIndustry(IndustryId)
 );
GO
IF OBJECT_ID('dbo.f_Report_IndustryUserScope') IS NULL
 EXEC('CREATE FUNCTION dbo.f_Report_IndustryUserScope(@UserName varchar(255)) RETURNS TABLE AS RETURN SELECT 1 AS Placeholder');
GO
ALTER FUNCTION dbo.f_Report_IndustryUserScope(@UserName varchar(255))
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
 JOIN dbo.Report_RoleMappings m ON m.RoleId=r.RoleId WHERE ur.UserId=u.UserId AND m.ScopeMode='all') THEN 1 ELSE 0 END) HasFullAccess,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Report_RoleMappings m ON m.RoleId=r.RoleId WHERE ur.UserId=u.UserId AND m.ScopeMode='industry') THEN 1 ELSE 0 END) HasIndustryRole,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles r ON r.RoleId=ur.RoleId AND r.IsDeleted=0
 JOIN dbo.Report_RoleMappings m ON m.RoleId=r.RoleId WHERE ur.UserId=u.UserId AND m.ScopeMode='enterprise') THEN 1 ELSE 0 END) HasEnterpriseRole
 FROM dbo.Sys_Users u WHERE u.UserName=@UserName AND u.IsActive=1 AND u.IsDeleted=0 AND ISNULL(u.IsLocked,0)=0
 AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings WHERE SemanticKey='SystemAdministrator' AND ScopeMode='all')
 AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings WHERE SemanticKey='Enterprise' AND ScopeMode='enterprise')
 AND NOT EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m LEFT JOIN dbo.Sys_Roles r ON r.RoleId=m.RoleId WHERE r.RoleId IS NULL OR r.IsDeleted<>0)
 ) flags
);
GO
IF OBJECT_ID('dbo.f_Report_IndustryEnterprises') IS NULL
 EXEC('CREATE FUNCTION dbo.f_Report_IndustryEnterprises(@UserName varchar(255)) RETURNS TABLE AS RETURN SELECT 1 AS Placeholder');
GO
ALTER FUNCTION dbo.f_Report_IndustryEnterprises(@UserName varchar(255))
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
  SELECT 1 FROM dbo.Cate_BusinessEnterprise b CROSS APPLY dbo.fnSplit(b.IndustryIds,',') token
  JOIN dbo.Report_UserBusinessIndustryPermissions p ON p.UserId=u.UserId AND p.IndustryId=TRY_CONVERT(int,LTRIM(RTRIM(token.Name)))
  WHERE b.EnterpriseId=e.EnterpriseId))
);
GO
-- Administrative operation only: do not grant this procedure to report viewers.
IF OBJECT_ID('dbo.p_Report_IndustryPermissions_Save') IS NULL
 EXEC('CREATE PROCEDURE dbo.p_Report_IndustryPermissions_Save AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_IndustryPermissions_Save
 @UserId int,@IndustryIds varchar(max),@SavedBy varchar(255)
AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 SET @IndustryIds=LTRIM(RTRIM(ISNULL(@IndustryIds,'')));
 IF LEN(@IndustryIds)>20000 OR @IndustryIds LIKE ',%' OR @IndustryIds LIKE '%,' OR @IndustryIds LIKE '%,,%'
  THROW 50001,'Invalid comma-separated industry IDs.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Sys_Users target WHERE target.UserId=@UserId AND target.IsActive=1 AND target.IsDeleted=0
  AND EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
   WHERE ur.UserId=target.UserId AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m WHERE m.RoleId=ur.RoleId AND m.IsIndustryEditorTarget=1)))
  THROW 50002,'Target user is inactive, unknown or has no eligible role.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Sys_Users WHERE UserName=@SavedBy AND IsActive=1 AND IsDeleted=0)
  THROW 50003,'Audit user is inactive or unknown.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Sys_Users actor
  JOIN dbo.Sys_UserRoles ur ON ur.UserId=actor.UserId
  JOIN dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
  JOIN dbo.Sys_Permissions p ON p.RoleId=role.RoleId
  JOIN dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
  WHERE actor.UserName=@SavedBy AND actor.IsActive=1 AND actor.IsDeleted=0
   AND ISNULL(actor.IsLocked,0)=0 AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m WHERE m.RoleId=ur.RoleId AND m.SemanticKey='SystemAdministrator' AND m.ScopeMode<>'enterprise') AND f.Area='Sys' AND f.Name='User' AND p.Action='Edit')
  THROW 50113,'Configured system administrator and user management Edit permission are required.',1;
 IF @IndustryIds<>'' AND EXISTS(SELECT 1 FROM dbo.fnSplit(@IndustryIds,',') token
  WHERE TRY_CONVERT(int,LTRIM(RTRIM(token.Name))) IS NULL OR NOT EXISTS(
   SELECT 1 FROM dbo.Cate_BusinessIndustry i WHERE i.IndustryId=TRY_CONVERT(int,LTRIM(RTRIM(token.Name))) AND i.IsActive=1 AND i.IsDeleted=0))
  THROW 50004,'One or more industry IDs are invalid or inactive.',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @LockedUser int;
  SELECT @LockedUser=UserId FROM dbo.Sys_Users WITH(UPDLOCK,HOLDLOCK) WHERE UserId=@UserId;
  DELETE dbo.Report_UserBusinessIndustryPermissions WHERE UserId=@UserId;
  IF @IndustryIds<>'' INSERT dbo.Report_UserBusinessIndustryPermissions(UserId,IndustryId,SavedBy)
   SELECT DISTINCT @UserId,TRY_CONVERT(int,LTRIM(RTRIM(Name))),@SavedBy FROM dbo.fnSplit(@IndustryIds,',');
  COMMIT;
 END TRY
 BEGIN CATCH
  IF @@TRANCOUNT>0 ROLLBACK;
  THROW;
 END CATCH;
 RETURN @UserId;
END;
GO
IF OBJECT_ID('dbo.p_Report_IndustryPermissions_Get') IS NULL
 EXEC('CREATE PROCEDURE dbo.p_Report_IndustryPermissions_Get AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_IndustryPermissions_Get @UserId int,@RequestedBy varchar(255)
AS
BEGIN
 SET NOCOUNT ON;
 IF NOT EXISTS(SELECT 1 FROM dbo.Sys_Users actor
  JOIN dbo.Sys_UserRoles ur ON ur.UserId=actor.UserId
  JOIN dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
  JOIN dbo.Sys_Permissions p ON p.RoleId=role.RoleId
  JOIN dbo.Sys_Functions f ON f.FunctionId=p.FunctionId AND f.IsDeleted=0
  WHERE actor.UserName=@RequestedBy AND actor.IsActive=1 AND actor.IsDeleted=0
   AND ISNULL(actor.IsLocked,0)=0 AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m WHERE m.RoleId=ur.RoleId AND m.SemanticKey='SystemAdministrator' AND m.ScopeMode<>'enterprise') AND f.Area='Sys' AND f.Name='User' AND p.Action='Edit')
  THROW 50113,'Configured system administrator and user management Edit permission are required.',1;
 IF NOT EXISTS(SELECT 1 FROM dbo.Sys_Users target WHERE target.UserId=@UserId AND target.IsActive=1 AND target.IsDeleted=0
  AND EXISTS(SELECT 1 FROM dbo.Sys_UserRoles ur JOIN dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
   WHERE ur.UserId=target.UserId AND EXISTS(SELECT 1 FROM dbo.Report_RoleMappings m WHERE m.RoleId=ur.RoleId AND m.IsIndustryEditorTarget=1)))
  THROW 50002,'Target user is inactive, unknown or has no eligible role.',1;
 SELECT i.IndustryId,i.IndustryCode,i.IndustryName,
  CONVERT(bit,CASE WHEN i.IsActive=1 AND i.IsDeleted=0 THEN 1 ELSE 0 END) IsActive,
  CONVERT(bit,CASE WHEN p.UserId IS NULL THEN 0 ELSE 1 END) IsSelected
 FROM dbo.Cate_BusinessIndustry i
 LEFT JOIN dbo.Report_UserBusinessIndustryPermissions p ON p.IndustryId=i.IndustryId AND p.UserId=@UserId
 WHERE (i.IsActive=1 AND i.IsDeleted=0) OR p.UserId IS NOT NULL
 ORDER BY i.IndustryCode,i.IndustryName,i.IndustryId;
END;
GO
