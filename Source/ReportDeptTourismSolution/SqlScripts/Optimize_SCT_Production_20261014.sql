/*
 Production query indexes -- inspected 14 October 2026 through negotiated TDS 7.0.
 SQL Server 2012 Enterprise, compatibility 110.
 Run this ENTIRE file in one SSMS/sqlcmd connection with access to both databases.
 No SQLCMD mode, application deploy, SP alteration, row update, unique constraint,
 existing index replacement, server setting change, or blanket plan-cache flush.

 DEFAULT: @Apply=1 creates up to 10 missing ordinary nonclustered indexes.
 PREVIEW: set @Apply=0; all metadata/coverage checks still run, no permanent DDL.
 OPTIONAL: @IncludeComputedMonthIndex=1 enables an eleventh index. Leave at 0 until
 ALL import/job/admin writers have the required SET options listed below and
 the real import path has been verified in staging. Existing inspected procedures
 have ANSI_NULLS/QUOTED_IDENTIFIER ON, but other clients were not verified.
 Merely running these SET statements here does NOT configure other connections.

 Run during low traffic: ONLINE=ON still needs short schema locks, CPU, log/disk
 space, and extra write maintenance. A 5-second lock timeout aborts a blocked build;
 SQL Server 2012 does not support WAIT_AT_LOW_PRIORITY or resumable index builds.
 Each CREATE commits separately. On failure, completed indexes remain; rerun safely.
 New index statistics are built automatically. No table-wide FULLSCAN/rebuild is run.
 Rollback SQL is RETURNED AS TEXT only for newly created indexes; save that result.

 Evidence: Cate_EnterprisePermissions 94,394 rows, Cate_Enterprises 18,893,
 Report_DataImports 1,048, Report_ReportFiles 124. Estimated representative SELECT
 plans showed heap scans for assignments, EnterpriseId, date and integer-month imports.
 VIEW SERVER STATE denied: no runtime CPU/read/duration ranking or speedup claim.
 DATEDIFF(month,...), wildcard search, CSV splitting, CASE normalization and repeated
 CTE work remain; these may need focused SP changes after measuring real requests.
 Broader review: all 293 installed stored procedures and 9 functions/views were
 inspected statically. Eight initial indexes are now present; representative plans
 use seeks for varchar assignment lookup, EnterpriseId, email and report date range.
 Two additional ordinary-index candidates (plan IDs 10/11) address the remaining
 document and code-first scans; their post-build behavior/speedup is NOT verified.
 Type-mismatch, CSV, wildcard and date-expression limitations are documented in
 Production_SP_IndexReview_20261014.md; more ordinary indexes cannot remove them.
 Use a login with visibility and ALTER rights on both databases. The ReportTourismDB
 login can inspect both; BaseApp cannot inspect report tables.
 No indexes were created or procedures/data modified by this inspection.

*/
SET NOCOUNT ON;
SET XACT_ABORT ON;
SET ANSI_NULLS ON;
SET ANSI_PADDING ON;
SET ANSI_WARNINGS ON;
SET ARITHABORT ON;
SET CONCAT_NULL_YIELDS_NULL ON;
SET QUOTED_IDENTIFIER ON;
SET NUMERIC_ROUNDABORT OFF;

DECLARE @Apply bit = 1;
DECLARE @IncludeComputedMonthIndex bit = 0;
IF @@TRANCOUNT <> 0
    THROW 51000, 'Run in a dedicated session outside an existing transaction.', 1;
IF DB_ID(N'baocaosct.khanhhoa.gov.vn.cate') IS NULL
 OR DB_ID(N'baocaosct.khanhhoa.gov.vn') IS NULL
    THROW 51001, 'Expected production databases are missing or not visible. Check the connection.', 1;
IF CONVERT(int, SERVERPROPERTY('EngineEdition')) <> 3
    THROW 51002, 'This script requires Enterprise/Developer/Evaluation online index support; review the target edition.', 1;

DECLARE @Plan TABLE
(
    PlanId int PRIMARY KEY, DatabaseName sysname, TableName sysname,
    IndexName sysname, KeySql nvarchar(1000), IncludeSql nvarchar(2000),
    OptionalComputed bit, ExistingIndex sysname NULL,
    Result varchar(20) NULL, CreateSql nvarchar(max) NULL, RollbackSql nvarchar(max) NULL
);
DECLARE @Columns TABLE
(
    PlanId int, ColumnName sysname, KeyOrdinal int,
    PRIMARY KEY(PlanId, ColumnName)
);
-- KeyOrdinal=0 denotes an INCLUDE column.

-- Exact user assignment lookup in GetViaUser, GetForUserOnMonth and chatbot scope.
INSERT @Plan(PlanId,DatabaseName,TableName,IndexName,KeySql,IncludeSql,OptionalComputed)
VALUES(1,N'baocaosct.khanhhoa.gov.vn.cate',N'Cate_EnterprisePermissions',N'IX_SCTProd_Assignments_UserEnterprise',N'[ForUser],[EnterpriseId]',N'',0);
INSERT @Columns VALUES
(1,N'ForUser',1),
(1,N'EnterpriseId',2);

-- Enterprise-side joins and legacy CASE/LEFT username checks. Normalized username remains a residual predicate.
INSERT @Plan(PlanId,DatabaseName,TableName,IndexName,KeySql,IncludeSql,OptionalComputed)
VALUES(2,N'baocaosct.khanhhoa.gov.vn.cate',N'Cate_EnterprisePermissions',N'IX_SCTProd_Assignments_EnterpriseUser',N'[EnterpriseId],[ForUser]',N'',0);
INSERT @Columns VALUES
(2,N'EnterpriseId',1),
(2,N'ForUser',2);

-- EnterpriseId lookups and covering dashboard/chatbot cohort joins. Nonunique: preserves legacy duplicates.
INSERT @Plan(PlanId,DatabaseName,TableName,IndexName,KeySql,IncludeSql,OptionalComputed)
VALUES(3,N'baocaosct.khanhhoa.gov.vn.cate',N'Cate_Enterprises',N'IX_SCTProd_Enterprises_Id',N'[EnterpriseId]',N'[BusinessName],[TaxCode],[TypeBusiness],[WardId],[IsActive],[IsDeleted],[IsApproved]',0);
INSERT @Columns VALUES
(3,N'EnterpriseId',1),
(3,N'BusinessName',0),
(3,N'TaxCode',0),
(3,N'TypeBusiness',0),
(3,N'WardId',0),
(3,N'IsActive',0),
(3,N'IsDeleted',0),
(3,N'IsApproved',0);

-- Email branch of existing UserName OR Email lookups. Existing username index is retained.
INSERT @Plan(PlanId,DatabaseName,TableName,IndexName,KeySql,IncludeSql,OptionalComputed)
VALUES(4,N'baocaosct.khanhhoa.gov.vn.cate',N'Sys_Users',N'IX_SCTProd_Users_Email',N'[Email]',N'[UserName],[FullName],[IsActive],[IsDeleted],[IsLocked]',0);
INSERT @Columns VALUES
(4,N'Email',1),
(4,N'UserName',0),
(4,N'FullName',0),
(4,N'IsActive',0),
(4,N'IsDeleted',0),
(4,N'IsLocked',0);

-- Role/function checks used by existing authorization procedures and chatbot scope.
INSERT @Plan(PlanId,DatabaseName,TableName,IndexName,KeySql,IncludeSql,OptionalComputed)
VALUES(5,N'baocaosct.khanhhoa.gov.vn.cate',N'Sys_Permissions',N'IX_SCTProd_Permissions_RoleFunction',N'[RoleId],[FunctionId]',N'[Action]',0);
INSERT @Columns VALUES
(5,N'RoleId',1),
(5,N'FunctionId',2),
(5,N'Action',0);

-- Enterprise-specific import reads/writes. DATEDIFF filters can seek EnterpriseId but remain residual on the month.
INSERT @Plan(PlanId,DatabaseName,TableName,IndexName,KeySql,IncludeSql,OptionalComputed)
VALUES(6,N'baocaosct.khanhhoa.gov.vn',N'Report_DataImports',N'IX_SCTProd_Imports_EnterprisePeriod',N'[EnterpriseId],[ForMonth],[TypeReport],[Code]',N'[IsDeleted],[IsLate],[CreatedDate],[LastModifiedDate]',0);
INSERT @Columns VALUES
(6,N'EnterpriseId',1),
(6,N'ForMonth',2),
(6,N'TypeReport',3),
(6,N'Code',4),
(6,N'IsDeleted',0),
(6,N'IsLate',0),
(6,N'CreatedDate',0),
(6,N'LastModifiedDate',0);

-- Dashboard and chatbot date-range aggregation, including existing ForMonth YTD queries.
INSERT @Plan(PlanId,DatabaseName,TableName,IndexName,KeySql,IncludeSql,OptionalComputed)
VALUES(7,N'baocaosct.khanhhoa.gov.vn',N'Report_DataImports',N'IX_SCTProd_Imports_Period',N'[ForMonth],[TypeReport],[EnterpriseId]',N'[Code],[Unit],[PerformInPeriod],[PerformPreviousPeriod],[AccumulatedBeginingOfYear],[ComparedSamePeriodLastYear],[IsDeleted],[IsLate],[CreatedDate],[LastModifiedDate]',0);
INSERT @Columns VALUES
(7,N'ForMonth',1),
(7,N'TypeReport',2),
(7,N'EnterpriseId',3),
(7,N'Code',0),
(7,N'Unit',0),
(7,N'PerformInPeriod',0),
(7,N'PerformPreviousPeriod',0),
(7,N'AccumulatedBeginingOfYear',0),
(7,N'ComparedSamePeriodLastYear',0),
(7,N'IsDeleted',0),
(7,N'IsLate',0),
(7,N'CreatedDate',0),
(7,N'LastModifiedDate',0);

-- Month-first file presence scans. Existing EnterpriseId/ForMonth clustered primary key is retained.
INSERT @Plan(PlanId,DatabaseName,TableName,IndexName,KeySql,IncludeSql,OptionalComputed)
VALUES(8,N'baocaosct.khanhhoa.gov.vn',N'Report_ReportFiles',N'IX_SCTProd_Files_Period',N'[ForMonth],[EnterpriseId]',N'[IsDeleted],[IsLate],[CreatedDate],[LastModifiedDate]',0);
INSERT @Columns VALUES
(8,N'ForMonth',1),
(8,N'EnterpriseId',2),
(8,N'IsDeleted',0),
(8,N'IsLate',0),
(8,N'CreatedDate',0),
(8,N'LastModifiedDate',0);

-- OPTIONAL: manufacturing/trading/KTXH integer-month aggregation. Requires verified writer SET options.
INSERT @Plan(PlanId,DatabaseName,TableName,IndexName,KeySql,IncludeSql,OptionalComputed)
VALUES(9,N'baocaosct.khanhhoa.gov.vn',N'Report_DataImports',N'IX_SCTProd_Imports_TypeMonthInt',N'[TypeReport],[ForMonthInt],[Code],[EnterpriseId]',N'[ForMonth],[IsDeleted],[Index],[Level],[Targets],[Unit],[PerformInPeriod],[PerformPreviousPeriod],[AccumulatedBeginingOfYear],[ComparedSamePeriodLastYear]',1);
INSERT @Columns VALUES
(9,N'TypeReport',1),
(9,N'ForMonthInt',2),
(9,N'Code',3),
(9,N'EnterpriseId',4),
(9,N'ForMonth',0),
(9,N'IsDeleted',0),
(9,N'Index',0),
(9,N'Level',0),
(9,N'Targets',0),
(9,N'Unit',0),
(9,N'PerformInPeriod',0),
(9,N'PerformPreviousPeriod',0),
(9,N'AccumulatedBeginingOfYear',0),
(9,N'ComparedSamePeriodLastYear',0);

-- Additional candidate: correlated enterprise attachment XML reads. Existing FileId clustered key is implicitly covered; no constraints or rows change.
INSERT @Plan(PlanId,DatabaseName,TableName,IndexName,KeySql,IncludeSql,OptionalComputed)
VALUES(10,N'baocaosct.khanhhoa.gov.vn.cate',N'Cate_Docs',N'IX_SCTProd_Docs_Object',N'[ObjectId],[TypeObject],[IsDeleted]',N'[FileName],[FileExt]',0);
INSERT @Columns VALUES
(10,N'ObjectId',1),
(10,N'TypeObject',2),
(10,N'IsDeleted',3),
(10,N'FileName',0),
(10,N'FileExt',0);

-- Additional candidate: code-first legacy tourism/revenue self-joins and aggregation. Month expressions remain residual filters; benefit is unmeasured at current 1,048 rows.
INSERT @Plan(PlanId,DatabaseName,TableName,IndexName,KeySql,IncludeSql,OptionalComputed)
VALUES(11,N'baocaosct.khanhhoa.gov.vn',N'Report_DataImports',N'IX_SCTProd_Imports_Code',N'[Code],[IsDeleted],[ForMonth]',N'[EnterpriseId],[TypeReport],[Unit],[Targets],[PerformPreviousPeriod],[PerformInPeriod],[AccumulatedBeginingOfYear],[ComparedSamePeriodLastYear]',0);
INSERT @Columns VALUES
(11,N'Code',1),
(11,N'IsDeleted',2),
(11,N'ForMonth',3),
(11,N'EnterpriseId',0),
(11,N'TypeReport',0),
(11,N'Unit',0),
(11,N'Targets',0),
(11,N'PerformPreviousPeriod',0),
(11,N'PerformInPeriod',0),
(11,N'AccumulatedBeginingOfYear',0),
(11,N'ComparedSamePeriodLastYear',0);

DELETE c FROM @Columns c JOIN @Plan p ON p.PlanId=c.PlanId
WHERE p.OptionalComputed=1 AND @IncludeComputedMonthIndex=0;
DELETE FROM @Plan WHERE OptionalComputed=1 AND @IncludeComputedMonthIndex=0;

DECLARE @Id int, @Db sysname, @Table sysname, @Index sysname;
DECLARE @Keys nvarchar(1000), @Includes nvarchar(2000), @Optional bit;
DECLARE @Sql nvarchar(max), @Ddl nvarchar(max), @Wanted xml, @Equivalent sysname;
DECLARE @Message nvarchar(2048);
DECLARE Preflight CURSOR LOCAL FAST_FORWARD FOR
    SELECT PlanId,DatabaseName,TableName,IndexName,KeySql,IncludeSql,OptionalComputed
    FROM @Plan ORDER BY PlanId;
BEGIN TRY
    OPEN Preflight;
    FETCH NEXT FROM Preflight INTO @Id,@Db,@Table,@Index,@Keys,@Includes,@Optional;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SELECT @Wanted=(SELECT ColumnName AS [@name],KeyOrdinal AS [@ordinal]
                        FROM @Columns WHERE PlanId=@Id FOR XML PATH('c'),ROOT('columns'),TYPE);
        SET @Equivalent=NULL;
        SET @Sql=N'USE '+QUOTENAME(@Db)+N';
DECLARE @ObjectId int=OBJECT_ID(N''dbo.''+QUOTENAME(@Table),N''U'');
IF @ObjectId IS NULL OR NOT EXISTS
    (SELECT 1 FROM fn_my_permissions(NULL,N''DATABASE'') WHERE permission_name=N''VIEW DEFINITION'')
    THROW 51003, ''Required table/metadata is not accessible.'', 1;
IF @Apply=1 AND ISNULL(HAS_PERMS_BY_NAME(N''dbo.''+QUOTENAME(@Table),N''OBJECT'',N''ALTER''),0)<>1
    THROW 51004, ''ALTER permission on an indexed table is required.'', 1;
IF EXISTS(SELECT 1 FROM @Wanted.nodes(''/columns/c'') w(c)
          WHERE NOT EXISTS(SELECT 1 FROM sys.columns sc WHERE sc.object_id=@ObjectId
                           AND sc.name=w.c.value(''@name'',''nvarchar(128)'')))
    THROW 51005, ''An expected index column is missing. Review schema drift.'', 1;
IF @Optional=1
BEGIN
    IF COLUMNPROPERTY(@ObjectId,N''ForMonthInt'',''IsComputed'')<>1
       OR COLUMNPROPERTY(@ObjectId,N''ForMonthInt'',''IsDeterministic'')<>1
       OR COLUMNPROPERTY(@ObjectId,N''ForMonthInt'',''IsPrecise'')<>1
        THROW 51006, ''ForMonthInt must be an existing deterministic precise computed column.'', 1;
    IF EXISTS(SELECT 1 FROM sys.sql_modules m WHERE m.definition LIKE N''%Report_DataImports%''
              AND (m.uses_ansi_nulls=0 OR m.uses_quoted_identifier=0))
        THROW 51007, ''A referencing SQL module has incompatible saved SET options. Leave computed indexing disabled.'', 1;
END;
-- Match ordered ASC key prefix plus coverage. Clustered keys are implicitly
-- present in nonclustered indexes. Wider matching indexes can be reused.
SELECT TOP(1) @Equivalent=i.name
FROM sys.indexes i
WHERE i.object_id=@ObjectId AND i.type IN(1,2)
  AND i.is_disabled=0 AND i.is_hypothetical=0 AND i.has_filter=0
  AND NOT EXISTS
  (
      SELECT 1 FROM @Wanted.nodes(''/columns/c'') w(c)
      WHERE w.c.value(''@ordinal'',''int'')>0
        AND NOT EXISTS
        (
            SELECT 1 FROM sys.index_columns ic
            JOIN sys.columns sc ON sc.object_id=ic.object_id AND sc.column_id=ic.column_id
            WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id
              AND ic.key_ordinal=w.c.value(''@ordinal'',''int'')
              AND ic.is_descending_key=0 AND sc.name=w.c.value(''@name'',''nvarchar(128)'')
        )
  )
  AND NOT EXISTS
  (
      SELECT 1 FROM @Wanted.nodes(''/columns/c'') w(c)
      WHERE w.c.value(''@ordinal'',''int'')=0 AND i.type<>1
        AND NOT EXISTS
        (
            SELECT 1 FROM sys.index_columns ic
            JOIN sys.columns sc ON sc.object_id=ic.object_id AND sc.column_id=ic.column_id
            WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id
              AND sc.name=w.c.value(''@name'',''nvarchar(128)'')
        )
        AND NOT EXISTS
        (
            SELECT 1 FROM sys.indexes ci
            JOIN sys.index_columns ic ON ic.object_id=ci.object_id AND ic.index_id=ci.index_id
            JOIN sys.columns sc ON sc.object_id=ic.object_id AND sc.column_id=ic.column_id
            WHERE ci.object_id=i.object_id AND ci.type=1 AND ci.is_disabled=0
              AND ic.key_ordinal>0 AND sc.name=w.c.value(''@name'',''nvarchar(128)'')
        )
  )
ORDER BY CASE WHEN i.name=@Index THEN 0 ELSE 1 END, i.index_id;
IF EXISTS(SELECT 1 FROM sys.indexes WHERE object_id=@ObjectId AND name=@Index)
   AND (@Equivalent IS NULL OR @Equivalent<>@Index)
    THROW 51008, ''A planned index name already exists with incompatible coverage/state. No replacement is automatic.'', 1;';
        EXEC sys.sp_executesql @Sql,
            N'@Table sysname,@Index sysname,@Wanted xml,@Optional bit,@Apply bit,@Equivalent sysname OUTPUT',
            @Table,@Index,@Wanted,@Optional,@Apply,@Equivalent OUTPUT;
        SET @Ddl=N'USE '+QUOTENAME(@Db)+N'; SET LOCK_TIMEOUT 5000; CREATE NONCLUSTERED INDEX '+QUOTENAME(@Index)
                +N' ON dbo.'+QUOTENAME(@Table)+N' ('+@Keys+N')'
                +CASE WHEN @Includes=N'' THEN N'' ELSE N' INCLUDE ('+@Includes+N')' END
                +N' WITH (ONLINE=ON, MAXDOP=2);';
        UPDATE @Plan SET ExistingIndex=@Equivalent,CreateSql=@Ddl,
            Result=CASE WHEN @Equivalent IS NULL THEN 'PLANNED' ELSE 'REUSED' END
        WHERE PlanId=@Id;
        FETCH NEXT FROM Preflight INTO @Id,@Db,@Table,@Index,@Keys,@Includes,@Optional;
    END;
    CLOSE Preflight;
    DEALLOCATE Preflight;

    -- All plans pass preflight before the first permanent database change.
    SELECT PlanId,DatabaseName,TableName,IndexName,ExistingIndex,Result,CreateSql
    FROM @Plan ORDER BY PlanId;
    IF @Apply=1
    BEGIN
        DECLARE BuildIndexes CURSOR LOCAL FAST_FORWARD FOR
            SELECT PlanId,DatabaseName,TableName,IndexName,CreateSql
            FROM @Plan WHERE Result='PLANNED' ORDER BY PlanId;
        OPEN BuildIndexes;
        FETCH NEXT FROM BuildIndexes INTO @Id,@Db,@Table,@Index,@Ddl;
        WHILE @@FETCH_STATUS=0
        BEGIN
            SET @Message=N'Creating '+QUOTENAME(@Db)+N'.dbo.'+QUOTENAME(@Index);
            RAISERROR(N'%s',10,1,@Message) WITH NOWAIT;
            EXEC sys.sp_executesql @Ddl;
            UPDATE @Plan SET Result='CREATED',
                RollbackSql=N'USE '+QUOTENAME(@Db)+N'; DROP INDEX '+QUOTENAME(@Index)
                            +N' ON dbo.'+QUOTENAME(@Table)+N';'
            WHERE PlanId=@Id;
            FETCH NEXT FROM BuildIndexes INTO @Id,@Db,@Table,@Index,@Ddl;
        END;
        CLOSE BuildIndexes;
        DEALLOCATE BuildIndexes;
    END;
    SELECT PlanId,DatabaseName,TableName,IndexName,ExistingIndex,Result,RollbackSql
    FROM @Plan ORDER BY PlanId;
    PRINT 'Finished. Compare real request timing/IO and check import/save behavior. No SP bodies were changed.';
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local','Preflight')>=0 CLOSE Preflight;
    IF CURSOR_STATUS('local','Preflight')>-3 DEALLOCATE Preflight;
    IF CURSOR_STATUS('local','BuildIndexes')>=0 CLOSE BuildIndexes;
    IF CURSOR_STATUS('local','BuildIndexes')>-3 DEALLOCATE BuildIndexes;
    SELECT PlanId,DatabaseName,TableName,IndexName,ExistingIndex,Result,RollbackSql
    FROM @Plan ORDER BY PlanId;
    THROW;
END CATCH;
