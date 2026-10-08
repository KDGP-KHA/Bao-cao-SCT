using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Web;
using CenIT.ReportTourism.Models.Cate;
using TSFramework.App.Processors;

namespace CenIT.ReportTourism.Biz.Report
{
    // Operational object eligibility is independent of reporting/Chatbot industry visibility.
    public sealed class ReportDataImportScope
    {
        private const string ContextKey = "CenIT.Reports.DataImportScope";
        private readonly List<CateEnterpriseModel> _enterprises = new List<CateEnterpriseModel>();
        private readonly HashSet<long> _writeIds = new HashSet<long>();
        private readonly HashSet<long> _ids = new HashSet<long>();
        public string UserName { get; private set; }
        public bool IsEnterpriseUser { get; private set; }
        public static ReportDataImportScope Current
        {
            get { return HttpContext.Current == null ? null : HttpContext.Current.Items[ContextKey] as ReportDataImportScope; }
        }

        public static ReportDataImportScope Begin(string userName)
        {
            var rows = AppProcessor.ProcedureProvider.ExecuteProcedure(
                "Report_DataImports_OperationalScope", "ReportTourismProvider", userName);
            if (rows == null) throw new HttpException(503, "DataImports authorization is unavailable.");
            if (!rows.Columns.Contains("RoleMappingSignature") || !rows.Columns.Contains("CanManageAllRecords"))
                throw new HttpException(503, "DataImports authorization contract is unavailable.");
            var scope = new ReportDataImportScope { UserName = userName };
            foreach (DataRow row in rows.Rows)
            {
                if (!rows.Columns.Contains("RoleMappingSignature") || !string.Equals(
                    Convert.ToString(row["RoleMappingSignature"]), ReportRoleMapping.Current.Signature, StringComparison.Ordinal))
                    throw new HttpException(503, "Application and SQL report role configurations differ.");
                var id = Convert.ToInt32(row["EnterpriseId"]);
                if (!scope._ids.Add(id)) continue;
                if (Convert.ToBoolean(row["CanManageAllRecords"])) scope._writeIds.Add(id);
                scope._enterprises.Add(new CateEnterpriseModel { EnterpriseId = id,
                    BusinessName = Convert.ToString(row["BusinessName"]), TaxCode = Convert.ToString(row["TaxCode"]),
                    TypeBusiness = Convert.ToString(row["TypeBusiness"]) });
                scope.IsEnterpriseUser = Convert.ToBoolean(row["IsEnterpriseUser"]);
            }
            HttpContext.Current.Items[ContextKey] = scope;
            return scope;
        }

        public IEnumerable<CateEnterpriseModel> GetEnterprises() { return _enterprises; }
        public void Demand(long enterpriseId)
        {
            if (enterpriseId <= 0 || !_ids.Contains(enterpriseId)) throw new HttpException(403, "Enterprise is outside your DataImports permissions.");
        }
        public void DemandWrite(long enterpriseId, DateTime? forMonth, int? typeReport, string operation)
        {
            Demand(enterpriseId);
            if (_writeIds.Contains(enterpriseId)) return;
            var rows = AppProcessor.ProcedureProvider.ExecuteProcedure("Report_DataImports_CheckOwnership",
                "ReportTourismProvider", enterpriseId, forMonth, typeReport, operation, UserName);
            if (rows == null || rows.Rows.Count != 1 || !Convert.ToBoolean(rows.Rows[0]["CanWrite"]))
                throw new HttpException(403, "The affected report records are outside your DataImports ownership.");
        }

        public static string Procedure(string name)
        {
            return Current == null ? ReportIndustryScope.Procedure(name) : name + "_Operational";
        }
        public static object[] Parameters(params object[] values)
        {
            return Current == null ? ReportIndustryScope.Parameters(values) : values.Concat(new object[] { Current.UserName }).ToArray();
        }
    }
}
