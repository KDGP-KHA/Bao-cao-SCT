using System;
using System.Web.Mvc;
using CenIT.ReportTourism.Caches.Report;
using CenIT.ReportTourism.Core.Apps;
using CenIT.ReportTourism.Models.Report;
using CenIT.ReportTourism.Models.Sys;
using TSFramework.App.Attributes;
using TSFramework.App.Processors;
using TSFramework.Core.Enums;

namespace CenIT.ReportTourism.Modules.ReportModule.Areas.Report.Controllers
{
    public class ExtendInfoController : IndustryScopedReportController
    {
        private readonly ReportExtendInfoCache _reportExtendInfoCache;
        private readonly string _reportExtendInfoTitle = AppProcessor.Messagor.GetMessage("ReportExtendInfo_Title");

        public ExtendInfoController()
        {
            _reportExtendInfoCache = new ReportExtendInfoCache();
        }

        // GET: Cate/ReportExtendInfo
        [ActionType(Type = EnumActionType.View)]
        [HttpGet]
        public ActionResult Index()
        {
            return View();
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult Get()
        {
            var search = Request.Form.GetValues("search[value]")?[0];
            var draw = Request.Form.GetValues("draw")?[0];
            var order = Request.Form.GetValues("order[0][column]")?[0];
            var orderDir = Request.Form.GetValues("order[0][dir]")?[0];
            var startRec = Convert.ToInt32(Request.Form.GetValues("start")?[0]);
            var pageSize = Convert.ToInt32(Request.Form.GetValues("length")?[0]);
            var dataSearch = new SysSearchModel
            {
                Search = string.IsNullOrEmpty(search) ? null : search,
                Order = order,
                OrderDir = orderDir,
                StartIndex = startRec,
                PageSize = pageSize
            };
            int total;
            var data = _reportExtendInfoCache.Get(out total, dataSearch);
            var result = Json(
                new { draw = Convert.ToInt32(draw), recordsTotal = total, recordsFiltered = total, data },
                JsonRequestBehavior.AllowGet);
            return result;
        }

        [AjaxOnly]
        [ActionType(Type = EnumActionType.Add)]
        [HttpGet]
        public ActionResult Add()
        {
            var model = new ReportExtendInfoModel();

            return PartialView("_Add", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Add)]
        [ValidateInput(false)]
        public ActionResult Add(ReportExtendInfoModel model)
        {
            if (!ModelState.IsValid) return PartialView("_ExtendInfos", model);

            var extendInfoId = _reportExtendInfoCache.Save(new ReportExtendInfoModel
            {
                Id = 0,
                ForMonth = model.ForMonth,
                TotalGuestViaShip = model.TotalGuestViaShip,
                Reason = model.Reason,
                SavedBy = User.UserName
            });
            if (extendInfoId == -2)
            {
                var errMessage = CreateMessage($"{_reportExtendInfoTitle} tháng [{model.ForMonth:MM/yyyy}]",
                    EnumProcessType.DataExisted, EnumMsgIcon.Error);
                return Json(new { status = true, message = errMessage });
            }

            var response = CreateMessage($"{_reportExtendInfoTitle} ", EnumProcessType.Add,
                extendInfoId > 0 ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = true, message = response });
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Edit(int id = 0)
        {
            var model = _reportExtendInfoCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_reportExtendInfoTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            return PartialView("_Edit", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ValidateAntiForgeryToken]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Edit(ReportExtendInfoModel model)
        {
            if (!ModelState.IsValid) return PartialView("_ExtendInfos", model);

            var extendInfoId = _reportExtendInfoCache.Save(new ReportExtendInfoModel
            {
                Id = model.Id,
                ForMonth = model.ForMonth,
                TotalGuestViaShip = model.TotalGuestViaShip,
                Reason = model.Reason,
                SavedBy = User.UserName
            });
            if (extendInfoId == -2)
            {
                var errMessage = CreateMessage($"{_reportExtendInfoTitle} tháng [{model.ForMonth:MM/yyyy}]",
                    EnumProcessType.DataExisted, EnumMsgIcon.Error);
                return Json(new { status = true, message = errMessage });
            }

            var response = CreateMessage($"{_reportExtendInfoTitle} tháng [{model.ForMonth:MM/yyyy}",
                EnumProcessType.Edit,
                extendInfoId > 0 ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = true, message = response }, JsonRequestBehavior.AllowGet);
        }
    }
}