using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Linq;


using CenIT.ReportTourism.Models.Report;

namespace CenIT.ReportTourism.Biz.Report
{
    public class ReportDashboardBiz
    {
        private const string SnapshotProcedure = "Report_Dashboard_IndustrialSnapshot";
        private const string SummaryProcedure = "Report_Dashboard_OverviewSummary";
        private static readonly CultureInfo Vietnamese = CultureInfo.GetCultureInfo("vi-VN");
        private readonly Func<string, object[], DataTable> _read;

        public ReportDashboardBiz() : this(null) { }

        /// <summary>Creates a dashboard reader with an optional account-scoped procedure executor.</summary>
        /// <param name="read">Procedure reader; null uses the existing application reader.</param>
        public ReportDashboardBiz(Func<string, object[], DataTable> read)
        {
            _read = read ?? ((name, parameters) => new ReportBiz().GetDataReport(name, parameters));
        }

        private readonly object _requestCacheKey = new object();

        private DataTable Read(string name, params object[] parameters)
        {
            var context = System.Web.HttpContext.Current;
            if (context == null) return _read(name, parameters);
            var results = context.Items[_requestCacheKey] as List<Tuple<string, object[], DataTable>>;
            if (results == null)
            {
                results = new List<Tuple<string, object[], DataTable>>();
                context.Items[_requestCacheKey] = results;
            }
            var found = results.FirstOrDefault(result => result.Item1 == name && result.Item2.SequenceEqual(parameters));
            if (found != null) return found.Item3;
            var table = _read(name, parameters);
            results.Add(Tuple.Create(name, (object[])parameters.Clone(), table));
            return table;
        }

        private static DashboardMetric[] Metrics(int type)
        {
            if (type == 1) return new[]
            {
                new DashboardMetric { Key = "primary", Code = "1.1", Label = DashboardText.Get("Metric_IndustrialRevenue"), Unit = DashboardText.Get("Unit_BillionVnd") },
                new DashboardMetric { Key = "secondary", Code = "6", Label = DashboardText.Get("Metric_ExportValue"), Unit = DashboardText.Get("Unit_ThousandUsd") },
                new DashboardMetric { Key = "tertiary", Code = "7", Label = DashboardText.Get("Metric_ImportValue"), Unit = DashboardText.Get("Unit_ThousandUsd") }
            };
            if (type == 2) return new[]
            {
                new DashboardMetric { Key = "primary", Code = "1", Label = DashboardText.Get("Metric_WholesaleRetailRevenue"), Unit = DashboardText.Get("Unit_MillionVnd") },
                new DashboardMetric { Key = "secondary", Code = "2", Label = DashboardText.Get("Metric_VehicleRepairRevenue"), Unit = DashboardText.Get("Unit_MillionVnd") },
                new DashboardMetric { Key = "tertiary", Code = "1.1", Label = DashboardText.Get("Metric_RetailSubset"), Unit = DashboardText.Get("Unit_MillionVnd") }
            };
            return new[]
            {
                new DashboardMetric { Key = "primary", Code = "0", Label = DashboardText.Get("Metric_FobValue"), Unit = DashboardText.Get("Unit_Usd") },
                new DashboardMetric { Key = "secondary", Code = "1", Label = DashboardText.Get("Metric_DirectExport"), Unit = DashboardText.Get("Unit_Usd") },
                new DashboardMetric { Key = "tertiary", Code = "2", Label = DashboardText.Get("Metric_EntrustedExport"), Unit = DashboardText.Get("Unit_Usd") }
            };
        }

        public static string TypeName(int type)
        {
            return DashboardText.Get(type == 2 ? "Type_Trading" : type == 3 ? "Type_ExportImport" : "Type_Manufacturing");
        }

        public DashboardModel GetDashboard(DashboardFilters filters)
        {
            filters = Normalize(filters);
            var byType = Enumerable.Range(1, 3).ToDictionary(type => type, type => GetRows(filters, type));
            var summary = GetSummary(filters);
            var cards = byType.Select(pair =>
            {
                var current = At(pair.Value, filters.Year, filters.Month).ToList();
                var metric = Metrics(pair.Key)[0];
                var mom = Comparable(pair.Value, filters, "primary");
                var yoy = Comparable(pair.Value, filters, "primary", -12);
                return new DashboardTypeCard
                {
                    ReportType = pair.Key, Name = TypeName(pair.Key), MetricLabel = metric.Label,
                    Unit = metric.Unit, Value = FormatOrDash(SumOrNull(current.Select(r => r.PrimaryValue))),
                    Assigned = summary.Expected(pair.Key), MetricCoverage = current.Count(r => r.PrimaryValue.HasValue),
                    Mom = Rate(mom), Yoy = Rate(yoy),
                    Compared = mom.Count(x => x.Percent.HasValue),
                    Declines = mom.Count(x => x.Percent < -10),
                    Incomplete = current.Count(r => r.DataImported && !Complete(r)), Received = current.Count(r => r.DataImported),
                    Conflicts = current.Count(r => r.MetricConflict)
                };
            }).ToList();
            var end = new DateTime(filters.Year, filters.Month, 1);
            var today = new DateTime(DateTime.Today.Year, DateTime.Today.Month, 1);
            if (end > today) end = today;
            var trend = Enumerable.Range(0, 12).Select(offset => end.AddMonths(offset - 11)).Select(date =>
            {
                var type1 = At(byType[1], date.Year, date.Month).Count(r => r.DataImported);
                var type2 = At(byType[2], date.Year, date.Month).Count(r => r.DataImported);
                var type3 = At(byType[3], date.Year, date.Month).Count(r => r.DataImported);
                return new DashboardReceiptPoint
                {
                    Month = date.ToString("yyyy-MM"),
                    Type1 = type1, Type2 = type2, Type3 = type3,
                    Type1Rate = Coverage(type1, summary.Type1Expected),
                    Type2Rate = Coverage(type2, summary.Type2Expected),
                    Type3Rate = Coverage(type3, summary.Type3Expected)
                };
            }).ToList();
            var movements = Comparable(byType[filters.ReportType], filters, "primary")
                .OrderByDescending(x => Math.Abs(x.Change)).Take(5).ToList();
            return new DashboardModel
            {
                Filters = filters, FilterOptions = BuildOptions(filters, "Index", false),
                TypeCards = cards, Classification = summary, ReceiptTrend = trend,
                Movements = movements
            };
        }

        public DashboardAnalysisModel GetAnalysis(DashboardFilters filters)
        {
            filters = Normalize(filters);
            var rows = GetRows(filters, filters.ReportType);
            var current = At(rows, filters.Year, filters.Month).ToList();
            var metric = SelectedMetric(filters);
            var summary = GetSummary(filters);
            var values = current.Select(r => Value(r, metric.Key));
            var monthly = Enumerable.Range(1, filters.Month).Select(month =>
                SumOrNull(At(rows, filters.Year, month).Select(r => Value(r, metric.Key)))).ToList();
            var ytdValues = monthly.Where(v => v.HasValue).ToList();
            var currentDate = new DateTime(filters.Year, filters.Month, 1);
            var trend = Enumerable.Range(0, 12).Select(offset => currentDate.AddMonths(offset - 11))
                .Where(date => date <= DateTime.Today)
                .Select(date => new DashboardMetricPoint
                {
                    Month = date.ToString("yyyy-MM"),
                    Value = SumOrNull(At(rows, date.Year, date.Month).Select(r => Value(r, metric.Key))),
                    Coverage = At(rows,date.Year,date.Month).Count(r => Value(r,metric.Key).HasValue), Expected = summary.Expected(filters.ReportType)
                }).ToList();
            var sectorValues = current.GroupBy(r => filters.Breakdown == "industry" ? r.IndustryName : filters.Breakdown == "enterprise" ? r.EnterpriseId.ToString() : r.EconomicSectorId.ToString())
                .Select(g => new DashboardBreakdown { Name = filters.Breakdown == "industry" ? g.First().IndustryName : filters.Breakdown == "enterprise" ? g.First().BusinessName : (String.IsNullOrWhiteSpace(g.First().EconomicSectorName) ? "Chưa phân loại" : g.First().EconomicSectorName), Key = filters.Breakdown == "sector" ? g.First().EconomicSectorId.ToString() : filters.Breakdown == "enterprise" ? g.First().EnterpriseId.ToString() : null,
                    Members = g.Select(r => new DashboardBreakdown { Key=r.EnterpriseId.ToString(),Name=r.BusinessName,Value=Value(r,metric.Key) }).OrderByDescending(x => x.Value).ToList(),
                    Value = SumOrNull(g.Select(r => Value(r,metric.Key))), Received = g.Count(r => Value(r,metric.Key).HasValue), Assigned = g.Count() })
                .OrderByDescending(g => g.Value).ToList();
            var sectorTotal = sectorValues.Sum(g => g.Value ?? 0);
            foreach (var sector in sectorValues) sector.Share = sectorTotal > 0 ? (sector.Value ?? 0) * 100 / sectorTotal : 0;
            var mom = Comparable(rows, filters, metric.Key).ToList();
            var yoy = Comparable(rows, filters, metric.Key, -12).ToList();
            return new DashboardAnalysisModel
            {
                Filters = filters, FilterOptions = BuildOptions(filters, "Analysis", true),
                TypeName = TypeName(filters.ReportType), SelectedMetric = metric, Metrics = Metrics(filters.ReportType),
                CurrentValue = FormatOrDash(SumOrNull(values)),
                YtdValue = ytdValues.Count == 0 ? "—" : Format(ytdValues.Sum(v => v.Value)),
                YtdMonths = ytdValues.Count,
                Mom = Rate(mom), Yoy = Rate(yoy), MomCompared = mom.Count, YoyCompared = yoy.Count,
                Assigned = summary.Expected(filters.ReportType), MetricCoverage = current.Count(r => Value(r,metric.Key).HasValue), Orphans = summary.OutsideCohortEnterprises,
                Trend = trend, Sectors = sectorValues,
                Movements = mom.OrderByDescending(x => Math.Abs(x.Change)).Take(8).ToList()
            };
        }

        public DashboardWarningsModel GetWarnings(DashboardFilters filters)
        {
            filters = Normalize(filters);
            var rows = GetRows(filters, filters.ReportType);
            var movements = Comparable(rows, filters, "primary").Where(x => x.Percent.HasValue).ToList();
            var summary = GetSummary(filters);
            var current = At(rows, filters.Year, filters.Month).ToList();
            var end = new DateTime(filters.Year, filters.Month, 1);
            var trend = Enumerable.Range(0, 12).Select(offset => end.AddMonths(offset - 11))
                .Where(date => date <= DateTime.Today)
                .Select(date =>
                {
                    var period = new DashboardFilters { Year = date.Year, Month = date.Month };
                    var pairs = Comparable(rows, period, "primary").Where(x => x.Percent.HasValue).ToList();
                    return new DashboardMetricPoint
                    {
                        Month = date.ToString("yyyy-MM"), Coverage = pairs.Count, Expected = summary.Expected(filters.ReportType),
                        Value = pairs.Count == 0 ? (decimal?)null :
                            pairs.Count(x => x.Percent.HasValue && x.Percent.Value < -10)
                    };
                }).ToList();
            return new DashboardWarningsModel
            {
                Filters = filters, FilterOptions = BuildOptions(filters, "Warnings", false),
                TypeName = TypeName(filters.ReportType), Metric = Metrics(filters.ReportType)[0],
                ComparableCount = movements.Count,
                Assigned = summary.Expected(filters.ReportType),
                Incomplete = current.Count(r => r.DataImported && !Complete(r)), Orphans = summary.OutsideCohortEnterprises,
                Issues = GetDetails(filters,"incomplete",1).Item1.Take(8).ToList(),
                DeclineOver10 = movements.Count(x => x.Percent < -10),
                DeclineOver20 = movements.Count(x => x.Percent < -20),
                DeclineOver30 = movements.Count(x => x.Percent < -30),
                ConflictCount = current.Count(r => r.MetricConflict), Trend = trend,
                Movements = movements.Where(x => x.Percent < -10).OrderBy(x => x.Change).ThenBy(x => x.Percent)
                    .ThenBy(x => x.EnterpriseId)
                    .Skip((int)Math.Min((long)(filters.Page - 1) * DashboardWarningsModel.PageSize, Int32.MaxValue))
                    .Take(DashboardWarningsModel.PageSize).ToList()
            };
        }

        public DashboardProgressModel GetProgress(DashboardFilters filters)
        {
            filters = Normalize(filters);
            var rows = GetRows(filters, filters.ReportType);
            var current = At(rows, filters.Year, filters.Month).ToList();
            var metrics = Metrics(filters.ReportType);
            var summary = GetSummary(filters);
            var details = GetDetails(filters,filters.Status,filters.Page);
            var end = new DateTime(filters.Year, filters.Month, 1);
            var trend = Enumerable.Range(0, 12).Select(offset => end.AddMonths(offset - 11))
                .Where(date => date <= DateTime.Today)
                .Select(date => new DashboardMetricPoint
                {
                    Month = date.ToString("yyyy-MM"),
                    Value = At(rows, date.Year, date.Month).Count(r => r.DataImported),
                    Rate = Coverage(At(rows,date.Year,date.Month).Count(r => r.DataImported),summary.Expected(filters.ReportType)),
                    Coverage = At(rows,date.Year,date.Month).Count(r => r.DataImported),
                    Files = At(rows,date.Year,date.Month).Count(r => r.FileAnyType), Expected = summary.Expected(filters.ReportType)
                }).ToList();
            return new DashboardProgressModel
            {
                Filters = filters, FilterOptions = BuildOptions(filters, "Progress", false),
                TypeName = TypeName(filters.ReportType), Assigned = summary.Expected(filters.ReportType),
                Complete = current.Count(Complete), Incomplete = current.Count(r => r.DataImported && !Complete(r)),
                FileLate = current.Count(r => r.FileLate), TotalRows = details.Item2, Orphans = summary.OutsideCohortEnterprises,
                Received = current.Count(r => r.DataImported),
                FileAnyType = current.Count(r => r.FileAnyType),
                MetricPresence = metrics.Select(metric => new DashboardBreakdown
                {
                    Name = metric.Label + " (" + metric.Code + ")",
                    Assigned = summary.Expected(filters.ReportType),
                    Received = current.Count(r => Value(r, metric.Key).HasValue)
                }).ToList(),
                Conflicts = current.Count(r => r.MetricConflict),
                CoveragePercent = Coverage(current.Count(r => r.DataImported),summary.Expected(filters.ReportType)),
                ReceiptTrend = trend,
                Areas = Breakdown(rows,filters,"ward"), Sectors = Breakdown(rows,filters,"sector"),
                Enterprises = details.Item1
            };
        }

        private DashboardOverviewSummary GetSummary(DashboardFilters filters)
        {
            var table = Read(SummaryProcedure, new DateTime(filters.Year, filters.Month, 1), DbFilter(filters.AreaId), DbFilter(filters.EconomicSectorId), DbFilter(filters.IndustryId), DbFilter(filters.EnterpriseId), DBNull.Value);
            if (table.Rows.Count == 0) return new DashboardOverviewSummary();
            var row = table.Rows[0];
            return new DashboardOverviewSummary
            {
                ActiveEnterprises = Convert.ToInt32(row["ActiveEnterprises"]),
                ConfiguredEnterprises = Convert.ToInt32(row["ConfiguredEnterprises"]),
                MissingBusinessRow = Convert.ToInt32(row["MissingBusinessRow"]),
                MissingIndustry = Convert.ToInt32(row["MissingIndustry"]),
                MissingReportType = Convert.ToInt32(row["MissingReportType"]),
                TypeZeroRows = Convert.ToInt32(row["TypeZeroRows"]),
                FutureDatedRows = Convert.ToInt32(row["FutureDatedRows"]),
                Type1Expected = Convert.ToInt32(row["Type1Expected"]), Type2Expected = Convert.ToInt32(row["Type2Expected"]),
                Type3Expected = Convert.ToInt32(row["Type3Expected"]), OutsideCohortEnterprises = Convert.ToInt32(row["OutsideCohortEnterprises"])
            };
        }

        private List<SnapshotRow> GetRows(DashboardFilters filters, int reportType)
        {
            var table = Read(SnapshotProcedure,
                new DateTime(filters.Year, filters.Month, 1), reportType, DbFilter(filters.AreaId),
                DbFilter(filters.EconomicSectorId), DbFilter(filters.IndustryId),
                DbFilter(filters.EnterpriseId));
            return table.Rows.Cast<DataRow>().Select(row => new SnapshotRow
            {
                ForMonth = Convert.ToDateTime(row["ForMonth"]), EnterpriseId = Convert.ToInt32(row["EnterpriseId"]),
                BusinessName = Convert.ToString(row["BusinessName"]),
                WardId = NullableInt(row["WardId"]), WardName = Convert.ToString(row["WardName"]),
                EconomicSectorId = NullableInt(row["EconomicSectorId"]),
                EconomicSectorName = Convert.ToString(row["EconomicSectorName"]),
                IndustryIds = Convert.ToString(row["IndustryIds"]), IndustryName = Convert.ToString(row["IndustryName"]),
                TaxCode = Convert.ToString(row["TaxCode"]), Reason = Convert.ToString(row["Reason"]), FileLate = Convert.ToBoolean(row["FileLate"]),
                DataImported = Convert.ToBoolean(row["DataImported"]),
                FileAnyType = Convert.ToBoolean(row["FileSubmittedAnyType"]),
                MetricConflict = Convert.ToBoolean(row["MetricConflict"]),
                PrimaryValue = NullableDecimal(row["PrimaryValue"]),
                SecondaryValue = NullableDecimal(row["SecondaryValue"]),
                TertiaryValue = NullableDecimal(row["TertiaryValue"])
            }).ToList();
        }

        private static object DbFilter(string value)
        {
            int parsed;
            return Int32.TryParse(value, out parsed) && parsed >= 0 ? (object)parsed : DBNull.Value;
        }

        private static int? NullableInt(object value) { return value == DBNull.Value ? (int?)null : Convert.ToInt32(value); }
        private static decimal? NullableDecimal(object value) { return value == DBNull.Value ? (decimal?)null : Convert.ToDecimal(value); }
        private static string Format(decimal value) { return DashboardNumber.Amount(value); }
        private static string FormatOrDash(decimal? value) { return DashboardNumber.Amount(value); }

        public DashboardFilters Normalize(DashboardFilters filters)
        {
            filters = filters ?? new DashboardFilters();
            if (filters.Year == 0 || filters.Month == 0)
            {
                var latest = GetFilterOptions("latest", null, null, 1, 1).FirstOrDefault();
                DateTime date;
                if (latest == null || !DateTime.TryParseExact(latest.Value,"yyyy-MM-dd",CultureInfo.InvariantCulture,DateTimeStyles.None,out date)) date = DateTime.Today.AddMonths(-1);
                if (filters.Year == 0) filters.Year = date.Year;
                if (filters.Month == 0) filters.Month = date.Month;
            }
            if (filters.Year < 2000 || filters.Year > 2100 || filters.Month < 1 || filters.Month > 12 ||
                new DateTime(filters.Year,filters.Month,1) > new DateTime(DateTime.Today.Year,DateTime.Today.Month,1))
                throw new ArgumentException("Kỳ báo cáo không hợp lệ hoặc ở tương lai.");
            if (filters.ReportType < 1 || filters.ReportType > 3) throw new ArgumentException("Loại báo cáo không hợp lệ.");
            filters.AreaId = ValidFilter(filters.AreaId); filters.EconomicSectorId = ValidFilter(filters.EconomicSectorId);
            filters.IndustryId = ValidFilter(filters.IndustryId); filters.EnterpriseId = ValidFilter(filters.EnterpriseId);
            if (filters.Metric != "secondary" && filters.Metric != "tertiary") filters.Metric = "primary";
            if (filters.Breakdown != "industry" && filters.Breakdown != "enterprise") filters.Breakdown = "sector";
            if (String.IsNullOrEmpty(filters.Status)) filters.Status = "all";
            if (!new[] { "all","missing","incomplete","complete","conflict","file-late" }.Contains(filters.Status)) throw new ArgumentException("Trạng thái không hợp lệ.");
            if (filters.Page < 1) throw new ArgumentException("Trang không hợp lệ.");
            return filters;
        }
        private static string ValidFilter(string value)
        {
            if (String.IsNullOrWhiteSpace(value) || value == "all") return "all";
            int id;
            if (!Int32.TryParse(value,out id) || id <= 0) throw new ArgumentException("Mã lọc không hợp lệ.");
            return id.ToString(CultureInfo.InvariantCulture);
        }
        private static decimal Coverage(int count,int expected) { return expected == 0 ? 0 : 100m * count / expected; }
        private static bool Complete(SnapshotRow row) { return row.PrimaryValue.HasValue && row.SecondaryValue.HasValue && row.TertiaryValue.HasValue; }

        private static DashboardMetric SelectedMetric(DashboardFilters filters)
        {
            return Metrics(filters.ReportType).First(m => m.Key == filters.Metric);
        }

        private static IEnumerable<SnapshotRow> At(IEnumerable<SnapshotRow> rows, int year, int month)
        {
            return rows.Where(r => r.ForMonth.Year == year && r.ForMonth.Month == month);
        }

        private static decimal? Value(SnapshotRow row, string metric)
        {
            return metric == "secondary" ? row.SecondaryValue : metric == "tertiary" ? row.TertiaryValue : row.PrimaryValue;
        }

        private static decimal? SumOrNull(IEnumerable<decimal?> values)
        {
            var known = values.Where(v => v.HasValue).ToList();
            return known.Count == 0 ? (decimal?)null : known.Sum(v => v.Value);
        }

        private static List<DashboardMovement> Comparable(List<SnapshotRow> rows, DashboardFilters filters,
            string metric, int offset = -1)
        {
            var currentDate = new DateTime(filters.Year, filters.Month, 1);
            var previousDate = currentDate.AddMonths(offset);
            var previous = At(rows, previousDate.Year, previousDate.Month).ToDictionary(r => r.EnterpriseId);
            var result = new List<DashboardMovement>();
            foreach (var row in At(rows, filters.Year, filters.Month))
            {
                SnapshotRow old;
                if (!previous.TryGetValue(row.EnterpriseId, out old)) continue;
                var value = Value(row, metric);
                var baseline = Value(old, metric);
                if (!value.HasValue || !baseline.HasValue) continue;
                result.Add(new DashboardMovement
                {
                    EnterpriseId = row.EnterpriseId, Reason = row.Reason, Name = row.BusinessName, WardName = row.WardName,
                    CurrentValue = value.Value, PreviousValue = baseline.Value,
                    Change = value.Value - baseline.Value,
                    Percent = baseline.Value > 0 ? (value.Value - baseline.Value) * 100m / baseline.Value : (decimal?)null
                });
            }
            return result;
        }

        private static decimal? Rate(IList<DashboardMovement> movements)
        {
            if (movements.Count == 0) return null;
            var baseline = movements.Sum(m => m.PreviousValue);
            return baseline <= 0 ? (decimal?)null : movements.Sum(m => m.Change) * 100m / baseline;
        }

        private IList<DashboardBreakdown> Breakdown(List<SnapshotRow> rows,DashboardFilters filters,string group)
        {
            var table = Read(SummaryProcedure,new DateTime(filters.Year,filters.Month,1),DbFilter(filters.AreaId),
                DbFilter(filters.EconomicSectorId),DbFilter(filters.IndustryId),DbFilter(filters.EnterpriseId),group);
            var current = At(rows,filters.Year,filters.Month).ToList();
            return table.Rows.Cast<DataRow>().Select(r => {
                var id = NullableInt(r["DimensionId"]);
                return new DashboardBreakdown { Key = id.ToString(),Name = Convert.ToString(r["DimensionName"]),
                    Assigned = Convert.ToInt32(r["Type" + filters.ReportType + "Expected"]),
                    Received = current.Count(x => x.DataImported && (group == "ward" ? x.WardId : x.EconomicSectorId) == id) };
            }).Where(x => x.Assigned > 0).OrderBy(x => Coverage(x.Received,x.Assigned)).ThenByDescending(x => x.Assigned).ToList();
        }

        public IList<DashboardOption> GetFilterOptions(string kind,int? type,string search,int page,int pageSize=50)
        {
            var table = Read("Report_Dashboard_FilterOptions",kind,(object)type ?? DBNull.Value,(object)search ?? DBNull.Value,page,pageSize);
            return table.Rows.Cast<DataRow>().Where(r => r["Value"] != DBNull.Value).Select(r => new DashboardOption {
                Value = Convert.ToString(r["Value"]), Text = Convert.ToString(r["Text"]), TotalRow = Convert.ToInt32(r["TotalRow"]) }).ToList();
        }
        private IList<DashboardOption> AllOptions(string kind,int? type,string allLabel,string selected = "all")
        {
            var options = new List<DashboardOption> { new DashboardOption { Value="all",Text=allLabel } };
            for (var page=1;;page++)
            {
                var batch = GetFilterOptions(kind,type,null,page,100); options.AddRange(batch);
                if (batch.Count == 0 || page*100 >= batch[0].TotalRow) break;
            }
            if (selected != "all" && !options.Any(x => x.Value == selected)) options.Add(new DashboardOption { Value=selected,Text="Mã " + selected + " (ngoài nhóm được chọn)" });
            return options;
        }
        private DashboardFilterOptions BuildOptions(DashboardFilters filters,string action,bool includeMetric)
        {
            int? type = action == "Index" ? (int?)null : filters.ReportType;
            var enterprises = new List<DashboardOption> { new DashboardOption { Value="all",Text=DashboardText.Get("Filter_AllEnterprises") } };
            if (filters.EnterpriseId != "all") enterprises.AddRange(GetFilterOptions("enterprise",type,filters.EnterpriseId,1,100).Where(x => x.Value == filters.EnterpriseId));
            if (filters.EnterpriseId != "all" && !enterprises.Any(x => x.Value == filters.EnterpriseId)) enterprises.Add(new DashboardOption { Value=filters.EnterpriseId,Text="Mã " + filters.EnterpriseId + " (ngoài nhóm được chọn)" });
            var years = AllOptions("year",type,"").Where(x => x.Value != "all").ToList();
            if (!years.Any(x => x.Value == filters.Year.ToString())) years.Add(new DashboardOption { Value=filters.Year.ToString(),Text=filters.Year.ToString() });
            return new DashboardFilterOptions {
                Filters=filters,Action=action,Years=years.OrderByDescending(x => x.Value).ToList(),
                Months=Enumerable.Range(1,12).Select(m => new DashboardOption { Value=m.ToString(),Text=Vietnamese.DateTimeFormat.GetMonthName(m) }).ToList(),
                Areas=AllOptions("ward",type,DashboardText.Get("Filter_AllAreas"),filters.AreaId),
                EconomicSectors=AllOptions("sector",type,DashboardText.Get("Filter_AllSectors"),filters.EconomicSectorId),
                Industries=AllOptions("industry",type,DashboardText.Get("Filter_AllIndustries"),filters.IndustryId),Enterprises=enterprises,
                Metrics=includeMetric ? Metrics(filters.ReportType).Select(m => new DashboardOption { Value=m.Key,Text=m.Label }).ToList() : new List<DashboardOption>()
            };
        }
        public Tuple<IList<DashboardEnterpriseRow>, int, int> GetProgressEnterprises(DashboardFilters filters, string search, int page, int pageSize)
        {
            filters = Normalize(filters);
            if (page < 1 || !new[] { 10, 25, 50, 100 }.Contains(pageSize) || (search != null && search.Length > 250))
                throw new ArgumentException("Bộ lọc danh sách không hợp lệ.");
            int total;
            var details = ReadDetails(filters, filters.Status, page, pageSize, search, out total);
            return Tuple.Create(details.Item1, details.Item2, total);
        }

        private Tuple<IList<DashboardEnterpriseRow>,int> GetDetails(DashboardFilters filters,string status,int page)
        {
            int total;
            return ReadDetails(filters, status, page, 50, null, out total);
        }

        private Tuple<IList<DashboardEnterpriseRow>,int> ReadDetails(DashboardFilters filters, string status, int page, int pageSize, string search, out int total)
        {
            DataTable table;
            try { table = Read("Report_Dashboard_ProgressDetails",new DateTime(filters.Year,filters.Month,1),filters.ReportType,
                DbFilter(filters.AreaId),DbFilter(filters.EconomicSectorId),DbFilter(filters.IndustryId),DbFilter(filters.EnterpriseId),status,page,pageSize,
                String.IsNullOrWhiteSpace(search) ? (object)DBNull.Value : search.Trim()); }
            catch (System.Data.SqlClient.SqlException ex)
            {
                if (ex.Number != 201 && ex.Number != 8144 && ex.Number != 2812) throw;
                throw new System.Web.HttpException(503, "Dashboard database contract is incompatible. Apply the reviewed SQL scripts before deploying the application.", ex);
            }
            if (new[] { "TotalRow", "TotalUnfiltered", "EnterpriseId", "BusinessName", "TaxCode", "WardName", "DataImported", "FileSubmittedAnyType", "FileLate", "Reason", "MetricConflict", "PrimaryValue", "SecondaryValue", "TertiaryValue" }.Any(column => !table.Columns.Contains(column)))
                throw new System.Web.HttpException(503, "Dashboard database result contract is incompatible. Apply the reviewed SQL deployment scripts.");
            var metrics=Metrics(filters.ReportType);
            var list=table.Rows.Cast<DataRow>().Where(r => r["EnterpriseId"] != DBNull.Value).Select(r => new DashboardEnterpriseRow {
                EnterpriseId=Convert.ToInt32(r["EnterpriseId"]),Name=Convert.ToString(r["BusinessName"]),TaxCode=Convert.ToString(r["TaxCode"]),WardName=Convert.ToString(r["WardName"]),
                DataImported=Convert.ToBoolean(r["DataImported"]),FileAnyType=Convert.ToBoolean(r["FileSubmittedAnyType"]),FileLate=Convert.ToBoolean(r["FileLate"]),
                Reason=Convert.ToString(r["Reason"]),MetricConflict=Convert.ToBoolean(r["MetricConflict"]),
                MissingMetricCodes=String.Join(", ",metrics.Where((m,i) => r[new[] { "PrimaryValue","SecondaryValue","TertiaryValue" }[i]] == DBNull.Value).Select(m => m.Code))
            }).ToList();
            total = table.Rows.Count == 0 ? 0 : Convert.ToInt32(table.Rows[0]["TotalUnfiltered"]);
            return Tuple.Create((IList<DashboardEnterpriseRow>)list,table.Rows.Count==0 ? 0 : Convert.ToInt32(table.Rows[0]["TotalRow"]));
        }

        private sealed class SnapshotRow
        {
            public DateTime ForMonth;
            public int EnterpriseId;
            public string BusinessName;
            public int? WardId;
            public string WardName;
            public int? EconomicSectorId;
            public string EconomicSectorName;
            public string IndustryIds;
            public string IndustryName;
            public string TaxCode;
            public string Reason;
            public bool FileLate;
            public bool DataImported;
            public bool FileAnyType;
            public bool MetricConflict;
            public decimal? PrimaryValue;
            public decimal? SecondaryValue;
            public decimal? TertiaryValue;
        }
    }
}
