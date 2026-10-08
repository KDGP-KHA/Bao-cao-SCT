-- Values are generated from Configs/AppSettings.config ReportRoles:* keys. Existing Sys_Roles and permissions are never migrated.
USE [baocaosct.khanhhoa.gov.vn.cate];
GO
IF OBJECT_ID('dbo.Report_RoleMappings','U') IS NULL
 CREATE TABLE dbo.Report_RoleMappings (
  SemanticKey varchar(80) NOT NULL PRIMARY KEY,
  RoleId int NOT NULL UNIQUE REFERENCES dbo.Sys_Roles(RoleId),
  ScopeMode varchar(10) NOT NULL,
  IsIndustryEditorTarget bit NOT NULL,
  CONSTRAINT CK_ReportRoleMapping_Scope CHECK(ScopeMode IN('all','industry','enterprise')),
  CONSTRAINT CK_ReportRoleMapping_Enterprise CHECK(ScopeMode<>'enterprise' OR IsIndustryEditorTarget=0)
 );
GO
