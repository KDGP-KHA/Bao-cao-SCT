using System.Data;
using System.Web;
using TSFramework.App.Processors;

namespace CenIT.ReportTourism.Biz.Report
{
    public class ReportBiz
    {
        private const string DATA_PROVIDER_NAME = "ReportTourismProvider";

        public DataTable GetDataReport(string procedureName, params object[] p)
        {
            var dataReport = AppProcessor.ProcedureProvider.ExecuteProcedure(ReportIndustryScope.Procedure(procedureName), DATA_PROVIDER_NAME, ReportIndustryScope.Parameters(p));
            return dataReport ?? throw new HttpException(503, "The report procedure is unavailable.");
        }
    }
}