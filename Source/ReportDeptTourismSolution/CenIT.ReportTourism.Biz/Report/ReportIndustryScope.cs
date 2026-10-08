using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using CenIT.ReportTourism.Models.Cate;
using TSFramework.App.Processors;

namespace CenIT.ReportTourism.Biz.Report
{
    // Activated by reporting and enterprise-information controllers after existing authorization filters.
    public sealed class ReportIndustryScope
    {
        private const string ContextKey = "CenIT.Reports.IndustryScope";
        private HashSet<long> _enterpriseIds;
        private List<CateEnterpriseModel> _enterprises;
        public string UserName { get; private set; }
        public bool IsRestricted { get; private set; }
        public bool IsEnterpriseUser { get; private set; }
        public static ReportIndustryScope Current
        {
            get { return HttpContext.Current == null ? null : HttpContext.Current.Items[ContextKey] as ReportIndustryScope; }
        }

        public static ReportIndustryScope Begin(string userName)
        {
            var rows = AppProcessor.ProcedureProvider.ExecuteProcedure(
                "Report_IndustryPermissions_Scope", "ReportTourismProvider", userName);
            if (rows == null || rows.Rows.Count != 1) throw new HttpException(403, "Report account is inactive or unknown.");
            if (!rows.Columns.Contains("RoleMappingSignature") || !string.Equals(Convert.ToString(rows.Rows[0]["RoleMappingSignature"]), ReportRoleMapping.Current.Signature, StringComparison.Ordinal))
                throw new HttpException(503, "Application and SQL report role configurations differ.");
            var scope = new ReportIndustryScope { UserName = userName, IsRestricted = Convert.ToBoolean(rows.Rows[0]["IsRestricted"]),
                IsEnterpriseUser = Convert.ToBoolean(rows.Rows[0]["HasEnterpriseRole"]) &&
                    !Convert.ToBoolean(rows.Rows[0]["HasFullAccess"]) && !Convert.ToBoolean(rows.Rows[0]["HasIndustryRole"]) };
            HttpContext.Current.Items[ContextKey] = scope;
            return scope;
        }

        // Request-local reuse only: never retain user authorization across requests.
        public IEnumerable<CateEnterpriseModel> GetEnterprises()
        {
            if (_enterprises == null)
            {
                _enterprises = AppProcessor.ProcedureProvider.ExecuteTypedList<CateEnterpriseModel>(
                    "Report_IndustryPermissions_Enterprises", "ReportTourismProvider", UserName);
                if (_enterprises == null) throw new HttpException(503, "Report authorization is unavailable.");
                _enterpriseIds = new HashSet<long>(_enterprises.Select(e => (long)e.EnterpriseId));
            }
            return _enterprises;
        }

        public bool Allows(long enterpriseId)
        {
            if (enterpriseId <= 0) return false;
            if (_enterpriseIds == null) GetEnterprises();
            return _enterpriseIds.Contains(enterpriseId);
        }

        public IEnumerable<T> Filter<T>(IEnumerable<T> enterprises, Func<T, long> enterpriseId)
        {
            return (enterprises ?? Enumerable.Empty<T>()).Where(e => Allows(enterpriseId(e)));
        }

        public void Demand(long enterpriseId)
        {
            if (!Allows(enterpriseId)) throw new HttpException(403, "Enterprise industry is outside your report permissions.");
        }

        public static string Procedure(string name)
        {
            return Current == null ? name : name + "_IndustryScope";
        }

        public static object[] Parameters(params object[] values)
        {
            return Current == null ? values : values.Concat(new object[] { Current.UserName }).ToArray();
        }
    }
}
