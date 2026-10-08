using System;
using System.Web.Mvc;
using CenIT.ReportTourism.Biz.Report;
using CenIT.ReportTourism.Core.Apps;

namespace CenIT.ReportTourism.Modules.ReportModule.Areas.Report.Controllers
{
    public abstract class IndustryScopedReportController : AppController
    {
        protected ReportIndustryScope IndustryScope { get; private set; }

        protected override void OnActionExecuting(ActionExecutingContext filterContext)
        {
            base.OnActionExecuting(filterContext);
            if (filterContext.Result != null) return;
            IndustryScope = ReportIndustryScope.Begin(User.UserName);
            ViewBag.IsIndustryRestricted = IndustryScope.IsRestricted;
            // Province supplementary figures have no enterprise/industry owner.
            if (IndustryScope.IsRestricted && this is ExtendInfoController)
            {
                filterContext.Result = new HttpStatusCodeResult(403);
                return;
            }
            foreach (var parameter in filterContext.ActionParameters)
            {
                var value = parameter.Value;
                if (value == null) continue;
                if (string.Equals(parameter.Key, "enterpriseId", StringComparison.OrdinalIgnoreCase))
                {
                    long id;
                    if (long.TryParse(Convert.ToString(value), out id) && id > 0) IndustryScope.Demand(id);
                }
                else
                {
                    var property = value.GetType().GetProperty("EnterpriseId");
                    var idValue = property == null ? null : property.GetValue(value, null);
                    if (idValue != null && Convert.ToInt64(idValue) > 0) IndustryScope.Demand(Convert.ToInt64(idValue));
                }
            }
        }
    }
}
