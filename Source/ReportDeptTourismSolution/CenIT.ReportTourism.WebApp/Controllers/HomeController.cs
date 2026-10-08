using System;
using System.Collections.Generic;
using System.Configuration;
using System.Linq;
using System.Reflection;
using System.Web.Mvc;
using CenIT.ReportTourism.Caches.Sys;
using CenIT.ReportTourism.Core.Apps;
using CenIT.ReportTourism.WebApp.Models;
using TSFramework.App.Attributes;
using TSFramework.App.BaseApps;
using TSFramework.App.Processors;
using TSFramework.Core.Enums;

namespace CenIT.ReportTourism.WebApp.Controllers
{
    public class HomeController : AppController
    {
        private readonly SysModuleCache _sysModuleCache = new SysModuleCache();
        private readonly SysUserCache _sysUserCache = new SysUserCache();

        private const string EnterpriseGuideType = "DN";
        private const string DepartmentGuideType = "SCT";
        private const string EnterpriseGuideFile = "~/Contents/DOANHNGHIEP_HUONGDAN.pdf";
        private const string DepartmentGuideFile = "~/Contents/SOCONGTHUONG_HUONGDAN.pdf";

        [ActionType(Type = EnumActionType.View)]
        public ActionResult Index()
        {
            //var activatedLayout = _sysLayoutCache.GetActivatedLayout();
            //var skinName = activatedLayout == null ? "_Default" : activatedLayout.LayoutName;
            //var layout = _sysLayoutCache.GetByName(skinName);
            //layout = layout ?? new AppLayoutModel();
            //layout.ListContentPanels = _sysContentPanelCache.GetByLayoutId(layout.Layout_ID);
            //if (MappingModuleWidget != null && MappingModuleWidget.Count > 0) return View(layout);
            //InitModulePanel();
            //return View(layout);

            var lstModuleBelongUsers = _sysModuleCache.GetByUserName(User.UserName);
            return View(lstModuleBelongUsers);
        }

        [HttpGet]
        [AjaxOnly]
        public ActionResult RenderModule(string widgetId)
        {
            var listModulesHtml = new List<PanelModuleHtmlModel>();
            if (MappingModuleWidget.Count == 0) InitModulePanel();

            if (!MappingModuleWidget.ContainsKey(widgetId)) return Json(null, JsonRequestBehavior.AllowGet);

            string moduleName = null;
            var listModules = MappingModuleWidget[widgetId];
            foreach (var module in listModules)
            {
                Assembly asm;
                try
                {
                    moduleName = module?.ModuleName;
                    asm = module?.AssemblyName != null ? Assembly.Load(module.AssemblyName) : null;
                    //asm = Assembly.Load($"Modules.{moduleName}");
                }
                catch
                {
                    asm = null;
                }

                string dataModuleHtml;
                if (asm == null || string.IsNullOrEmpty(module.MainController))
                {
                    dataModuleHtml = string.Empty;
                }
                else
                {
                    var moduleController = ControllerBuilder.Current.GetControllerFactory()
                        .CreateController(ControllerContext.RequestContext, module.MainController) as BaseController;
                    if (moduleController == null)
                    {
                        dataModuleHtml = string.Empty;
                    }
                    else
                    {
                        moduleController.ControllerContext =
                            new ControllerContext(Request.RequestContext, moduleController);
                        dataModuleHtml = RenderPartialToString(moduleController, $"~/Views/{module.ModuleView}",
                            null, ViewData, TempData);
                        //dataModuleHtml = RenderPartialToString(moduleController, $@"~/Views/{moduleName}/_View.cshtml",
                        //    null, ViewData, TempData);
                    }
                }

                listModulesHtml.Add(new PanelModuleHtmlModel
                {
                    ModuleHtml = dataModuleHtml, ModuleName = moduleName, ModuleId = module.ModuleId,
                    OrderBy = module.OrderBy
                });
            }

            return Json(listModulesHtml, JsonRequestBehavior.AllowGet);
        }

        /// <summary>
        ///     Modal "Hướng dẫn sử dụng": mọi tài khoản đã đăng nhập đều xem được,
        ///     mục hướng dẫn cho Sở Công Thương chỉ hiển thị với tài khoản thuộc Sở
        /// </summary>
        [HttpGet]
        [AjaxOnly]
        [AllowAnyPermission]
        public ActionResult UserGuide()
        {
            ViewBag.IsDepartmentUser = IsDepartmentUser();
            return PartialView("_UserGuide");
        }

        /// <summary>
        ///     Xem file PDF hướng dẫn sử dụng (type: DN - doanh nghiệp, SCT - Sở Công Thương)
        /// </summary>
        [HttpGet]
        [AjaxOnly]
        [AllowAnyPermission]
        public ActionResult UserGuideView(string type = EnterpriseGuideType)
        {
            string filePath;
            if (string.Equals(type, DepartmentGuideType, StringComparison.OrdinalIgnoreCase))
            {
                if (!IsDepartmentUser())
                    return Json(new
                    {
                        status = false,
                        message = CreateMessage(AppProcessor.Messagor.GetMessage("Common_AccessDenied_Message"),
                            EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    }, JsonRequestBehavior.AllowGet);

                ViewBag.Title = "Hướng dẫn sử dụng cho Sở Công Thương";
                filePath = DepartmentGuideFile;
            }
            else
            {
                ViewBag.Title = "Hướng dẫn sử dụng cho doanh nghiệp";
                filePath = EnterpriseGuideFile;
            }

            var physicalPath = Server.MapPath(filePath);
            ViewBag.FileUrl = System.IO.File.Exists(physicalPath)
                ? $"{Url.Content(filePath)}?v={System.IO.File.GetLastWriteTimeUtc(physicalPath).Ticks}"
                : null;
            return PartialView("_UserGuideView");
        }

        /// <summary>
        ///     Tài khoản thuộc Sở: có vai trò khác vai trò Doanh nghiệp (Configs/AppSettings.config ReportRoles:*)
        /// </summary>
        private bool IsDepartmentUser()
        {
            try
            {
                var enterpriseRoleIds = CenIT.ReportTourism.Biz.Report.ReportRoleMapping.Current.EnterpriseRoleIds
                    .Split(',').Select(r => r.Trim()).ToList();
                var sysUser = _sysUserCache.GetByUserName(User?.UserName);
                if (sysUser?.UserId == null) return false;

                var roles = _sysUserCache.GetRoles(sysUser.UserId);
                return roles != null && roles.Any(r => !enterpriseRoleIds.Contains(r.RoleId.ToString()));
            }
            catch (Exception ex)
            {
                AppProcessor.Logger.Error(ex);
                return false;
            }
        }

        //[ActionType(Type = EnumActionType.Edit)]
        //public ActionResult ClearCache(string returnUrl = "")
        //{
        //    HttpRuntime.UnloadAppDomain();
        //    if (Url.IsLocalUrl(returnUrl)) return Redirect(returnUrl);
        //    return RedirectToAction("Index");
        //}
    }
}