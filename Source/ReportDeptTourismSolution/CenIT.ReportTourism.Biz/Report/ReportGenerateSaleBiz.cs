using System;
using System.Collections.Generic;
using CenIT.ReportTourism.Models.Report;
using TSFramework.App.Processors;

namespace CenIT.ReportTourism.Biz.Report
{
    public class ReportGenerateSaleBiz
    {
        private const string DATA_PROVIDER_NAME = "ReportTourismProvider";
        private readonly string _reportGenerateSale = "Report_DataImports_GenerateSaleOfTourism";

        public List<ReportGenerateSaleModel> GetGenerateSaleOnMonth(DateTime? forMonth)
        {
            var dataReports = AppProcessor.ProcedureProvider.ExecuteTypedList<ReportGenerateSaleModel>(
                ReportIndustryScope.Procedure(_reportGenerateSale), DATA_PROVIDER_NAME,
                ReportIndustryScope.Parameters(forMonth));
            return dataReports;
        }
    }
}