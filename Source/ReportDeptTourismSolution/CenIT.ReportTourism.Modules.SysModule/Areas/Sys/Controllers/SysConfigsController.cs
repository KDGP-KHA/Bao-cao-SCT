using System;
using System.Web;
using System.Web.Mvc;
using System.Web.Script.Serialization;
using System.Web.Security;
using CenIT.ReportTourism.Caches.Sys;
using CenIT.ReportTourism.Core.Apps;
using CenIT.ReportTourism.Models.Sys;
using TSFramework.App.Attributes;
using TSFramework.App.Principals;
using TSFramework.App.Processors;
using TSFramework.Core.Enums;

namespace CenIT.ReportTourism.Modules.SysModule.Areas.Sys.Controllers
{
    public class SysConfigsController : AppController
    {
        private readonly string _funcName = AppProcessor.Messagor.GetMessage("SysConfig_Title");
        private readonly SysConfigsCache _sysConfigsCache;
        private readonly SysUserCache _sysUserCache;

        public SysConfigsController()
        {
            _sysConfigsCache = new SysConfigsCache();
            _sysUserCache = new SysUserCache();
        }

        // GET: 
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
            var data = _sysConfigsCache.Get(out total, dataSearch);

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
            var model = new SysConfigsModel();
            return PartialView("_Add", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult Add(SysConfigsModel model)
        {
            if (!ModelState.IsValid) return PartialView("_SysConfig", model);
            string response;
            var idConfigs = _sysConfigsCache.Save(new SysConfigsModel
            {
                ConfigId = model.ConfigId,
                ConfigKey = model.ConfigKey,
                ConfigValue = model.ConfigValue,
                ConfigDesc = model.ConfigDesc,
                CreatedBy = User.UserName,
                CreatedDate = DateTime.Now
            });

            if (idConfigs == 0)
                response = CreateMessage($"{_funcName} [{model.ConfigKey}]", EnumProcessType.Add,
                    EnumMsgIcon.Success);
            else if (idConfigs == -2)
                response = CreateMessage($"{_funcName} [ {model.ConfigKey}]", EnumProcessType.DataExisted,
                    EnumMsgIcon.Error
                );
            else
                response = CreateMessage($"{_funcName} [ {model.ConfigKey}]", EnumProcessType.Add, EnumMsgIcon.Success
                );
            return Json(new
            {
                status = true,
                message = response
            }, JsonRequestBehavior.AllowGet);
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Edit(int id)
        {
            var model = _sysConfigsCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_funcName}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            return PartialView("_Edit", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ValidateAntiForgeryToken]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Edit(SysConfigsModel model)
        {
            if (!ModelState.IsValid) return PartialView("_SysConfig", model);
            var update = _sysConfigsCache.GetById(model.ConfigId);
            update.ConfigId = model.ConfigId;
            update.ConfigKey = model.ConfigKey;
            update.ConfigValue = model.ConfigValue;
            update.ConfigDesc = model.ConfigDesc;
            update.LastModifiedBy = User.UserName;
            update.LastModifiedDate = DateTime.Now;

            var idMenu = _sysConfigsCache.Save(update);
            string response;
            if (idMenu == 0)
                response = CreateMessage($"{_funcName} [{model.ConfigKey}]", EnumProcessType.Add,
                    EnumMsgIcon.Success);
            else if (idMenu == -2)
                response = CreateMessage($"{_funcName} [ {model.ConfigKey}]", EnumProcessType.DataExisted,
                    EnumMsgIcon.Error
                );
            else
                response = CreateMessage($"{_funcName} [ {model.ConfigKey}]", EnumProcessType.Add, EnumMsgIcon.Success
                );
            return Json(new
            {
                status = true,
                message = response
            }, JsonRequestBehavior.AllowGet);
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult Delete(int id = 0)
        {
            var model = _sysConfigsCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_funcName}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            ViewBag.ConfirmMessage = string.Format(AppProcessor.Messagor.GetMessage("Common_ConfirmMessage"),
                $"<b>{_funcName} [{model.ConfigKey}]</b>");

            return PartialView("_Delete", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult Delete(SysConfigsModel model)
        {
            var delete = _sysConfigsCache.GetById(model.ConfigId);
            delete.DeletedBy = User.UserName;
            var deleted = _sysConfigsCache.Delete(delete);

            var response = CreateMessage($"{_funcName} [{model.ConfigKey}]", EnumProcessType.Delete,
                deleted ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = true, message = response });
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult TestUser()
        {
            var lstUsers = _sysUserCache.GetAll();
            return PartialView("_TestUser", lstUsers);
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult TestUser(string UserName)
        {
            if (string.IsNullOrEmpty(UserName))
            {
                var empTitle = AppProcessor.Messagor.GetMessage("User_Title");
                var response = CreateMessage(empTitle, EnumProcessType.DataNotExist, EnumMsgIcon.Error);
                return Json(new { status = true, message = response }, JsonRequestBehavior.AllowGet);
            }

            var userInfo = _sysUserCache.GetByUserName(UserName);

            if (userInfo == null || userInfo.UserId.GetValueOrDefault() <= 0)
            {
                var empTitle = AppProcessor.Messagor.GetMessage("User_Title");
                var response = CreateMessage($"{empTitle} không tồn tại hoặc đã ngưng hoạt động",
                    EnumProcessType.NonFormat, EnumMsgIcon.Error);
                return Json(new { status = true, message = response }, JsonRequestBehavior.AllowGet);
            }

            var loginUser = new AppPrincipalSerializeModel
            {
                UserId = userInfo.UserId.Value,
                FullName = userInfo.FullName,
                UserName = userInfo.UserName,
                Email = userInfo.Email,
                CreatedDate = userInfo.CreatedDate
            };

            var serializer = new JavaScriptSerializer();

            var userData = serializer.Serialize(loginUser);
            var authTicket = new FormsAuthenticationTicket(
                1,
                loginUser.UserName,
                DateTime.Now,
                DateTime.Now.AddMinutes(30),
                true,
                userData);

            var encTicket = FormsAuthentication.Encrypt(authTicket);
            var faCookie = new HttpCookie(FormsAuthentication.FormsCookieName, encTicket);
            HttpContext.Response.Cookies.Add(faCookie);
            // Giả lập tài khoản: không bắt quản trị đổi mật khẩu thay cho tài khoản được giả lập
            //SetRequireChangePasswordSession(loginUser.UserName, false);

            var msgRes = CreateMessage($"Giả lập tài khoản [{UserName}]", EnumProcessType.Edit, EnumMsgIcon.Success);

            return Json(new { status = true, message = msgRes }, JsonRequestBehavior.AllowGet);
        }

        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult ClearCache(string returnUrl = "")
        {
            HttpRuntime.UnloadAppDomain();
            if (Url.IsLocalUrl(returnUrl)) return Redirect(returnUrl);
            return RedirectToAction("Index");
        }
    }
}
