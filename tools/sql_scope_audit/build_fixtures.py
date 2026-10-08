"""Generate isolated SQL Server fixtures from actual source bodies; never executes SQL."""
from pathlib import Path
import re
from tools.sql_scope_audit.inventory import definitions,ROOT
objs=definitions()
setup="""-- Run ONLY in an empty, disposable database named ScopeAuditFixture* (SQLCMD -b).
-- All fixture DDL/data are rolled back; no production connection or credentials are loaded.
:ON ERROR EXIT
IF DB_NAME() NOT LIKE N'ScopeAuditFixture%' THROW 51000,'Isolated ScopeAuditFixture database required',1;
IF EXISTS(SELECT 1 FROM sys.tables WHERE is_ms_shipped=0) THROW 51000,'Fixture database must be empty',1;
BEGIN TRANSACTION;
CREATE TABLE dbo.Sys_Users(UserId int PRIMARY KEY,UserName varchar(255),FullName nvarchar(250),Email varchar(250),IsActive bit,IsDeleted bit,IsLocked bit);
CREATE TABLE dbo.Sys_Roles(RoleId int PRIMARY KEY,Name nvarchar(100),IsDeleted bit);
CREATE TABLE dbo.Sys_UserRoles(UserId int,RoleId int);
CREATE TABLE dbo.Sys_Functions(FunctionId int,Area varchar(20),Name varchar(100),IsDeleted bit);
CREATE TABLE dbo.Sys_Permissions(RoleId int,FunctionId int,Action varchar(30));
CREATE TABLE dbo.Report_RoleMappings(SemanticKey varchar(80),RoleId int,ScopeMode varchar(10),IsIndustryEditorTarget bit);
CREATE TABLE dbo.Report_UserBusinessIndustryPermissions(UserId int,IndustryId int);
CREATE TABLE dbo.Cate_EnterprisePermissions(ForUser varchar(255),EnterpriseId int);
CREATE TABLE dbo.Cate_Enterprises(EnterpriseId int PRIMARY KEY,BusinessName nvarchar(250),TaxCode varchar(100),TypeBusiness varchar(50),IsActive bit,IsDeleted bit,IsApproved bit,WardId int,
 OwnerEnterpriseName nvarchar(250),BusinessAddress nvarchar(250),StreetName nvarchar(250),WardName nvarchar(100),DistrictName nvarchar(100),ProvinceName nvarchar(100),TypeBusinessName nvarchar(100),LegalRepresentationName nvarchar(100),LegalRepresentationPhone varchar(100),LegalRepresentationEmail varchar(100),Phone varchar(100),Website varchar(100),Email varchar(100),CreatedBy varchar(255));
CREATE TABLE dbo.Cate_BusinessEnterprise(EnterpriseId int,IndustryIds varchar(255),EconomicSectorId int);
CREATE TABLE dbo.Cate_BusinessIndustry(IndustryId int,IndustryName nvarchar(100),IsActive bit,IsDeleted bit);
CREATE TABLE dbo.Cate_Wards(WardId int,WardName nvarchar(100));
CREATE TABLE dbo.Cate_EconomicSector(EconomicSectorId int,Name nvarchar(100));
CREATE TABLE dbo.Sys_Configs(ConfigKey varchar(100),ConfigValue varchar(100),IsDeleted bit);
CREATE TABLE dbo.Report_DataImports(ReportId int,EnterpriseId int,ForMonth datetime,TypeReport int,TypeReportName nvarchar(100),IsLate bit,IsDeleted bit,CreatedBy varchar(255),CreatedDate datetime,Code varchar(20),Targets nvarchar(100),Unit nvarchar(20),PerformPreviousPeriod float,PerformInPeriod float,AccumulatedBeginingOfYear float,[Index] int,[Level] varchar(10),ComparedSamePeriodLastYear float);
CREATE TABLE dbo.Report_ReportFiles(EnterpriseId int,ForMonth datetime,IsDeleted bit,CreatedBy varchar(255));
CREATE TABLE dbo.Report_ExtendInfos(ForMonth datetime);
GO
-- Fixture-only CSV helper; deployed dbo.fnSplit must separately pass production-collation checks.
CREATE FUNCTION dbo.fnSplit(@s varchar(max),@sep char(1)) RETURNS @t TABLE(Name varchar(max)) AS BEGIN
 DECLARE @p int; WHILE LEN(ISNULL(@s,''))>0 BEGIN SET @p=CHARINDEX(@sep,@s); IF @p=0 SET @p=LEN(@s)+1; INSERT @t VALUES(SUBSTRING(@s,1,@p-1));SET @s=SUBSTRING(@s,@p+1,LEN(@s)); END; RETURN; END;
GO
"""
order=['f_Report_IndustryUserScope','f_Report_IndustryEnterprises','f_Chatbot_UserScope','f_Chatbot_AuthorizedEnterprises','f_Report_IndustryDataImports','f_Report_IndustryReportFiles','f_Report_IndustryExtendInfos','f_Report_DataImportEnterprises','p_Report_DataImports_OperationalScope','p_Report_DataImports_CheckOwnership','p_Report_DataImports_GetDataImport_Operational','p_Report_Dashboard_FilterOptions_IndustryScope','p_Report_DataImports_GetForUserOnMonth_IndustryScope','p_Report_DataImports_GetForUserOnMonth_Operational','p_Report_Industry_Enterprises_SearchSelect2','p_Report_DataImports_Enterprises_SearchSelect2','p_Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope','p_Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope']
for n in order:
 body=re.sub(r'^ALTER ','CREATE ',objs[n]['sql']);body=body.replace('[baocaosct.khanhhoa.gov.vn.cate].dbo.','dbo.').replace('[baocaosct.khanhhoa.gov.vn].dbo.','dbo.')
 setup+=body+'\nGO\n'
setup+="""
INSERT dbo.Sys_Roles VALUES(1,N'SpAdmin',0),(2,N'Management2',0),(3,N'Management3',0),(4,N'Management4',0),(5,N'Enterprise',0),(6,N'Management6',0);
INSERT dbo.Report_RoleMappings VALUES('SystemAdministrator',1,'all',1),('ReportingRole2',2,'industry',1),('ReportingRole3',3,'industry',1),('ReportingRole4',4,'industry',1),('Enterprise',5,'enterprise',0),('IndustryAdministrator',6,'industry',1);
INSERT dbo.Sys_Users(UserId,UserName,IsActive,IsDeleted,IsLocked) VALUES(1,'u1',1,0,0),(2,'u2',1,0,0),(3,'u3',1,0,0),(4,'u4',1,0,0),(5,'u5',1,0,0),(6,'u6',1,0,0),(7,'u7',0,0,0),(8,'u8',1,0,1),(9,'u9',1,1,0),(10,'u10',1,0,0),(11,'u11',1,0,0),(12,'u12',1,0,0),(13,'u13',1,0,0),(14,'u14',1,0,0);
INSERT dbo.Sys_UserRoles VALUES(1,1),(2,6),(3,6),(4,5),(5,5),(6,5),(6,6),(7,1),(8,1),(9,1),(10,6),(11,1),(12,2),(13,2),(14,5);
INSERT dbo.Sys_Functions VALUES(1,'Report','Dashboard',0),(2,'Report','Import',0),(3,'Cate','Enterprise',0);
INSERT dbo.Sys_Permissions VALUES(1,1,'View'),(1,2,'View'),(1,3,'View'),(6,1,'View'),(6,2,'View'),(5,2,'View'),(2,2,'Add');
INSERT dbo.Report_UserBusinessIndustryPermissions VALUES(2,10),(6,10),(10,99),(12,10);
INSERT dbo.Cate_EnterprisePermissions VALUES('u1',1),('u2',3),('u3',2),('u4',1),('u6',2),('u12',2);
INSERT dbo.Cate_Enterprises(EnterpriseId,BusinessName,TaxCode,TypeBusiness,IsActive,IsDeleted,IsApproved,WardId) VALUES(1,N'One','1','1',1,0,1,1),(2,N'Two','2','1',1,0,1,2),(3,N'Three','3','1',1,0,1,1),(4,N'Deleted','4','1',1,1,1,1),(5,N'Inactive','5','1',0,0,1,1),(6,N'Unapproved','6','1',1,0,0,1);
INSERT dbo.Cate_BusinessEnterprise VALUES(1,'10',1),(2,'20',2),(3,'10,20',1),(4,'10',1),(5,'10',1),(6,'10',1);
INSERT dbo.Cate_BusinessIndustry VALUES(10,N'Industry10',1,0),(20,N'Industry20',1,0),(99,N'EmptyIndustry',1,0);
INSERT dbo.Cate_Wards VALUES(1,N'Ward1'),(2,N'Ward2'); INSERT dbo.Cate_EconomicSector VALUES(1,N'Sector1'),(2,N'Sector2');
INSERT dbo.Sys_Configs VALUES('Day_Deadline_Send_Late_Report','31',0);
INSERT dbo.Report_DataImports(ReportId,EnterpriseId,ForMonth,TypeReport,TypeReportName,IsLate,IsDeleted,CreatedBy,CreatedDate,Code,Targets,Unit,PerformPreviousPeriod,PerformInPeriod,AccumulatedBeginingOfYear) VALUES(1,1,'20260901',1,N'Type1',0,0,'u4','20260902','A',N'A',N'VND',0,10,10),(2,1,'20260901',1,N'Type1',0,0,'u4','20260902','B',N'B',N'VND',0,5,5),(3,2,'20260901',1,N'Type1',0,0,'u3','20260902','A',N'A',N'VND',0,20,20),(4,3,'20260901',1,N'Type1',0,0,'u13','20260902','A',N'A',N'VND',0,30,30);
UPDATE dbo.Sys_Users SET FullName=N'One',Email='same@example.invalid' WHERE UserId=14;
UPDATE dbo.Cate_Enterprises SET Email='same@example.invalid' WHERE EnterpriseId=1;
DECLARE @Ownership TABLE(CanWrite bit);
INSERT @Ownership EXEC dbo.p_Report_DataImports_CheckOwnership 3,'20260901',1,'Import','u13';
IF NOT EXISTS(SELECT 1 FROM @Ownership WHERE CanWrite=1) THROW 51001,'Owned existing write incorrectly denied',1;
DELETE FROM @Ownership;
INSERT @Ownership EXEC dbo.p_Report_DataImports_CheckOwnership 3,'20261001',1,'Import','u13';
IF EXISTS(SELECT 1 FROM @Ownership WHERE CanWrite=1) THROW 51001,'Historical creator authorized unrelated new month',1;
INSERT dbo.Report_ReportFiles VALUES(3,'20260901',0,'someone-else');
DELETE FROM @Ownership;
INSERT @Ownership EXEC dbo.p_Report_DataImports_CheckOwnership 3,'20260901',1,'Import','u13';
IF EXISTS(SELECT 1 FROM @Ownership WHERE CanWrite=1) THROW 51001,'Creator overwrite of foreign report file allowed',1;
DELETE FROM dbo.Report_ReportFiles;
INSERT dbo.Report_DataImports(ReportId,EnterpriseId,ForMonth,TypeReport,TypeReportName,IsLate,IsDeleted,CreatedBy,CreatedDate,Code,Targets,Unit,PerformInPeriod) VALUES(5,3,'20260901',1,N'Type1',0,0,'u3','20260902','Z',N'Foreign',N'VND',99);
DECLARE @OwnedRows TABLE(EnterpriseId int,EnterpriseName nvarchar(250),ForMonth datetime,TypeReport int,TypeReportName nvarchar(100),[Index] int,[Level] varchar(10),Targets nvarchar(100),Unit nvarchar(20),Code varchar(20),PerformPreviousPeriod float,PerformInPeriod float,AccumulatedBeginingOfYear float,ComparedSamePeriodLastYear float,CreatedBy nvarchar(250),CreatedDate datetime);
INSERT @OwnedRows EXEC dbo.p_Report_DataImports_GetDataImport_Operational 3,'20260901','u13';
IF (SELECT COUNT(*) FROM @OwnedRows)<>1 OR EXISTS(SELECT 1 FROM @OwnedRows WHERE PerformInPeriod<>30) THROW 51001,'Creator-only read exposed another creator records',1;
DELETE FROM @Ownership;
INSERT @Ownership EXEC dbo.p_Report_DataImports_CheckOwnership 3,'20260901',1,'Import','u13';
IF EXISTS(SELECT 1 FROM @Ownership WHERE CanWrite=1) THROW 51001,'Creator update overwrites foreign target rows',1;
DELETE FROM @Ownership;
INSERT @Ownership EXEC dbo.p_Report_DataImports_CheckOwnership 3,'20260901',NULL,'Delete','u13';
IF EXISTS(SELECT 1 FROM @Ownership WHERE CanWrite=1) THROW 51001,'Creator delete removes foreign month rows',1;
DELETE FROM dbo.Report_DataImports WHERE ReportId=5;
DECLARE @Expected TABLE(UserName varchar(255),EnterpriseId int);
INSERT @Expected VALUES('u1',1),('u1',2),('u1',3),('u1',6),('u2',1),('u2',3),('u2',6),('u3',2),('u4',1),('u6',1),('u6',3),('u6',6),('u11',1),('u11',2),('u11',3),('u11',6),('u12',1),('u12',3),('u12',6);
DECLARE @OpModels TABLE(EnterpriseId int,BusinessName nvarchar(250),TaxCode varchar(100),TypeBusiness varchar(50),IsEnterpriseUser bit,RoleMappingSignature varchar(max),CanManageAllRecords bit);
INSERT @OpModels EXEC dbo.p_Report_DataImports_OperationalScope 'u6';
IF EXISTS(SELECT 1 FROM @OpModels WHERE IsEnterpriseUser<>0 OR RoleMappingSignature NOT LIKE 'SystemAdministrator:1:all:1|ReportingRole2:2:industry:1|%') THROW 51001,'Operational UI role classification or mapping signature changed',1;
DECLARE @Actual TABLE(UserName varchar(255),EnterpriseId int);
INSERT @Actual SELECT u.UserName,e.EnterpriseId FROM dbo.Sys_Users u CROSS APPLY dbo.f_Report_IndustryEnterprises(u.UserName) e;
IF EXISTS(SELECT * FROM @Actual EXCEPT SELECT * FROM @Expected) OR EXISTS(SELECT * FROM @Expected EXCEPT SELECT * FROM @Actual) THROW 51001,'R07 exact enterprise population mismatch',1;
IF EXISTS(SELECT 1 FROM dbo.f_Report_IndustryEnterprises('unknown')) THROW 51001,'Unknown user broadened',1;
IF NOT EXISTS(SELECT 1 FROM dbo.f_Report_DataImportEnterprises('u12') WHERE EnterpriseId=2) THROW 51001,'R01 operational assignment blocked by unrelated industry',1;
IF EXISTS(SELECT 1 FROM dbo.f_Report_DataImportEnterprises('u12') WHERE EnterpriseId=1) THROW 51001,'R01 unrelated enterprise allowed',1;
IF NOT EXISTS(SELECT 1 FROM dbo.f_Report_DataImportEnterprises('u13') WHERE EnterpriseId=3) THROW 51001,'Exact report creator relationship lost',1;
IF EXISTS(SELECT 1 FROM dbo.f_Report_DataImportEnterprises('u14')) THROW 51001,'Weak identity independently grants operational access',1;
IF (SELECT SUM(r.PerformInPeriod) FROM dbo.Report_DataImports r JOIN dbo.f_Report_IndustryEnterprises('u2') e ON e.EnterpriseId=r.EnterpriseId)<>45 THROW 51001,'R08 scoped total mismatch',1;
IF EXISTS(SELECT 1 FROM dbo.f_Chatbot_AuthorizedEnterprises(4,'1,2,3,4,6','5',1) WHERE EnterpriseId<>1) THROW 51001,'R05 allowProvince grants foreign enterprise',1;
IF EXISTS(SELECT 1 FROM dbo.f_Chatbot_AuthorizedEnterprises(1,'1','5',1)) THROW 51001,'R05 invalid role mapping accepted',1;
IF (SELECT COUNT(*) FROM dbo.f_Chatbot_AuthorizedEnterprises(1,'1,2,3,4,6','5',0))<>1 THROW 51001,'R05 assigned operation widened',1;
IF (SELECT COUNT(*) FROM dbo.f_Chatbot_AuthorizedEnterprises(1,'1,2,3,4,6','5',1))<>4 THROW 51001,'R05 full administrator narrowed',1;
DECLARE @Work TABLE(EnterpriseId int,EnterpriseName nvarchar(250),ForMonth datetime,TypeReport int,TypeReportName nvarchar(100),IsLate bit,CanDelete bit,CreatedBy nvarchar(250),CreatedDate datetime);
INSERT @Work EXEC dbo.p_Report_DataImports_GetForUserOnMonth_IndustryScope 'u1','20260901','u1';
IF (SELECT COUNT(*) FROM @Work)<>1 OR EXISTS(SELECT 1 FROM @Work WHERE EnterpriseId<>1) THROW 51001,'R02 admin worklist widened/duplicated',1;
DELETE FROM @Work;
INSERT @Work EXEC dbo.p_Report_DataImports_GetForUserOnMonth_Operational 'u12','20260901','u12';
IF (SELECT COUNT(*) FROM @Work)<>1 OR EXISTS(SELECT 1 FROM @Work WHERE EnterpriseId<>2) THROW 51001,'R02 operational worklist lost assigned enterprise',1;
DELETE FROM @Work;
INSERT @Work EXEC dbo.p_Report_DataImports_GetForUserOnMonth_IndustryScope 'u11','20260901','u11';
IF EXISTS(SELECT 1 FROM @Work) THROW 51001,'R02 unassigned admin personal worklist widened',1;
DECLARE @Options TABLE(TotalRow int,Value varchar(20),Text nvarchar(250));
INSERT @Options EXEC dbo.p_Report_Dashboard_FilterOptions_IndustryScope 'enterprise',NULL,NULL,1,50,'u10';
IF EXISTS(SELECT 1 FROM @Options WHERE Value IS NOT NULL OR TotalRow<>0) THROW 51001,'R03 empty scope widened',1;
DELETE FROM @Options;
INSERT @Options EXEC dbo.p_Report_Dashboard_FilterOptions_IndustryScope 'industry',NULL,NULL,1,50,'u3';
IF EXISTS(SELECT 1 FROM @Options WHERE Value IS NOT NULL AND Value<>'20') THROW 51001,'R03 unrelated industry disclosed',1;
BEGIN TRY EXEC dbo.p_Report_Dashboard_FilterOptions_IndustryScope 'year',NULL,NULL,1,50,'unknown'; THROW 51002,'R03 failed scope accepted',1; END TRY BEGIN CATCH IF ERROR_NUMBER()<>50112 THROW; END CATCH;
DECLARE @Search TABLE(EnterpriseId int,BusinessName nvarchar(250),TaxCode varchar(100),TypeBusiness varchar(50),TotalRow int);
INSERT @Search EXEC dbo.p_Report_Industry_Enterprises_SearchSelect2 NULL,NULL,0,1,'u2';
IF (SELECT COUNT(*) FROM @Search)<>1 OR EXISTS(SELECT 1 FROM @Search WHERE TotalRow<>2 OR EnterpriseId NOT IN(1,3)) THROW 51001,'R04 search pagination/approval mismatch',1;
DELETE FROM @Search;
INSERT @Search EXEC dbo.p_Report_DataImports_Enterprises_SearchSelect2 NULL,NULL,0,20,'u12';
IF (SELECT COUNT(*) FROM @Search)<>1 OR EXISTS(SELECT 1 FROM @Search WHERE EnterpriseId<>2) THROW 51001,'R04 operational picker unexpectedly industry-limited',1;
DELETE FROM @Search;
INSERT @Search EXEC dbo.p_Report_Industry_Enterprises_SearchSelect2 N'Three',NULL,0,20,'u2';
IF (SELECT COUNT(*) FROM @Search)<>1 OR EXISTS(SELECT 1 FROM @Search WHERE EnterpriseId<>3 OR TotalRow<>1) THROW 51001,'R04 keyword filtering mismatch',1;
DECLARE @Missing TABLE(OwnerEnterpriseName nvarchar(250),BusinessName nvarchar(250),TaxCode varchar(100),BusinessAddress nvarchar(250),StreetName nvarchar(250),WardName nvarchar(100),DistrictName nvarchar(100),ProvinceName nvarchar(100),TypeBusinessName nvarchar(100),LegalRepresentationName nvarchar(100),LegalRepresentationPhone varchar(100),LegalRepresentationEmail varchar(100),Phone varchar(100),Website varchar(100),Email varchar(100));
INSERT @Missing EXEC dbo.p_Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope '20260901','u1';
IF (SELECT COUNT(*) FROM @Missing)<>1 OR EXISTS(SELECT 1 FROM @Missing WHERE BusinessName<>N'Unapproved') THROW 51001,'R06 missing-report denominator/submission mismatch',1;
DECLARE @Metrics TABLE(RowNo bigint,TargetName nvarchar(100),Unit nvarchar(20),YearPlan decimal(18,2),PreviousYearMonth decimal(18,2),PreviousYearAccumulated decimal(18,2),PreviousMonth decimal(18,2),EstimatedCurrentMonth decimal(18,2),CurrentYearAccumulated decimal(18,2),RateAccumulatedVsPlan decimal(18,2),RateAccumulatedVsPreviousYear decimal(18,2),RateCurrentMonthVsPreviousYear decimal(18,2));
INSERT @Metrics EXEC dbo.p_Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope '20260901',NULL,'u2';
IF (SELECT SUM(EstimatedCurrentMonth) FROM @Metrics)<>45 THROW 51001,'R08 report aggregate does not reconcile to scoped raw data',1;
INSERT dbo.Report_UserBusinessIndustryPermissions VALUES(2,20),(2,10);
IF (SELECT COUNT(*) FROM dbo.f_Report_IndustryEnterprises('u2'))<>4 THROW 51001,'R07 multiple/duplicate industry grants duplicate enterprises',1;
DELETE FROM dbo.Report_UserBusinessIndustryPermissions WHERE UserId=6;
IF (SELECT COUNT(*) FROM dbo.f_Report_IndustryEnterprises('u6'))<>1 OR NOT EXISTS(SELECT 1 FROM dbo.f_Report_IndustryEnterprises('u6') WHERE EnterpriseId=2) THROW 51001,'R07 mixed-role zero-grants fallback changed',1;
DELETE FROM dbo.Sys_Permissions WHERE RoleId=6 AND FunctionId=2;
IF EXISTS(SELECT 1 FROM dbo.f_Report_DataImportEnterprises('u2')) THROW 51001,'R04 selector grants operational data without Import operation rights',1;
UPDATE dbo.Report_RoleMappings SET RoleId=999 WHERE RoleId=6;
IF EXISTS(SELECT 1 FROM dbo.f_Report_IndustryEnterprises('u1')) THROW 51001,'R07 invalid mapping broadened',1;
ROLLBACK TRANSACTION;
SELECT 'PASS' FixtureStatus,'Exact row sets, worklist, isolation, mapping, pagination and scoped total assertions passed; no fixture data retained' Detail;
"""
p=ROOT/'tests/sql_scope_audit/scope-fixtures.sql';p.write_text(setup);print(p)
