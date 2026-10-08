using System;
using System.Collections.Generic;
using System.ComponentModel;
using CenIT.ReportTourism.Biz.Report;
using CenIT.ReportTourism.Models.Report;
using CenIT.ReportTourism.Models.Sys;
using TSFramework.Core.Members.Caching;
using TSFramework.Core.Utils;

namespace CenIT.ReportTourism.Caches.Report
{
    [DataObject]
    public class ReportDataImportCache : CacheLayer
    {
        private ReportDataImportBiz _dataImportApi;
        private ReportDataImportBiz Api => _dataImportApi ?? (_dataImportApi = new ReportDataImportBiz());

        protected override string[] MasterCacheKeyArray => new[]
            { "DataImportCache", "EnterprisesCache", "SysConfigsCache", "CENIT.APP.Cache" };

        [DataObjectMethod(DataObjectMethodType.Select, true)]
        public List<ReportDataImportModel> Get(string forEmp, string enterpriseIds, DateTime? fromMonth,
            DateTime? toMonth, string typeBusinessIds, out int total, SysSearchModel search = null)
        {
            if (ReportIndustryScope.Current != null || ReportDataImportScope.Current != null) return Api.Get(forEmp, enterpriseIds, fromMonth, toMonth, typeBusinessIds, out total, search);
            var objectKey = EHashMD5.FromObject(search);
            var rawKey =
                string.Concat($"ListDataImports-{forEmp}-{enterpriseIds}-{fromMonth}-{toMonth}-{typeBusinessIds}-",
                    objectKey);
            var rawKeyTotal = string.Concat(rawKey, "-Total");
            total = 0;
            var cacheTotal = (int?)GetCacheItem(rawKeyTotal);
            total = cacheTotal ?? 0;
            // See if the item is in the cache
            var dataImports = GetCacheItem(rawKey) as List<ReportDataImportModel>;
            if (dataImports != null) return dataImports;
            // Item not found in cache - retrieve it and insert it into the cache
            dataImports = Api.Get(forEmp, enterpriseIds, fromMonth, toMonth, typeBusinessIds, out total, search);
            AddCacheItem(rawKey, dataImports);
            AddCacheItem(rawKeyTotal, total);
            return dataImports;
        }

        [DataObjectMethod(DataObjectMethodType.Select, true)]
        public List<ReportDataImportModel> GetForUserOnMonth(string forUser, DateTime? onMonth)
        {
            if (ReportIndustryScope.Current != null || ReportDataImportScope.Current != null) return Api.GetForUserOnMonth(forUser, onMonth);
            var rawKey = $"ListDataImportsForUserOnMonth-{forUser}-{onMonth}";
            // See if the item is in the cache
            var dataImports = GetCacheItem(rawKey) as List<ReportDataImportModel>;
            if (dataImports != null) return dataImports;
            // Item not found in cache - retrieve it and insert it into the cache
            dataImports = Api.GetForUserOnMonth(forUser, onMonth);
            AddCacheItem(rawKey, dataImports);
            return dataImports;
        }

        [DataObjectMethod(DataObjectMethodType.Select, true)]
        public ReportDataImportModel GetDataImportViaEnterpriseOnMonth(int? enterprise, DateTime? forMonth)
        {
            if (ReportIndustryScope.Current != null || ReportDataImportScope.Current != null) return Api.GetDataImportViaEnterpriseOnMonth(enterprise, forMonth);
            var rawKey = $"DataImport-{enterprise}-{forMonth}";
            // See if the item is in the cache
            var dataImport = GetCacheItem(rawKey) as ReportDataImportModel;
            if (dataImport != null) return dataImport;
            // Item not found in cache - retrieve it and insert it into the cache
            dataImport = Api.GetDataImportViaEnterpriseOnMonth(enterprise, forMonth);
            AddCacheItem(rawKey, dataImport);
            return dataImport;
        }

        [DataObjectMethod(DataObjectMethodType.Select, true)]
        public List<ReportDataImportModel> GetViaEnterpriseOnMonth(int? enterprise, DateTime? forMonth)
        {
            if (ReportIndustryScope.Current != null || ReportDataImportScope.Current != null) return Api.GetViaEnterpriseOnMonth(enterprise, forMonth);
            var rawKey = $"ListDataImportsViaEnterpriseOnMonth-{enterprise}-{forMonth}";
            // See if the item is in the cache
            var dataImports = GetCacheItem(rawKey) as List<ReportDataImportModel>;
            if (dataImports != null) return dataImports;
            // Item not found in cache - retrieve it and insert it into the cache
            dataImports = Api.GetViaEnterpriseOnMonth(enterprise, forMonth);
            AddCacheItem(rawKey, dataImports);
            return dataImports;
        }

        [DataObjectMethod(DataObjectMethodType.Update, false)]
        public int? Import(ReportDataImportModel model)
        {
            var enterpriseId = Api.Import(model);
            if (enterpriseId > 0)
                // Invalidate the cache
                InvalidateCache();
            return enterpriseId;
        }

        [DataObjectMethod(DataObjectMethodType.Select, false)]
        public List<ReportDataImportModel> CheckDataImport(ReportDataImportModel model)
        {
            // See if the item is in the cache
            // Item not found in cache - retrieve it and insert it into the cache
            var dataImports = Api.CheckDataImport(model);
            return dataImports;
        }

        [DataObjectMethod(DataObjectMethodType.Delete, false)]
        public bool Delete(ReportDataImportModel model)
        {
            var isDeleted = Api.Delete(model);
            if (isDeleted)
                // Invalidate the cache
                InvalidateCache();
            return isDeleted;
        }
    }
}