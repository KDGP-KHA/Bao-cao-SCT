using System;
using System.Collections.Generic;
using System.Linq;
using CenIT.ReportTourism.Models.Report;
using CenIT.ReportTourism.Models.Sys;
using TSFramework.App.Processors;

namespace CenIT.ReportTourism.Biz.Report
{
    public class ReportDataImportBiz
    {
        private const string DATA_PROVIDER_NAME = "ReportTourismProvider";
        private readonly string _reportDataImportsCheckDataImport = "Report_DataImports_CheckDataImport";
        private readonly string _reportDataImportsDelete = "Report_DataImports_Delete";
        private readonly string _reportDataImportsGet = "Report_DataImports_Get";
        private readonly string _reportDataImportsGetDataImport = "Report_DataImports_GetDataImport";
        private readonly string _reportDataImportsGetForUserOnMonth = "Report_DataImports_GetForUserOnMonth";

        private readonly string _reportDataImportsGetViaEnterpriseOnMonth =
            "Report_DataImports_GetViaEnterpriseOnMonth";

        private readonly string _reportDataImportsImportDatas = "Report_DataImports_ImportDatas";

        public List<ReportDataImportModel> Get(string forEmp, string enterpriseIds, DateTime? fromMonth,
            DateTime? toMonth, string typeBusinessIds, out int total, SysSearchModel search)
        {
            search = search ?? new SysSearchModel
            {
                Search = null,
                Order = "1",
                OrderDir = "ASC",
                StartIndex = 0,
                PageSize = -1
            };
            var dataImports = AppProcessor.ProcedureProvider.ExecuteTypedList<ReportDataImportModel>(
                ReportDataImportScope.Procedure(_reportDataImportsGet), DATA_PROVIDER_NAME,
                ReportDataImportScope.Parameters(forEmp, enterpriseIds, fromMonth, toMonth, typeBusinessIds,
                search.Search,
                search.Order,
                search.OrderDir,
                search.StartIndex,
                search.PageSize));
            total = 0;
            if (dataImports != null && dataImports.Count > 0)
                total = int.Parse(dataImports.First().TotalRow.ToString());
            return dataImports;
        }

        public List<ReportDataImportModel> GetForUserOnMonth(string forUser, DateTime? onMonth)
        {
            var dataImports = AppProcessor.ProcedureProvider.ExecuteTypedList<ReportDataImportModel>(
                ReportDataImportScope.Current == null ? _reportDataImportsGetForUserOnMonth + "_IndustryScope" : _reportDataImportsGetForUserOnMonth + "_Operational", DATA_PROVIDER_NAME,
                new object[] { forUser, onMonth, forUser });
            return dataImports;
        }

        public ReportDataImportModel GetDataImportViaEnterpriseOnMonth(int? enterpriseId, DateTime? forMonth)
        {
            var dataImports = AppProcessor.ProcedureProvider.ExecuteScalarObject<ReportDataImportModel>(
                ReportDataImportScope.Procedure(_reportDataImportsGetViaEnterpriseOnMonth), DATA_PROVIDER_NAME,
                ReportDataImportScope.Parameters(enterpriseId, forMonth));
            return dataImports;
        }

        public List<ReportDataImportModel> GetViaEnterpriseOnMonth(int? enterpriseId, DateTime? forMonth)
        {
            var dataImports = AppProcessor.ProcedureProvider.ExecuteTypedList<ReportDataImportModel>(
                ReportDataImportScope.Procedure(_reportDataImportsGetDataImport), DATA_PROVIDER_NAME,
                ReportDataImportScope.Parameters(enterpriseId, forMonth));
            return dataImports;
        }

        public int Import(ReportDataImportModel model)
        {
            if (ReportDataImportScope.Current != null)
                ReportDataImportScope.Current.DemandWrite(model.EnterpriseId.GetValueOrDefault(), model.ForMonth, model.TypeReport, "Import");
            var result = AppProcessor.ProcedureProvider.Execute(_reportDataImportsImportDatas, DATA_PROVIDER_NAME,
                model.EnterpriseId,
                model.ForMonth,
                model.TypeReport,
                model.TypeReportName,
                model.DataImport,
                model.ReportFile,
                model.Reason,
                model.CreatedBy
            );
            return result.GetValueOrDefault(0);
        }

        public List<ReportDataImportModel> CheckDataImport(ReportDataImportModel model)
        {
            if (ReportDataImportScope.Current != null)
                ReportDataImportScope.Current.Demand(model.EnterpriseId.GetValueOrDefault());

            var dataImports = AppProcessor.ProcedureProvider.ExecuteTypedList<ReportDataImportModel>(
                _reportDataImportsCheckDataImport, DATA_PROVIDER_NAME,
                model.ForMonth,
                model.EnterpriseId,
                model.DataImport
            );
            return dataImports;
        }

        public bool Delete(ReportDataImportModel model)
        {
            if (ReportDataImportScope.Current != null)
                ReportDataImportScope.Current.DemandWrite(model.EnterpriseId.GetValueOrDefault(), model.ForMonth, null, "Delete");

            var result = AppProcessor.ProcedureProvider.Execute(_reportDataImportsDelete, DATA_PROVIDER_NAME,
                model.EnterpriseId, model.ForMonth, model.Reason, model.SavedBy);
            return result == model.EnterpriseId;
        }
    }
}