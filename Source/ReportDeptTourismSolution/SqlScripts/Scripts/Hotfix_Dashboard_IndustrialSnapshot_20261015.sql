USE [baocaosct.khanhhoa.gov.vn];
GO
-- Production hotfix: preserve the currently installed dashboard contract.
-- Verified against 1,334 active Report_DataImports rows on 2026-10-15.
-- All three report types matched an independent Level/unit calculation; deployed row population unchanged.
-- Four export enterprise/months contain Kg instead of USD and return NULL metrics + MetricConflict=1.
-- No application/bundle deployment required.
-- Review and run only in baocaosct.khanhhoa.gov.vn; this script alters one procedure.
ALTER PROCEDURE dbo.p_Report_Dashboard_IndustrialSnapshot
    @ForMonth date,
    @TypeReport int,
    @WardId int = NULL,
    @EconomicSectorId int = NULL,
    @IndustryId int = NULL,
    @EnterpriseId int = NULL
AS
BEGIN
    SET NOCOUNT ON;
    IF @TypeReport IS NULL OR @TypeReport NOT IN (1, 2, 3) THROW 50001, 'Unsupported report type', 1;

    DECLARE @Start date = DATEFROMPARTS(YEAR(@ForMonth) - 1, 1, 1);
    DECLARE @End date = DATEFROMPARTS(YEAR(@ForMonth) + 1, 1, 1);
    -- Level is stable across legacy/new Code values; Index changes with detail rows.
    -- Industrial revenue is level 1.1. Level 1 is total enterprise revenue.
    DECLARE @PrimaryLevel varchar(20) = CASE @TypeReport WHEN 1 THEN '1.1' WHEN 2 THEN '1' ELSE '0' END;
    DECLARE @SecondaryLevel varchar(20) = CASE @TypeReport WHEN 1 THEN '6' WHEN 2 THEN '2' ELSE '1' END;
    DECLARE @TertiaryLevel varchar(20) = CASE @TypeReport WHEN 1 THEN '7' WHEN 2 THEN '1.1' ELSE '2' END;

    ;WITH Months AS
    (
        SELECT @Start AS ForMonth
        UNION ALL
        SELECT DATEADD(month, 1, ForMonth) FROM Months
        WHERE DATEADD(month, 1, ForMonth) < @End
    ), Cohort AS
    (
        SELECT e.EnterpriseId, e.BusinessName, e.WardId,
               COALESCE(w.WardName, e.WardName) AS WardName,
               b.EconomicSectorId, s.Name AS EconomicSectorName, b.IndustryIds
        FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Enterprises AS e
        CROSS APPLY
        (
            SELECT TOP (1) candidate.EconomicSectorId, candidate.IndustryIds
            FROM [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_BusinessEnterprise AS candidate
            WHERE candidate.EnterpriseId = e.EnterpriseId
              AND NULLIF(LTRIM(RTRIM(candidate.IndustryIds)), '') IS NOT NULL
              AND (@EconomicSectorId IS NULL OR candidate.EconomicSectorId = @EconomicSectorId)
              AND (@IndustryId IS NULL OR ',' + REPLACE(candidate.IndustryIds, ' ', '') + ','
                  LIKE '%,' + CONVERT(varchar(11), @IndustryId) + ',%')
            ORDER BY candidate.IndustryIds, candidate.EconomicSectorId
        ) AS b
        LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_Wards AS w ON w.WardId = e.WardId
        LEFT JOIN [baocaosct.khanhhoa.gov.vn.cate].dbo.Cate_EconomicSector AS s
            ON s.EconomicSectorId = b.EconomicSectorId
        WHERE e.IsActive = 1 AND e.IsDeleted = 0
          AND ',' + REPLACE(ISNULL(e.TypeBusiness, ''), ' ', '') + ','
              LIKE '%,' + CONVERT(varchar(11), @TypeReport) + ',%'
          AND (@WardId IS NULL OR e.WardId = @WardId)
          AND (@EnterpriseId IS NULL OR e.EnterpriseId = @EnterpriseId)
    ), Imports AS
    (
        SELECT r.EnterpriseId,
               DATEFROMPARTS(YEAR(r.ForMonth), MONTH(r.ForMonth), 1) AS ForMonth,
               LTRIM(RTRIM(r.[Level])) AS IndicatorLevel, r.PerformInPeriod,
               LOWER(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(ISNULL(r.Unit, N''), N' ', N''), N'.', N''),
                   CHAR(13), N''), CHAR(10), N''), CHAR(9), N'')) AS NormalUnit
        FROM dbo.Report_DataImports AS r
        WHERE r.IsDeleted = 0 AND r.TypeReport = @TypeReport
          AND r.ForMonth >= @Start AND r.ForMonth < @End
    ), ImportPresence AS
    (
        SELECT EnterpriseId, ForMonth FROM Imports GROUP BY EnterpriseId, ForMonth
    ), MetricGroups AS
    (
        SELECT EnterpriseId, ForMonth, IndicatorLevel, COUNT(*) AS SourceRows,
               MAX(TRY_CONVERT(decimal(28, 4), PerformInPeriod)) AS SingleValue,
               MAX(CASE
                   WHEN @TypeReport = 1 AND IndicatorLevel = @PrimaryLevel AND NormalUnit = N'tỷđồng' THEN 0
                   WHEN @TypeReport = 1 AND IndicatorLevel <> @PrimaryLevel AND NormalUnit = N'1000usd' THEN 0
                   WHEN @TypeReport = 2 AND NormalUnit = N'triệuđồng' THEN 0
                   WHEN @TypeReport = 3 AND NormalUnit = N'usd' THEN 0
                   ELSE 1 END) AS InvalidUnit,
               MAX(CASE WHEN PerformInPeriod IS NOT NULL
                        AND TRY_CONVERT(decimal(28, 4), PerformInPeriod) IS NULL THEN 1 ELSE 0 END) AS InvalidNumber
        FROM Imports
        -- Only the three exact total levels participate; detail rows cannot cause conflicts.
        WHERE IndicatorLevel IN (@PrimaryLevel, @SecondaryLevel, @TertiaryLevel)
        GROUP BY EnterpriseId, ForMonth, IndicatorLevel
    ), MetricValues AS
    (
        SELECT EnterpriseId, ForMonth,
               MAX(CASE WHEN IndicatorLevel = @PrimaryLevel AND SourceRows = 1 AND InvalidUnit = 0 AND InvalidNumber = 0
                        THEN SingleValue END) AS PrimaryValue,
               MAX(CASE WHEN IndicatorLevel = @SecondaryLevel AND SourceRows = 1 AND InvalidUnit = 0 AND InvalidNumber = 0
                        THEN SingleValue END) AS SecondaryValue,
               MAX(CASE WHEN IndicatorLevel = @TertiaryLevel AND SourceRows = 1 AND InvalidUnit = 0 AND InvalidNumber = 0
                        THEN SingleValue END) AS TertiaryValue,
               CAST(MAX(CASE WHEN SourceRows > 1 OR InvalidUnit = 1 OR InvalidNumber = 1 THEN 1 ELSE 0 END) AS bit) AS MetricConflict
        FROM MetricGroups GROUP BY EnterpriseId, ForMonth
    ), Files AS
    (
        SELECT EnterpriseId, DATEFROMPARTS(YEAR(ForMonth), MONTH(ForMonth), 1) AS ForMonth
        FROM dbo.Report_ReportFiles
        WHERE IsDeleted = 0 AND ForMonth >= @Start AND ForMonth < @End
        GROUP BY EnterpriseId, DATEFROMPARTS(YEAR(ForMonth), MONTH(ForMonth), 1)
    )
    SELECT m.ForMonth, @TypeReport AS TypeReport, c.EnterpriseId, c.BusinessName,
           c.WardId, c.WardName, c.EconomicSectorId, c.EconomicSectorName, c.IndustryIds,
           CAST(CASE WHEN p.EnterpriseId IS NULL THEN 0 ELSE 1 END AS bit) AS DataImported,
           CAST(CASE WHEN f.EnterpriseId IS NULL THEN 0 ELSE 1 END AS bit) AS FileSubmittedAnyType,
           v.PrimaryValue, v.SecondaryValue, v.TertiaryValue,
           CAST(ISNULL(v.MetricConflict, 0) AS bit) AS MetricConflict
    FROM Cohort AS c CROSS JOIN Months AS m
    LEFT JOIN ImportPresence AS p ON p.EnterpriseId = c.EnterpriseId AND p.ForMonth = m.ForMonth
    LEFT JOIN MetricValues AS v ON v.EnterpriseId = c.EnterpriseId AND v.ForMonth = m.ForMonth
    LEFT JOIN Files AS f ON f.EnterpriseId = c.EnterpriseId AND f.ForMonth = m.ForMonth
    ORDER BY m.ForMonth, c.EnterpriseId
    OPTION (MAXRECURSION 24);
END
GO
