using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Linq;
using CenIT.ReportTourism.Biz.Report;
using CenIT.ReportTourism.Caches.Cate;
using CenIT.ReportTourism.Models.Report;
using Newtonsoft.Json.Linq;

namespace CenIT.ReportTourism.WebApp.Chatbot
{
    // Reuses the dashboard snapshot contract. This service does not accept procedure names or SQL from callers.
    internal sealed class ChatbotAnalytics
    {
        private readonly ChatbotAccess _access;
        internal ChatbotAnalytics(ChatbotAccess access) { _access = access; }

        private const string SnapshotProcedure = "Report_Dashboard_IndustrialSnapshot";

        internal static bool Contains(string name) => name == "get_indicator_comparison" ||
            name == "analyze_growth_drivers" || name == "get_indicator_alerts" || name == "get_reporting_data_quality";

        internal static int ReportType(JObject input)
        {
            var metric = (string)input["metric"];
            return new[] { "export_fob", "direct_export_value", "entrusted_export_value" }.Contains(metric) ? 3
                : new[] { "wholesale_retail_revenue", "retail_revenue", "repair_revenue" }.Contains(metric) ? 2 : 1;
        }

        internal object Execute(string name, DashboardFilters filters, JObject input)
        {
            var metric = Metric.For((string)input["metric"] ?? "industrial_revenue");
            if (metric == null) return new
            {
                supported = false, metric = "industrial_production_value", reason = "missing_verified_indicator_source",
                message = "Chưa có mã/đơn vị GTSXCN được xác nhận trong SP hiện hữu. Mã 0101 là doanh thu công nghiệp, không phải GTSXCN.",
                requiredData = new[] { "Mã chỉ tiêu GTSXCN", "Đơn vị", "Giá hiện hành hay giá so sánh", "Nguồn và kỳ dữ liệu" }
            };
            var month = new DateTime(filters.Year, filters.Month, 1);
            var rows = Read(filters, month, metric, (string)input["industryGroup"]);
            var current = rows.Where(r => r.Month == month).ToList();
            var summaryTable = _access.Report("Report_Dashboard_OverviewSummary", month,
                DbId(filters.AreaId), DbId(filters.EconomicSectorId), DbId(filters.IndustryId), DbId(filters.EnterpriseId), DBNull.Value);
            ChatbotQueries.RequireColumns(summaryTable, "Type" + metric.ReportType + "Expected", "ActiveEnterprises", "ConfiguredEnterprises");
            var summary = summaryTable.Rows.Count == 0 ? null : summaryTable.Rows[0];
            var expected = summary == null || input["industryGroup"] != null ? (int?)null : NullableInt(summary["Type" + metric.ReportType + "Expected"]);
            var coverage = new
            {
                expectedEnterprises = expected, observedEnterprises = current.Count,
                enterprisesWithIndicator = current.Count(r => r.Value.HasValue),
                missingIndicator = expected - current.Count(r => r.Value.HasValue), conflicts = current.Count(r => r.Conflict),
                classificationConflicts = current.Count(r => r.ClassificationConflict),
                enterprisesWithImportedRows = current.Count(r => r.DataImported),
                enterprisesWithFileOfAnyType = current.Count(r => r.FileSubmittedAnyType),
                isComplete = expected > 0 && current.Count(r => r.Value.HasValue) == expected,
                population = "active_enterprises_configured_for_selected_report_type",
                expectedCountSource = input["industryGroup"] == null ? "p_Report_Chatbot_Summary.TypeNExpected" : "unavailable_for_exact_industry_assignment_group",
                registrySummaryScope = _access.IsIndustryRestricted ? "authorized_industry_intersection_unfiltered_by_dimensions" : _access.CanReadProvince ? "authorized_province_unfiltered_by_dimensions" : "authorized_assignments_unfiltered_by_dimensions",
                activeRegistryEnterprises = summary == null ? (int?)null : NullableInt(summary["ActiveEnterprises"]),
                configuredRegistryEnterprises = summary == null ? (int?)null : NullableInt(summary["ConfiguredEnterprises"]),
                representsAllProvincialEnterprises = false
            };
            if (name == "get_reporting_data_quality")
            {
                var affected = current.Where(r => !r.Value.HasValue || r.Conflict).ToList();
                return new
                {
                    supported = true, month = month.ToString("yyyy-MM"), metric, coverage,
                    source = "p_Report_Chatbot_Snapshot", total = affected.Count,
                    items = affected.Skip(Offset(input)).Take(Limit(input)).Select(r => new
                    {
                        r.EnterpriseId, r.BusinessName, r.WardName, r.EconomicSectorName,
                        missingIndicator = !r.Value.HasValue, r.Conflict, r.DataImported, r.FileSubmittedAnyType
                    }),
                    hasMore = affected.Count > Offset(input) + Limit(input), nextOffset = Offset(input) + Limit(input),
                    itemsCoverage = "observed_rows_with_issues", missingEnterprisesTool = "get_reporting_progress",
                    notes = new[] { "FileSubmittedAnyType không chứng minh đã nộp đúng loại báo cáo.", "SP snapshot chỉ trả tháng có dữ liệu/tệp; số doanh nghiệp kỳ vọng lấy từ Summary, không từ số dòng snapshot.", "Xung đột chỉ tiêu áp dụng cho chỉ tiêu đang chọn; phân loại doanh nghiệp mâu thuẫn bị loại khỏi phép so sánh." }
                };
            }
            if (name == "get_indicator_comparison") return new
            {
                supported = true, month = month.ToString("yyyy-MM"), metric, coverage,
                currentObservedValue = Sum(current.Select(r => r.Value)),
                monthOverMonth = ComparisonView(Compare(rows, month, "month_over_month", expected)),
                yearOverYear = ComparisonView(Compare(rows, month, "year_over_year", expected)),
                yearToDate = ComparisonView(Compare(rows, month, "year_to_date", expected)),
                source = "p_Report_Chatbot_Snapshot", scope = "configured_reporting_cohort",
                comparisonPolicy = "Only enterprises with valid values in every required month in both periods are compared. Missing/conflicting values remain unknown, not zero."
            };

            var comparisonName = (string)input["comparison"] ?? "month_over_month";
            var comparison = Compare(rows, month, comparisonName, expected);
            if (name == "get_indicator_alerts")
            {
                var threshold = (int?)input["declineThreshold"] ?? 10;
                var affected = comparison.Pairs.Where(p => p.Percent.HasValue && p.Percent.Value < -threshold)
                    .OrderBy(p => p.Change).ThenBy(p => p.Percent).ToList();
                return new
                {
                    supported = true, month = month.ToString("yyyy-MM"), metric, coverage,
                    comparison = ComparisonView(comparison), declineThreshold = threshold,
                    severityCounts = new
                    {
                        over10 = comparison.Pairs.Count(p => p.Percent < -10),
                        over20 = comparison.Pairs.Count(p => p.Percent < -20),
                        over30 = comparison.Pairs.Count(p => p.Percent < -30)
                    },
                    total = affected.Count, items = affected.Skip(Offset(input)).Take(Limit(input)).Select(p => new
                    {
                        p.Row.EnterpriseId, p.Row.BusinessName, p.Row.WardName, p.Row.EconomicSectorName,
                        p.CurrentValue, p.BaselineValue, p.Change, declinePercent = -p.Percent,
                        severity = p.Percent < -30 ? "over_30" : p.Percent < -20 ? "over_20" : "over_10",
                        reasonTool = "get_reported_reasons"
                    }),
                    hasMore = affected.Count > Offset(input) + Limit(input), nextOffset = Offset(input) + Limit(input),
                    isPersistedAlert = false, source = "p_Report_Chatbot_Snapshot"
                };
            }

            var groupBy = (string)input["groupBy"] ?? "economic_sector";
            var industryNames = new CateBusinessIndustryCache().GetAll()
                ?.GroupBy(i => i.IndustryId).ToDictionary(g => g.Key, g => g.First().IndustryName)
                ?? new Dictionary<int, string>();
            var baseline = Sum(comparison.Pairs.Select(p => (decimal?)p.BaselineValue));
            var groups = comparison.Pairs.GroupBy(p => GroupKey(p.Row, groupBy))
                .Select(g =>
                {
                    var first = g.First().Row;
                    var before = g.Sum(p => p.BaselineValue);
                    var after = g.Sum(p => p.CurrentValue);
                    return new
                    {
                        id = g.Key, name = GroupName(first, groupBy, industryNames), enterprises = g.Count(),
                        currentValue = after, baselineValue = before, change = after - before,
                        growthPercent = Rate(after, before),
                        contributionToScopePercentagePoints = baseline > 0 ? (decimal?)((after - before) * 100m / baseline.Value) : null,
                        nextTool = groupBy == "enterprise" ? "get_reported_reasons" : "analyze_growth_drivers",
                        nextInput = NextInput(input, month, first, groupBy),
                        reportedReasonAvailable = (bool?)null
                    };
                }).ToList();
            var direction = (string)input["direction"] ?? "all";
            var selected = groups.Where(g => direction == "all" || (direction == "decrease" ? g.change < 0 : g.change > 0))
                .OrderByDescending(g => Math.Abs(g.change)).ThenBy(g => g.id).ToList();
            return new
            {
                supported = true, month = month.ToString("yyyy-MM"), metric, coverage, groupBy,
                comparison = ComparisonView(comparison), total = selected.Count,
                items = selected.Skip(Offset(input)).Take(Limit(input)),
                hasMore = selected.Count > Offset(input) + Limit(input), nextOffset = Offset(input) + Limit(input),
                allGroupsChange = groups.Count == 0 ? (decimal?)null : groups.Sum(g => g.change),
                source = "p_Report_Chatbot_Snapshot", scope = "selected_configured_reporting_cohort",
                attributionPolicy = "Current classification; each enterprise attributed once to its full industry assignment group. A single industry filter tests membership; assignment groups are not individual-industry allocations. Contributions use the selected scope's matched baseline. Reported reasons are statements, not verified causation."
            };
        }

        private List<SnapshotRow> Read(DashboardFilters filters, DateTime month, Metric metric, string industryGroup)
        {
            var table = _access.Report(SnapshotProcedure, month, metric.ReportType,
                DbId(filters.AreaId), DBNull.Value, DBNull.Value, DbId(filters.EnterpriseId));
            ChatbotQueries.RequireColumns(table, "ForMonth", "EnterpriseId", "IndustryIds", metric.Column, metric.Column.Replace("Value", "Conflict"), "DataImported", "FileSubmittedAnyType");
            var rows = table.Rows.Cast<DataRow>().Select(r => new SnapshotRow
            {
                Month = Convert.ToDateTime(r["ForMonth"]), EnterpriseId = Convert.ToInt32(r["EnterpriseId"]),
                BusinessName = Convert.ToString(r["BusinessName"]), WardId = NullableInt(r["WardId"]),
                WardName = Convert.ToString(r["WardName"]), EconomicSectorId = NullableInt(r["EconomicSectorId"]),
                EconomicSectorName = Convert.ToString(r["EconomicSectorName"]),
                IndustryIds = Industries(Convert.ToString(r["IndustryIds"])),
                Conflict = Convert.ToBoolean(r[metric.Column.Replace("Value", "Conflict")]), DataImported = Convert.ToBoolean(r["DataImported"]),
                FileSubmittedAnyType = Convert.ToBoolean(r["FileSubmittedAnyType"]),
                Value = r[metric.Column] == DBNull.Value || Convert.ToBoolean(r[metric.Column.Replace("Value", "Conflict")]) ? (decimal?)null : Convert.ToDecimal(r[metric.Column])
            });
            // Multiple category rows must not multiply an enterprise's reported value or contribution.
            var unique = rows.GroupBy(r => new { r.EnterpriseId, r.Month }).Select(group =>
            {
                var first = group.OrderBy(r => r.EconomicSectorId).ThenBy(r => string.Join(",", r.IndustryIds)).First();
                first.ClassificationConflict = group.Select(r => new { r.EconomicSectorId, IndustryGroup = string.Join(",", r.IndustryIds) }).Distinct().Count() > 1;
                if (first.ClassificationConflict) first.Value = null;
                return first;
            });
            // Do not let the snapshot's conditional TOP(1) choose a different classification while drilling down.
            // Apply sector/industry-membership filters to the same classification used by the parent comparison.
            var selectedGroup = industryGroup == null ? null : string.Join(",", Industries(industryGroup));
            if (industryGroup != null && selectedGroup.Length == 0) throw new ArgumentException("industryGroup requires comma-separated positive industry IDs.");
            int selectedIndustry, selectedSector;
            return unique.Where(r => r.Month <= month &&
                (!int.TryParse(filters.IndustryId, out selectedIndustry) || r.IndustryIds.Contains(selectedIndustry)) &&
                (selectedGroup == null || string.Join(",", r.IndustryIds) == selectedGroup) &&
                (!int.TryParse(filters.EconomicSectorId, out selectedSector) || r.EconomicSectorId == selectedSector)).ToList();
        }

        private static Comparison Compare(List<SnapshotRow> rows, DateTime month, string comparison, int? expected)
        {
            var currentMonths = comparison == "year_to_date"
                ? Enumerable.Range(1, month.Month).Select(m => new DateTime(month.Year, m, 1)).ToList()
                : new List<DateTime> { month };
            var baselineMonths = currentMonths.Select(m => m.AddMonths(comparison == "month_over_month" ? -1 : -12)).ToList();
            var currentSet = new HashSet<DateTime>(currentMonths);
            var baselineSet = new HashSet<DateTime>(baselineMonths);
            var result = new Comparison
            {
                Name = comparison, CurrentMonths = currentMonths, BaselineMonths = baselineMonths,
                ExpectedEnterprises = expected,
                CurrentObserved = Sum(rows.Where(r => currentSet.Contains(r.Month)).Select(r => r.Value)),
                BaselineObserved = Sum(rows.Where(r => baselineSet.Contains(r.Month)).Select(r => r.Value))
            };
            foreach (var enterprise in rows.GroupBy(r => r.EnterpriseId))
            {
                var current = enterprise.Where(r => currentSet.Contains(r.Month) && r.Value.HasValue).ToList();
                var baseline = enterprise.Where(r => baselineSet.Contains(r.Month) && r.Value.HasValue).ToList();
                if (current.Count != currentMonths.Count || baseline.Count != baselineMonths.Count ||
                    current.Select(r => r.Month).Distinct().Count() != currentMonths.Count ||
                    baseline.Select(r => r.Month).Distinct().Count() != baselineMonths.Count) continue;
                result.Pairs.Add(new Pair
                {
                    Row = current.Single(r => r.Month == month),
                    CurrentValue = current.Sum(r => r.Value.Value), BaselineValue = baseline.Sum(r => r.Value.Value)
                });
            }
            return result;
        }

        private static object ComparisonView(Comparison comparison)
        {
            var current = Sum(comparison.Pairs.Select(p => (decimal?)p.CurrentValue));
            var baseline = Sum(comparison.Pairs.Select(p => (decimal?)p.BaselineValue));
            return new
            {
                comparison = comparison.Name,
                currentMonths = comparison.CurrentMonths.Select(m => m.ToString("yyyy-MM")),
                baselineMonths = comparison.BaselineMonths.Select(m => m.ToString("yyyy-MM")),
                currentObservedValue = comparison.CurrentObserved, baselineObservedValue = comparison.BaselineObserved,
                comparableCurrentValue = current, comparableBaselineValue = baseline,
                change = current.HasValue && baseline.HasValue ? current - baseline : null,
                growthPercent = current.HasValue && baseline.HasValue ? Rate(current.Value, baseline.Value) : null,
                growthStatus = !baseline.HasValue ? "missing_baseline" : baseline <= 0 ? "non_positive_baseline" : "available",
                comparableEnterprises = comparison.Pairs.Count, excludedEnterprises = comparison.ExpectedEnterprises - comparison.Pairs.Count,
                isComplete = comparison.ExpectedEnterprises > 0 && comparison.Pairs.Count == comparison.ExpectedEnterprises,
                status = comparison.Pairs.Count == 0 ? "insufficient_comparable_data" : comparison.Pairs.Count == comparison.ExpectedEnterprises ? "complete_for_configured_cohort" : "partial_comparable_cohort"
            };
        }

        private static JObject NextInput(JObject input, DateTime month, SnapshotRow row, string dimension)
        {
            var next = (JObject)input.DeepClone();
            next.Remove("offset"); next.Remove("direction"); next.Remove("timeframe");
            next["month"] = month.ToString("yyyy-MM");
            if (dimension == "economic_sector")
            {
                if (!row.EconomicSectorId.HasValue) return null;
                next["economicSector"] = row.EconomicSectorId.Value.ToString(CultureInfo.InvariantCulture);
                next["groupBy"] = "industry";
            }
            else if (dimension == "industry")
            {
                if (row.IndustryIds.Length == 0) return null;
                next["industryGroup"] = string.Join(",", row.IndustryIds);
                next["groupBy"] = "enterprise";
            }
            else if (dimension == "area")
            {
                if (!row.WardId.HasValue) return null;
                next["area"] = row.WardId.Value.ToString(CultureInfo.InvariantCulture);
                next["groupBy"] = "enterprise";
            }
            else
            {
                // Reasons use the report metadata query's schema, not the analytical comparison schema.
                next = new JObject
                {
                    ["month"] = month.ToString("yyyy-MM"), ["enterprise"] = row.EnterpriseId.ToString(CultureInfo.InvariantCulture),
                    ["reportType"] = ReportType(input) == 3 ? "export_import" : ReportType(input) == 2 ? "trading" : "manufacturing"
                };
            }
            return next;
        }

        private static string GroupKey(SnapshotRow row, string dimension) => dimension == "economic_sector" ? row.EconomicSectorId?.ToString() ?? "unknown"
            : dimension == "industry" ? row.IndustryIds.Length == 0 ? "unknown" : string.Join(",", row.IndustryIds)
            : dimension == "area" ? row.WardId?.ToString() ?? "unknown" : row.EnterpriseId.ToString(CultureInfo.InvariantCulture);

        private static string GroupName(SnapshotRow row, string dimension, Dictionary<int, string> industries)
        {
            if (dimension == "economic_sector") return string.IsNullOrWhiteSpace(row.EconomicSectorName) ? "Chưa phân loại" : row.EconomicSectorName;
            if (dimension == "area") return string.IsNullOrWhiteSpace(row.WardName) ? "Chưa xác định địa bàn" : row.WardName;
            if (dimension == "enterprise") return row.BusinessName;
            return row.IndustryIds.Length == 0 ? "Chưa xác định ngành" : string.Join(" / ", row.IndustryIds.Select(id =>
            {
                string label;
                return industries.TryGetValue(id, out label) ? label : "Mã ngành " + id;
            }));
        }

        private static object DbId(string value) { int id; return int.TryParse(value, out id) ? (object)id : DBNull.Value; }
        private static int? NullableInt(object value) => value == DBNull.Value ? (int?)null : Convert.ToInt32(value);
        private static int[] Industries(string value)
        {
            if (string.IsNullOrWhiteSpace(value)) return new int[0];
            return value.Split(',').Select(v =>
            {
                int id;
                if (!int.TryParse(v.Trim(), out id) || id <= 0) throw new ArgumentException("Invalid industry ID list.");
                return id;
            }).Distinct().OrderBy(id => id).ToArray();
        }
        private static int Limit(JObject input) => (int?)input["limit"] ?? 10;
        private static int Offset(JObject input) => (int?)input["offset"] ?? 0;
        private static decimal? Rate(decimal current, decimal baseline) => baseline > 0 ? (decimal?)((current - baseline) * 100m / baseline) : null;
        private static decimal? Sum(IEnumerable<decimal?> values)
        {
            var known = values.Where(v => v.HasValue).ToList();
            return known.Count == 0 ? (decimal?)null : known.Sum(v => v.Value);
        }

        private sealed class SnapshotRow
        {
            internal DateTime Month;
            internal int EnterpriseId;
            internal string BusinessName;
            internal int? WardId;
            internal string WardName;
            internal int? EconomicSectorId;
            internal string EconomicSectorName;
            internal int[] IndustryIds;
            internal bool Conflict;
            internal bool ClassificationConflict;
            internal bool DataImported;
            internal bool FileSubmittedAnyType;
            internal decimal? Value;
        }

        private sealed class Pair
        {
            internal SnapshotRow Row;
            internal decimal CurrentValue;
            internal decimal BaselineValue;
            internal decimal Change => CurrentValue - BaselineValue;
            internal decimal? Percent => Rate(CurrentValue, BaselineValue);
        }

        private sealed class Comparison
        {
            internal string Name;
            internal List<DateTime> CurrentMonths;
            internal List<DateTime> BaselineMonths;
            internal int? ExpectedEnterprises;
            internal decimal? CurrentObserved;
            internal decimal? BaselineObserved;
            internal List<Pair> Pairs = new List<Pair>();
        }

        private sealed class Metric
        {
            public string Name { get; private set; }
            public string Label { get; private set; }
            public string Code { get; private set; }
            public string Unit { get; private set; }
            public int ReportType { get; private set; }
            internal string Column { get; private set; }
            internal static Metric For(string name)
            {
                switch (name)
                {
                    case "industrial_revenue": return new Metric { Name = name, Label = "Doanh thu công nghiệp", Code = "0101", Unit = "tỷ đồng", ReportType = 1, Column = "PrimaryValue" };
                    case "export_value": return new Metric { Name = name, Label = "Xuất khẩu từ báo cáo sản xuất", Code = "06", Unit = "nghìn USD", ReportType = 1, Column = "SecondaryValue" };
                    case "import_value": return new Metric { Name = name, Label = "Nhập khẩu từ báo cáo sản xuất", Code = "07", Unit = "nghìn USD", ReportType = 1, Column = "TertiaryValue" };
                    case "export_fob": return new Metric { Name = name, Label = "Kim ngạch FOB từ báo cáo xuất nhập khẩu", Code = "FOB", Unit = "USD", ReportType = 3, Column = "PrimaryValue" };
                    case "wholesale_retail_revenue": return new Metric { Name = name, Label = "Doanh thu bán buôn bán lẻ", Code = "01", Unit = "triệu đồng", ReportType = 2, Column = "PrimaryValue" };
                    case "retail_revenue": return new Metric { Name = name, Label = "Doanh thu bán lẻ (tập con)", Code = "02", Unit = "triệu đồng", ReportType = 2, Column = "TertiaryValue" };
                    case "repair_revenue": return new Metric { Name = name, Label = "Doanh thu sửa chữa", Code = "40", Unit = "triệu đồng", ReportType = 2, Column = "SecondaryValue" };
                    case "direct_export_value": return new Metric { Name = name, Label = "Xuất khẩu trực tiếp", Code = "XK_TT", Unit = "USD", ReportType = 3, Column = "SecondaryValue" };
                    case "entrusted_export_value": return new Metric { Name = name, Label = "Ủy thác xuất khẩu", Code = "UT_XK", Unit = "USD", ReportType = 3, Column = "TertiaryValue" };
                    case "industrial_production_value": return null;
                    default: throw new ArgumentException("Unsupported metric.");
                }
            }
        }
    }
}
