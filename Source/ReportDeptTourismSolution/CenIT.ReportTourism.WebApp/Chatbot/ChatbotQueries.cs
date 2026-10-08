using System;
using System.Collections.Generic;
using System.Data;
using System.Globalization;
using System.Linq;
using System.Web;
using CenIT.ReportTourism.Biz.Report;
using CenIT.ReportTourism.Models.Report;
using Newtonsoft.Json.Linq;
using TSFramework.App.Processors;

namespace CenIT.ReportTourism.WebApp.Chatbot
{
    // Fixed, read-only contracts; callers cannot choose SQL or procedure names.
    internal static class ChatbotQueries
    {
        internal static bool Contains(string name) => name == "get_reporting_dimensions" || name == "search_indicator_catalog" ||
            name == "query_report_indicators" || name == "get_reporting_policy" || name == "get_report_submission_history" || name == "get_data_capabilities";

        internal static int? ReportType(JObject input)
        {
            var value = (string)input["reportType"];
            return value == null ? (int?)null : value == "trading" ? 2 : value == "export_import" ? 3 : 1;
        }

        internal static object Execute(string name, ChatbotAccess access, DashboardFilters filters, JObject input)
        {
            var offset = (int?)input["offset"] ?? 0;
            var limit = (int?)input["limit"] ?? 10;
            if (name == "get_reporting_dimensions")
            {
                var kind = (string)input["dimension"] ?? "sector";
                var options = new List<DashboardOption>();
                var page = offset / 100 + 1;
                var skip = offset % 100;
                var total = 0;
                do
                {
                    var batch = new ReportDashboardBiz(access.Report).GetFilterOptions(kind, ReportType(input), (string)input["keyword"], page, 100);
                    total = batch.Count == 0 ? 0 : batch[0].TotalRow;
                    options.AddRange(batch.Skip(skip).Take(limit - options.Count));
                    if (batch.Count < 100 || page * 100 >= total) break;
                    page++; skip = 0;
                } while (options.Count < limit);
                return new { dimension = kind, total, items = options.Select(o => new { id = o.Value, name = o.Text }),
                    nextOffset = offset + options.Count, hasMore = total > offset + options.Count, source = "p_Report_Chatbot_FilterOptions" };
            }
            if (name == "search_indicator_catalog" || name == "get_reporting_policy" || name == "get_data_capabilities")
            {
                var kind = name == "search_indicator_catalog" ? "catalog" : name == "get_reporting_policy" ? "policy" : "capabilities";
                var table = access.Report("Report_Chatbot_Metadata", kind, Db(ReportType(input)), Db((string)input["keyword"]), offset, limit);
                if (kind == "catalog") return Page(table, "Code", input, "p_Report_Chatbot_Metadata / ReportTargetConfig + ReportDynamicGroupRule + Report_DataImports",
                    "Configured definitions and observed codes are separate records; match report type, label and unit before selecting a code. Headings are not measured values.");
                if (kind == "policy") ChatbotQueries.RequireColumns(table, "ConfigKey", "ConfigValue", "ConfigDesc");
                if (kind == "policy") return new { items = Rows(table), source = "p_Report_Chatbot_Metadata / Sys_Configs (two deadline keys only)",
                    ruleScope = "current_configured_day_of_month", isEnforcedPeriodLock = false,
                    note = "Deadline values are configuration, not evidence of a locked period or an approved reopen request. Existing import/delete procedures must enforce their own rules." };
                ChatbotQueries.RequireColumns(table, "ActiveIndicatorRows", "ObservedEnterpriseIds", "ObservedMonths", "OrphanIndicatorRows");
                return new { observations = Rows(table), source = "p_Report_Chatbot_Metadata / authorized Report_DataImports",
                    supported = new[] { "Enterprise registry and assigned products", "Raw indicators of report types 1/2/3", "Reporting coverage", "Validated monetary KPI comparisons when history exists", "Reported file reasons and latest timestamps", "Current reporting deadline settings" },
                    unavailable = new[] { "Verified GTSXCN code and price basis", "Normalized export/import market dimension (currently encoded in source codes/labels)", "Historical before/after revision ledger", "Period lock and reopen workflow", "Province data exchange provenance and sync history" },
                    limitations = new[] { "Files have no report type.", "Source timestamps are not a complete audit trail.", "No values or causes are inferred from missing source data.", "System credentials and technical security logs are not exposed as chatbot business data." } };
            }
            DateTime from, to;
            Period(access, input, out from, out to);
            if (name == "get_report_submission_history")
            {
                var id = Id(filters.EnterpriseId);
                if (id == DBNull.Value) return new { needsClarification = true, field = "enterprise", message = "Chọn doanh nghiệp qua search_enterprise_registry trước." };
                var table = access.Report("Report_Chatbot_ReportFiles", id, from, to, offset, limit);
                return Page(table, "EnterpriseId", input, "p_Report_Chatbot_ReportFiles / Report_ReportFiles",
                    "Current and soft-deleted file records only; no file path/content or user identities. No TypeReport column. Latest modification timestamp is not before/after revision history. Reason is unverified reported text.");
            }
            var data = access.Report("Report_Chatbot_IndicatorData", from, to, Db(ReportType(input)),
                Id(filters.EnterpriseId), Id(filters.AreaId), Id(filters.EconomicSectorId), Id(filters.IndustryId),
                Db((string)input["code"]), Db((string)input["codePrefix"]), Db((string)input["keyword"]), offset, limit);
            return new { fromMonth = from.ToString("yyyy-MM"), toMonth = to.ToString("yyyy-MM"),
                data = Page(data, "ReportId", input, "p_Report_Chatbot_IndicatorData / Report_DataImports + active enterprise master",
                    "Raw reported fields, not recomputed growth. AccumulatedBeginingOfYear is used as annual plan by manufacturing templates. Do not sum parent/subset rows, average incomes, currencies, or different quantity units. ExactCodeRows flags exact-code duplicates only; aliases need metric validation."),
                population = "authorized_active_registered_enterprises_with_observed_report_rows", includesUnconfiguredEnterprises = true,
                excludesOrphanEnterpriseRows = true, isAggregated = false };
        }

        internal static object Products(ChatbotAccess access, int enterpriseId, JObject input)
        {
            var table = access.Products(enterpriseId, (int?)input["offset"] ?? 0, (int?)input["limit"] ?? 10);
            return Page(table, "ProductId", input, "p_Cate_Chatbot_EnterpriseProducts / Cate_BusinessEnterpriseProduct + Cate_BusinessProduct",
                "Actual active assigned products; IsMainProduct is stored evidence. Multiple main flags are returned for reconciliation, not silently reduced to one.");
        }

        private static void Period(ChatbotAccess access, JObject input, out DateTime from, out DateTime to)
        {
            var month = access.Month(input);
            from = input["fromMonth"] == null ? month : access.Month(new JObject { ["month"] = input["fromMonth"] });
            to = input["toMonth"] == null ? month : access.Month(new JObject { ["month"] = input["toMonth"] });
            if (to < from || (to.Year - from.Year) * 12 + to.Month - from.Month > 11)
                throw new ArgumentException("Select an ordered period of at most 12 months.");
        }

        private static object Page(DataTable table, string idColumn, JObject input, string source, string notes)
        {
            RequireColumns(table, idColumn, "TotalRow");
            var rows = table.Rows.Cast<DataRow>().Where(r => r[idColumn] != DBNull.Value).ToList();
            var total = table.Rows.Count == 0 ? 0 : Convert.ToInt32(table.Rows[0]["TotalRow"]);
            var offset = (int?)input["offset"] ?? 0;
            return new { total, items = rows.Select(Row), hasMore = total > offset + rows.Count, nextOffset = offset + rows.Count, source, notes };
        }

        internal static void RequireColumns(DataTable table, params string[] columns)
        {
            if (columns.Any(name => !table.Columns.Contains(name)))
                throw new HttpException(503, "Chatbot database result contract is missing or incompatible. Apply the reviewed SQL deployment scripts.");
        }

        private static IEnumerable<Dictionary<string, object>> Rows(DataTable table) => table.Rows.Cast<DataRow>().Select(Row);
        private static Dictionary<string, object> Row(DataRow row) => row.Table.Columns.Cast<DataColumn>().Where(c => c.ColumnName != "TotalRow")
            .ToDictionary(c => char.ToLowerInvariant(c.ColumnName[0]) + c.ColumnName.Substring(1), c => row[c] == DBNull.Value ? null : row[c]);
        private static object Db(object value) => value ?? DBNull.Value;
        private static object Id(string value) { int id; return int.TryParse(value, NumberStyles.None, CultureInfo.InvariantCulture, out id) ? (object)id : DBNull.Value; }
    }
}
