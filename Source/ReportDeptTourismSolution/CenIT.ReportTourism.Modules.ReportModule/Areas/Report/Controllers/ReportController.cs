using System.Threading.Tasks;
using System.Linq;
using System.Web.Mvc;
using System.Web.UI.WebControls;
using CenIT.ReportTourism.Caches.Cate;
using CenIT.ReportTourism.Core.Apps;
using CenIT.ReportTourism.Modules.ReportModule.Areas.Report.Models;
using CenIT.ReportTourism.Modules.ReportModule.Processor;
using CenIT.ReportTourism.Modules.ReportModule.Providers;
using TSFramework.App.Attributes;
using TSFramework.App.Processors;
using TSFramework.Core.Enums;

namespace CenIT.ReportTourism.Modules.ReportModule.Areas.Report.Controllers
{
    public class ReportController : IndustryScopedReportController
    {
        private readonly string _reportTitle = AppProcessor.Messagor.GetMessage("Report_Title");
        private readonly CateEnterpriseCache _enterpriseCache = new CateEnterpriseCache();

        public ActionResult Index()
        {
            ViewBag.Title = _reportTitle;
            var lstReports = ReportProcessor.Reports;
            return View(lstReports);
        }

        [ActionType(Type = EnumActionType.View)]
        [HttpGet]
        [AjaxOnly]
        public async Task<ActionResult> ViewReport(string report)
        {
            var pReport = ReportProcessor.GetReportByKey(report);
            ViewBag.Title = pReport.ReportName;
            var listEnterprise = IndustryScope.GetEnterprises().ToList();

            var reportModel = new ReportViewModel
            {
                ReportKey = pReport.ReportKey,
                ReportName = pReport.ReportName,
                ViewName = pReport.ViewName,
                Reporter = User.FullName,
                ListEnterprises = listEnterprise.Select(x => new ListItem
                {
                    Text = x.BusinessName,
                    Value = x.EnterpriseId.ToString()
                }).ToList()
            };

            //var enterprise = listEnterprise.FirstOrDefault();
            //ViewBag.EnterpriseId = enterprise?.EnterpriseId;
            //ViewBag.EnterpriseName = enterprise?.BusinessName ?? User.FullName;
            //ViewBag.TaxCode = enterprise?.TaxCode ?? string.Empty;

            return await Task.Run(() => PartialView("_Report", reportModel));
        }

        [ActionType(Type = EnumActionType.View)]
        [AjaxOnly]
        [HttpPost]
        public async Task<ActionResult> RenderReport()
        {
            var enterpriseValue = Request.Form["EnterpriseId"];
            if (!string.IsNullOrEmpty(enterpriseValue))
            {
                int enterpriseId;
                if (!int.TryParse(enterpriseValue, out enterpriseId) || enterpriseId <= 0)
                    return new HttpStatusCodeResult(400);
                IndustryScope.Demand(enterpriseId);
            }
            var sReportKey = Request.Form["ReportKey"];
            ViewBag.Title = Request.Form["ReportName"];

            ViewBag.ReportViewer =
                ReportProvider.CreateViewExport(sReportKey, Request.Form,
                    Server.MapPath("~/Contents/Modules/Report/Templates/"));
            return await Task.Run(() => PartialView("_Viewer"));
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult GetEnterpriseInfo(int enterpriseId = 0)
        {
            var enterpriseInfo = _enterpriseCache.GetById(enterpriseId);
            return Json(new { Info = enterpriseInfo });
        }
    }
}
