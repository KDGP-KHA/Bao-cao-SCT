using System;
using System.Collections.Generic;
using System.ComponentModel;
using CenIT.ReportTourism.Biz.Report;
using CenIT.ReportTourism.Models.Report;
using TSFramework.Core.Members.Caching;

namespace CenIT.ReportTourism.Caches.Report
{
    [DataObject]
    public class ReportGeneratSaleCache : CacheLayer
    {
        private ReportGenerateSaleBiz _dataGenerateApi;
        private ReportGenerateSaleBiz Api => _dataGenerateApi ?? (_dataGenerateApi = new ReportGenerateSaleBiz());

        protected override string[] MasterCacheKeyArray => new[]
            { "GenerateSale" };

        [DataObjectMethod(DataObjectMethodType.Select, true)]
        public List<ReportGenerateSaleModel> GetGenerateSaleOnMonth(DateTime? onMonth)
        {
            if (ReportIndustryScope.Current != null) return Api.GetGenerateSaleOnMonth(onMonth);
            var rawKey = $"ListDataGenerateSaleOnMonth-{onMonth}";
            // See if the item is in the cache
            var data = GetCacheItem(rawKey) as List<ReportGenerateSaleModel>;
            if (data != null) return data;
            // Item not found in cache - retrieve it and insert it into the cache
            data = Api.GetGenerateSaleOnMonth(onMonth);
            AddCacheItem(rawKey, data);
            return data;
        }
    }
}