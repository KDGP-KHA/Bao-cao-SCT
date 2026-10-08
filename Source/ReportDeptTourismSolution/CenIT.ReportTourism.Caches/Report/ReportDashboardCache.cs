using System;
using System.Collections.Generic;
using System.Web;
using CenIT.ReportTourism.Biz.Report;
using CenIT.ReportTourism.Models.Report;
using TSFramework.Core.Members.Caching;

namespace CenIT.ReportTourism.Caches.Report
{
    public class ReportDashboardCache : CacheLayer
    {
        private ReportDashboardBiz _dataDashboardApi;
        private ReportDashboardBiz Api => _dataDashboardApi ?? (_dataDashboardApi = new ReportDashboardBiz());

        protected override string[] MasterCacheKeyArray => new[]
        {
            "ReportDashboardCache", "DataImportCache", "ReportExtendInfosCache", "EnterprisesCache", "SysMessagesCache", "SysConfigsCache", "BusinessIndustryCache", "EconomicSectorCache", "BusinessProductsCache", "CENIT.APP.Cache"
        };

        public DashboardModel GetDashboard(DashboardFilters filters)
        {
            filters = Normalize(filters);
            var key = CacheKey("Overview", filters);
            var cached = GetDashboardItem(key) as DashboardModel;
            if (cached != null) return cached;
            cached = Api.GetDashboard(filters);
            AddDashboardItem(key, cached);
            return cached;
        }

        public DashboardAnalysisModel GetAnalysis(DashboardFilters filters)
        {
            filters = Normalize(filters);
            var key = CacheKey("Analysis", filters);
            var cached = GetDashboardItem(key) as DashboardAnalysisModel;
            if (cached != null) return cached;
            cached = Api.GetAnalysis(filters);
            AddDashboardItem(key, cached);
            return cached;
        }

        public DashboardWarningsModel GetWarnings(DashboardFilters filters)
        {
            filters = Normalize(filters);
            var key = CacheKey("Warnings", filters);
            var cached = GetDashboardItem(key) as DashboardWarningsModel;
            if (cached != null) return cached;
            cached = Api.GetWarnings(filters);
            AddDashboardItem(key, cached);
            return cached;
        }

        public DashboardProgressModel GetProgress(DashboardFilters filters)
        {
            filters = Normalize(filters);
            var key = CacheKey("Progress", filters);
            var cached = GetDashboardItem(key) as DashboardProgressModel;
            if (cached != null) return cached;
            cached = Api.GetProgress(filters);
            AddDashboardItem(key, cached);
            return cached;
        }

        public DashboardFilters Normalize(DashboardFilters filters) { return Api.Normalize(filters); }

        public IList<DashboardOption> GetEnterpriseOptions(int? type,string search,int page)
        {
            var key = "EnterpriseOptions-" + type + "-" + page + "-" + search;
            var cached = GetDashboardItem(key) as IList<DashboardOption>;
            if (cached != null) return cached;
            cached = Api.GetFilterOptions("enterprise",type,search,page);
            AddDashboardItem(key,cached);
            return cached;
        }

        private object GetDashboardItem(string key)
        {
            var context = HttpContext.Current;
            var scope = ReportIndustryScope.Current;
            if (context == null || scope == null) return null;
            return context.Items["ReportDashboard:" + scope.UserName + ":" + key];
        }

        private void AddDashboardItem(string key, object value)
        {
            var context = HttpContext.Current;
            var scope = ReportIndustryScope.Current;
            if (context != null && scope != null)
                context.Items["ReportDashboard:" + scope.UserName + ":" + key] = value;
        }

        private static string CacheKey(string page, DashboardFilters filters)
        {
            filters = filters ?? new DashboardFilters();
            return string.Join("-", "ManagementDashboard", page, filters.Year, filters.Month, filters.ReportType,
                filters.AreaId ?? "all", filters.EconomicSectorId ?? "all", filters.IndustryId ?? "all",
                filters.EnterpriseId ?? "all", filters.Metric ?? "primary", filters.Status, filters.Page, filters.Breakdown);
        }
    }
}
