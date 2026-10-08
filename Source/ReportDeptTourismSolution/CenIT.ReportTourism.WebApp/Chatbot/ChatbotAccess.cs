using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Globalization;
using System.Linq;
using System.Web;
using CenIT.ReportTourism.Biz.Report;
using CenIT.ReportTourism.Models.Cate;
using Newtonsoft.Json.Linq;
using TSFramework.App.Processors;

namespace CenIT.ReportTourism.WebApp.Chatbot
{
    // Request-local identity. No caller-supplied roles, user IDs, or reusable cross-user cache entries.
    internal sealed class ChatbotAccess
    {
        private readonly int _userId;
        private readonly string _provinceRoles;
        private readonly string _enterpriseRoles;
        internal bool HasAuthorizedEnterprises { get; private set; }
        internal bool CanReadProvince { get; private set; }
        internal bool IsIndustryRestricted { get; private set; }
        internal bool CanReadDashboard { get; private set; }
        internal bool CanReadImports { get; private set; }
        internal bool CanReadRegistryDetail { get; private set; }

        internal ChatbotAccess(int userId, string userName)
        {
            _userId = userId;
            _provinceRoles = ReportRoleMapping.Current.ReportingRoleIds;
            _enterpriseRoles = ReportRoleMapping.Current.EnterpriseRoleIds;
            if (_provinceRoles.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries).Intersect(_enterpriseRoles.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries)).Any())
                throw new ConfigurationErrorsException("Chatbot province and enterprise role sets must not overlap.");
            var table = Category("access", null);
            ChatbotQueries.RequireColumns(table, "UserName", "CanReadProvince", "CanReadDashboard", "CanReadImports", "CanReadRegistryDetail", "IsIndustryRestricted", "HasAuthorizedEnterprises", "RoleMappingSignature");
            if (table.Rows.Count != 1 || !string.Equals(Convert.ToString(table.Rows[0]["UserName"]), userName, StringComparison.Ordinal))
                throw new HttpException(403, "Account is inactive, locked, or outside the authenticated scope.");
            var row = table.Rows[0];
            if (!string.Equals(Convert.ToString(row["RoleMappingSignature"]), ReportRoleMapping.Current.Signature, StringComparison.Ordinal))
                throw new HttpException(503, "Application and SQL report role configurations differ.");
            HasAuthorizedEnterprises = Convert.ToBoolean(row["HasAuthorizedEnterprises"]);
            CanReadProvince = Convert.ToBoolean(row["CanReadProvince"]);
            IsIndustryRestricted = Convert.ToBoolean(row["IsIndustryRestricted"]);
            CanReadDashboard = Convert.ToBoolean(row["CanReadDashboard"]);
            CanReadImports = Convert.ToBoolean(row["CanReadImports"]);
            CanReadRegistryDetail = Convert.ToBoolean(row["CanReadRegistryDetail"]);
        }

        private DataTable Category(string mode, int? id) => AppProcessor.ProcedureProvider.ExecuteProcedure(
            "Cate_Chatbot_EnterpriseScope", "SysProvider", _userId, _provinceRoles, _enterpriseRoles, mode, (object)id ?? DBNull.Value) ?? new DataTable();

        private List<CateEnterpriseModel> _assigned;
        internal List<CateEnterpriseModel> Assigned()
        {
            return _assigned ?? (_assigned = (AppProcessor.ProcedureProvider.ExecuteTypedList<CateEnterpriseModel>(
                "Cate_Chatbot_EnterpriseScope", "SysProvider", _userId, _provinceRoles, _enterpriseRoles, "assigned", DBNull.Value)
                ?? new List<CateEnterpriseModel>()).Where(e => e.IsActive && !e.IsDeleted)
                .GroupBy(e => e.EnterpriseId).Select(g => g.First()).ToList());
        }

        internal CateEnterpriseModel Enterprise(int id) => AppProcessor.ProcedureProvider.ExecuteScalarObject<CateEnterpriseModel>(
            "Cate_Chatbot_EnterpriseScope", "SysProvider", _userId, _provinceRoles, _enterpriseRoles, "detail", id);

        internal DataTable Products(int enterpriseId, int offset, int limit) => AppProcessor.ProcedureProvider.ExecuteProcedure(
            "Cate_Chatbot_EnterpriseProducts", "SysProvider", _userId, _provinceRoles, _enterpriseRoles, enterpriseId, offset, limit) ?? new DataTable();

        internal DataTable Report(string name, params object[] parameters)
        {
            if (!CanReadDashboard) throw new HttpException(403, "Dashboard access is required.");
            string procedure;
            switch (name)
            {
                case "Report_Dashboard_IndustrialSnapshot": procedure = "Report_Chatbot_Snapshot"; break;
                case "Report_Dashboard_OverviewSummary": procedure = "Report_Chatbot_Summary"; break;
                case "Report_Dashboard_FilterOptions": procedure = "Report_Chatbot_FilterOptions"; break;
                case "Report_Dashboard_ProgressDetails": procedure = "Report_Chatbot_ProgressDetails"; break;
                case "Report_Chatbot_IndicatorData": case "Report_Chatbot_Metadata": case "Report_Chatbot_ReportFiles": procedure = name; break;
                default: throw new HttpException(403, "Unscoped report procedure is not allowed.");
            }
            return new ReportBiz().GetDataReport(procedure, new object[] { _userId, _provinceRoles, _enterpriseRoles }.Concat(parameters).ToArray());
        }

        private DateTime? _latestMonth;

        internal DateTime Month(JObject input)
        {
            var now = DateTime.UtcNow.AddHours(7);
            var current = new DateTime(now.Year, now.Month, 1);
            var value = (string)input["month"];
            if (value == null)
            {
                if ((string)input["timeframe"] == "this_month") return current;
                if ((string)input["timeframe"] == "last_month") return current.AddMonths(-1);
                // Enterprise accounts must not discover another account's latest reporting month.
                if (!CanReadDashboard) return current;
                if (_latestMonth.HasValue) return _latestMonth.Value;
                var latest = new ReportDashboardBiz(Report).GetFilterOptions("latest", null, null, 1).FirstOrDefault();
                DateTime observed;
                _latestMonth = latest != null && DateTime.TryParse(latest.Value, CultureInfo.InvariantCulture, DateTimeStyles.None, out observed)
                    ? new DateTime(observed.Year, observed.Month, 1) : current;
                return _latestMonth.Value;
            }
            DateTime parsed;
            if (!DateTime.TryParseExact(value, "yyyy-MM", CultureInfo.InvariantCulture, DateTimeStyles.None, out parsed) || parsed.Year < 2000 || parsed > current)
                throw new ArgumentException("month must be yyyy-MM between 2000-01 and the current month.");
            return parsed;
        }

    }
}
