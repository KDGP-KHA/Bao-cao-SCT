USE [baocaosct.khanhhoa.gov.vn];
GO
IF OBJECT_ID('dbo.f_Report_IndustryDataImports') IS NULL EXEC('CREATE FUNCTION dbo.f_Report_IndustryDataImports(@UserName varchar(255)) RETURNS TABLE AS RETURN SELECT 1 AS Placeholder');
GO
ALTER FUNCTION dbo.f_Report_IndustryDataImports(@UserName varchar(255)) RETURNS TABLE AS RETURN (SELECT r.* FROM dbo.Report_DataImports r WHERE EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@UserName) e WHERE e.EnterpriseId=r.EnterpriseId));
GO
IF OBJECT_ID('dbo.f_Report_IndustryReportFiles') IS NULL EXEC('CREATE FUNCTION dbo.f_Report_IndustryReportFiles(@UserName varchar(255)) RETURNS TABLE AS RETURN SELECT 1 AS Placeholder');
GO
ALTER FUNCTION dbo.f_Report_IndustryReportFiles(@UserName varchar(255)) RETURNS TABLE AS RETURN (SELECT r.* FROM dbo.Report_ReportFiles r WHERE EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@UserName) e WHERE e.EnterpriseId=r.EnterpriseId));
GO
IF OBJECT_ID('dbo.f_Report_IndustryExtendInfos') IS NULL EXEC('CREATE FUNCTION dbo.f_Report_IndustryExtendInfos(@UserName varchar(255)) RETURNS TABLE AS RETURN SELECT 1 AS Placeholder');
GO
ALTER FUNCTION dbo.f_Report_IndustryExtendInfos(@UserName varchar(255)) RETURNS TABLE AS RETURN (SELECT r.* FROM dbo.Report_ExtendInfos r WHERE EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@UserName) u WHERE u.IsRestricted=0));
GO
IF OBJECT_ID('dbo.p_Report_IndustryPermissions_Scope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_IndustryPermissions_Scope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_IndustryPermissions_Scope @UserName varchar(255) AS BEGIN SET NOCOUNT ON; SELECT s.*, STUFF((SELECT '|' + m.SemanticKey + ':' + CONVERT(varchar(11),m.RoleId) + ':' + m.ScopeMode + ':' + CONVERT(varchar(1),m.IsIndustryEditorTarget) FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m ORDER BY m.RoleId FOR XML PATH(''),TYPE).value('.','varchar(max)'),1,1,'') AS RoleMappingSignature FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryUserScope(@UserName) s; END;
GO
IF OBJECT_ID('dbo.p_Report_IndustryPermissions_Enterprises') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_IndustryPermissions_Enterprises AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_IndustryPermissions_Enterprises @UserName varchar(255) AS BEGIN SET NOCOUNT ON; SELECT e.* FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.f_Report_IndustryEnterprises(@UserName) e; END;
GO
