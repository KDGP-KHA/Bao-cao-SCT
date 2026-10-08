-- Operational authorization, separate from Dashboard/Chatbot industry visibility.
-- Preserves the original Get administrator roles (configured semantic keys for 1/6),
-- explicit assignments, and exact server-maintained report CreatedBy when no assignments exist.
-- Email/display-name/tax-code similarity is not ownership. No base writes are altered.
USE [baocaosct.khanhhoa.gov.vn];
GO
IF OBJECT_ID('dbo.f_Report_DataImportEnterprises') IS NULL EXEC('CREATE FUNCTION dbo.f_Report_DataImportEnterprises(@UserName varchar(255)) RETURNS TABLE AS RETURN SELECT 1 Placeholder');
GO
ALTER FUNCTION dbo.f_Report_DataImportEnterprises(@UserName varchar(255)) RETURNS TABLE AS RETURN (
 SELECT e.*,CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_UserRoles ur
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m ON m.RoleId=ur.RoleId
 WHERE ur.UserId=u.UserId AND m.SemanticKey IN('SystemAdministrator','IndustryAdministrator')) OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions p WHERE p.ForUser=u.UserName AND p.EnterpriseId=e.EnterpriseId) THEN 1 ELSE 0 END) CanManageAllRecords
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises e
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users u ON u.UserName=@UserName
 WHERE u.IsActive=1 AND u.IsDeleted=0 AND ISNULL(u.IsLocked,0)=0
 AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_UserRoles rightsRole
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Roles liveRole ON liveRole.RoleId=rightsRole.RoleId AND liveRole.IsDeleted=0
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Permissions rightsPermission ON rightsPermission.RoleId=rightsRole.RoleId
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Functions rightsFunction ON rightsFunction.FunctionId=rightsPermission.FunctionId AND rightsFunction.IsDeleted=0
 WHERE rightsRole.UserId=u.UserId AND rightsFunction.Area='Report' AND rightsFunction.Name='Import'
 AND rightsPermission.Action IN('View','Add','Edit','Delete'))
 AND NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m
  LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Roles r ON r.RoleId=m.RoleId WHERE r.RoleId IS NULL OR r.IsDeleted<>0)
 AND EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings WHERE SemanticKey='SystemAdministrator')
 AND (
 EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_UserRoles ur
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Roles role ON role.RoleId=ur.RoleId AND role.IsDeleted=0
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m ON m.RoleId=ur.RoleId
 WHERE ur.UserId=u.UserId AND m.SemanticKey IN('SystemAdministrator','IndustryAdministrator'))
 OR EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions p WHERE p.ForUser=u.UserName AND p.EnterpriseId=e.EnterpriseId)
 OR (NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EnterprisePermissions p WHERE p.ForUser=u.UserName)
 AND EXISTS(SELECT 1 FROM dbo.Report_DataImports r WHERE r.EnterpriseId=e.EnterpriseId AND r.CreatedBy=u.UserName AND r.IsDeleted=0))
 ));
GO
IF OBJECT_ID('dbo.p_Report_DataImports_OperationalScope') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_DataImports_OperationalScope AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_DataImports_OperationalScope @ForUser varchar(255)
AS BEGIN
 SET NOCOUNT ON;
 SELECT e.EnterpriseId,e.BusinessName,e.TaxCode,e.TypeBusiness,
 CONVERT(bit,CASE WHEN EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users u
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_UserRoles ur ON ur.UserId=u.UserId
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m ON m.RoleId=ur.RoleId
 WHERE u.UserName=@ForUser AND m.ScopeMode='enterprise')
 AND NOT EXISTS(SELECT 1 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_Users u
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Sys_UserRoles ur ON ur.UserId=u.UserId
 JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m ON m.RoleId=ur.RoleId
 WHERE u.UserName=@ForUser AND m.ScopeMode IN('all','industry')) THEN 1 ELSE 0 END) IsEnterpriseUser,
 STUFF((SELECT '|' + m.SemanticKey + ':' + CONVERT(varchar(11),m.RoleId) + ':' + m.ScopeMode + ':' + CONVERT(varchar(1),m.IsIndustryEditorTarget)
 FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Report_RoleMappings m ORDER BY m.RoleId FOR XML PATH(''),TYPE).value('.','varchar(max)'),1,1,'') RoleMappingSignature,e.CanManageAllRecords
 FROM dbo.f_Report_DataImportEnterprises(@ForUser) e;
END;
GO
IF OBJECT_ID('dbo.p_Report_DataImports_Get_Operational') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_DataImports_Get_Operational AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_DataImports_Get_Operational
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
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY,CanManageAllRecords bit NOT NULL);
 INSERT #ReportScope SELECT EnterpriseId,CanManageAllRecords FROM dbo.f_Report_DataImportEnterprises(@IndustryUserName);

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
	    FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId WHERE scope.CanManageAllRecords=1 OR data.CreatedBy=@IndustryUserName)  AS rdi
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
IF OBJECT_ID('dbo.p_Report_DataImports_GetDataImport_Operational') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_DataImports_GetDataImport_Operational AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_DataImports_GetDataImport_Operational

	@EnterpriseId INT,
	@ForMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY,CanManageAllRecords bit NOT NULL);
 INSERT #ReportScope SELECT EnterpriseId,CanManageAllRecords FROM dbo.f_Report_DataImportEnterprises(@IndustryUserName);




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
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId WHERE scope.CanManageAllRecords=1 OR data.CreatedBy=@IndustryUserName)  AS rdi
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
IF OBJECT_ID('dbo.p_Report_DataImports_GetViaEnterpriseOnMonth_Operational') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_DataImports_GetViaEnterpriseOnMonth_Operational AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_DataImports_GetViaEnterpriseOnMonth_Operational

	@EnterpriseId INT,
	@ForMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN


	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY,CanManageAllRecords bit NOT NULL);
 INSERT #ReportScope SELECT EnterpriseId,CanManageAllRecords FROM dbo.f_Report_DataImportEnterprises(@IndustryUserName);





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
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId WHERE scope.CanManageAllRecords=1 OR data.CreatedBy=@IndustryUserName)  AS rdi
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
IF OBJECT_ID('dbo.p_Report_DataImports_GetForUserOnMonth_Operational') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_DataImports_GetForUserOnMonth_Operational AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_DataImports_GetForUserOnMonth_Operational
	@ForUser VARCHAR(500),
	@OnMonth DATETIME,
 @IndustryUserName varchar(255)

AS
BEGIN
	SET NOCOUNT ON;
 CREATE TABLE #ReportScope(EnterpriseId int NOT NULL PRIMARY KEY,CanManageAllRecords bit NOT NULL);
 INSERT #ReportScope SELECT EnterpriseId,CanManageAllRecords FROM dbo.f_Report_DataImportEnterprises(@IndustryUserName);

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
	FROM (SELECT data.* FROM dbo.Report_DataImports data JOIN #ReportScope scope ON scope.EnterpriseId=data.EnterpriseId WHERE scope.CanManageAllRecords=1 OR data.CreatedBy=@IndustryUserName)  AS rdi
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
IF OBJECT_ID('dbo.p_Report_DataImports_Enterprises_SearchSelect2') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_DataImports_Enterprises_SearchSelect2 AS RETURN 0');
GO
ALTER PROCEDURE dbo.p_Report_DataImports_Enterprises_SearchSelect2
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
  FROM dbo.f_Report_DataImportEnterprises(@IndustryUserName) ce
  WHERE ce.IsApproved=1
   AND (@TypeBusiness IS NULL OR ','+REPLACE(ISNULL(ce.TypeBusiness,''),' ','')+',' LIKE '%,'+@TypeBusiness+',%')
   AND (@Keyword IS NULL OR ce.BusinessName LIKE N'%'+@Keyword+N'%' OR ce.TaxCode LIKE N'%'+@Keyword+N'%')
 )
 SELECT EnterpriseId,BusinessName,TaxCode,TypeBusiness,TotalRow FROM Paged
 WHERE RowNum>CONVERT(bigint,@PageIndex)*@PageSize AND RowNum<=(CONVERT(bigint,@PageIndex)+1)*@PageSize
 ORDER BY RowNum;
END
GO

IF OBJECT_ID('dbo.p_Report_DataImports_CheckOwnership') IS NULL EXEC('CREATE PROCEDURE dbo.p_Report_DataImports_CheckOwnership AS RETURN 0');
GO
-- Read-only validation of the base write set; original write/audit/transaction contracts stay unchanged.
ALTER PROCEDURE dbo.p_Report_DataImports_CheckOwnership
 @EnterpriseId int,@ForMonth datetime,@TypeReport int,@Operation varchar(10),@UserName varchar(255)
AS BEGIN
 SET NOCOUNT ON;
 IF @Operation NOT IN('Import','Delete') THROW 50112,'Invalid operational write kind',1;
 DECLARE @Manage bit;
 SELECT @Manage=CanManageAllRecords FROM dbo.f_Report_DataImportEnterprises(@UserName) WHERE EnterpriseId=@EnterpriseId;
 SELECT CONVERT(bit,CASE WHEN @Manage=1 THEN 1
 WHEN @Manage=0 AND @ForMonth IS NOT NULL
 AND EXISTS(SELECT 1 FROM dbo.Report_DataImports r WHERE r.EnterpriseId=@EnterpriseId
  AND r.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND r.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0)
  AND (@Operation='Delete' OR @TypeReport IS NULL OR @TypeReport=0 OR r.TypeReport=@TypeReport))
 AND NOT EXISTS(SELECT 1 FROM dbo.Report_DataImports r WHERE r.EnterpriseId=@EnterpriseId
  AND r.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND r.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0)
  AND (@Operation='Delete' OR @TypeReport IS NULL OR @TypeReport=0 OR r.TypeReport=@TypeReport)
  AND (r.CreatedBy IS NULL OR r.CreatedBy<>@UserName))
 AND (@Operation='Delete' OR NOT EXISTS(SELECT 1 FROM dbo.Report_ReportFiles f WHERE f.EnterpriseId=@EnterpriseId
  AND f.ForMonth>=DATEADD(month,DATEDIFF(month,0,@ForMonth),0) AND f.ForMonth<DATEADD(month,DATEDIFF(month,0,@ForMonth)+1,0)
  AND (f.CreatedBy IS NULL OR f.CreatedBy<>@UserName)))
 THEN 1 ELSE 0 END) CanWrite;
END;
GO
