using System;
using System.Collections.Generic;
using System.Globalization;
using System.Linq;
using System.Web;
using CenIT.ReportTourism.Biz.Report;
using System.Data;
using CenIT.ReportTourism.Models.Cate;
using CenIT.ReportTourism.Models.Report;
using CenIT.ReportTourism.Models.Sys;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using Newtonsoft.Json.Serialization;
using TSFramework.App.Processors;

namespace CenIT.ReportTourism.WebApp.Chatbot
{
    internal sealed class ChatbotTools
    {
        private ChatbotAccess _access;
        private readonly ReportDataImportBiz _reports = new ReportDataImportBiz();
        private ReportDashboardBiz _dashboard;
        internal static readonly JsonSerializerSettings JsonSettings = new JsonSerializerSettings
        {
            ContractResolver = new CamelCasePropertyNamesContractResolver(), MaxDepth = 20
        };
        private static DateTime CurrentMonth
        {
            get
            {
                var now = DateTime.UtcNow.AddHours(7);
                return new DateTime(now.Year, now.Month, 1);
            }
        }

        internal object Execute(string name, int userId, string userName, JObject input)
        {
            var value = ExecuteScoped(name, userId, userName, input);
            var result = JObject.FromObject(value, JsonSerializer.Create(JsonSettings));
            if ((string)result["scope"] != "none")
            {
                result["scope"] = _access.IsIndustryRestricted ? "authorized_industry_intersection" : _access.CanReadProvince ? "authorized_province" : "authorized_enterprise_assignments";
                result["scopeNote"] = "Chatbot chỉ đọc doanh nghiệp được phép theo vai trò, phân công và ngành. Dashboard web và Chatbot dùng cùng phạm vi doanh nghiệp; chỉ đối chiếu tổng với cùng kỳ, bộ lọc và định nghĩa chỉ tiêu. Khi trả lời, nêu rõ phạm vi này và không gọi tổng phạm vi hạn chế là tổng toàn tỉnh.";
            }
            return result;
        }

        private object ExecuteScoped(string name, int userId, string userName, JObject input)
        {
            ChatbotCatalog.Validate(name, input);
            _access = new ChatbotAccess(userId, userName);
            _dashboard = new ReportDashboardBiz(_access.Report);
            try
            {
                if (!_access.HasAuthorizedEnterprises)
                    return new { scope = "none", message = "Tài khoản chưa có doanh nghiệp trong phạm vi được phép. Liên hệ quản trị viên để kiểm tra phân quyền." };
                if (name == "get_enterprise_products" && (string)input["scope"] == "registry")
                {
                    RequireDashboardOrReportPermission(userName, "Dashboard");
                    return RegistryTool(name, userName, input);
                }
                if (name == "search_enterprises" || name == "get_enterprise_detail" || name == "get_enterprise_products")
                    return EnterpriseTool(name, userName, input);
                if (name == "search_reports" || name == "get_report_detail" || name == "get_my_reporting_status")
                {
                    RequireDashboardOrReportPermission(userName, "Import");
                    return ReportTool(name, userName, input);
                }
                RequireDashboardOrReportPermission(userName, "Dashboard");
                if (name == "search_enterprise_registry" || name == "get_enterprise_registry_detail")
                    return RegistryTool(name, userName, input);
                if (name == "get_reported_reasons")
                {
                    return ReportedReasons(input);
                }
                if (ChatbotQueries.Contains(name))
                    return ChatbotQueries.Execute(name, _access, name == "query_report_indicators" || name == "get_report_submission_history"
                        ? CreateDashboardFilters(input, ChatbotQueries.ReportType(input)) : null, input);
                if (ChatbotAnalytics.Contains(name))
                    return new ChatbotAnalytics(_access).Execute(name, CreateDashboardFilters(input, ChatbotAnalytics.ReportType(input)), input);
                return DashboardTool(name, input);
            }
            catch (SelectionRequiredException exception) { return exception.Result; }
        }

        private void RequireDashboardOrReportPermission(string userName, string controller)
        {
            if (!(controller == "Dashboard" ? _access.CanReadDashboard : _access.CanReadImports) ||
                !AppProcessor.Author.IsAllow(userName, "Report", controller, "View"))
                throw new HttpException(403, "You do not have permission to view these reports.");
        }

        private List<CateEnterpriseModel> Assigned(string userName) => _access.Assigned();

        private object EnterpriseTool(string name, string userName, JObject input)
        {
            var assigned = Assigned(userName);
            if (name == "get_enterprise_products")
                return ChatbotQueries.Products(_access, SelectEnterprise(assigned, input).EnterpriseId, input);
            if (name == "get_enterprise_detail")
            {
                var enterprise = SelectEnterprise(assigned, input);
                return new
                {
                    enterprise = EnterpriseView(enterprise),
                    assignedProducts = ChatbotQueries.Products(_access, enterprise.EnterpriseId, new JObject { ["limit"] = 50 })
                };
            }
            var keyword = (string)input["keyword"];
            var type = (string)input["businessType"];
            var matches = assigned.Where(e =>
                (keyword == null || Match(e.BusinessName, keyword) || Match(e.TaxCode, keyword) || Match(e.BusinessAddress, keyword)) &&
                (type == null || (e.TypeBusiness ?? "").Split(',').Contains(type == "manufacturing" ? "1" : "2")))
                .OrderBy(e => e.BusinessName).ToList();
            return new { total = matches.Count, items = matches.Skip(Offset(input)).Take(Limit(input)).Select(EnterpriseView), hasMore = matches.Count > Offset(input) + Limit(input), nextOffset = Offset(input) + Math.Min(Limit(input), Math.Max(0, matches.Count - Offset(input))) };
        }

        private object ReportTool(string name, string userName, JObject input)
        {
            var assigned = Assigned(userName);
            var month = Month(input);
            if (name == "get_report_detail")
            {
                var enterprise = SelectEnterprise(assigned, input);
                var rows = (_reports.GetViaEnterpriseOnMonth(enterprise.EnterpriseId, month) ?? new List<ReportDataImportModel>())
                    // The SP is bound to the authorized enterprise/month; also reject unexpected enterprise rows.
                    .Where(r => r.EnterpriseId == enterprise.EnterpriseId && !r.IsDeleted &&
                        (input["reportType"] == null || r.TypeReport == (int)input["reportType"]) &&
                        (input["indicator"] == null || Match(r.Targets, (string)input["indicator"]) || Match(r.Code, (string)input["indicator"])))
                    .ToList();
                var offset = (int?)input["offset"] ?? 0;
                return new
                {
                    enterprise = EnterpriseView(enterprise), month = month.ToString("yyyy-MM"), total = rows.Count,
                    items = rows.Skip(offset).Take(Limit(input)).Select(r => new
                    {
                        r.TypeReport, r.TypeReportName, r.Code, r.Targets, r.Unit,
                        r.PerformPreviousPeriod, r.PerformInPeriod, r.AccumulatedBeginingOfYear, r.ComparedSamePeriodLastYear, r.CreatedDate
                    }),
                    hasMore = rows.Count > offset + Limit(input), nextOffset = offset + Limit(input)
                };
            }
            if (name == "get_my_reporting_status")
            {
                var reports = _reports.GetForUserOnMonth(userName, month) ?? new List<ReportDataImportModel>();
                var submitted = new HashSet<int>(reports.Where(r => !r.IsDeleted && r.EnterpriseId.HasValue)
                    .Select(r => r.EnterpriseId.Value));
                var status = (string)input["status"] ?? "all";
                var matches = assigned.Where(e => status == "all" || submitted.Contains(e.EnterpriseId) == (status == "submitted")).ToList();
                return new
                {
                    month = month.ToString("yyyy-MM"), assigned = assigned.Count,
                    submitted = assigned.Count(e => submitted.Contains(e.EnterpriseId)),
                    missing = assigned.Count(e => !submitted.Contains(e.EnterpriseId)), total = matches.Count,
                    items = matches.Skip(Offset(input)).Take(Limit(input)).Select(e => new { e.EnterpriseId, e.BusinessName, submitted = submitted.Contains(e.EnterpriseId) }),
                    hasMore = matches.Count > Offset(input) + Limit(input), nextOffset = Offset(input) + Math.Min(Limit(input), Math.Max(0, matches.Count - Offset(input)))
                };
            }
            if (input["enterpriseId"] != null)
            {
                var id = (int)input["enterpriseId"];
                if (!assigned.Any(e => e.EnterpriseId == id)) throw new HttpException(403, "Enterprise is outside your assigned scope.");
                assigned = assigned.Where(e => e.EnterpriseId == id).ToList();
            }
            if (assigned.Count == 0) return new { total = 0, items = new object[0], hasMore = false };
            var assignedIds = string.Join(",", assigned.Select(e => e.EnterpriseId));
            if (assignedIds.Length > 500)
                return new { needsClarification = true, field = "enterpriseId", totalAssigned = assigned.Count,
                    message = "Chọn một doanh nghiệp qua search_enterprises; SP tìm báo cáo hiện hữu giới hạn danh sách ID ở 500 ký tự." };
            DateTime from, to;
            Range(input, month, out from, out to);
            int total;
            var found = _reports.Get(userName, assignedIds, from, to, null,
                out total, new SysSearchModel { Search = (string)input["keyword"], StartIndex = Offset(input), PageSize = Limit(input), Order = "1", OrderDir = "DESC" })
                ?? new List<ReportDataImportModel>();
            var ids = new HashSet<int>(assigned.Select(e => e.EnterpriseId));
            return new
            {
                fromMonth = from.ToString("yyyy-MM"), toMonth = to.ToString("yyyy-MM"), total,
                items = found.Where(r => !r.IsDeleted && r.EnterpriseId.HasValue && ids.Contains(r.EnterpriseId.Value))
                    .Take(Limit(input)).Select(r => new { r.EnterpriseId, r.EnterpriseName, r.ForMonth, r.TypeReport, r.TypeReportName, r.CreatedDate }),
                hasMore = total > Offset(input) + found.Count, nextOffset = Offset(input) + found.Count
            };
        }

        private object DashboardTool(string name, JObject input)
        {
            var type = (string)input["reportType"];
            var filters = CreateDashboardFilters(input, type == "trading" ? 2 : type == "export_import" ? 3 : 1);
            if (name == "get_reporting_progress") filters.Status = (string)input["status"] ?? "all";
            object model;
            switch (name)
            {
                case "get_commerce_statistics": model = _dashboard.GetDashboard(filters); break;
                case "analyze_commerce_indicator": model = _dashboard.GetAnalysis(filters); break;
                case "get_reporting_warnings": model = _dashboard.GetWarnings(filters); break;
                case "get_reporting_progress": model = _dashboard.GetProgress(filters); break;
                default: throw new HttpException(403, "Tool is not allowed.");
            }
            var result = JObject.FromObject(model, JsonSerializer.Create(JsonSettings));
            result.Remove("filterOptions");
            // The existing classification summary is system-wide and does not apply dashboard filters.
            result.Remove("classification");
            result["scope"] = _access.IsIndustryRestricted ? "authorized_industry_intersection" : _access.CanReadProvince ? "authorized_province" : "authorized_enterprise_assignments";
            result["population"] = "active_enterprises_configured_for_selected_report_type";
            result["representsAllProvincialEnterprises"] = false;
            if (name == "get_commerce_statistics")
            {
                // Use the dedicated analytical tools for explicit metric/comparison movement queries.
                result.Remove("movements");
                if (type != null)
                {
                    result["typeCards"] = new JArray(((JArray)result["typeCards"])
                        .Where(card => (int)card["reportType"] == filters.ReportType));
                    result["receiptTrend"] = new JArray(((JArray)result["receiptTrend"]).Select(point => new JObject
                    {
                        ["month"] = point["month"], ["received"] = point["type" + filters.ReportType]
                    }));
                }
            }
            if (name == "get_reporting_progress")
            {
                result.Remove("page"); result.Remove("pageSize"); result.Remove("totalPages");
                var details = ProgressDetails(filters, (string)input["status"] ?? "all", Offset(input), Limit(input));
                result["totalEnterprises"] = details.Item2;
                result["hasMore"] = details.Item2 > Offset(input) + details.Item1.Count;
                result["nextOffset"] = Offset(input) + details.Item1.Count;
                result["enterprises"] = JArray.FromObject(details.Item1.Select(ProgressView), JsonSerializer.Create(JsonSettings));
                result["submissionDefinition"] = "DataImported means indicator rows for selected report type; FileSubmittedAnyType does not prove submission of that report type.";
            }
            return result;
        }

        private DashboardFilters CreateDashboardFilters(JObject input, int? reportType)
        {
            var month = Month(input);
            var filters = new DashboardFilters
            {
                Year = month.Year, Month = month.Month, ReportType = reportType ?? 1,
                AreaId = "all", EconomicSectorId = "all", IndustryId = "all", EnterpriseId = "all", Metric = (string)input["metric"] ?? "primary"
            };
            filters.EnterpriseId = ResolveDashboardOption("enterprise", (string)input["enterprise"], reportType, "enterprise");
            filters.AreaId = ResolveDashboardOption("ward", (string)input["area"], reportType, "area");
            filters.IndustryId = ResolveDashboardOption("industry", (string)input["industry"], reportType, "industry");
            filters.EconomicSectorId = ResolveDashboardOption("sector", (string)input["economicSector"], reportType, "economicSector");
            return filters;
        }

        private object ReportedReasons(JObject input)
        {
            var type = (string)input["reportType"];
            var filters = CreateDashboardFilters(input, type == "trading" ? 2 : type == "export_import" ? 3 : 1);
            if (filters.EnterpriseId == "all")
            {
                var options = _dashboard.GetFilterOptions("enterprise", filters.ReportType, null, 1);
                return new { needsClarification = true, field = "enterprise", total = options.Count == 0 ? 0 : options[0].TotalRow, candidates = options.Take(20) };
            }
            var details = ProgressDetails(filters, "all", 0, 1);
            return new
            {
                month = new DateTime(filters.Year, filters.Month, 1).ToString("yyyy-MM"),
                items = details.Item1.Select(r => new
                {
                    enterpriseId = Convert.ToInt32(r["EnterpriseId"]), businessName = Convert.ToString(r["BusinessName"]),
                    reportedText = string.IsNullOrWhiteSpace(Convert.ToString(r["Reason"])) ? null : Convert.ToString(r["Reason"]),
                    hasReportedText = !string.IsNullOrWhiteSpace(Convert.ToString(r["Reason"])),
                    fileCreatedAt = r["FileCreatedAt"] == DBNull.Value ? (DateTime?)null : Convert.ToDateTime(r["FileCreatedAt"])
                }),
                source = "p_Report_Chatbot_ProgressDetails / Report_ReportFiles.Reason", statementType = "latest_monthly_file_reason",
                reportTypeScope = "file_of_any_report_type", isVerifiedBusinessCause = false,
                note = "Reason là nội dung của tệp báo cáo tháng gần nhất; có thể là lý do nộp/sửa số liệu, không bảo đảm là nguyên nhân biến động kinh doanh. Không tự suy luận nguyên nhân khi trường trống."
            };
        }

        private object RegistryTool(string name, string userName, JObject input)
        {
            if (name == "get_enterprise_registry_detail" || name == "get_enterprise_products")
            {
                if (!_access.CanReadRegistryDetail || !AppProcessor.Author.IsAllow(userName, "Cate", "Enterprise", "View"))
                    throw new HttpException(403, "Enterprise registry detail permission is required.");
                var query = (string)input["enterprise"] ?? (string)input["query"] ?? input["enterpriseId"]?.ToString();
                if (query == null) return new { needsClarification = true, field = "enterprise", message = "Chọn mã/tên/mã số thuế doanh nghiệp từ search_enterprise_registry." };
                var id = int.Parse(ResolveDashboardOption("enterprise", query, null, "enterprise"), CultureInfo.InvariantCulture);
                var enterprise = _access.Enterprise(id);
                if (enterprise == null || enterprise.EnterpriseId != id || !enterprise.IsActive || enterprise.IsDeleted)
                    throw new HttpException(403, "Enterprise is outside the active registry.");
                if (name == "get_enterprise_products") return ChatbotQueries.Products(_access, id, input);
                return new
                {
                    enterprise = EnterpriseView(enterprise),
                    assignedProducts = ChatbotQueries.Products(_access, id, new JObject { ["limit"] = 50 }),
                    sources = new[] { "p_Cate_Chatbot_EnterpriseScope(detail)", "p_Cate_Chatbot_EnterpriseProducts" }
                };
            }
            var offset = Offset(input);
            var items = new List<DashboardOption>();
            var page = offset / 100 + 1;
            var skip = offset % 100;
            var total = 0;
            do
            {
                var batch = _dashboard.GetFilterOptions("enterprise", null, (string)input["keyword"], page, 100);
                total = batch.Count == 0 ? 0 : batch[0].TotalRow;
                items.AddRange(batch.Skip(skip).Take(Limit(input) - items.Count));
                if (batch.Count < 100 || page * 100 >= total) break;
                page++; skip = 0;
            } while (items.Count < Limit(input));
            return new
            {
                total, items = items.Select(e => new { enterpriseId = int.Parse(e.Value, CultureInfo.InvariantCulture), displayName = e.Text }),
                hasMore = total > offset + items.Count, nextOffset = offset + items.Count,
                scope = _access.IsIndustryRestricted ? "authorized_industry_intersection" : _access.CanReadProvince ? "authorized_province" : "authorized_enterprise_assignments", source = "p_Report_Chatbot_FilterOptions enterprise / TypeReport=NULL",
                includesUnconfiguredEnterprises = true
            };
        }

        private Tuple<List<DataRow>, int> ProgressDetails(DashboardFilters filters, string status, int offset, int limit)
        {
            const int pageSize = 100;
            var items = new List<DataRow>();
            var page = offset / pageSize + 1;
            var skip = offset % pageSize;
            var total = 0;
            do
            {
                var table = _access.Report("Report_Dashboard_ProgressDetails",
                    new DateTime(filters.Year, filters.Month, 1), filters.ReportType, DbId(filters.AreaId),
                    DbId(filters.EconomicSectorId), DbId(filters.IndustryId), DbId(filters.EnterpriseId), status, page, pageSize);
                ChatbotQueries.RequireColumns(table, "TotalRow", "TotalUnfiltered", "EnterpriseId", "Reason", "FileCreatedAt", "MetricConflict");
                total = table.Rows.Count == 0 ? 0 : Convert.ToInt32(table.Rows[0]["TotalRow"]);
                var rows = table.Rows.Cast<DataRow>().Where(r => r["EnterpriseId"] != DBNull.Value).ToList();
                items.AddRange(rows.Skip(skip).Take(limit - items.Count));
                if (rows.Count < pageSize || page * pageSize >= total) break;
                page++; skip = 0;
            } while (items.Count < limit);
            return Tuple.Create(items, total);
        }

        private static object ProgressView(DataRow row) => new
        {
            enterpriseId = Convert.ToInt32(row["EnterpriseId"]), name = Convert.ToString(row["BusinessName"]),
            taxCode = Convert.ToString(row["TaxCode"]), wardName = Convert.ToString(row["WardName"]),
            economicSectorName = Convert.ToString(row["EconomicSectorName"]), industryName = Convert.ToString(row["IndustryName"]),
            dataImported = Convert.ToBoolean(row["DataImported"]), fileAnyType = Convert.ToBoolean(row["FileSubmittedAnyType"]),
            fileLate = Convert.ToBoolean(row["FileLate"]), metricConflict = Convert.ToBoolean(row["MetricConflict"]),
            reason = Convert.ToString(row["Reason"]), isVerifiedBusinessCause = false
        };

        private static object DbId(string value) { int id; return int.TryParse(value, out id) ? (object)id : DBNull.Value; }

        private string ResolveDashboardOption(string kind, string query, int? reportType, string field)
        {
            if (query == null) return "all";
            var search = field == "economicSector" && string.Equals(query, "FDI", StringComparison.OrdinalIgnoreCase) ? "nước ngoài"
                : field == "economicSector" && string.Equals(query, "DNNN", StringComparison.OrdinalIgnoreCase) ? "nhà nước" : query;
            var options = _dashboard.GetFilterOptions(kind, reportType, search, 1).GroupBy(o => o.Value).Select(g => g.First()).ToList();
            var exact = options.Where(o => o.Value == query || string.Equals(o.Text, query, StringComparison.OrdinalIgnoreCase)).ToList();
            if (exact.Count == 1) return exact[0].Value;
            int requestedId;
            if (int.TryParse(query, NumberStyles.None, CultureInfo.InvariantCulture, out requestedId))
                throw new HttpException(403, "Requested object is unavailable in your authorized scope.");
            var matches = options.Where(o => !(field == "economicSector" && string.Equals(query, "DNNN", StringComparison.OrdinalIgnoreCase)) || !Match(o.Text, "ngoài")).ToList();
            var total = options.Count == 0 ? 0 : options[0].TotalRow;
            // A page of search matches is not proof of uniqueness when more matches exist in the database.
            if (total <= options.Count && matches.Count == 1) return matches[0].Value;
            throw new SelectionRequiredException(new { needsClarification = true, field, query, total, candidates = matches.Take(20) });
        }

        private static CateEnterpriseModel SelectEnterprise(List<CateEnterpriseModel> assigned, JObject input)
        {
            if (input["enterpriseId"] != null)
            {
                var enterprise = assigned.SingleOrDefault(e => e.EnterpriseId == (int)input["enterpriseId"]);
                if (enterprise == null) throw new HttpException(403, "Enterprise is outside your assigned scope.");
                return enterprise;
            }
            var query = (string)input["query"];
            var exact = assigned.Where(e => query != null && (e.TaxCode == query || string.Equals(e.BusinessName, query, StringComparison.OrdinalIgnoreCase))).ToList();
            var matches = exact.Count > 0 ? exact : assigned.Where(e => query == null || Match(e.BusinessName, query) || Match(e.TaxCode, query)).ToList();
            if (matches.Count == 1) return matches[0];
            throw new SelectionRequiredException(new { needsClarification = true, field = "enterpriseId", total = matches.Count, candidates = matches.Take(20).Select(EnterpriseView) });
        }

        private static object EnterpriseView(CateEnterpriseModel enterprise) => new
        {
            enterprise.EnterpriseId, enterprise.BusinessName, enterprise.TaxCode, enterprise.BusinessAddress,
            enterprise.WardId, enterprise.WardName, enterprise.ProvinceId, enterprise.ProvinceName, enterprise.TypeBusiness, enterprise.IndustryIds,
            enterprise.EconomicSectorId, enterprise.EnterpriseTypeId, enterprise.EnterpriseStatusId,
            enterprise.EnterpriseTypeName, enterprise.EconomicSectorName, enterprise.EnterpriseStatusName, enterprise.IsActive
        };

        private static bool Match(string value, string query) => value != null && CultureInfo.GetCultureInfo("vi-VN").CompareInfo
            .IndexOf(value, query, CompareOptions.IgnoreCase | CompareOptions.IgnoreNonSpace) >= 0;
        private static int Limit(JObject input) => (int?)input["limit"] ?? 10;
        private static int Offset(JObject input) => (int?)input["offset"] ?? 0;

        private DateTime Month(JObject input) => _access.Month(input);

        private static void Range(JObject input, DateTime month, out DateTime from, out DateTime to)
        {
            from = to = month;
            if (input["month"] != null) return;
            var current = CurrentMonth;
            switch ((string)input["timeframe"])
            {
                case "this_year": from = new DateTime(current.Year, 1, 1); to = current; break;
                case "last_year": from = new DateTime(current.Year - 1, 1, 1); to = new DateTime(current.Year - 1, 12, 1); break;
                case "recent": from = current.AddMonths(-2); to = current; break;
            }
        }

        private sealed class SelectionRequiredException : Exception
        {
            internal object Result { get; }
            internal SelectionRequiredException(object result) { Result = result; }
        }
    }
}
