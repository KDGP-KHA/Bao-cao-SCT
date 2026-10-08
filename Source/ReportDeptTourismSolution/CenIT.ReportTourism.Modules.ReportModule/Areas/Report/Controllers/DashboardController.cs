using System;
using System.Data;
using System.Linq;
using CenIT.ReportTourism.Biz.Report;
using System.Web.Mvc;
using CenIT.ReportTourism.Caches.Report;
using CenIT.ReportTourism.Core.Apps;
using CenIT.ReportTourism.Models.Report;
using TSFramework.App.Attributes;
using TSFramework.Core.Enums;

namespace CenIT.ReportTourism.Modules.ReportModule.Areas.Report.Controllers
{
    public class DashboardController : IndustryScopedReportController
    {
        private readonly ReportDashboardCache _dashboardCache = new ReportDashboardCache();

        [ActionType(Type = EnumActionType.View)]
        public ActionResult Index(int? year, int? month, int? reportType, string areaId,
            string economicSectorId, string industryId, string enterpriseId)
        {
            var filters = CreateFilters(year, month, reportType, areaId, economicSectorId, industryId, enterpriseId);
            return DashboardView(() => _dashboardCache.GetDashboard(filters));
        }

        [ActionType(Type = EnumActionType.View)]
        public ActionResult Analysis(int? year, int? month, int? reportType, string areaId,
            string economicSectorId, string industryId, string enterpriseId, string metric, string breakdown = "sector")
        {
            var filters = CreateFilters(year, month, reportType, areaId, economicSectorId, industryId, enterpriseId, metric);
            filters.Breakdown = breakdown;
            return DashboardView(() => _dashboardCache.GetAnalysis(filters));
        }

        [ActionType(Type = EnumActionType.View)]
        public ActionResult Warnings(int? year, int? month, int? reportType, string areaId,
            string economicSectorId, string industryId, string enterpriseId, int page = 1)
        {
            var filters = CreateFilters(year, month, reportType, areaId, economicSectorId, industryId, enterpriseId);
            filters.Page = page;
            return DashboardView(() => _dashboardCache.GetWarnings(filters));
        }

        [ActionType(Type = EnumActionType.View)]
        public ActionResult Progress(int? year, int? month, int? reportType, string areaId,
            string economicSectorId, string industryId, string enterpriseId, string status = "all", int page = 1)
        {
            var filters = CreateFilters(year,month,reportType,areaId,economicSectorId,industryId,enterpriseId);
            filters.Status = status; filters.Page = page;
            return DashboardView(() => _dashboardCache.GetProgress(filters));
        }

        [HttpGet]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult ProgressEnterprises(int? year, int? month, int? reportType, string areaId,
            string economicSectorId, string industryId, string enterpriseId, string status = "all")
        {
            int draw, start, length;
            if (!ModelState.IsValid || !Int32.TryParse(Request.QueryString["draw"], out draw) || draw < 0 ||
                !Int32.TryParse(Request.QueryString["start"], out start) || start < 0 ||
                !Int32.TryParse(Request.QueryString["length"], out length) || !new[] { 10, 25, 50, 100 }.Contains(length) || start % length != 0)
                return new HttpStatusCodeResult(400, "Bộ lọc danh sách không hợp lệ.");
            var filters = CreateFilters(year, month, reportType, areaId, economicSectorId, industryId, enterpriseId);
            filters.Status = status;
            try
            {
                var result = new ReportDashboardBiz().GetProgressEnterprises(filters, Request.QueryString["search[value]"], start / length + 1, length);
                Response.Cache.SetCacheability(System.Web.HttpCacheability.NoCache);
                Response.Cache.SetNoStore();
                return Json(new { draw, recordsTotal = result.Item3, recordsFiltered = result.Item2, data = result.Item1 }, JsonRequestBehavior.AllowGet);
            }
            catch (ArgumentException ex) { return new HttpStatusCodeResult(400, ex.Message); }
        }

        [HttpGet]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult EnterpriseOptions(int? reportType,string q = null,int page = 1)
        {
            if (!ModelState.IsValid || page < 1 || (reportType.HasValue && (reportType < 1 || reportType > 3)) || (q != null && q.Length > 250))
                return new HttpStatusCodeResult(400,"Bộ lọc không hợp lệ.");
            var options = _dashboardCache.GetEnterpriseOptions(reportType,q,page);
            return Json(new { results = options.Select(x => new { id=x.Value,text=x.Text }),
                pagination = new { more=options.Count>0 && (long)page*50 < options[0].TotalRow } },JsonRequestBehavior.AllowGet);
        }

        [HttpGet]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult EnterpriseDetail(int enterpriseId,int year,int month,int reportType)
        {
            if (!ModelState.IsValid || enterpriseId <= 0 || year < 2000 || year > 2100 || month < 1 || month > 12 || reportType < 1 || reportType > 3)
                return new HttpStatusCodeResult(400,"Bộ lọc không hợp lệ.");
            var table = new ReportBiz().GetDataReport("Report_DataImports_GetDataImport",enterpriseId,new DateTime(year,month,1));
            var selected = table.Clone();
            foreach (DataRow row in table.Rows)
                if (row["TypeReport"] != DBNull.Value && Convert.ToInt32(row["TypeReport"]) == reportType) selected.ImportRow(row);
            return PartialView("_DashboardEnterpriseDetail",selected);
        }

        private ActionResult DashboardView(Func<object> load)
        {
            if (!ModelState.IsValid) return new HttpStatusCodeResult(400,"Bộ lọc không hợp lệ.");
            try { return View(load()); }
            catch (ArgumentException ex) { return new HttpStatusCodeResult(400,ex.Message); }
        }

        private static DashboardFilters CreateFilters(int? year, int? month, int? reportType,
            string areaId, string economicSectorId, string industryId, string enterpriseId, string metric = null)
        {
            return new DashboardFilters
            {
                Year = year ?? 0,
                Month = month ?? 0,
                ReportType = reportType ?? 1,
                AreaId = areaId ?? "all",
                EconomicSectorId = economicSectorId ?? "all",
                IndustryId = industryId ?? "all",
                EnterpriseId = enterpriseId ?? "all",
                Metric = metric ?? "primary"
            };
        }
    }
}
