using System;
using System.Globalization;
using System.Collections.Generic;
using TSFramework.App.Processors;

namespace CenIT.ReportTourism.Models.Report
{
    public static class DashboardText
    {
        public static string Get(string key)
        {
            return AppProcessor.Messagor.GetMessage("Dashboard_" + key);
        }
    }

    public static class DashboardNumber
    {
        public static readonly CultureInfo Culture = CultureInfo.GetCultureInfo("vi-VN");
        public static string Amount(decimal? value)
        {
            if (!value.HasValue) return "—";
            if (value.Value != 0 && Math.Abs(value.Value) < 0.01m) return value.Value < 0 ? ">−0,01" : "<0,01";
            return value.Value.ToString("#,##0.##", Culture);
        }
        public static string Count(int value) { return value.ToString("N0", Culture); }
        public static string Percent(decimal? value) { return value.HasValue ? value.Value.ToString("0.0", Culture) + "%" : "—"; }
        public static string Signed(decimal? value)
        {
            if (!value.HasValue) return "—";
            return (value.Value > 0 ? "+" : "") + Amount(value);
        }
        public static string SignedPercent(decimal? value)
        {
            return value.HasValue ? (value.Value > 0 ? "+" : "") + Percent(value) : "—";
        }
    }

    public class DashboardFilters
    {
        public int Year { get; set; }
        public int Month { get; set; }
        public int ReportType { get; set; }
        public string AreaId { get; set; }
        public string EconomicSectorId { get; set; }
        public string IndustryId { get; set; }
        public string EnterpriseId { get; set; }
        public string Metric { get; set; }
        public string Status { get; set; }
        public int Page { get; set; } = 1;
        public string Breakdown { get; set; } = "sector";
    }

    public class DashboardOption
    {
        public int TotalRow { get; set; }
        public string Value { get; set; }
        public string Text { get; set; }
    }

    public class DashboardFilterOptions
    {
        public DashboardFilters Filters { get; set; }
        public string Action { get; set; }
        public IList<DashboardOption> Years { get; set; }
        public IList<DashboardOption> Months { get; set; }
        public IList<DashboardOption> Areas { get; set; }
        public IList<DashboardOption> EconomicSectors { get; set; }
        public IList<DashboardOption> Industries { get; set; }
        public IList<DashboardOption> Enterprises { get; set; }
        public IList<DashboardOption> Metrics { get; set; }
    }

    public class DashboardNavigationModel
    {
        public string Active { get; set; }
        public DashboardFilters Filters { get; set; }
    }

    public class DashboardMetric
    {
        public string Key { get; set; }
        public string Label { get; set; }
        public string Unit { get; set; }
        public string Code { get; set; }
    }

    public class DashboardTypeCard
    {
        public int ReportType { get; set; }
        public string Name { get; set; }
        public string MetricLabel { get; set; }
        public string Unit { get; set; }
        public string Value { get; set; }
        public decimal? Mom { get; set; }
        public decimal? Yoy { get; set; }
        public int MetricCoverage { get; set; }
        public int Declines { get; set; }
        public int Compared { get; set; }
        public int Incomplete { get; set; }
        public int Assigned { get; set; }
        public int Received { get; set; }
        public int Conflicts { get; set; }
    }

    public class DashboardOverviewSummary
    {
        public int ActiveEnterprises { get; set; }
        public int ConfiguredEnterprises { get; set; }
        public int MissingBusinessRow { get; set; }
        public int MissingIndustry { get; set; }
        public int MissingReportType { get; set; }
        public int TypeZeroRows { get; set; }
        public int FutureDatedRows { get; set; }
        public int Type1Expected { get; set; }
        public int Type2Expected { get; set; }
        public int Type3Expected { get; set; }
        public int OutsideCohortEnterprises { get; set; }
        public int Expected(int type) { return type == 2 ? Type2Expected : type == 3 ? Type3Expected : Type1Expected; }
        public int NeedsClassification { get { return ActiveEnterprises - ConfiguredEnterprises; } }
    }

    public class DashboardReceiptPoint
    {
        public string Month { get; set; }
        public int Type1 { get; set; }
        public int Type2 { get; set; }
        public int Type3 { get; set; }
        public decimal Type1Rate { get; set; }
        public decimal Type2Rate { get; set; }
        public decimal Type3Rate { get; set; }
    }

    public class DashboardMetricPoint
    {
        public string Month { get; set; }
        public decimal? Value { get; set; }
        public int Coverage { get; set; }
        public int Expected { get; set; }
        public decimal? Rate { get; set; }
        public int Files { get; set; }
    }

    public class DashboardBreakdown
    {
        public IList<DashboardBreakdown> Members { get; set; }
        public string Name { get; set; }
        public string Key { get; set; }
        public int Assigned { get; set; }
        public int Received { get; set; }
        public decimal? Value { get; set; }
        public decimal Share { get; set; }
    }

    public class DashboardMovement
    {
        public int EnterpriseId { get; set; }
        public string Reason { get; set; }
        public string Name { get; set; }
        public string WardName { get; set; }
        public decimal PreviousValue { get; set; }
        public decimal CurrentValue { get; set; }
        public decimal Change { get; set; }
        public decimal? Percent { get; set; }
    }

    public class DashboardEnterpriseRow
    {
        public int EnterpriseId { get; set; }
        public string Name { get; set; }
        public string WardName { get; set; }
        public string TaxCode { get; set; }
        public bool FileLate { get; set; }
        public string Reason { get; set; }
        public bool DataImported { get; set; }
        public bool FileAnyType { get; set; }
        public bool MetricConflict { get; set; }
        public string MissingMetricCodes { get; set; }
    }

    public class DashboardModel
    {
        public DashboardFilters Filters { get; set; }
        public DashboardFilterOptions FilterOptions { get; set; }
        public IList<DashboardTypeCard> TypeCards { get; set; }
        public DashboardOverviewSummary Classification { get; set; }
        public IList<DashboardReceiptPoint> ReceiptTrend { get; set; }
        public IList<DashboardMovement> Movements { get; set; }
    }

    public class DashboardAnalysisModel
    {
        public DashboardFilters Filters { get; set; }
        public DashboardFilterOptions FilterOptions { get; set; }
        public string TypeName { get; set; }
        public DashboardMetric SelectedMetric { get; set; }
        public IList<DashboardMetric> Metrics { get; set; }
        public string CurrentValue { get; set; }
        public string YtdValue { get; set; }
        public int YtdMonths { get; set; }
        public decimal? Mom { get; set; }
        public decimal? Yoy { get; set; }
        public int MomCompared { get; set; }
        public int YoyCompared { get; set; }
        public int Assigned { get; set; }
        public int MetricCoverage { get; set; }
        public int Orphans { get; set; }
        public IList<DashboardMetricPoint> Trend { get; set; }
        public IList<DashboardBreakdown> Sectors { get; set; }
        public IList<DashboardMovement> Movements { get; set; }
    }

    public class DashboardWarningsModel
    {
        public const int PageSize = 8;
        public DashboardFilters Filters { get; set; }
        public DashboardFilterOptions FilterOptions { get; set; }
        public string TypeName { get; set; }
        public DashboardMetric Metric { get; set; }
        public int ComparableCount { get; set; }
        public int Assigned { get; set; }
        public int DeclineOver10 { get; set; }
        public int DeclineOver20 { get; set; }
        public int DeclineOver30 { get; set; }
        public int ConflictCount { get; set; }
        public int Incomplete { get; set; }
        public int Orphans { get; set; }
        public IList<DashboardEnterpriseRow> Issues { get; set; }
        public IList<DashboardMetricPoint> Trend { get; set; }
        public IList<DashboardMovement> Movements { get; set; }
    }

    public class DashboardProgressModel
    {
        public DashboardFilters Filters { get; set; }
        public DashboardFilterOptions FilterOptions { get; set; }
        public string TypeName { get; set; }
        public int Assigned { get; set; }
        public int Received { get; set; }
        public int Complete { get; set; }
        public int Incomplete { get; set; }
        public int FileLate { get; set; }
        public int TotalRows { get; set; }
        public int Orphans { get; set; }
        public int PageSize { get; set; } = 50;
        public int FileAnyType { get; set; }
        public IList<DashboardBreakdown> MetricPresence { get; set; }
        public int Conflicts { get; set; }
        public decimal CoveragePercent { get; set; }
        public IList<DashboardMetricPoint> ReceiptTrend { get; set; }
        public IList<DashboardBreakdown> Areas { get; set; }
        public IList<DashboardBreakdown> Sectors { get; set; }
        public IList<DashboardEnterpriseRow> Enterprises { get; set; }
    }
}
