using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Linq;
using System.Text.RegularExpressions;
using System.Web.Hosting;
using System.Web;
using System.Web.Mvc;
using System.Web.UI.WebControls;
using CenIT.ReportTourism.Caches.Cate;
using CenIT.ReportTourism.Caches.Sys;
using CenIT.ReportTourism.Core.Apps;
using CenIT.ReportTourism.Models.Cate;
using CenIT.ReportTourism.Models.Sys;
using CenIT.ReportTourism.Modules.SysModule.Areas.Sys.Models;
using Newtonsoft.Json;
using TSFramework.App.Attributes;
using TSFramework.App.Processors;
using TSFramework.Core.Enums;
using TSFramework.Core.Members.Mail;
using TSFramework.Core.Providers;
using TSFramework.Core.Utils;

namespace CenIT.ReportTourism.Modules.SysModule.Areas.Sys.Controllers
{
    public class UserController : AppController
    {
        [HttpGet]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult IndustryPermissions(int id = 0)
        {
            if (!CanEditIndustryPermissions()) return new HttpStatusCodeResult(403);
            var model = LoadIndustryPermissions(id);
            if (model == null) return HttpNotFound();
            return PartialView("_IndustryPermissions", model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult IndustryPermissions(IndustryPermissionsModel model)
        {
            if (!CanEditIndustryPermissions()) return new HttpStatusCodeResult(403);
            var current = LoadIndustryPermissions(model.UserId);
            if (current == null) return HttpNotFound();
            var selected = (model.IndustryIds ?? new int[0]).Distinct().ToArray();
            if (selected.Length > 2000 || selected.Any(id => id <= 0))
                ModelState.AddModelError("IndustryIds", AppProcessor.Messagor.GetMessage("User_IndustryPermissions_InvalidSelection"));
            if (selected.Any(id => !current.Industries.Any(option => option.Value == id.ToString()
                && !option.Disabled)))
                ModelState.AddModelError("IndustryIds", AppProcessor.Messagor.GetMessage("User_IndustryPermissions_InactiveSelection"));
            if (selected.Length == 0 && !model.ConfirmRestoreScope)
                ModelState.AddModelError("ConfirmRestoreScope", AppProcessor.Messagor.GetMessage("User_IndustryPermissions_RestoreRequired"));
            if (!ModelState.IsValid)
            {
                current.IndustryIds = selected;
                current.ConfirmRestoreScope = model.ConfirmRestoreScope;
                foreach (var option in current.Industries)
                    option.Selected = selected.Contains(int.Parse(option.Value));
                return PartialView("_IndustryPermissions", current);
            }
            // Identity and audit actor are server-owned. SQL rechecks Sys/User/Edit.
            try
            {
                var savedId = AppProcessor.ProcedureProvider.Execute("Report_IndustryPermissions_Save", "SysProvider",
                    current.UserId, string.Join(",", selected), User.UserName);
                if (savedId != current.UserId)
                    throw new HttpException(503, "Industry permission save did not confirm the target user.");
            }
            catch (SqlException exception)
            {
                if (exception.Number == 50113) return new HttpStatusCodeResult(403);
                if (exception.Number < 50001 || exception.Number > 50004) throw;
                ModelState.AddModelError("IndustryIds", AppProcessor.Messagor.GetMessage("User_IndustryPermissions_DataChanged"));
                return PartialView("_IndustryPermissions", current);
            }
            return Json(new { status = true, message = CreateMessage(AppProcessor.Messagor.GetMessage("User_IndustryPermissions_Saved"),
                EnumProcessType.Edit, EnumMsgIcon.Success) });
        }

        private bool CanEditIndustryPermissions()
        {
            if (User == null || string.IsNullOrEmpty(User.UserName)) return false;
            // Existing login cookies may predate serialization of UserId.
            // Resolve the same signed-in username that SQL uses for authorization.
            var actor = _userCache.GetByUserName(User.UserName);
            return actor != null && actor.IsActive && actor.UserId.GetValueOrDefault() > 0
                && GetCurrentIndustryPermissionRoles(actor.UserId.Value)
                .Any(role => !role.IsDeleted && role.RoleId == CenIT.ReportTourism.Biz.Report.ReportRoleMapping.Current.SystemAdministratorId);
        }

        private bool HasIndustryPermissionRole(int? userId)
        {
            return userId.HasValue && GetCurrentIndustryPermissionRoles(userId.Value)
                .Any(role => !role.IsDeleted && CenIT.ReportTourism.Biz.Report.ReportRoleMapping.Current.IsIndustryEditorTarget(role.RoleId));
        }

        private readonly Dictionary<int, List<SysRoleModel>> _industryPermissionRoles =
            new Dictionary<int, List<SysRoleModel>>();

        private List<SysRoleModel> GetCurrentIndustryPermissionRoles(int userId)
        {
            List<SysRoleModel> roles;
            if (!_industryPermissionRoles.TryGetValue(userId, out roles))
            {
                // Role changes must affect visibility and authorization immediately.
                // Reuse lookups within this request, never the hour-long user cache.
                roles = AppProcessor.ProcedureProvider.ExecuteTypedList<SysRoleModel>(
                    "Sys_Role_GetByUserId", "SysProvider", userId) ?? new List<SysRoleModel>();
                _industryPermissionRoles.Add(userId, roles);
            }
            return roles;
        }

        private IndustryPermissionsModel LoadIndustryPermissions(int id)
        {
            var target = _userCache.GetById(id);
            if (target == null || !target.IsActive) return null;
            if (!HasIndustryPermissionRole(id)) return null;
            DataTable rows;
            try
            {
                rows = AppProcessor.ProcedureProvider.ExecuteProcedure(
                    "Report_IndustryPermissions_Get", "SysProvider", id, User.UserName);
            }
            catch (SqlException exception)
            {
                if (exception.Number == 50113) throw new HttpException(403, "User management Edit permission is required.");
                if (exception.Number == 50002) return null;
                throw;
            }
            return new IndustryPermissionsModel
            {
                UserId = id, UserName = target.UserName, FullName = target.FullName,
                IndustryIds = rows.AsEnumerable().Where(r => Convert.ToBoolean(r["IsSelected"]))
                    .Select(r => Convert.ToInt32(r["IndustryId"])).ToArray(),
                Industries = rows.AsEnumerable().Select(r => new SelectListItem
                {
                    Value = Convert.ToString(r["IndustryId"]),
                    Text = Convert.ToString(r["IndustryCode"]) + " — " + Convert.ToString(r["IndustryName"])
                        + (Convert.ToBoolean(r["IsActive"]) ? "" : " " + AppProcessor.Messagor.GetMessage("User_IndustryPermissions_InactiveIndustry")),
                    Disabled = !Convert.ToBoolean(r["IsActive"]),
                    // Keep existing inactive selections visible; do not re-grant them.
                    Selected = Convert.ToBoolean(r["IsSelected"])
                }).ToList()
            };
        }

        private readonly CateEnterpriseCache _cateEnterpriseCache;
        private readonly SysConfigsCache _configsCache;
        private readonly string _funcName = AppProcessor.Messagor.GetMessage("User_Title");
        private readonly SysRoleCache _groupCache;
        private readonly SysUserCache _userCache;

        public UserController()
        {
            _userCache = new SysUserCache();
            _groupCache = new SysRoleCache();
            _cateEnterpriseCache = new CateEnterpriseCache();
            _configsCache = new SysConfigsCache();
        }

        // GET: User
        [ActionType(Type = EnumActionType.View)]
        [HttpGet]
        public ActionResult Index()
        {
            #region Test

            //_userCache.GetAll()
            //    .Where(e => e.IsActive 
            //                //&& e.UserName != "trunglc.kha"
            //                //&& e.UserName != "milv.kha"
            //                && e.UserName != "chuongnh.kha"
            //                && e.UserName != "huyntq.kha"
            //                && e.UserName != "thuntm.kha"
            //    )
            //    //.Where(e => e.UserName == "trunglc.kha")
            //    .ToList().ForEach(
            //   e => {
            //       e.Password = EString.GenerateStrongPassword(8);
            //       var lstRoles = _userCache.GetRoles(e.UserId);
            //       var mailNewUser = new SysMailUserModel
            //       {
            //           FullName = e.FullName,
            //           UserName = e.UserName,
            //           Email = e.Email,
            //           Password = e.Password,
            //           HostUrl = "http://baocaosodulich.cenit.vn" //Request.Url?.Host
            //       };
            //       var salt = UPasswordHash.GenerateSalt(e.Password);
            //       var passwordHash = UPasswordHash.GenerateCryptoPassword(e.Password, salt);

            //       var idUser = _userCache.Save(new SysUserModel
            //       {
            //           UserId = e.UserId,
            //           FullName = e.FullName,
            //           UserName = e.UserName,
            //           Email = e.Email,
            //           Password = passwordHash,
            //           Salt = salt,
            //           RoleIDs = string.Join(",", lstRoles.Select(g => g.RoleId)),
            //           IsActive = true,
            //           Reason = "Re-Update",
            //           //HostlUrl = Request.Url.AbsoluteUri.Replace(Request.Url.PathAndQuery, "")
            //       }, User.UserName);

            //       var dataHtml = RenderTemplateHtmlProvider.RenderStringHtml(
            //           HostingEnvironment.MapPath(@"~/Contents/Modules/Sys/EmailTemplates/_TemplateNewUser.cshtml"),
            //           mailNewUser);

            //       AppProcessor.Mailer.PushEmail(new List<MailModel>
            //       {
            //           new MailModel
            //           {
            //               From = null,
            //               DisplayNameFrom = null,
            //               Subject =
            //                   $"[{AppProcessor.Messagor.GetMessage("App_Title")}] Thông tin tài khoản {e.FullName}",
            //               To = new List<string> { e.Email },
            //               IsBodyHtml = true,
            //               Body = dataHtml
            //           }
            //       });
            //   });

            #endregion

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
            var data = _userCache.Get(out total, dataSearch);
            var canEditIndustries = CanEditIndustryPermissions();
            var rows = (data ?? new List<SysUserModel>()).Select(item => new
            {
                item.UserId, item.FullName, item.UserName, item.IsActive,
                CanEditIndustryPermissions = canEditIndustries && item.IsActive && HasIndustryPermissionRole(item.UserId)
            }).ToList();

            var result = Json(
                new { draw = Convert.ToInt32(draw), recordsTotal = total, recordsFiltered = total, data = rows },
                JsonRequestBehavior.AllowGet);
            return result;
        }

        [AjaxOnly]
        [ActionType(Type = EnumActionType.Add)]
        [HttpGet]
        public ActionResult Add()
        {
            var model = new SysUserModel { Roles = _groupCache.GetAll() };
            return PartialView("_Add", model);
        }

        [HttpPost]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult Add(SysUserModel model)
        {
            if (!ModelState.IsValid)
            {
                model.Roles = _groupCache.GetAll();
                return PartialView("_Add", model);
            }

            model.RoleIDs = string.IsNullOrEmpty(model.RoleIDs) ? null : model.RoleIDs.Trim(',');
            model.Password = EString.GenerateStrongPassword(8);

            var mailNewUser = new SysMailUserModel
            {
                FullName = model.FullName,
                UserName = model.UserName,
                Email = model.Email,
                Password = model.Password,
                HostUrl = Request.Url?.Host,
                SupportEmail = _configsCache.GetViaKey("Email_Support")?.ConfigValue
            };

            var salt = UPasswordHash.GenerateSalt(model.Password);
            var passwordHash = UPasswordHash.GenerateCryptoPassword(model.Password, salt);

            var idUser = _userCache.Save(new SysUserModel
            {
                UserId = 0,
                FullName = model.FullName,
                UserName = model.UserName,
                Email = model.Email,
                Password = passwordHash,
                Salt = salt,
                RoleIDs = model.RoleIDs,
                IsActive = true,
                Reason = model.Reason
                //HostlUrl = Request.Url.AbsoluteUri.Replace(Request.Url.PathAndQuery, "")
            }, User.UserName);
            if (idUser == -9)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_funcName} <b>[{model.UserName}]</b>", EnumProcessType.DataExisted,
                        EnumMsgIcon.Error)
                });
            if (idUser == -8)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"Email <b>[{model.Email}]</b>", EnumProcessType.DataExisted,
                        EnumMsgIcon.Error)
                });
            if (idUser > 0)
            {
                var dataHtml = RenderTemplateHtmlProvider.RenderStringHtml(
                    HostingEnvironment.MapPath(@"~/Contents/Modules/Sys/EmailTemplates/_TemplateNewUser.cshtml"),
                    mailNewUser);

                AppProcessor.Mailer.PushEmail(new List<MailModel>
                {
                    new MailModel
                    {
                        DicImgs = new Dictionary<string, byte[]>
                        {
                            {
                                "LogoVNPT",
                                System.IO.File.ReadAllBytes(
                                    $"{Server.MapPath(ConfigurationManager.AppSettings["Mail_VNPTLogoPath"])}")
                            },
                            {
                                "LogoTourism",
                                System.IO.File.ReadAllBytes(
                                    $"{Server.MapPath(ConfigurationManager.AppSettings["Mail_TourismLogoPath"])}")
                                //new WebClient().DownloadData(ConfigurationManager.AppSettings["Mail_TourismLogoPath"])
                            }
                        },
                        From = null,
                        DisplayNameFrom = null,
                        Subject =
                            $"[{AppProcessor.Messagor.GetMessage("App_Title")}] Thông tin tài khoản {model.FullName}",
                        To = new List<string> { model.Email },
                        IsBodyHtml = true,
                        Body = dataHtml
                    }
                });
            }

            var response = CreateMessage($"{_funcName} [{model.FullName}]", EnumProcessType.Add,
                idUser > 0 ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = true, message = response });
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Edit(int id = 0)
        {
            var model = _userCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_funcName}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            model.RoleIDs = string.Join(",", _userCache.GetRoles(model.UserId).Select(g => g.RoleId));
            model.Roles = _groupCache.GetAll();
            return PartialView("_Edit", model);
        }

        [HttpPost]
        [ValidateAntiForgeryToken]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Edit(SysUserModel model)
        {
            ModelState.Remove("Password");
            ModelState.Remove("ConfirmPassword");
            if (ModelState.IsValid)
            {
                int? idUser;
                model.RoleIDs = string.IsNullOrEmpty(model.RoleIDs) ? null : model.RoleIDs.Trim(',');

                if (!string.IsNullOrEmpty(model.Password))
                    idUser = _userCache.Save(new SysUserModel
                    {
                        UserId = model.UserId,
                        FullName = model.FullName,
                        UserName = model.UserName,
                        Email = model.Email,
                        RoleIDs = model.RoleIDs,
                        IsActive = true,
                        Reason = model.Reason
                    }, User.UserName);
                else
                    idUser = _userCache.Save(new SysUserModel
                    {
                        UserId = model.UserId,
                        FullName = model.FullName,
                        UserName = model.UserName,
                        Email = model.Email,
                        Password = null,
                        Salt = null,
                        RoleIDs = model.RoleIDs,
                        IsActive = true,
                        Reason = model.Reason
                    }, User.UserName);
                if (idUser == -9)
                    return Json(new
                    {
                        status = true,
                        message = CreateMessage($"{_funcName} <b>[{model.UserName}]</b>", EnumProcessType.DataExisted,
                            EnumMsgIcon.Error)
                    });
                if (idUser == -8)
                    return Json(new
                    {
                        status = true,
                        message = CreateMessage($"Email <b>[{model.Email}]</b>", EnumProcessType.DataExisted,
                            EnumMsgIcon.Error)
                    });
                var response = CreateMessage($"{_funcName} [{model.FullName}]", EnumProcessType.Edit,
                    idUser > 0 ? EnumMsgIcon.Success : EnumMsgIcon.Error);
                return Json(new { status = true, message = response });
            }

            model.Roles = _groupCache.GetAll();
            return PartialView("_User", model);
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult Delete(int id = 0)
        {
            var model = _userCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_funcName}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            ViewBag.ConfirmMessage = string.Format(AppProcessor.Messagor.GetMessage("Common_ConfirmMessage"),
                $"<b>{_funcName} [{model.FullName}]</b>");
            return PartialView("_Delete", model);
        }

        [HttpPost]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult Delete(SysUserModel model)
        {
            var deleted = _userCache.Delete(model, User.UserName);

            var response = CreateMessage($"{_funcName} [{model.FullName}]", EnumProcessType.Delete,
                deleted ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = true, message = response });
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult IsExistUser(string userName, int userId)
        {
            var model = _userCache.GetByUserName(userName);
            if (model == null)
                return Json(new
                {
                    status = false,
                    message = CreateMessage($"{_funcName}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            if (userId < 1)
                return Json(new
                {
                    status = false
                });
            if (model.UserId != userId)
                return Json(new
                {
                    status = false
                });
            return Json(new
            {
                status = true
            });
        }

        [HttpGet]
        [AjaxOnly]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult ResetPassword(int id = 0)
        {
            var currentUser = _userCache.GetById(id);
            if (currentUser == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage("Tài khoản",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                }, JsonRequestBehavior.AllowGet);
            return PartialView("_ResetPassword", new ResetPasswordModel
            {
                FullName = currentUser.FullName,
                UserName = currentUser.UserName,
                Email = currentUser.Email
            });
        }

        [HttpPost]
        [AjaxOnly]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult ResetPassword(ResetPasswordModel model)
        {
            ModelState.Remove("CurrentPassword");
            if (!ModelState.IsValid) return PartialView("_Password", model);
            if (!Regex.IsMatch(model.NewPassword, @"^(?=(.*\d){2})(?=.*[a-z])(?=.*[A-Z])(?=.*[^a-zA-Z\d]).{8,}$"))
            {
                ModelState.AddModelError("NewPassword",
                    "Mật khẩu phải dài ít nhất 8 ký tự và bao gồm ký tự thường, ký tự hoa, chữ số và ký tự đặc biệt");
                return PartialView("_Password", model);
            }

            var salt = UPasswordHash.GenerateSalt(model.NewPassword);
            var passwordHash = UPasswordHash.GenerateCryptoPassword(model.NewPassword, salt);

            var idUser = _userCache.ResetPassword(
                model.UserName,
                passwordHash,
                salt,
                model.Reason,
                User.UserName
            );
            switch (idUser)
            {
                case -1:
                    return Json(new
                    {
                        status = false,
                        message = CreateMessage("Tài khoản không tồn tại hoặc đã khoá.",
                            EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    }, JsonRequestBehavior.AllowGet);
                default:
                    // Quản trị cấp lại mật khẩu => người dùng phải đổi mật khẩu ở lần đăng nhập kế tiếp
                    if (!string.Equals(model.UserName, User.UserName, StringComparison.OrdinalIgnoreCase))
                        SetRequireChangePassword(model.UserName, true, "Quản trị cấp lại mật khẩu");
                    AppProcessor.Notifider.ForceLogout(model.UserName);
                    return Json(new
                    {
                        status = true,
                        message = CreateMessage("Mật khẩu",
                            EnumProcessType.Edit, EnumMsgIcon.Success)
                    }, JsonRequestBehavior.AllowGet);
            }
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult SendMail(int id = 0)
        {
            var model = _userCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_funcName}", EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            if (!model.IsActive)
                return Json(new
                {
                    status = true,
                    message = CreateMessage(
                        $"{_funcName} <b>[{model.FullName} - {model.UserName}]</b> đã ngưng hoạt động.",
                        EnumProcessType.NonFormat, EnumMsgIcon.Error)
                });
            model.Reason = "Reset password";
            ViewBag.ConfirmMessage =
                $"Bạn muốn đặt lại mật khẩu cho tài khoản <b>[{model.FullName} - {model.UserName}]</b>?";
            return PartialView("_ConfirmSendMail", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult SendMail(SysUserModel model)
        {
            var userModel = _userCache.GetById(model.UserId.GetValueOrDefault(0));
            if (userModel == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_funcName}", EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            if (!userModel.IsActive)
                return Json(new
                {
                    status = true,
                    message = CreateMessage(
                        $"{_funcName} <b>[{model.FullName} - {model.UserName}]</b> đã ngưng hoạt động.",
                        EnumProcessType.NonFormat, EnumMsgIcon.Error)
                });


            model.HostUrl = Request.Url.AbsoluteUri.Replace(Request.Url.PathAndQuery, "");
            var baseToken = $"{userModel.Password}-{DateTime.Now.AddHours(24).Ticks}";
            var passPharse = userModel.Password;
            var tokenResetPassword = EStringCipher.Encrypt(baseToken, passPharse);
            model.DetailUrl = Url.Action("ResetPassword", "Account",
                new { area = "", userName = model.UserName, token = tokenResetPassword });

            var mailBodyHtml = RenderTemplateHtmlProvider.RenderStringHtml(
                HostingEnvironment.MapPath(
                    @"~/Contents/Modules/Sys/EmailTemplates/_TemplateResetPassword.cshtml"), model);

            AppProcessor.Mailer.PushEmail(new List<MailModel>
            {
                new MailModel
                {
                    DicImgs = new Dictionary<string, byte[]>
                    {
                        {
                            "LogoVNPT",
                            System.IO.File.ReadAllBytes(
                                $"{Server.MapPath(ConfigurationManager.AppSettings["Mail_VNPTLogoPath"])}")
                        },
                        {
                            "LogoTourism",
                            System.IO.File.ReadAllBytes(
                                $"{Server.MapPath(ConfigurationManager.AppSettings["Mail_TourismLogoPath"])}")
                            //new WebClient().DownloadData(ConfigurationManager.AppSettings["Mail_TourismLogoPath"])
                        }
                    },
                    Subject =
                        $"[{AppProcessor.Messagor.GetMessage("App_Title")}] {AppProcessor.Messagor.GetMessage("MailSubject_ResetPassword_Message")}",
                    To = new List<string> { model.Email },
                    Body = mailBodyHtml,
                    IsBodyHtml = true,
                    DisplayNameFrom = AppProcessor.Messagor.GetMessage("App_Owner_DisplayName")
                }
            });

            return Json(new
            {
                status = true,
                message = CreateMessage($"Đã gửi yêu cầu đặt lại mật khẩu đến <b>{_funcName} [{model.Email}]</b> ",
                    EnumProcessType.NonFormat, EnumMsgIcon.Success)
            }, JsonRequestBehavior.AllowGet);
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult DeActive(int id = 0)
        {
            var model = _userCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_funcName}", EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            ViewBag.ConfirmMessage = $"Bạn muốn ngưng hoạt động <b class='text-primary'>{_funcName} [{model.FullName}]</b>";
            return PartialView("_DeActive", model);
        }

        [HttpPost]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult DeActive(SysUserModel model)
        {
            if (ModelState.IsValidField("Reason"))
            {
                var isSuccess = _userCache.DeActive(model, User.UserName);

                var response = CreateMessage($"Ngưng hoạt động <b>{_funcName} [{model.FullName}]</b> thành công",
                    EnumProcessType.NonFormat, isSuccess ? EnumMsgIcon.Success : EnumMsgIcon.Error);
                return Json(new { status = true, message = response });
            }

            ViewBag.ConfirmMessage = $"Bạn muốn ngưng hoạt động <b>{_funcName} [{model.FullName}]</b>";
            return PartialView("_DeActive", model);
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Active(int id = 0)
        {
            var model = _userCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_funcName}", EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            ViewBag.ConfirmMessage = $"Bạn muốn kích hoạt lại <b>{_funcName} [{model.FullName}]</b>";
            return PartialView("_Active", model);
        }

        [HttpPost]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Active(SysUserModel model)
        {
            if (ModelState.IsValidField("Reason"))
            {
                var isSuccess = _userCache.Active(model, User.UserName);

                var response = CreateMessage($"Kích hoạt <b>{_funcName} [{model.FullName}]</b> thành công",
                    EnumProcessType.NonFormat, isSuccess ? EnumMsgIcon.Success : EnumMsgIcon.Error);
                return Json(new { status = true, message = response });
            }

            ViewBag.ConfirmMessage = $"Bạn muốn kích hoạt lại <b>{_funcName} [{model.FullName}]</b>";
            return PartialView("_Active", model);
        }

        [HttpGet]
        [AjaxOnly]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult EnterprisesUser(int id = 0)
        {
            var currentUser = _userCache.GetById(id);
            if (currentUser == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage("Tài khoản", EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                }, JsonRequestBehavior.AllowGet);

            //var enterprises = _cateEnterpriseCache.GetAll()
            //    .Select(u => new ListItem(u.BusinessName, u.EnterpriseId.ToString())).ToList();

            var listPermittedEnterpise = _cateEnterpriseCache.GetCateEnterprisePermissions(currentUser.UserName);
                //.Select(o => new ListItem(o.BusinessName, o.EnterpriseId.ToString())).ToList();

            var enterprisesSelected = listPermittedEnterpise
                .Select(o => o.EnterpriseId).ToList();

            return PartialView("_EnterprisePermissions", new EnterpriseUserModel
            {
                FullName = currentUser.FullName,
                UserName = currentUser.UserName,
                Email = currentUser.Email,
                Enterprises = new List<ListItem>(),
                //Enterprises = permittedEnterpise,
                SelectedEnterprise = JsonConvert.SerializeObject(listPermittedEnterpise.Select(e => new {id = e.EnterpriseId, text = e.BusinessName}).ToArray()),
                StrEnterprisesSelected = string.Join(",", enterprisesSelected)
            });
        }

        [HttpPost]
        [AjaxOnly]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult EnterprisesUser(EnterpriseUserModel model)
        {
            model.StrEnterprisesSelected = string.Join(",", model.ListEnterpiseIds);
            var cateEnterprisePermissionsModel = new CateEnterprisePermissionsModel
            {
                ForUser = model.UserName,
                EnterpriseIds = model.StrEnterprisesSelected
            };
            var retId = _cateEnterpriseCache.SaveEnterprisePermissions(cateEnterprisePermissionsModel);
            return Json(new
            {
                status = true,
                message = CreateMessage($"Phân quyền quản lý doanh nghiệp cho <b> tài khoản [{model.UserName}]</b>",
                    EnumProcessType.Edit, EnumMsgIcon.Success)
            }, JsonRequestBehavior.AllowGet);
        }

        [HttpGet]
        [AjaxOnly]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult SearchEnterprise(string q, string username)
        {
            var currentUser = _userCache.GetByUserName(username);
            List<int> enterprisesSelected = new List<int>();
            
            if (currentUser != null)
            {
                enterprisesSelected = _cateEnterpriseCache.GetCateEnterprisePermissions(currentUser.UserName)
                    .Select(o => o.EnterpriseId).ToList();
            }

            var resultEnterpise = _cateEnterpriseCache.GetAll()
                .Where(o => enterprisesSelected.All(e => e != o.EnterpriseId) && o.BusinessName.ToLower().Contains(q.ToLower()))
                .Select(u => new { id = u.EnterpriseId, text = u.BusinessName }).ToArray();

           
            return Json(new
            {
                status = true,
                results = resultEnterpise
            }, JsonRequestBehavior.AllowGet);
        }
    }
}
