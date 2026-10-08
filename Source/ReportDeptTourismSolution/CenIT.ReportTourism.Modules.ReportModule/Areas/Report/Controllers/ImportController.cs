using System;
using System.Collections.Generic;
using System.Collections.Specialized;
using System.Configuration;
using System.Data;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;
using System.Threading.Tasks;
using System.Web;
using System.Web.Hosting;
using System.Web.Mvc;
using System.Web.UI.WebControls;
using CenIT.Libs.VNPTSmartCA.Models.Responses;
using CenIT.Libs.VNPTSmartCA.Providers;
using CenIT.Libs.VNPTSmartCA.Services;
using CenIT.ReportTourism.Caches.Cate;
using CenIT.ReportTourism.Caches.Report;
using CenIT.ReportTourism.Caches.Sys;
using CenIT.ReportTourism.Core.Apps;
using CenIT.ReportTourism.Core.Conts;
using CenIT.ReportTourism.Core.Helpers;
using CenIT.ReportTourism.Models.Cate;
using CenIT.ReportTourism.Models.Report;
using CenIT.ReportTourism.Models.Sys;
using CenIT.ReportTourism.Modules.ReportModule.Areas.Report.Models;
using CenIT.ReportTourism.Modules.SysModule.Areas.Sys.Models;
using DocumentFormat.OpenXml.Packaging;
using ExcelDataReader;
using Microsoft.Reporting.WebForms;
using Spire.Xls;
using Spire.Xls.Collections;
using TSFramework.App.Attributes;
using TSFramework.App.Processors;
using TSFramework.Core.Enums;
using TSFramework.Core.Helpers;
using TSFramework.Core.Providers;
using VnptHashSignatures.Interface;

namespace CenIT.ReportTourism.Modules.ReportModule.Areas.Report.Controllers
{
    public class ImportController : AppController
    {
        private CenIT.ReportTourism.Biz.Report.ReportDataImportScope OperationalScope { get; set; }

        protected override void OnActionExecuting(ActionExecutingContext filterContext)
        {
            base.OnActionExecuting(filterContext);
            if (filterContext.Result != null) return;
            OperationalScope = CenIT.ReportTourism.Biz.Report.ReportDataImportScope.Begin(User.UserName);
            foreach (var parameter in filterContext.ActionParameters)
            {
                if (parameter.Value == null) continue;
                if (string.Equals(parameter.Key, "enterpriseId", StringComparison.OrdinalIgnoreCase))
                {
                    long id;
                    if (long.TryParse(Convert.ToString(parameter.Value), out id) && id > 0) OperationalScope.Demand(id);
                }
                else
                {
                    var property = parameter.Value.GetType().GetProperty("EnterpriseId");
                    var id = property == null ? null : property.GetValue(parameter.Value, null);
                    if (id != null && Convert.ToInt64(id) > 0) OperationalScope.Demand(Convert.ToInt64(id));
                }
            }
        }

        private readonly SysConfigsCache _configCache = new SysConfigsCache();
        private readonly CateEnterpriseCache _enterpriseCache = new CateEnterpriseCache();

        private readonly string _enterpriseTitle = AppProcessor.Messagor.GetMessage("Enterprise_Title");
        private readonly ReportDataImportCache _importCache = new ReportDataImportCache();
        private readonly string _importTile = AppProcessor.Messagor.GetMessage("ReportDataImport_Title");
        private readonly CateBusinessProductCache _businessProductCache;
        private readonly CateNationalCache _nationalCache = new CateNationalCache();

        private readonly string _templateImportPathFolder =
            ConfigurationManager.AppSettings["Modules_Report_TemplateImportFolderPath"] ??
            "/Contents/Modules/Report/Templates/";

        #region Mapping

        private readonly Dictionary<int, string> _mappingReportTypeBiz = new Dictionary<int, string>{
            //{
            //    (int)EnumTypeBusiness.Accommodation,
            //    AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(EnumTypeBusiness.Accommodation))
            //},
            //{
            //    (int)EnumTypeBusiness.Traveling,
            //    AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(EnumTypeBusiness.Traveling))
            //},
            //{
            //    (int)EnumTypeBusiness.ServicesForTourists,
            //    AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(EnumTypeBusiness.TouristAttraction))
            //},
            //{
            //    (int)EnumTypeBusiness.TransportTourists,
            //    AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(EnumTypeBusiness.Traveling))
            //},
            {
                (int)EnumTypeBusiness.Manufacturing,
                AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(EnumTypeBusiness.Manufacturing))
            },
            {
                (int)EnumTypeBusiness.Trading,
                AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(EnumTypeBusiness.Trading))
            },
            {
                (int)EnumTypeBusiness.ImportExport,
                AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(EnumTypeBusiness.ImportExport))
            }
        };

        #endregion

        public ImportController()
        {
            _importCache = new ReportDataImportCache();
            _enterpriseCache = new CateEnterpriseCache();
            _configCache = new SysConfigsCache();
            _nationalCache = new CateNationalCache();
            _businessProductCache = new CateBusinessProductCache();
        }
        // GET: Cate/ReportDataImport
        public ActionResult Index()
        {
            var lstEnterpisePermits = OperationalScope.GetEnterprises().ToList();
            var lstReportsViaUsers = _importCache.GetForUserOnMonth(User.UserName, DateTime.Now);
            var lstEnterpriseOther = (lstEnterpisePermits ?? new List<CateEnterpriseModel>())
                .Where(e => lstReportsViaUsers == null || !lstReportsViaUsers.Exists(r => r.EnterpriseId == e.EnterpriseId)).ToList();

            var isEnterpriseUser = OperationalScope.IsEnterpriseUser;
            var searchModel = new ReportDataImportSearchModel
            {
                ListEnterprises = (lstEnterpisePermits ?? new List<CateEnterpriseModel>())
                    .Select(e => new ListItem(e.BusinessName, e.EnterpriseId.ToString())).ToList(),
                DayDeadlineSendReport =
                    int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Report")?.ConfigValue ?? "0"),
                DayDeadlineSendReportLate =
                    int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Late_Report")?.ConfigValue ?? "0"),
                ExistEnterpriseSubmitReportYet = (lstEnterpisePermits != null && lstEnterpisePermits.Count > 0 ? lstEnterpriseOther.Count > 0 : true),
                IsEnterpriseUser = isEnterpriseUser,
                IsReportLocked = IsReportLocked(DateTime.Now),
                CanUnlockReport = CanUnlockReport(),
                ListTypeBusiness = Enum.GetValues(typeof(EnumTypeBusiness))
                    .Cast<EnumTypeBusiness>()
                    .Select(x => new ListItem(AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(x)),
                        ((int)x).ToString()))
                    .ToList(),
                EnableSignDigitalDoc =
                    (_configCache.GetViaKey("Enable_SignDigital_Doc")?.ConfigValue ?? "0") != "0"
            };
            return View(searchModel);
        }

        [HttpGet]
        [AllowAnyPermission]
        public ActionResult SearchEnterprisesSelect2(string q = null, string typeBusiness = null, int page = 1)
        {
            try
            {
                int pageSize = 20;
                int pageIndex = page > 0 ? page - 1 : 0;
                var keyword = string.IsNullOrWhiteSpace(q) ? null : q.Trim();
                var typeBiz = string.IsNullOrWhiteSpace(typeBusiness) ? null : typeBusiness.Trim();

                List<CateEnterpriseModel> list = null;
                try
                {
                    list = AppProcessor.ProcedureProvider.ExecuteTypedList<CateEnterpriseModel>(
                        "Report_DataImports_Enterprises_SearchSelect2", "ReportTourismProvider",
                        keyword, typeBiz, pageIndex, pageSize, User.UserName);
                }
                catch (Exception exSp)
                {
                    AppProcessor.Logger.Message("ExecuteTypedList error in SearchEnterprisesSelect2: " + exSp.Message);
                }


                int total = 0;
                if (list != null && list.Count > 0)
                {
                    total = list.First().TotalRow.GetValueOrDefault(0);
                }

                var results = (list ?? new List<CateEnterpriseModel>()).Select(e => new
                {
                    id = e.EnterpriseId,
                    text = string.IsNullOrEmpty(e.TaxCode) ? e.BusinessName : string.Format("{0} - {1}", e.BusinessName, e.TaxCode),
                    typeBusiness = e.TypeBusiness
                }).ToList();

                bool more = ((long)pageIndex + 1) * pageSize < total;
                return Json(new
                {
                    results = results,
                    pagination = new { more = more }
                }, JsonRequestBehavior.AllowGet);
            }
            catch (Exception ex)
            {
                AppProcessor.Logger.Message("General error in SearchEnterprisesSelect2: " + ex.Message);
                return Json(new
                {
                    results = new object[0],
                    pagination = new { more = false }
                }, JsonRequestBehavior.AllowGet);
            }
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult Get(ReportDataImportSearchModel searchModel)
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
            var data = _importCache.Get(User.UserName, searchModel.EnterpriseIds, searchModel.FromMonth,
                searchModel.ToMonth, searchModel.TypeBusinessIds, out total, dataSearch);
            if (data != null)
            {
                foreach (var report in data)
                    report.CanDelete = report.CanDelete && !IsReportLocked(report.ForMonth);
            }
            var result = Json(
                new { draw = Convert.ToInt32(draw), recordsTotal = total, recordsFiltered = total, data },
                JsonRequestBehavior.AllowGet);
            return result;
        }

        #region Download

        [HttpGet]
        [AjaxOnly]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult DownloadSignedDoc(int enterpriseId, DateTime onMonth)
        {
            var enterpriseModel = _enterpriseCache.GetById(enterpriseId);
            if (enterpriseModel == null)
                return Json(new
                {
                    status = false,
                    errorCode = 1,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            var dataImports = _importCache.GetViaEnterpriseOnMonth(enterpriseId, onMonth);
            if (dataImports == null || dataImports.Count <= 0)
                return Json(new
                {
                    status = false,
                    errorCode = 1,
                    message = CreateMessage($"{_importTile}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            var fullSignedPath = HostingEnvironment.MapPath("/" + _signedFilesPathFolder);
            if (!Directory.Exists(fullSignedPath))
                return Json(new
                {
                    status = false,
                    errorCode = 1,
                    message = CreateMessage($"{_importTile}", EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            var subFolderSignedPath = Path.Combine(fullSignedPath, $"{onMonth.Year}", $"{onMonth.Month}",
                $"{enterpriseModel.EnterpriseId}");
            if (!Directory.Exists(subFolderSignedPath) || !Directory.GetFiles(subFolderSignedPath).ToList().Any())
                return Json(new
                {
                    status = false,
                    errorCode = 1,
                    message = CreateMessage($"{_importTile}", EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            return Json(new
            {
                status = true,
                downloadPath = Url.Action("DownloadDoc", new { year = onMonth.Year, month = onMonth.Month, enterpriseId })
            });
        }

        [HttpGet]
        [ActionType(Type = EnumActionType.View)]
        public async Task<ActionResult> DownloadDoc(int year, int month, int enterpriseId)
        {
            var enterpriseModel = _enterpriseCache.GetById(enterpriseId);
            var fullSignedPath = HostingEnvironment.MapPath("/" + _signedFilesPathFolder);
            var subFolderSignedPath = Path.Combine(fullSignedPath, $"{year}", $"{month}", $"{enterpriseId}");
            var signedFiles = Directory.GetFiles(subFolderSignedPath);
            var signedFile = signedFiles[0];
            var fileInfo = new FileInfo(signedFile);

            var fileData = System.IO.File.ReadAllBytes(signedFile);
            return await Task.Run(() => File(fileData, MimeMapping.GetMimeMapping(fileInfo.Name),
                $"{enterpriseModel.BusinessName}-{fileInfo.Name}"));
        }

        [HttpGet]
        [ActionType(Type = EnumActionType.View)]
        public async Task<ActionResult> DownloadTemplate(string templateName = "TemplateImport_LuHanh.xlsx")
        {
            var lstEnterpisePermits = OperationalScope.GetEnterprises().ToList();
            var lstReportsViaUsers = _importCache.GetForUserOnMonth(User.UserName, DateTime.Now);
            var lstEnterpriseOther = lstEnterpisePermits
                .Where(e => !lstReportsViaUsers.Exists(r => r.EnterpriseId == e.EnterpriseId)).ToList();

            var searchModel = new ReportDataImportSearchModel
            {
                ListEnterprises = lstEnterpisePermits
                    .Select(e => new ListItem(e.BusinessName, e.EnterpriseId.ToString())).ToList(),
                DayDeadlineSendReport =
                    int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Report")?.ConfigValue ?? "0"),
                DayDeadlineSendReportLate =
                    int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Late_Report")?.ConfigValue ?? "0"),
                ExistEnterpriseSubmitReportYet = lstEnterpriseOther.Count > 0,
                ListTypeBusiness = Enum.GetValues(typeof(EnumTypeBusiness))
                    .Cast<EnumTypeBusiness>()
                    .Select(x => new ListItem(AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(x)),
                        ((int)x).ToString()))
                    .ToList(),
                EnableSignDigitalDoc =
                    (_configCache.GetViaKey("Enable_SignDigital_Doc")?.ConfigValue ?? "0") != "0"
            };

            #region Download File

            var fullPathTemplateImportFolder = HostingEnvironment.MapPath("/" + _templateImportPathFolder);

            var attachDocPath = Path.Combine(fullPathTemplateImportFolder, templateName);
            if (!System.IO.File.Exists(attachDocPath)) return View("Index", searchModel);
            Response.Clear();
            Response.Buffer = true;
            Response.Charset = "";
            Response.ContentType = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet";
            Response.AddHeader("content-disposition", "attachment;filename= " + $"{templateName}");
            using (var fileStream = new FileStream(attachDocPath, FileMode.Open))
            {
                using (var myMemoryStream = new MemoryStream())
                {
                    await fileStream.CopyToAsync(myMemoryStream);
                    myMemoryStream.WriteTo(Response.OutputStream);
                    Response.Flush();
                    Response.End();
                }
            }

            #endregion

            return View("Index", searchModel);
        }

        #endregion

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult ViewAction()
        {
            var lstEnterpisePermits = OperationalScope.GetEnterprises().ToList();
            var lstReportsViaUsers = _importCache.GetForUserOnMonth(User.UserName, DateTime.Now);
            var lstEnterpriseOther = (lstEnterpisePermits ?? new List<CateEnterpriseModel>())
                .Where(e => lstReportsViaUsers == null || !lstReportsViaUsers.Exists(r => r.EnterpriseId == e.EnterpriseId)).ToList();

            var isEnterpriseUser = OperationalScope.IsEnterpriseUser;
            var searchModel = new ReportDataImportSearchModel
            {
                ListEnterprises = (lstEnterpisePermits ?? new List<CateEnterpriseModel>())
                    .Select(e => new ListItem(e.BusinessName, e.EnterpriseId.ToString())).ToList(),
                DayDeadlineSendReport =
                    int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Report")?.ConfigValue ?? "0"),
                DayDeadlineSendReportLate =
                    int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Late_Report")?.ConfigValue ?? "0"),
                ExistEnterpriseSubmitReportYet = (lstEnterpisePermits != null && lstEnterpisePermits.Count > 0 ? lstEnterpriseOther.Count > 0 : true),
                IsEnterpriseUser = isEnterpriseUser,
                IsReportLocked = IsReportLocked(DateTime.Now),
                CanUnlockReport = CanUnlockReport(),
                EnableSignDigitalDoc =
                    (_configCache.GetViaKey("Enable_SignDigital_Doc")?.ConfigValue ?? "0") != "0"
            };
            return PartialView("_ActionView", searchModel);
        }

        #region Import

        [HttpPost]
        [ActionType(Type = EnumActionType.Unlock)]
        public ActionResult UnlockReport()
        {
            var config = _configCache.GetViaKey("Enable_Report_Lock");
            if (config == null)
                return Json(new { status = false, message = "Không tìm thấy cấu hình khóa báo cáo." });

            config.ConfigValue = "0";
            config.SaveBy = User.UserName;
            var result = _configCache.Save(config);
            return Json(new
            {
                status = result.GetValueOrDefault(0) > 0,
                message = result.GetValueOrDefault(0) > 0 ? "Đã mở khóa báo cáo." : "Không thể mở khóa báo cáo."
            });
        }

        [AjaxOnly]
        [ActionType(Type = EnumActionType.Add)]
        [HttpGet]
        public ActionResult ImportData()
        {
            var lstEnterpisePermits = OperationalScope.GetEnterprises().ToList();
            var lstReportsViaUsers = _importCache.GetForUserOnMonth(User.UserName, DateTime.Now);
            var lstEnterpriseOther = lstEnterpisePermits
                .Where(e => !lstReportsViaUsers.Exists(r => r.EnterpriseId == e.EnterpriseId)).ToList();

            var model = new ReportDataImportModel
            {
                ListEnterprises = lstEnterpriseOther.OrderBy(e => e.BusinessName)
                    .Select(e => new ListItem(e.BusinessName, e.EnterpriseId.ToString())).ToList(),
                EnterpriseId = lstEnterpriseOther.Count == 1 ? lstEnterpriseOther[0].EnterpriseId : (int?)null,
                EnterpriseName = lstEnterpriseOther.Count == 1 ? lstEnterpriseOther[0].BusinessName : null,
                DayDeadlineSendReport =
                    int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Report")?.ConfigValue ?? "0"),
                DayDeadlineSendReportLate =
                    int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Late_Report")?.ConfigValue ?? "0"),
                AccessToken = (string)Session[$"VNPT-SmartCA-{User?.UserName}-AccessToken"],
                EnableSignDigitalDoc =
                    (_configCache.GetViaKey("Enable_SignDigital_Doc")?.ConfigValue ?? "0") != "0"
            };
            return PartialView("_ImportData", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult UploadData(ReportDataImportModel model)
        {
            StringBuilder logActions = new StringBuilder();
            logActions.AppendLine("=========================================");
            if (IsReportLocked(model.ForMonth))
            {
                return Json(new
                {
                    status = false,
                    errorCode = 1,
                    message = CreateMessage(GetReportLockedMessage(model.ForMonth), EnumProcessType.NonFormat,
                        EnumMsgIcon.Error)
                });
            }
            logActions.AppendLine(
                $" - Loại ký số báo cáo: {model.TypeSignature} : {(model.TypeSignature == 0 ? "Tải file đã ký sẵn" : (model.TypeSignature == 1 ? "Ký số trực tiếp bằng Smart CA" : "Ký số Token CA"))}");

            if (model.TypeSignature == 2)
            {
                #region Check Valid Model And Data

                ModelState.Remove("FileImport");
                if (!ModelState.IsValid)
                {
                    var lstEnterpisePermits = OperationalScope.GetEnterprises().ToList();
                    var lstReportsViaUsers = _importCache.GetForUserOnMonth(User.UserName, DateTime.Now);
                    var lstEnterpriseOther = lstEnterpisePermits
                        .Where(e => !lstReportsViaUsers.Exists(r => r.EnterpriseId == e.EnterpriseId)).ToList();

                    model.ListEnterprises = lstEnterpriseOther.OrderBy(e => e.BusinessName)
                        .Select(e => new ListItem(e.BusinessName, e.EnterpriseId.ToString())).ToList();
                    model.DayDeadlineSendReport =
                        int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Report")?.ConfigValue ?? "0");
                    model.DayDeadlineSendReportLate =
                        int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Late_Report")?.ConfigValue ?? "0");
                    model.EnableSignDigitalDoc =
                        (_configCache.GetViaKey("Enable_SignDigital_Doc")?.ConfigValue ?? "0") != "0";
                    model.AccessToken = (string)Session[$"VNPT-SmartCA-{User?.UserName}-AccessToken"];

                    return PartialView("_ImportView", model);
                }

                var enterpriseModel = _enterpriseCache.GetById(model.EnterpriseId);
                if (enterpriseModel == null)
                {
                    logActions.AppendLine(" - Lỗi: Doanh nghiệp không tồn tại");
                    AppProcessor.Logger.Message(logActions.ToString());
                    return Json(new
                    {
                        status = false,
                        message = CreateMessage($"{_enterpriseTitle}",
                            EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                    });
                }

                #endregion

                #region Create FilePame And Folder Path

                var dataFileImport = Convert.FromBase64String(model.FileDataBase64);
                var streamDatas = new MemoryStream(dataFileImport);

                var fullSignedPath = HostingEnvironment.MapPath("/" + _signedFilesPathFolder);
                var subFolderSignedPath = Path.Combine(fullSignedPath,
                    $"{model.ForMonth.GetValueOrDefault(DateTime.Now).Year}",
                    $"{model.ForMonth.GetValueOrDefault(DateTime.Now).Month}", $"{enterpriseModel.EnterpriseId}");

                if (!Directory.Exists(subFolderSignedPath) && !string.IsNullOrEmpty(subFolderSignedPath))
                    Directory.CreateDirectory(subFolderSignedPath);
                var fileExt = model.FileExt;
                var fileNameSigned =
                    $"Report_{enterpriseModel.EnterpriseId}_{(model.EnableSignDigitalDoc ? "signed" : "")}.{fileExt}";
                var fileSignedFullPath = Path.Combine(subFolderSignedPath, fileNameSigned);

                var sFileName = model.FileName;

                #endregion

                #region Check Data Import

                bool isSuccessImport;
                var dataImports = ReadDataImports(streamDatas, fileExt, out isSuccessImport);
                if (!isSuccessImport)
                {
                    logActions.AppendLine(" - Đọc nội dung báo cáo lỗi");
                    AppProcessor.Logger.Message(logActions.ToString());
                    return Json(new
                    {
                        status = false,
                        message = CreateMessage(AppProcessor.Messagor.GetMessage("ImportData_Message_Fail"),
                            EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }

                var lstDataImports = ModelProvider.CreateListFromTable<ReportDataImportModel>(dataImports);
                var isWrongData = false;
                dataImports.Columns.Remove("RowIndex");

                var dataChecked = CheckDataImport(dataImports, model.ForMonth, model.EnterpriseId);
                if (dataChecked.Count > 0)
                {
                    logActions.AppendLine(" - Kiểm tra dung báo cáo: Nội dung báo cáo không đúng");
                    AppProcessor.Logger.Message(logActions.ToString());

                    //lstDataImports.ForEach(t =>
                    //{
                    //    if (dataChecked.FirstOrDefault(d => d.Code == t.Code) ==
                    //        null) return;
                    //    t.IsWrong = true;
                    //    isWrongData = true;
                    //});

                    var viewModel = new ReportDataImportViewModel
                    {
                        EnterpriseId = model.EnterpriseId,
                        ForMonth = model.ForMonth,
                        ReponseMessage =
                            CreateMessage($"{_importTile} - [{model.EnterpriseName} tháng {model.ForMonth:MM/yyyy}]",
                                EnumProcessType.Add, EnumMsgIcon.Error)
                    };
                    Session[$"DataImports-{User.UserName}-{model.EnterpriseId}-{model.ForMonth:MM/yyyy}"] =
                        lstDataImports;

                    ViewBag.Title = $"{_importTile} - <b>[{model.EnterpriseName} tháng {model.ForMonth:MM/yyyy}]</b>";
                    return PartialView("_ReviewData", viewModel);
                }

                #endregion

                logActions.AppendLine(" - Thực hiện lưu file báo cáo vào hệ thống");
                System.IO.File.WriteAllBytes(fileSignedFullPath, dataFileImport);

                #region Save data import

                var enterpriseId = _importCache.Import(new ReportDataImportModel
                {
                    EnterpriseId = model.EnterpriseId,
                    ForMonth = model.ForMonth,
                    TypeReport = model.TypeReport,
                    TypeReportName = model.TypeReportName,
                    //TypeReport = enterpriseModel.TypeBusiness,
                    //TypeReportName =
                    //    AppProcessor.Messagor.GetMessage(
                    //        EnumHelper.GetDescription((EnumTypeBusiness)enterpriseModel.TypeBusiness)),
                    DataImport = dataImports,
                    ReportFile = fileNameSigned,
                    CreatedBy = User.UserName,
                    Reason = model.Reason
                });
                if (enterpriseId == -7)
                {
                    logActions.AppendLine(" - Lưu nội dung báo cáo vào hệ thống thất bại: Doanh nghiệp không tồn tại");
                    AppProcessor.Logger.Message(logActions.ToString());

                    return Json(new
                    {
                        status = false,
                        message = CreateMessage($"{_enterpriseTitle}",
                            EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                    });
                }

                if (enterpriseId == -99)
                {
                    logActions.AppendLine(
                        $" - Lưu nội dung báo cáo vào hệ thống thất bại: {AppProcessor.Messagor.GetMessage("ImportData_Message_Expire_Submit_Report")}");
                    AppProcessor.Logger.Message(logActions.ToString());

                    return Json(new
                    {
                        status = false,
                        message = CreateMessage(
                            AppProcessor.Messagor.GetMessage("ImportData_Message_Expire_Submit_Report"),
                            EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }

                logActions.AppendLine(" - Lưu nội dung báo cáo vào hệ thống thành công");
                AppProcessor.Logger.Message(logActions.ToString());

                var response = CreateMessage($"{_importTile} - [{model.EnterpriseName} tháng {model.ForMonth:MM/yyyy}]",
                    EnumProcessType.Add,
                    enterpriseId > 0 ? EnumMsgIcon.Success : EnumMsgIcon.Error);
                return Json(new { status = true, message = response });

                #endregion
            }
            else
            {
                #region Check Valid Model & Data

                if (!ModelState.IsValid)
                {
                    var lstEnterpisePermits = OperationalScope.GetEnterprises().ToList();
                    var lstReportsViaUsers = _importCache.GetForUserOnMonth(User.UserName, DateTime.Now);
                    var lstEnterpriseOther = lstEnterpisePermits
                        .Where(e => !lstReportsViaUsers.Exists(r => r.EnterpriseId == e.EnterpriseId)).ToList();

                    model.ListEnterprises = lstEnterpriseOther.OrderBy(e => e.BusinessName)
                        .Select(e => new ListItem(e.BusinessName, e.EnterpriseId.ToString())).ToList();
                    model.DayDeadlineSendReport =
                        int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Report")?.ConfigValue ?? "0");
                    model.DayDeadlineSendReportLate =
                        int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Late_Report")?.ConfigValue ?? "0");
                    model.EnableSignDigitalDoc =
                        (_configCache.GetViaKey("Enable_SignDigital_Doc")?.ConfigValue ?? "0") != "0";
                    model.AccessToken = (string)Session[$"VNPT-SmartCA-{User?.UserName}-AccessToken"];

                    return PartialView("_ImportView", model);
                }

                var enterpriseModel = _enterpriseCache.GetById(model.EnterpriseId);
                if (enterpriseModel == null)
                {
                    logActions.AppendLine(" - Lỗi: Doanh nghiệp không tồn tại");
                    AppProcessor.Logger.Message(logActions.ToString());
                    return Json(new
                    {
                        status = false,
                        message = CreateMessage($"{_enterpriseTitle}",
                            EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                    });
                }

                #endregion

                #region Check Correct Type Template

                //logActions.AppendLine(
                //    $" - [{User.UserName}] thực hiện gửi báo cáo [{EnumHelper.GetDescription((EnumTypeBusiness)enterpriseModel.TypeBusiness)}] cho doanh nghiệp [{enterpriseModel.BusinessName}]");

                logActions.AppendLine(
                    $" - [{User.UserName}] thực hiện gửi báo cáo [{model.TypeReportName}] cho doanh nghiệp [{enterpriseModel.BusinessName}]");
                logActions.AppendLine(" - Thực hiện kiểm tra nội dung báo cáo");

                //if (!CheckCorrectTemplate(model.FileImport, EnumHelper.GetDescription((EnumTypeBusiness)enterpriseModel.TypeBusiness)))
                if (!CheckCorrectTemplate(model.FileImport, model.TypeReportName))
                {
                    logActions.AppendLine(" + Nội dung báo cáo không đúng định dạng");
                    AppProcessor.Logger.Message(logActions.ToString());

                    //string sTypeBiz = _mappingReportTypeBiz[enterpriseModel.TypeBusiness];
                    string sTypeBiz = _mappingReportTypeBiz[model.TypeReport];
                    return Json(new
                    {
                        status = false,
                        message = CreateMessage($"Tệp dữ liệu import không đúng loại báo cáo thuộc [{sTypeBiz}]",
                            EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }

                #endregion

                #region Create File Import

                var fullSignedPath = HostingEnvironment.MapPath("/" + _signedFilesPathFolder);
                var subFolderSignedPath = Path.Combine(fullSignedPath,
                    $"{model.ForMonth.GetValueOrDefault(DateTime.Now).Year}",
                    $"{model.ForMonth.GetValueOrDefault(DateTime.Now).Month}", $"{enterpriseModel.EnterpriseId}");

                if (!Directory.Exists(subFolderSignedPath) && !string.IsNullOrEmpty(subFolderSignedPath))
                    Directory.CreateDirectory(subFolderSignedPath);
                var fileExt = Path.GetExtension(model.FileImport.FileName);
                var fileNameSigned =
                    $"Report_{enterpriseModel.EnterpriseId}_{(model.EnableSignDigitalDoc ? "signed" : "")}{fileExt}";
                var fileSignedFullPath = Path.Combine(subFolderSignedPath, fileNameSigned);

                var dataFileImport = StreamHelper.ReadFully(model.FileImport.InputStream);
                var sFileName = model.FileImport.FileName;

                #endregion

                #region Check Data Import

                bool isSuccessImport;
                var dataImports = ReadDataImports(model.FileImport, out isSuccessImport);
                if (!isSuccessImport)
                {
                    logActions.AppendLine(" - Đọc nội dung báo cáo lỗi");
                    AppProcessor.Logger.Message(logActions.ToString());
                    return Json(new
                    {
                        status = false,
                        message = CreateMessage(AppProcessor.Messagor.GetMessage("ImportData_Message_Fail"),
                            EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }

                var lstDataImports = ModelProvider.CreateListFromTable<ReportDataImportModel>(dataImports);
                var isWrongData = false;
                dataImports.Columns.Remove("RowIndex");

                var dataChecked = CheckDataImport(dataImports, model.ForMonth, model.EnterpriseId);
                if (dataChecked.Count > 0)
                {
                    logActions.AppendLine(" - Kiểm tra dung báo cáo: Nội dung báo cáo không đúng");
                    AppProcessor.Logger.Message(logActions.ToString());

                    //lstDataImports.ForEach(t =>
                    //{
                    //    if (dataChecked.FirstOrDefault(d => d.Code == t.Code) ==
                    //        null) return;
                    //    t.IsWrong = true;
                    //    isWrongData = true;
                    //});

                    var viewModel = new ReportDataImportViewModel
                    {
                        EnterpriseId = model.EnterpriseId,
                        ForMonth = model.ForMonth,
                        ReponseMessage =
                            CreateMessage($"{_importTile} - [{model.EnterpriseName} tháng {model.ForMonth:MM/yyyy}]",
                                EnumProcessType.Add, EnumMsgIcon.Error)
                    };
                    Session[$"DataImports-{User.UserName}-{model.EnterpriseId}-{model.ForMonth:MM/yyyy}"] =
                        lstDataImports;

                    ViewBag.Title = $"{_importTile} - <b>[{model.EnterpriseName} tháng {model.ForMonth:MM/yyyy}]</b>";
                    return PartialView("_ReviewData", viewModel);
                }

                #endregion

                if (model.EnableSignDigitalDoc && model.TypeSignature == 1)
                {
                    logActions.AppendLine(" - Thực hiện ký số báo cáo");

                    #region Sign Data

                    var accessToken = (string)Session[$"VNPT-SmartCA-{User?.UserName}-AccessToken"];
                    if (string.IsNullOrEmpty(accessToken))
                    {
                        logActions.AppendLine(" - Chưa đăng nhập Smart CA");
                        AppProcessor.Logger.Message(logActions.ToString());

                        return Json(new
                        {
                            status = false,
                            errorCode = 1,
                            message = CreateMessage("Bạn chưa đăng nhập tài khoản Smart CA", EnumProcessType.NonFormat,
                                EnumMsgIcon.Error)
                        });
                    }

                    int isSuccess;
                    try
                    {
                        //isSuccess = SignHash(accessToken, model.FileImport, fileSignedFullPath);
                        string msgSignLogs;
                        isSuccess = Sign(accessToken, dataFileImport, sFileName, fileSignedFullPath, out msgSignLogs);
                        logActions.AppendLine(msgSignLogs);
                    }
                    catch (Exception e)
                    {
                        logActions.AppendLine(
                            $" - Thực hiện {_digitalSignTitle} dữ liệu báo cáo thất bại. Lỗi: [{e.Message}]");
                        AppProcessor.Logger.Message(logActions.ToString());

                        return Json(new
                        {
                            status = false,
                            errorCode = 1,
                            message = CreateMessage(
                                $"Thực hiện {_digitalSignTitle} dữ liệu báo cáo thất bại. Lỗi: [{e.Message}]",
                                EnumProcessType.NonFormat, EnumMsgIcon.Error)
                        });
                    }

                    if (isSuccess > 0)
                    {
                        var errMsg = "";
                        switch (isSuccess)
                        {
                            case 1:
                                errMsg = "Ký số thất bại";
                                break;
                            case 2:
                                errMsg = "Lỗi thông tin chữ ký số";
                                break;
                            case 3:
                                errMsg = "Người dùng không xác nhận ký số từ ứng dụng";
                                break;
                            case 4:
                                errMsg = "Lỗi chữ ký số";
                                break;
                            case 5:
                                errMsg = "Chữ ký số không khớp";
                                break;
                            case 6:
                                errMsg = "Từ chối ký số";
                                break;
                        }

                        logActions.AppendLine(
                            $" - Thực hiện {_digitalSignTitle} dữ liệu báo cáo thất bại. Lỗi: [{errMsg}]");
                        AppProcessor.Logger.Message(logActions.ToString());

                        return Json(new
                        {
                            status = false,
                            errorCode = 1,
                            message = CreateMessage(
                                $"Thực hiện {_digitalSignTitle} dữ liệu báo cáo thất bại. Lỗi: [{errMsg}]",
                                EnumProcessType.NonFormat, EnumMsgIcon.Error)
                        });
                    }

                    logActions.AppendLine($" - Thực hiện {_digitalSignTitle} dữ liệu báo cáo thành công");

                    #endregion
                }
                else
                {
                    logActions.AppendLine(" - Không cần ký số báo cáo và thực hiện lưu file báo cáo vào hệ thống");
                    model.FileImport.SaveAs(fileSignedFullPath);
                }

                //var lstTargets = lstDataImports.GroupBy(d => new { d.Targets, d.Unit })
                //    .Select(g => new { g.Key, Count = g.Count() });

                //lstDataImports.ForEach(t =>
                //{
                //    if (lstTargets.FirstOrDefault(d => d.Key.Targets == t.Targets && d.Key.Unit == t.Unit && d.Count > 1) ==
                //        null) return;
                //    t.IsWrong = true;
                //    isWrongData = true;
                //});

                //if (isWrongData)
                //{
                //    ReportDataImportViewModel viewModel = new ReportDataImportViewModel
                //    {
                //        EnterpriseId = model.EnterpriseId,
                //        ForMonth = model.ForMonth,
                //        ReponseMessage = CreateMessage($"{_importTile} - [{model.EnterpriseName} tháng {model.ForMonth:MM/yyyy}]", EnumProcessType.Add, EnumMsgIcon.Error)
                //    };
                //    Session[$"DataImports-{User.UserName}-{model.EnterpriseId}-{model.ForMonth:MM/yyyy}"] = lstDataImports;

                //    ViewBag.Title = $"{_importTile} - <b>[{model.EnterpriseName} tháng {model.ForMonth:MM/yyyy}]</b>";
                //    return PartialView("_ReviewData", viewModel);
                //}

                #region Save Data Import

                var enterpriseId = _importCache.Import(new ReportDataImportModel
                {
                    EnterpriseId = model.EnterpriseId,
                    ForMonth = model.ForMonth,
                    TypeReport = model.TypeReport,
                    TypeReportName = model.TypeReportName,
                    //TypeReport = enterpriseModel.TypeBusiness,
                    //TypeReportName =
                    //    AppProcessor.Messagor.GetMessage(
                    //        EnumHelper.GetDescription((EnumTypeBusiness)enterpriseModel.TypeBusiness)),
                    DataImport = dataImports,
                    ReportFile = fileNameSigned,
                    CreatedBy = User.UserName,
                    Reason = model.Reason
                });
                if (enterpriseId == -7)
                {
                    logActions.AppendLine(" - Lưu nội dung báo cáo vào hệ thống thất bại: Doanh nghiệp không tồn tại");
                    AppProcessor.Logger.Message(logActions.ToString());

                    return Json(new
                    {
                        status = false,
                        message = CreateMessage($"{_enterpriseTitle}",
                            EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                    });
                }

                if (enterpriseId == -99)
                {
                    logActions.AppendLine(
                        $" - Lưu nội dung báo cáo vào hệ thống thất bại: {AppProcessor.Messagor.GetMessage("ImportData_Message_Expire_Submit_Report")}");
                    AppProcessor.Logger.Message(logActions.ToString());

                    return Json(new
                    {
                        status = false,
                        message = CreateMessage(
                            AppProcessor.Messagor.GetMessage("ImportData_Message_Expire_Submit_Report"),
                            EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }

                logActions.AppendLine(" - Lưu nội dung báo cáo vào hệ thống thành công");
                AppProcessor.Logger.Message(logActions.ToString());

                var response = CreateMessage($"{_importTile} - [{model.EnterpriseName} tháng {model.ForMonth:MM/yyyy}]",
                    EnumProcessType.Add,
                    enterpriseId > 0 ? EnumMsgIcon.Success : EnumMsgIcon.Error);
                return Json(new { status = true, message = response });

                #endregion

            }
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult GetReviewDataImport(ReportDataImportViewSearchModel searchModel)
        {
            var draw = Request.Form.GetValues("draw")?[0];
            var dataImports =
                Session[$"DataImports-{User.UserName}-{searchModel.EnterpriseId}-{searchModel.ForMonth:MM/yyyy}"] as
                    List<ReportDataImportModel>;
            var total = dataImports?.Count ?? 0;
            var result = Json(
                new { draw = Convert.ToInt32(draw), recordsTotal = total, recordsFiltered = total, data = dataImports },
                JsonRequestBehavior.AllowGet);
            return result;
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult ImportData(ReportDataImportModel model)
        {
            if (!ModelState.IsValid)
            {
                model.ListEnterprises = OperationalScope.GetEnterprises().ToList()
                    .Select(e => new ListItem(e.BusinessName, e.EnterpriseId.ToString())).ToList();
                return PartialView("_ImportView", model);
            }

            var enterpriseModel = _enterpriseCache.GetById(model.EnterpriseId);
            if (enterpriseModel == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            //string sTypeBusiness = "EnumTypeBusiness.Accommodation";
            //int eTypeBusiness = enterpriseModel.TypeBusiness;

            //switch ((EnumTypeBusiness)eTypeBusiness)
            //{
            //    case EnumTypeBusiness.Accommodation:
            //        {
            //            sTypeBusiness = "EnumTypeBusiness.Accommodation";
            //            break;
            //        }
            //    case EnumTypeBusiness.Traveling:
            //        {
            //            sTypeBusiness = "EnumTypeBusiness.Traveling";
            //            break;
            //        }
            //}

            //Workbook workbook = new Workbook();
            //workbook.LoadFromStream(model.FileImport.InputStream);
            //BuiltInDocumentProperties wbProps = workbook.DocumentProperties;
            //if (wbProps.Category != sTypeBusiness && eTypeBusiness.ToString() != wbProps.Keywords)
            //{
            //    return Json(new
            //    {
            //        status = true,
            //        message = CreateMessage(string.Format(AppProcessor.Messagor.GetMessage("ImportData_Message_Wrong_Template"), AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription((EnumTypeBusiness)enterpriseModel.TypeBusiness))), EnumProcessType.NonFormat, EnumMsgIcon.Error)
            //    });
            //}

            bool isSuccessImport;
            var dataImport = ReadDataImports(model.FileImport, out isSuccessImport);

            if (!isSuccessImport)
                return Json(new
                {
                    status = true,
                    message = CreateMessage(AppProcessor.Messagor.GetMessage("ImportData_Message_Fail"),
                        EnumProcessType.NonFormat, EnumMsgIcon.Error)
                });

            var enterpriseId = _importCache.Import(new ReportDataImportModel
            {
                EnterpriseId = model.EnterpriseId,
                ForMonth = model.ForMonth,
                TypeReport = model.TypeReport,
                TypeReportName = model.TypeReportName,
                //TypeReport = enterpriseModel.TypeBusiness,
                //TypeReportName =
                //    AppProcessor.Messagor.GetMessage(
                //        EnumHelper.GetDescription((EnumTypeBusiness)enterpriseModel.TypeBusiness)),
                DataImport = dataImport,
                CreatedBy = User.UserName,
                Reason = model.Reason
            });
            if (enterpriseId == -7)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            var response = CreateMessage($"{_importTile} - [{model.EnterpriseName} tháng {model.ForMonth:MM/yyyy}]",
                EnumProcessType.Add,
                enterpriseId > 0 ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = enterpriseId > 0, message = response });
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult UploadFile(ReportDataImportModel model)
        {
            if (model.FileImport == null)
            {
                return Json(new
                {
                    status = false,
                    message = string.Empty
                });
            }

            var enterpriseModel = _enterpriseCache.GetById(model.EnterpriseId);
            if (enterpriseModel == null)
                return Json(new
                {
                    status = false,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            if (model.EnableSignDigitalDoc && model.TypeSignature != 1 && !HasSignature(model.FileImport))
            {
                return Json(new
                {
                    status = false,
                    message = CreateMessage("Tệp dữ liệu import chưa được ký số. Vui lòng kiểm tra lại.",
                        EnumProcessType.NonFormat, EnumMsgIcon.Error)
                });
            }

            //if (!CheckCorrectTemplate(model.FileImport, EnumHelper.GetDescription((EnumTypeBusiness)enterpriseModel.TypeBusiness)))
            if (!CheckCorrectTemplate(model.FileImport, model.TypeReportName))
            {
                //string sTypeBiz = _mappingReportTypeBiz[enterpriseModel.TypeBusiness];
                string sTypeBiz = _mappingReportTypeBiz[model.TypeReport];
                return Json(new
                {
                    status = false,
                    message = CreateMessage($"Tệp dữ liệu import không đúng loại báo cáo thuộc [{sTypeBiz}]",
                        EnumProcessType.NonFormat, EnumMsgIcon.Error)
                });
            }

            #region Check Data Import

            bool isSuccessImport;
            var dataImports = ReadDataImports(model.FileImport, out isSuccessImport);
            if (!isSuccessImport)
                return Json(new
                {
                    status = false,
                    message = CreateMessage(AppProcessor.Messagor.GetMessage("ImportData_Message_Fail"),
                        EnumProcessType.NonFormat, EnumMsgIcon.Error)
                });
            var lstDataImports = ModelProvider.CreateListFromTable<ReportDataImportModel>(dataImports);

            #endregion

            return Json(new
            {
                status = true,
                dataImport = lstDataImports.OrderBy(d => d.RowIndex),
                typeReport = enterpriseModel.TypeBusiness,
                message = ""
            });
        }

        #endregion

        #region View Data Report

        [AjaxOnly]
        [ActionType(Type = EnumActionType.View)]
        [HttpGet]
        public ActionResult View(int? enterpriseId, DateTime? onMonth, int? typeReport = null)
        {
            var enterpriseModel = _enterpriseCache.GetById(enterpriseId);
            if (enterpriseModel == null)
                return Content("<div class='alert alert-danger'>Không tìm thấy doanh nghiệp.</div>");

            // Always retain the original result.  Older reports were stored before
            // TypeReport was introduced, therefore filtering strictly by the type
            // from the listing used to return an empty result and prevented the
            // framework from opening the view modal.
            var allDataImports = _importCache.GetViaEnterpriseOnMonth(enterpriseId, onMonth) ??
                                 new List<ReportDataImportModel>();
            var dataImports = allDataImports;
            if (typeReport.HasValue)
            {
                dataImports = allDataImports.Where(x => x.TypeReport == typeReport.Value).ToList();
                if (!dataImports.Any() && allDataImports.Any(x => x.TypeReport <= 0))
                    dataImports = allDataImports.Where(x => x.TypeReport <= 0).ToList();
            }
            if (dataImports == null || dataImports.Count <= 0)
                return Content("<div class='alert alert-info'>Chưa có dữ liệu báo cáo cho kỳ đã chọn.</div>");

            EnumTypeBusiness selectedType = EnumTypeBusiness.Manufacturing;
            if (typeReport.HasValue && Enum.IsDefined(typeof(EnumTypeBusiness), typeReport.Value))
            {
                selectedType = (EnumTypeBusiness)typeReport.Value;
            }
            else
            {
                var savedTypeVal = dataImports?.FirstOrDefault(d => d.TypeReport > 0)?.TypeReport;
                if (savedTypeVal.HasValue && Enum.IsDefined(typeof(EnumTypeBusiness), savedTypeVal.Value))
                {
                    selectedType = (EnumTypeBusiness)savedTypeVal.Value;
                }
                else if (!string.IsNullOrEmpty(enterpriseModel.TypeBusiness))
                {
                    int entType;
                    if (int.TryParse(enterpriseModel.TypeBusiness.Split(',')[0], out entType) && Enum.IsDefined(typeof(EnumTypeBusiness), entType))
                    {
                        selectedType = (EnumTypeBusiness)entType;
                    }
                }
            }

            var typeReportName = GetTypeBusinessDisplayName(selectedType);
            ViewBag.Title = $"{_importTile} - {typeReportName} <b>[{enterpriseModel.BusinessName} tháng {onMonth?.ToString("MM/yyyy")}]</b>";
            ViewBag.ForMonth = onMonth ?? DateTime.Now;

            if (selectedType == EnumTypeBusiness.Trading)
            {
                var tradingResult = LoadTradingReport(enterpriseId, onMonth, null, dataImports);
                dataImports = tradingResult.Model as List<ReportDataImportModel> ?? dataImports;
                ViewBag.IsTradingReport = true;
            }
            else if (selectedType == EnumTypeBusiness.ImportExport)
            {
                var ieResult = LoadImportExportReport(enterpriseId, onMonth, null, dataImports);
                dataImports = ieResult.Model as List<ReportDataImportModel> ?? dataImports;
                ViewBag.IsImportExportReport = true;
            }
            else
            {
                var catalogResult = LoadViewTypeReport(enterpriseId, onMonth, null, (int)EnumTypeBusiness.Manufacturing) as PartialViewResult;
                var catalog = catalogResult?.Model as List<ReportDataImportModel>;
                if (catalog != null && catalog.Any())
                {
                    dataImports = MergeBusinessProductData(catalog, dataImports);
                }
                else
                {
                    dataImports = RestoreBusinessProductHierarchyCodes(dataImports);
                }
                ViewBag.IsBusinessProductReport = true;
            }

            var viewModel = new ReportDataImportViewModel
            {
                EnterpriseId = enterpriseId,
                ForMonth = onMonth,
                TypeReport = (int)selectedType,
                ListDataImports = dataImports
            };
            return PartialView("_View", viewModel);
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult GetDataImport(ReportDataImportViewSearchModel searchModel)
        {
            var draw = Request.Form.GetValues("draw")?[0];
            var data = _importCache.GetViaEnterpriseOnMonth(searchModel.EnterpriseId, searchModel.ForMonth);
            if (!searchModel.TypeReport.HasValue && data != null && data.Any())
            {
                var detected = data.FirstOrDefault(d => d.TypeReport > 0)?.TypeReport;
                if (detected.HasValue) searchModel.TypeReport = detected.Value;
            }
            if (searchModel.TypeReport.HasValue)
                data = (data ?? new List<ReportDataImportModel>()).Where(x => x.TypeReport == searchModel.TypeReport.Value).ToList();
            if (searchModel.TypeReport.HasValue && searchModel.TypeReport.Value == (int)EnumTypeBusiness.Trading)
            {
                var tradingResult = LoadTradingReport(searchModel.EnterpriseId, searchModel.ForMonth, null, data);
                data = tradingResult.Model as List<ReportDataImportModel> ?? data;
                if (data.Any(x => (x.Code ?? "").StartsWith("TM_", StringComparison.OrdinalIgnoreCase)))
                {
                    data = data.Where(x => x.Code != "38" && x.Code != "39").ToList();
                }
            }
            else if (searchModel.TypeReport.HasValue && searchModel.TypeReport.Value == (int)EnumTypeBusiness.ImportExport)
            {
                var ieResult = LoadImportExportReport(searchModel.EnterpriseId, searchModel.ForMonth, null, data);
                data = ieResult.Model as List<ReportDataImportModel> ?? data;
            }
            else
            {
                var catalogResult = LoadViewTypeReport(searchModel.EnterpriseId, searchModel.ForMonth, null, (int)EnumTypeBusiness.Manufacturing) as PartialViewResult;
                var catalog = catalogResult?.Model as List<ReportDataImportModel>;
                if (catalog != null && catalog.Any())
                    data = MergeBusinessProductData(catalog, data);
                else
                    data = RestoreBusinessProductHierarchyCodes(data);
            }
            var total = data.Count;
            var result = Json(
                new { draw = Convert.ToInt32(draw), recordsTotal = total, recordsFiltered = total, data },
                JsonRequestBehavior.AllowGet);
            return result;
        }

        #endregion

        #region Delete

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult Delete(int? enterpriseId, DateTime? onMonth)
        {
            if (IsReportLocked(onMonth))
                return Json(new
                {
                    status = false,
                    errorCode = 1,
                    message = CreateMessage(GetReportLockedMessage(onMonth), EnumProcessType.NonFormat,
                        EnumMsgIcon.Error)
                });

            var enterpriseModel = _enterpriseCache.GetById(enterpriseId);
            if (enterpriseModel == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            var model = _importCache.GetDataImportViaEnterpriseOnMonth(enterpriseId, onMonth);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_importTile}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            model.EnterpriseName = enterpriseModel.BusinessName;
            ViewBag.ConfirmMessage = string.Format(AppProcessor.Messagor.GetMessage("Common_ConfirmMessage"),
                $"<b>{_importTile} [{enterpriseModel.BusinessName} tháng {onMonth?.ToString("MM/yyyy")}]</b>");
            return PartialView("_Delete", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult Delete(ReportDataImportModel model)
        {
            if (IsReportLocked(model.ForMonth))
                return Json(new
                {
                    status = false,
                    errorCode = 1,
                    message = CreateMessage(GetReportLockedMessage(model.ForMonth), EnumProcessType.NonFormat,
                        EnumMsgIcon.Error)
                });

            if (!ModelState.IsValidField("Reason") ||
                !ModelState.IsValidField("EnterpriseId"))
                return PartialView("_DeleteView", model);
            model.SavedBy = User.Email;
            var isSuccess = _importCache.Delete(model);

            if (isSuccess)
            {
                var enterpriseModel = _enterpriseCache.GetById(model.EnterpriseId);
                if (enterpriseModel != null)
                {
                    var fullSignedPath = HostingEnvironment.MapPath("/" + _signedFilesPathFolder);
                    if (Directory.Exists(fullSignedPath))
                    {
                        var subFolderSignedPath = Path.Combine(fullSignedPath, $"{model.ForMonth.Value.Year}",
                            $"{model.ForMonth.Value.Month}",
                            $"{enterpriseModel.EnterpriseId}");
                        if (Directory.Exists(subFolderSignedPath) &&
                            Directory.GetFiles(subFolderSignedPath).ToList().Any())
                        {
                            var signedFiles = Directory.GetFiles(subFolderSignedPath);
                            foreach (var signedFilePath in signedFiles)
                            {
                                System.IO.File.Delete(signedFilePath);
                            }
                        }

                    }
                }
            }

            var response = CreateMessage(
                $"<b>{_importTile} [{model.EnterpriseName} tháng {model.ForMonth:MM/yyyy}]</b>",
                EnumProcessType.Delete, isSuccess ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = isSuccess, message = response });
        }

        #endregion

        #region Add Data Report

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult Add()
        {
            var lstEnterpisePermits = OperationalScope.GetEnterprises().ToList();
            var lstEnterpriseOther = (lstEnterpisePermits ?? new List<CateEnterpriseModel>())
                .Where(e => !string.IsNullOrWhiteSpace(e.TypeBusiness))
                .OrderBy(e => e.BusinessName)
                .ToList();

            EnumTypeBusiness defaultType = EnumTypeBusiness.Manufacturing;
            if (lstEnterpriseOther.Count > 0)
            {
                int tbVal;
                if (int.TryParse(lstEnterpriseOther[0].TypeBusiness.Split(',')[0], out tbVal) && Enum.IsDefined(typeof(EnumTypeBusiness), tbVal))
                {
                    defaultType = (EnumTypeBusiness)tbVal;
                }
            }

            var reportModel = new TourismReportModel
            {
                // Chỉ render doanh nghiệp đầu tiên để Select2 lấy các lựa chọn còn lại qua AJAX
                // (response AJAX có kèm TypeBusiness; option tĩnh không có metadata này).
                ListEnterprises = lstEnterpriseOther.OrderBy(e => e.BusinessName).Take(1)
                    .Select(e => new ListItem(e.BusinessName, e.EnterpriseId.ToString())).ToList(),
                EnterpriseId = lstEnterpriseOther.Count > 0 ? lstEnterpriseOther[0].EnterpriseId : (int?)null,
                EnterpriseName = lstEnterpriseOther.Count > 0 ? lstEnterpriseOther[0].BusinessName : null,
                EnterpriseTypeBusiness = lstEnterpriseOther.Count > 0 ? lstEnterpriseOther[0].TypeBusiness : null,
                DayDeadlineSendReport =
                    int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Report")?.ConfigValue ?? "0"),
                DayDeadlineSendReportLate =
                    int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Late_Report")?.ConfigValue ?? "0"),
                AccessToken = (string)Session[$"VNPT-SmartCA-{User?.UserName}-AccessToken"],
                EnableSignDigitalDoc =
                    (_configCache.GetViaKey("Enable_SignDigital_Doc")?.ConfigValue ?? "0") != "0",
                ForMonth = DateTime.Now,
                TypeReport = defaultType,
                TypeReportName = GetTypeBusinessDisplayName(defaultType),
                ListTypeBusiness = GetListTypeBusinessItems(),
                IsEnterpriseUser = OperationalScope.IsEnterpriseUser
            };
            return PartialView("_Add", reportModel);
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult Add(TourismReportModel model)
        {
            StringBuilder logActions = new StringBuilder();
            logActions.AppendLine("=========================================");

            if (IsReportLocked(model.ForMonth))
            {
                return Json(new
                {
                    status = false,
                    errorCode = 1,
                    message = CreateMessage(GetReportLockedMessage(model.ForMonth), EnumProcessType.NonFormat,
                        EnumMsgIcon.Error)
                });
            }

            if (!ModelState.IsValid)
            {
                var lstEnterpisePermits = OperationalScope.GetEnterprises().ToList();
                var lstEnterpriseOther = lstEnterpisePermits
                    .Where(e => e.TypeBusiness == "1").ToList();

                var reportModel = new TourismReportModel
                {
                    ListEnterprises = lstEnterpriseOther.OrderBy(e => e.BusinessName)
                        .Select(e => new ListItem(e.BusinessName, e.EnterpriseId.ToString())).ToList(),
                    DayDeadlineSendReport =
                        int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Report")?.ConfigValue ?? "0"),
                    DayDeadlineSendReportLate =
                        int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Late_Report")?.ConfigValue ?? "0"),
                    EnableSignDigitalDoc =
                        (_configCache.GetViaKey("Enable_SignDigital_Doc")?.ConfigValue ?? "0") != "0",
                    ForMonth = model.ForMonth,
                    TypeReport = model.TypeReport,
                    TypeReportName = string.IsNullOrWhiteSpace(model.TypeReportName) || model.TypeReportName.StartsWith("TypeBusiness_") ? GetTypeBusinessDisplayName(model.TypeReport) : model.TypeReportName,
                    ListTypeBusiness = GetListTypeBusinessItems(),
                    IsEnterpriseUser = OperationalScope.IsEnterpriseUser
                };
                return PartialView("_Add", reportModel);
            }

            var enterpriseModel = _enterpriseCache.GetById(model.EnterpriseId);
            if (enterpriseModel == null)
            {
                logActions.AppendLine(" - Lỗi: Doanh nghiệp không tồn tại");
                AppProcessor.Logger.Message(logActions.ToString());
                return Json(new
                {
                    status = false,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            }

            //logActions.AppendLine($" - [{User.UserName}] thực hiện gửi báo cáo [{EnumHelper.GetDescription((EnumTypeBusiness)enterpriseModel.TypeBusiness)}] cho doanh nghiệp [{enterpriseModel.BusinessName}]");

            logActions.AppendLine($" - [{User.UserName}] thực hiện gửi báo cáo [{model.TypeReportName}] cho doanh nghiệp [{enterpriseModel.BusinessName}]");
            logActions.AppendLine(" - Đọc nội dung báo cáo");

            var dataReport = ReadFormData(Request.Form, model.EnterpriseId ?? 0);
            EnsureTradingDynamicCodes(dataReport, model.EnterpriseId ?? 0);

            if (string.Equals(Request.Form["BusinessProductReport"], "true", StringComparison.OrdinalIgnoreCase))
            {
                string revenueError;
                if (!ValidateRevenueConstraint(dataReport, out revenueError))
                {
                    logActions.AppendLine(" - Lỗi: " + revenueError);
                    AppProcessor.Logger.Message(logActions.ToString());
                    return Json(new
                    {
                        status = false,
                        errorCode = 1,
                        message = CreateMessage(revenueError, EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }
            }

            if (string.Equals(Request.Form["TradingReport"], "true", StringComparison.OrdinalIgnoreCase))
            {
                string tradingError;
                if (!ValidateTradingDynamicConstraint(dataReport, out tradingError))
                {
                    logActions.AppendLine(" - Lỗi: " + tradingError);
                    AppProcessor.Logger.Message(logActions.ToString());
                    return Json(new
                    {
                        status = false,
                        errorCode = 1,
                        message = CreateMessage(tradingError, EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }
            }

            #region Create File Report And Path

            var pathReportTemplate = Server.MapPath("~/Contents/Modules/Report/Templates/_TemplateImportReport.rdlc");
            string mimeType;
            string fileExt;

            var fullSignedPath = HostingEnvironment.MapPath("/" + _signedFilesPathFolder);
            var fileNameReport = $"Report-{enterpriseModel.BusinessName}-{User?.UserName}";

            var dataImports = CreateReport(dataReport, fileNameReport, pathReportTemplate, out mimeType, out fileExt);

            var subFolderSignedPath = Path.Combine(fullSignedPath, $"{model.ForMonth.Year}", $"{model.ForMonth.Month}",
                $"{enterpriseModel.EnterpriseId}");
            if (!Directory.Exists(subFolderSignedPath) && !string.IsNullOrEmpty(subFolderSignedPath))
                Directory.CreateDirectory(subFolderSignedPath);
            var fileNameWithExt = $"{fileNameReport}.{fileExt}";
            var fileNameSigned = $"Report_{enterpriseModel.EnterpriseId}_signed.{fileExt}";
            var fileSignedFullPath = Path.Combine(subFolderSignedPath, fileNameSigned);

            #endregion

            if (model.EnableSignDigitalDoc)
            {
                logActions.AppendLine(" - Thực hiện ký số báo cáo");

                #region Sign Data

                var accessToken = (string)Session[$"VNPT-SmartCA-{User?.UserName}-AccessToken"];
                if (string.IsNullOrEmpty(accessToken))
                {
                    logActions.AppendLine(" - Chưa đăng nhập Smart CA");
                    AppProcessor.Logger.Message(logActions.ToString());

                    return Json(new
                    {
                        status = false,
                        errorCode = 1,
                        message = CreateMessage("Bạn chưa đăng nhập tài khoản Smart CA", EnumProcessType.NonFormat,
                            EnumMsgIcon.Error)
                    });
                }

                int isSuccess;
                try
                {
                    //isSuccess = SignHash(accessToken, dataImports, fileNameWithExt, fileExt, fileSignedFullPath);
                    string msgSignLogs;
                    isSuccess = Sign(accessToken, dataImports, fileNameWithExt, fileSignedFullPath, out msgSignLogs);
                    logActions.AppendLine(msgSignLogs);
                }
                catch (Exception e)
                {
                    logActions.AppendLine($" - Thực hiện {_digitalSignTitle} dữ liệu báo cáo thất bại. Lỗi: [{e.Message}]");
                    AppProcessor.Logger.Message(logActions.ToString());
                    return Json(new
                    {
                        status = false,
                        errorCode = 1,
                        message = CreateMessage(
                            $"Thực hiện {_digitalSignTitle} dữ liệu báo cáo thất bại. Lỗi: [{e.Message}]",
                            EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }

                if (isSuccess > 0)
                {
                    var errMsg = "";
                    switch (isSuccess)
                    {
                        case 1:
                            errMsg = "Ký số thất bại";
                            break;
                        case 2:
                            errMsg = "Lỗi thông tin chữ ký số";
                            break;
                        case 3:
                            errMsg = "Người dùng không xác nhận ký số từ ứng dụng";
                            break;
                        case 4:
                            errMsg = "Lỗi chữ ký số";
                            break;
                        case 5:
                            errMsg = "Chữ ký số không khớp";
                            break;
                        case 6:
                            errMsg = "Từ chối ký số";
                            break;
                    }

                    logActions.AppendLine($" - Thực hiện {_digitalSignTitle} dữ liệu báo cáo thất bại. Lỗi: [{errMsg}]");
                    AppProcessor.Logger.Message(logActions.ToString());

                    return Json(new
                    {
                        status = false,
                        errorCode = 1,
                        message = CreateMessage(
                            $"Thực hiện {_digitalSignTitle} dữ liệu báo cáo thất bại. Lỗi: [{errMsg}]",
                            EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }

                logActions.AppendLine($" - Thực hiện {_digitalSignTitle} dữ liệu báo cáo thành công");

                #endregion
            }
            else
            {
                logActions.AppendLine($" - Thực hiện {_digitalSignTitle} dữ liệu báo cáo thành công");
                System.IO.File.WriteAllBytes(fileSignedFullPath, dataImports);
            }

            if (string.IsNullOrWhiteSpace(model.TypeReportName) || model.TypeReportName.StartsWith("TypeBusiness_"))
            {
                model.TypeReportName = GetTypeBusinessDisplayName(model.TypeReport);
            }

            var enterpriseId = _importCache.Import(new ReportDataImportModel
            {
                EnterpriseId = model.EnterpriseId,
                ForMonth = model.ForMonth,
                TypeReport = (int)model.TypeReport,
                TypeReportName = model.TypeReportName,
                //TypeReport = enterpriseModel.TypeBusiness,
                //TypeReportName =
                //    AppProcessor.Messagor.GetMessage(
                //        EnumHelper.GetDescription((EnumTypeBusiness)enterpriseModel.TypeBusiness)),
                DataImport = dataReport,
                ReportFile = fileNameSigned,
                CreatedBy = User.UserName,
                Reason = "Thêm mới báo cáo"
            });

            if (enterpriseId == -7)
            {
                logActions.AppendLine(" - Lưu nội dung báo cáo vào hệ thống thất bại: Doanh nghiệp không tồn tại");
                AppProcessor.Logger.Message(logActions.ToString());
                return Json(new
                {
                    status = false,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            }

            if (enterpriseId == -99)
            {
                logActions.AppendLine($" - Lưu nội dung báo cáo vào hệ thống thất bại: {AppProcessor.Messagor.GetMessage("ImportData_Message_Expire_Submit_Report")}");
                AppProcessor.Logger.Message(logActions.ToString());

                return Json(new
                {
                    status = false,
                    message = CreateMessage(AppProcessor.Messagor.GetMessage("ImportData_Message_Expire_Submit_Report"),
                        EnumProcessType.NonFormat, EnumMsgIcon.Error)
                });
            }

            logActions.AppendLine(" - Lưu nội dung báo cáo vào hệ thống thành công");
            AppProcessor.Logger.Message(logActions.ToString());

            var response = CreateMessage($"{_importTile} - [{model.EnterpriseName} tháng {model.ForMonth:MM/yyyy}]",
                EnumProcessType.Add,
                enterpriseId > 0 ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = true, message = response });
        }

        #endregion

        #region Edit Data Report

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Edit(int? enterpriseId, DateTime? onMonth, int? typeReport = null)
        {
            if (IsReportLocked(onMonth))
                return Json(new
                {
                    status = false,
                    errorCode = 1,
                    message = CreateMessage(GetReportLockedMessage(onMonth), EnumProcessType.NonFormat,
                        EnumMsgIcon.Error)
                });

            var enterpriseModel = _enterpriseCache.GetById(enterpriseId);
            if (enterpriseModel == null)
                return Json(new
                {
                    status = false,
                    errorCode = 1,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            ViewBag.Title =
                $"{_importTile} <b>[{enterpriseModel.BusinessName}]</b> tháng <b class='text-yellow'>[{onMonth?.ToString("MM/yyyy")}]</b>";
            var dataImports = _importCache.GetViaEnterpriseOnMonth(enterpriseId, onMonth);
            if (typeReport.HasValue)
                dataImports = (dataImports ?? new List<ReportDataImportModel>()).Where(x => x.TypeReport == typeReport.Value).ToList();
            if (dataImports == null || dataImports.Count <= 0)
                return Json(new
                {
                    status = false,
                    errorCode = 1,
                    message = CreateMessage($"{_importTile}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            EnumTypeBusiness selectedType = EnumTypeBusiness.Manufacturing;
            if (typeReport.HasValue && Enum.IsDefined(typeof(EnumTypeBusiness), typeReport.Value))
            {
                selectedType = (EnumTypeBusiness)typeReport.Value;
            }
            else
            {
                var savedTypeVal = dataImports?.FirstOrDefault(d => d.TypeReport > 0)?.TypeReport;
                if (savedTypeVal.HasValue && Enum.IsDefined(typeof(EnumTypeBusiness), savedTypeVal.Value))
                {
                    selectedType = (EnumTypeBusiness)savedTypeVal.Value;
                }
                else if (!string.IsNullOrEmpty(enterpriseModel.TypeBusiness))
                {
                    int entType;
                    if (int.TryParse(enterpriseModel.TypeBusiness.Split(',')[0], out entType) && Enum.IsDefined(typeof(EnumTypeBusiness), entType))
                    {
                        selectedType = (EnumTypeBusiness)entType;
                    }
                }
            }

            if (selectedType == EnumTypeBusiness.Trading)
            {
                var tradingResult = LoadTradingReport(enterpriseId, onMonth, null, dataImports);
                dataImports = tradingResult.Model as List<ReportDataImportModel> ?? dataImports;
                ViewBag.IsTradingReport = true;
                ViewBag.TradingProductOptions = tradingResult.ViewData["TradingProductOptions"];
                ViewBag.ForMonth = tradingResult.ViewData["ForMonth"] ?? (onMonth ?? DateTime.Now);
            }
            else if (selectedType == EnumTypeBusiness.ImportExport)
            {
                var ieResult = LoadImportExportReport(enterpriseId, onMonth, null, dataImports);
                dataImports = ieResult.Model as List<ReportDataImportModel> ?? dataImports;
                ViewBag.IsImportExportReport = true;
                ViewBag.ListNationals = ieResult.ViewData["ListNationals"];
                ViewBag.ForMonth = ieResult.ViewData["ForMonth"] ?? (onMonth ?? DateTime.Now);
                ViewBag.ImportExportEnterpriseId = enterpriseId ?? 0;
                ViewBag.IsEdit = true;
            }
            else
            {
                // Báo cáo chỉ tiêu công nghiệp không lưu các dòng tiêu đề nhóm. Khi sửa,
                // dựng lại toàn bộ khung từ danh mục rồi gắn số liệu đã lưu theo chỉ tiêu.
                var catalogResult = LoadViewTypeReport(enterpriseId, onMonth, null, (int)EnumTypeBusiness.Manufacturing) as PartialViewResult;
                var catalog = catalogResult?.Model as List<ReportDataImportModel>;
                if (catalog != null && catalog.Any())
                {
                    dataImports = MergeBusinessProductData(catalog, dataImports);
                }
                ViewBag.IsBusinessProductReport = true;
                if (catalogResult != null)
                {
                    ViewBag.ExportBusinessProductOptions = catalogResult.ViewData["ExportBusinessProductOptions"];
                    ViewBag.ImportBusinessProductOptions = catalogResult.ViewData["ImportBusinessProductOptions"];
                    ViewBag.BusinessProductEnterpriseId = catalogResult.ViewData["BusinessProductEnterpriseId"];
                    ViewBag.ForMonth = catalogResult.ViewData["ForMonth"] ?? (onMonth ?? DateTime.Now);
                }
            }

            var typeReportName = GetTypeBusinessDisplayName(selectedType);

            var reportModel = new TourismReportModel
            {
                DayDeadlineSendReport =
                    int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Report")?.ConfigValue ?? "0"),
                DayDeadlineSendReportLate =
                    int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Late_Report")?.ConfigValue ?? "0"),
                EnterpriseId = enterpriseId,
                ForMonth = onMonth ?? DateTime.Now,
                ListDataImports = dataImports,
                EnterpriseName = enterpriseModel.BusinessName,
                TypeReport = selectedType,
                TypeReportName = typeReportName,
                ListTypeBusiness = GetListTypeBusinessItems(),
                IsEdit = true,
                AccessToken = (string)Session[$"VNPT-SmartCA-{User?.UserName}-AccessToken"],
                EnableSignDigitalDoc =
                    (_configCache.GetViaKey("Enable_SignDigital_Doc")?.ConfigValue ?? "0") != "0",
                IsEnterpriseUser = OperationalScope.IsEnterpriseUser
            };

            return PartialView("_Edit", reportModel);
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Edit(TourismReportModel model)
        {
            StringBuilder logActions = new StringBuilder();
            logActions.AppendLine("=========================================");

            if (IsReportLocked(model.ForMonth))
            {
                return Json(new
                {
                    status = false,
                    errorCode = 1,
                    message = CreateMessage(GetReportLockedMessage(model.ForMonth), EnumProcessType.NonFormat,
                        EnumMsgIcon.Error)
                });
            }

            #region Check Valid Form

            var enterpriseModel = _enterpriseCache.GetById(model.EnterpriseId);
            if (enterpriseModel == null)
            {
                logActions.AppendLine(" - Lỗi: Doanh nghiệp không tồn tại");
                AppProcessor.Logger.Message(logActions.ToString());

                return Json(new
                {
                    status = false,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            }

            if (!ModelState.IsValid)
            {
                ViewBag.Title =
                    $"{_importTile} <b>[{enterpriseModel.BusinessName}]</b> tháng <b class='text-yellow'>[{model.ForMonth:MM/yyyy}]</b>";
                var dataImports = _importCache.GetViaEnterpriseOnMonth(model.EnterpriseId, model.ForMonth);
                if (dataImports == null || dataImports.Count <= 0)
                    return Json(new
                    {
                        status = false,
                        message = CreateMessage($"{_importTile}",
                            EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                    });

                if (model.TypeReport == EnumTypeBusiness.Trading)
                {
                    var tradingResult = LoadTradingReport(model.EnterpriseId, model.ForMonth, null, dataImports);
                    ViewBag.IsTradingReport = true;
                    ViewBag.TradingProductOptions = tradingResult.ViewData["TradingProductOptions"];
                    ViewBag.ForMonth = tradingResult.ViewData["ForMonth"] ?? model.ForMonth;
                }
                else if (model.TypeReport == EnumTypeBusiness.ImportExport)
                {
                    var ieResult = LoadImportExportReport(model.EnterpriseId, model.ForMonth, null, dataImports);
                    ViewBag.IsImportExportReport = true;
                    ViewBag.ListNationals = ieResult.ViewData["ListNationals"];
                    ViewBag.ForMonth = ieResult.ViewData["ForMonth"] ?? model.ForMonth;
                    ViewBag.ImportExportEnterpriseId = model.EnterpriseId ?? 0;
                    ViewBag.IsEdit = true;
                }
                else
                {
                    var catalogResult = LoadViewTypeReport(model.EnterpriseId, model.ForMonth, null, (int)EnumTypeBusiness.Manufacturing) as PartialViewResult;
                    ViewBag.IsBusinessProductReport = true;
                    if (catalogResult != null)
                    {
                        ViewBag.ExportBusinessProductOptions = catalogResult.ViewData["ExportBusinessProductOptions"];
                        ViewBag.ImportBusinessProductOptions = catalogResult.ViewData["ImportBusinessProductOptions"];
                        ViewBag.BusinessProductEnterpriseId = catalogResult.ViewData["BusinessProductEnterpriseId"];
                        ViewBag.ForMonth = catalogResult.ViewData["ForMonth"] ?? model.ForMonth;
                    }
                }

                var reportModel = new TourismReportModel
                {
                    DayDeadlineSendReport =
                        int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Report")?.ConfigValue ?? "0"),
                    DayDeadlineSendReportLate =
                        int.Parse(_configCache.GetViaKey("Day_Deadline_Send_Late_Report")?.ConfigValue ?? "0"),
                    EnterpriseId = model.EnterpriseId,
                    ForMonth = model.ForMonth,
                    ListDataImports = dataImports,
                    EnterpriseName = enterpriseModel.BusinessName,
                    TypeReport = model.TypeReport,
                    TypeReportName = string.IsNullOrWhiteSpace(model.TypeReportName) || model.TypeReportName.StartsWith("TypeBusiness_") ? GetTypeBusinessDisplayName(model.TypeReport) : model.TypeReportName,
                    ListTypeBusiness = GetListTypeBusinessItems(),
                    IsEdit = true,
                    EnableSignDigitalDoc =
                        (_configCache.GetViaKey("Enable_SignDigital_Doc")?.ConfigValue ?? "0") != "0",
                    IsEnterpriseUser = OperationalScope.IsEnterpriseUser
                };
                return PartialView("_Edit", reportModel);
            }

            #endregion

            //logActions.AppendLine($" - [{User.UserName}] thực hiện gửi báo cáo [{EnumHelper.GetDescription((EnumTypeBusiness)enterpriseModel.TypeBusiness)}] cho doanh nghiệp [{enterpriseModel.BusinessName}]");
            logActions.AppendLine($" - [{User.UserName}] thực hiện gửi báo cáo [{model.TypeReportName}] cho doanh nghiệp [{enterpriseModel.BusinessName}]");
            logActions.AppendLine(" - Đọc nội dung báo cáo");

            var dataReport = ReadFormData(Request.Form, model.EnterpriseId ?? 0);
            EnsureTradingDynamicCodes(dataReport, model.EnterpriseId ?? 0);

            if (string.Equals(Request.Form["BusinessProductReport"], "true", StringComparison.OrdinalIgnoreCase))
            {
                string revenueError;
                if (!ValidateRevenueConstraint(dataReport, out revenueError))
                {
                    logActions.AppendLine(" - Lỗi: " + revenueError);
                    AppProcessor.Logger.Message(logActions.ToString());
                    return Json(new
                    {
                        status = false,
                        errorCode = 1,
                        message = CreateMessage(revenueError, EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }
            }

            if (string.Equals(Request.Form["TradingReport"], "true", StringComparison.OrdinalIgnoreCase))
            {
                string tradingError;
                if (!ValidateTradingDynamicConstraint(dataReport, out tradingError))
                {
                    logActions.AppendLine(" - Lỗi: " + tradingError);
                    AppProcessor.Logger.Message(logActions.ToString());
                    return Json(new
                    {
                        status = false,
                        errorCode = 1,
                        message = CreateMessage(tradingError, EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }
            }

            #region Create Report And File Path

            var pathReportTemplate = Server.MapPath("~/Contents/Modules/Report/Templates/_TemplateImportReport.rdlc");
            string mimeType;
            string fileExt;

            var fullSignedPath = HostingEnvironment.MapPath("/" + _signedFilesPathFolder);
            var fileNameReport = $"Report-{enterpriseModel.BusinessName}-{User?.UserName}";

            var dataImportViaTemplates =
                CreateReport(dataReport, fileNameReport, pathReportTemplate, out mimeType, out fileExt);

            var subFolderSignedPath = Path.Combine(fullSignedPath, $"{model.ForMonth.Year}", $"{model.ForMonth.Month}",
                $"{enterpriseModel.EnterpriseId}");
            if (!Directory.Exists(subFolderSignedPath) && !string.IsNullOrEmpty(subFolderSignedPath))
                Directory.CreateDirectory(subFolderSignedPath);
            var fileNameWithExt = $"{fileNameReport}.{fileExt}";
            var fileNameSigned = $"Report_{enterpriseModel.EnterpriseId}_signed.{fileExt}";
            var fileSignedFullPath = Path.Combine(subFolderSignedPath, fileNameSigned);

            #endregion

            if (model.EnableSignDigitalDoc)
            {
                logActions.AppendLine(" - Thực hiện ký số báo cáo");

                #region Sign Data

                var accessToken = (string)Session[$"VNPT-SmartCA-{User?.UserName}-AccessToken"];
                if (string.IsNullOrEmpty(accessToken))
                {
                    logActions.AppendLine(" - Chưa đăng nhập Smart CA");
                    AppProcessor.Logger.Message(logActions.ToString());

                    return Json(new
                    {
                        status = false,
                        errorCode = 1,
                        message = CreateMessage("Bạn chưa đăng nhập tài khoản Smart CA", EnumProcessType.NonFormat,
                            EnumMsgIcon.Error)
                    });
                }

                int isSuccess;
                try
                {
                    //isSuccess = SignHash(accessToken, dataImportViaTemplates, fileNameWithExt, fileExt, fileSignedFullPath);
                    string msgSignLogs;
                    isSuccess = Sign(accessToken, dataImportViaTemplates, fileNameWithExt, fileSignedFullPath, out msgSignLogs);
                    logActions.AppendLine(msgSignLogs);
                }
                catch (Exception e)
                {
                    logActions.AppendLine($" - Thực hiện {_digitalSignTitle} dữ liệu báo cáo thất bại. Lỗi: [{e.Message}]");
                    AppProcessor.Logger.Message(logActions.ToString());

                    return Json(new
                    {
                        status = false,
                        errorCode = 1,
                        message = CreateMessage(
                            $"Thực hiện {_digitalSignTitle} dữ liệu báo cáo thất bại. Lỗi: [{e.Message}]",
                            EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }

                if (isSuccess > 0)
                {
                    var errMsg = "";
                    switch (isSuccess)
                    {
                        case 1:
                            errMsg = "Ký số thất bại";
                            break;
                        case 2:
                            errMsg = "Lỗi thông tin chữ ký số";
                            break;
                        case 3:
                            errMsg = "Người dùng không xác nhận ký số từ ứng dụng";
                            break;
                        case 4:
                            errMsg = "Lỗi chữ ký số";
                            break;
                        case 5:
                            errMsg = "Chữ ký số không khớp";
                            break;
                        case 6:
                            errMsg = "Từ chối ký số";
                            break;
                    }

                    logActions.AppendLine($" - Thực hiện {_digitalSignTitle} dữ liệu báo cáo thất bại. Lỗi: [{errMsg}]");
                    AppProcessor.Logger.Message(logActions.ToString());

                    return Json(new
                    {
                        status = false,
                        errorCode = 1,
                        message = CreateMessage(
                            $"Thực hiện {_digitalSignTitle} dữ liệu báo cáo thất bại. Lỗi: [{errMsg}]",
                            EnumProcessType.NonFormat, EnumMsgIcon.Error)
                    });
                }

                logActions.AppendLine($" - Thực hiện {_digitalSignTitle} dữ liệu báo cáo thành công");

                #endregion
            }
            else
            {
                logActions.AppendLine($" - Thực hiện {_digitalSignTitle} dữ liệu báo cáo thành công");

                System.IO.File.WriteAllBytes(fileSignedFullPath, dataImportViaTemplates);
            }

            if (string.IsNullOrWhiteSpace(model.TypeReportName) || model.TypeReportName.StartsWith("TypeBusiness_"))
            {
                model.TypeReportName = GetTypeBusinessDisplayName(model.TypeReport);
            }

            var enterpriseId = _importCache.Import(new ReportDataImportModel
            {
                EnterpriseId = model.EnterpriseId,
                ForMonth = model.ForMonth,
                TypeReport = (int)model.TypeReport,
                TypeReportName = model.TypeReportName,
                //TypeReport = enterpriseModel.TypeBusiness,
                //TypeReportName =
                //    AppProcessor.Messagor.GetMessage(
                //        EnumHelper.GetDescription((EnumTypeBusiness)enterpriseModel.TypeBusiness)),
                DataImport = dataReport,
                CreatedBy = User.UserName,
                Reason = "Cập nhật báo cáo"
            });

            if (enterpriseId == -7)
            {
                logActions.AppendLine(" - Lưu nội dung báo cáo vào hệ thống thất bại: Doanh nghiệp không tồn tại");
                AppProcessor.Logger.Message(logActions.ToString());

                return Json(new
                {
                    status = false,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            }

            if (enterpriseId == -99)
            {
                logActions.AppendLine($" - Lưu nội dung báo cáo vào hệ thống thất bại: {AppProcessor.Messagor.GetMessage("ImportData_Message_Expire_Submit_Report")}");
                AppProcessor.Logger.Message(logActions.ToString());

                return Json(new
                {
                    status = false,
                    message = CreateMessage(AppProcessor.Messagor.GetMessage("ImportData_Message_Expire_Submit_Report"),
                        EnumProcessType.NonFormat, EnumMsgIcon.Error)
                });
            }

            logActions.AppendLine(" - Lưu nội dung báo cáo vào hệ thống thành công");
            AppProcessor.Logger.Message(logActions.ToString());

            var response = CreateMessage($"{_importTile} - [{model.EnterpriseName} tháng {model.ForMonth:MM/yyyy}]",
                EnumProcessType.Edit,
                enterpriseId > 0 ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = true, message = response });
        }

        #endregion

        #region Other Function

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult AddTradeCatalogProduct(string prefix)
        {
            var codePrefix = GetTradeCatalogCodePrefix(prefix);
            if (codePrefix == null)
                return Json(new { status = false, message = "Nhóm mặt hàng không hợp lệ." },
                    JsonRequestBehavior.AllowGet);

            ViewBag.TradePrefix = prefix.ToUpperInvariant();
            return PartialView("_AddTradeCatalogProduct");
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Add)]
        [ValidateInput(false)]
        public ActionResult AddTradeCatalogProduct(string prefix, string productName, string unit)
        {
            var codePrefix = GetTradeCatalogCodePrefix(prefix);
            productName = (productName ?? string.Empty).Trim();
            unit = (unit ?? string.Empty).Trim();
            if (codePrefix == null || string.IsNullOrWhiteSpace(productName))
                return Json(new { status = false, message = "Vui lòng nhập tên mặt hàng." });

            var products = _businessProductCache.GetAll() ?? new List<CateBusinessProductModel>();
            var nextNumber = products.Where(product => !string.IsNullOrWhiteSpace(product.ProductCode) &&
                                                       product.ProductCode.StartsWith(codePrefix,
                                                           StringComparison.OrdinalIgnoreCase))
                .Select(product => product.ProductCode.Substring(codePrefix.Length))
                .Select(suffix =>
                {
                    int number;
                    return int.TryParse(suffix, out number) ? number : 0;
                })
                .DefaultIfEmpty(0)
                .Max() + 1;

            int? productId = null;
            string productCode = null;
            // Retry to handle a concurrent insertion which happens to use the same next code.
            for (var attempt = 0; attempt < 10; attempt++)
            {
                productCode = codePrefix + (nextNumber + attempt).ToString("D3");
                productId = _businessProductCache.Save(new CateBusinessProductModel
                {
                    ProductCode = productCode,
                    ProductName = productName,
                    IndustryId = null,
                    Unit = unit,
                    DisplayOrder = 0,
                    IsActive = true,
                    UpdatedBy = User.UserName
                });
                if (productId != -2) break;
            }

            if (!productId.HasValue || productId.Value <= 0)
                return Json(new { status = false, message = "Không thể thêm mặt hàng. Vui lòng thử lại." });

            return Json(new
            {
                status = true,
                product = new { code = productCode, name = productName, unit }
            });
        }

        [AjaxOnly]
        [HttpGet]
        [AllowAnyPermission]
        public ActionResult SearchTradingProducts(string q = null, int page = 1)
        {
            const int pageSize = 20;
            page = Math.Max(1, page);
            int total;
            var search = new SysSearchModel
            {
                Search = string.IsNullOrWhiteSpace(q) ? null : q.Trim(),
                Order = "1",
                OrderDir = "ASC",
                StartIndex = (page - 1) * pageSize,
                PageSize = pageSize
            };
            var products = (_businessProductCache.Get(out total, null, search) ?? new List<CateBusinessProductModel>())
                .Where(x => x.IsActive && !string.IsNullOrWhiteSpace(x.ProductCode))
                .Select(x => new { id = x.ProductCode, text = x.ProductName + " (" + x.ProductCode + ")", name = x.ProductName })
                .ToList();
            return Json(new { results = products, pagination = new { more = page * pageSize < total } }, JsonRequestBehavior.AllowGet);
        }

        [AjaxOnly]
        [HttpGet]
        [AllowAnyPermission]
        public ActionResult SearchUnconfiguredBusinessProducts(int enterpriseId, string prefix, string q = null, int page = 1)
        {
            const int pageSize = 20;
            page = Math.Max(1, page);
            prefix = string.Equals(prefix, "NK", StringComparison.OrdinalIgnoreCase) ? "NK" : "XK";
            var all = _businessProductCache.GetUnconfiguredByPrefix(enterpriseId, prefix) ?? new List<CateBusinessProductModel>();
            if (!string.IsNullOrWhiteSpace(q))
            {
                q = q.Trim();
                all = all.Where(x => (x.ProductName ?? string.Empty).IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0 || (x.ProductCode ?? string.Empty).IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0).ToList();
            }
            var total = all.Count;
            var results = all.OrderBy(x => x.DisplayOrder).ThenBy(x => x.ProductName).Skip((page - 1) * pageSize).Take(pageSize)
                .Select(x => new { id = x.ProductCode, text = x.ProductName + " (" + x.ProductCode + ")", name = x.ProductName, unit = x.Unit }).ToList();
            return Json(new { results, pagination = new { more = page * pageSize < total } }, JsonRequestBehavior.AllowGet);
        }

        [AjaxOnly]
        [HttpGet]
        [AllowAnyPermission]
        public ActionResult SearchNationals(string q = null, int page = 1)
        {
            const int pageSize = 20;
            page = Math.Max(1, page);
            int total;
            var search = new SysSearchModel { Search = string.IsNullOrWhiteSpace(q) ? null : q.Trim(), Order = "1", OrderDir = "ASC", StartIndex = (page - 1) * pageSize, PageSize = pageSize };
            var nationals = _nationalCache.Get(out total, search) ?? new List<CateNationalModel>();
            var results = nationals.Select(x => new { id = x.NationalCode, text = x.NationalName, name = x.NationalName }).ToList();
            return Json(new { results, pagination = new { more = page * pageSize < total } }, JsonRequestBehavior.AllowGet);
        }

        [AjaxOnly]
        [HttpGet]
        [AllowAnyPermission]
        public ActionResult SearchExportProducts(int? enterpriseId, string q = null, int page = 1)
        {
            const int pageSize = 20;
            page = Math.Max(1, page);
            var all = new List<CateBusinessProductModel>();
            if (enterpriseId.GetValueOrDefault() > 0)
            {
                all.AddRange(_businessProductCache.GetUnconfiguredByPrefix(enterpriseId.Value, "XK") ?? new List<CateBusinessProductModel>());
                all.AddRange(_businessProductCache.GetByPrefix(enterpriseId.Value, "XK") ?? new List<CateBusinessProductModel>());
                all = all.GroupBy(x => x.ProductCode ?? string.Empty, StringComparer.OrdinalIgnoreCase).Select(x => x.First()).ToList();
            }
            all = all.Where(x => !string.IsNullOrWhiteSpace(x.ProductCode) && x.ProductCode.StartsWith("XKB", StringComparison.OrdinalIgnoreCase)).ToList();
            if (!string.IsNullOrWhiteSpace(q))
            {
                q = q.Trim();
                all = all.Where(x => (x.ProductName ?? string.Empty).IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0 || (x.ProductCode ?? string.Empty).IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0).ToList();
            }
            var total = all.Count;
            var products = all.OrderBy(x => x.DisplayOrder).ThenBy(x => x.ProductName).Skip((page - 1) * pageSize).Take(pageSize)
                .Select(x => new { id = x.ProductCode, text = x.ProductName, name = x.ProductName }).ToList();
            return Json(new { results = products, pagination = new { more = page * pageSize < total } }, JsonRequestBehavior.AllowGet);
        }

        [AjaxOnly]
        [HttpGet]
        [AllowAnyPermission]
        public ActionResult LoadViewTypeReport(int? enterpriseId, DateTime? onMonth = null, string forMonth = null, int? typeReport = null)
        {
            if (typeReport.HasValue && typeReport.Value == (int)EnumTypeBusiness.Trading)
            {
                return LoadTradingReport(enterpriseId, onMonth, forMonth);
            }
            if (typeReport.HasValue && typeReport.Value == (int)EnumTypeBusiness.ImportExport)
            {
                return LoadImportExportReport(enterpriseId, onMonth, forMonth);
            }

            if (!typeReport.HasValue && enterpriseId.HasValue && enterpriseId.Value > 0)
            {
                var ent = _enterpriseCache.GetById(enterpriseId.Value);
                if (ent != null && !string.IsNullOrEmpty(ent.TypeBusiness))
                {
                    int biz;
                    if (int.TryParse(ent.TypeBusiness.Split(',')[0], out biz))
                    {
                        if (biz == (int)EnumTypeBusiness.Trading)
                            return LoadTradingReport(enterpriseId, onMonth, forMonth);
                        if (biz == (int)EnumTypeBusiness.ImportExport)
                            return LoadImportExportReport(enterpriseId, onMonth, forMonth);
                    }
                }
            }

            var products = new List<ReportDataImportModel>();
            var mainProducts = new List<ReportDataImportModel>();
            var exportProducts = new List<ReportDataImportModel>();
            var importProducts = new List<ReportDataImportModel>();
            if (!enterpriseId.HasValue || enterpriseId.Value <= 0)
            {
                return PartialView("_BusinessProductReport", products);
            }

            var targetDate = onMonth;
            if (!targetDate.HasValue && !string.IsNullOrWhiteSpace(forMonth))
            {
                DateTime dt;
                if (DateTime.TryParseExact(forMonth.Trim(), new[] { "MM/yyyy", "M/yyyy", "yyyy-MM-dd", "yyyy/MM", "dd/MM/yyyy" },
                    System.Globalization.CultureInfo.InvariantCulture, System.Globalization.DateTimeStyles.None, out dt))
                {
                    targetDate = dt;
                }
                else if (DateTime.TryParse(forMonth.Trim(), out dt))
                {
                    targetDate = dt;
                }
            }
            var currentForMonth = targetDate ?? DateTime.Now;

            try
            {
                mainProducts = (_businessProductCache.GetViaEnterprise(enterpriseId.Value) ?? new List<CateBusinessProductModel>())
                    .Select(product => new ReportDataImportModel
                    {
                        Targets = product.ProductName,
                        Unit = product.Unit,
                        // Mã đường dẫn: sản phẩm thuộc nhóm "2. Sản phẩm công nghiệp chủ yếu".
                        // Ví dụ mã danh mục 3512200 được lưu là 2.3512200.
                        Code = "2." + (!string.IsNullOrWhiteSpace(product.ProductCode)
                            ? product.ProductCode.Trim()
                            : product.ProductId.ToString())
                    }).ToList();
            }
            catch (Exception exMain)
            {
                AppProcessor.Logger.Message("GetViaEnterprise error: " + exMain.Message);
            }

            try
            {
                exportProducts = (_businessProductCache.GetByPrefix(enterpriseId.Value, "XK") ?? new List<CateBusinessProductModel>())
                    .Select(product => new ReportDataImportModel
                    {
                        Targets = product.ProductName,
                        Unit = product.Unit,
                        Code = product.ProductCode
                    }).ToList();
            }
            catch (Exception exXk)
            {
                AppProcessor.Logger.Message("GetByPrefix XK error: " + exXk.Message);
            }

            try
            {
                importProducts = (_businessProductCache.GetByPrefix(enterpriseId.Value, "NK") ?? new List<CateBusinessProductModel>())
                    .Select(product => new ReportDataImportModel
                    {
                        Targets = product.ProductName,
                        Unit = product.Unit,
                        Code = product.ProductCode
                    }).ToList();
            }
            catch (Exception exNk)
            {
                AppProcessor.Logger.Message("GetByPrefix NK error: " + exNk.Message);
            }

            // Khung chỉ tiêu theo mẫu báo cáo doanh nghiệp hằng tháng.
            products.Add(CreateBusinessProductLine("Tổng doanh thu", "Tỷ đồng", "1"));
            products.Add(CreateBusinessProductLine("Trong đó doanh thu công nghiệp", "Tỷ đồng", "1.1"));
            products.Add(CreateBusinessProductHeader("Sản phẩm công nghiệp chủ yếu", "2"));
            products.AddRange(mainProducts);
            products.Add(CreateBusinessProductLine("Kim ngạch xuất khẩu", "1.000 USD", "6"));
            products.Add(CreateBusinessProductHeader("Nhóm/mặt hàng xuất khẩu chủ yếu", "6.0"));
            products.AddRange(exportProducts);
            products.Add(CreateBusinessProductLine("Kim ngạch nhập khẩu", "1.000 USD", "7"));
            products.Add(CreateBusinessProductHeader("Nhóm/mặt hàng nhập khẩu chủ yếu", "7.0"));
            products.AddRange(importProducts);
            ApplyBusinessProductHierarchy(products);

            // Tự động nạp kế hoạch năm nếu đã từng nhập trong năm báo cáo hiện tại
            try
            {
                var reportYear = currentForMonth.Year;
                var allEnterpriseReports = _importCache.GetViaEnterpriseOnMonth(enterpriseId.Value, null);
                if (allEnterpriseReports != null && allEnterpriseReports.Any())
                {
                    var yearlyPlans = allEnterpriseReports
                        .Where(r => r.ForMonth.HasValue && r.ForMonth.Value.Year == reportYear && r.AccumulatedBeginingOfYear.HasValue && r.AccumulatedBeginingOfYear.Value > 0)
                        .ToList();

                    if (yearlyPlans.Any())
                    {
                        var plansByCode = yearlyPlans
                            .Where(r => !string.IsNullOrWhiteSpace(r.Code))
                            .GroupBy(r => r.Code.Trim(), StringComparer.OrdinalIgnoreCase)
                            .ToDictionary(g => g.Key, g => g.OrderByDescending(r => r.ForMonth ?? DateTime.MinValue).First().AccumulatedBeginingOfYear, StringComparer.OrdinalIgnoreCase);

                        var plansByTarget = yearlyPlans
                            .Where(r => !string.IsNullOrWhiteSpace(r.Targets))
                            .GroupBy(r => r.Targets.Trim(), StringComparer.OrdinalIgnoreCase)
                            .ToDictionary(g => g.Key, g => g.OrderByDescending(r => r.ForMonth ?? DateTime.MinValue).First().AccumulatedBeginingOfYear, StringComparer.OrdinalIgnoreCase);

                        foreach (var p in products)
                        {
                            // Kim ngạch xuất khẩu (6) và nhập khẩu (7) không nạp trực tiếp, chỉ tính từ các mặt hàng bên trong
                            if (p.Code == "6" || p.Code == "06" || p.Code == "7" || p.Code == "07" || p.Targets == "Kim ngạch xuất khẩu" || p.Targets == "Kim ngạch nhập khẩu")
                            {
                                continue;
                            }

                            if (!p.AccumulatedBeginingOfYear.HasValue || p.AccumulatedBeginingOfYear.Value <= 0)
                            {
                                double? planVal;
                                if (!string.IsNullOrWhiteSpace(p.Code) && plansByCode.TryGetValue(p.Code.Trim(), out planVal))
                                {
                                    p.AccumulatedBeginingOfYear = planVal;
                                }
                                else if (!string.IsNullOrWhiteSpace(p.Targets) && plansByTarget.TryGetValue(p.Targets.Trim(), out planVal))
                                {
                                    p.AccumulatedBeginingOfYear = planVal;
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception exPlan)
            {
                AppProcessor.Logger.Message("YearlyPlan loading error: " + exPlan.Message);
            }

            // Kim ngạch xuất khẩu và nhập khẩu chỉ tính từ tổng các mặt hàng bên trong
            RecalculateTradeSummaryInModel(products);

            ViewBag.BusinessProductEnterpriseId = enterpriseId.Value;
            ViewBag.ForMonth = currentForMonth;

            return PartialView("_BusinessProductReport", products);
        }

        private PartialViewResult LoadTradingReport(int? enterpriseId, DateTime? onMonth, string forMonth,
            List<ReportDataImportModel> savedData = null)
        {
            savedData = RestoreTradingHierarchyCodes(savedData);
            if (savedData != null)
            {
                savedData = savedData
                    .Where(x => !(x.Code == "38" || x.Code == "39" || ((x.Level == "1.13.1" || x.Level == "1.13.2") && (string.Equals(x.Targets, "Trong đó: Bán lẻ", StringComparison.OrdinalIgnoreCase) || string.Equals(x.Targets, "Trong đó: Nền tảng trực tuyến", StringComparison.OrdinalIgnoreCase)))))
                    .ToList();
            }
            DateTime reportMonth;
            if (!onMonth.HasValue && !string.IsNullOrWhiteSpace(forMonth) &&
                DateTime.TryParse(forMonth, out reportMonth))
                onMonth = reportMonth;
            reportMonth = onMonth ?? DateTime.Now;

            var rows = CreateTradingReportLines();
            if (enterpriseId.HasValue && enterpriseId.Value > 0)
            {
                var previous = (_importCache.GetViaEnterpriseOnMonth(enterpriseId.Value, null) ?? new List<ReportDataImportModel>())
                    .Where(x => x.ForMonth.HasValue && x.ForMonth.Value.Year == reportMonth.Year &&
                                x.ForMonth.Value.Month < reportMonth.Month && x.TypeReport == (int)EnumTypeBusiness.Trading)
                    .GroupBy(x => x.Code ?? string.Empty, StringComparer.OrdinalIgnoreCase)
                    .ToDictionary(x => x.Key, x => x.Sum(y => y.PerformInPeriod ?? 0), StringComparer.OrdinalIgnoreCase);
                foreach (var row in rows)
                {
                    double value;
                    row.ComparedSamePeriodLastYear = previous.TryGetValue(row.Code ?? string.Empty, out value) ? value : 0;
                }
            }
            if (savedData != null)
            {
                foreach (var row in rows)
                {
                    var saved = savedData.FirstOrDefault(x => string.Equals(x.Code, row.Code, StringComparison.OrdinalIgnoreCase));
                    if (saved == null) continue;
                    row.PerformInPeriod = saved.PerformInPeriod;
                    row.PerformPreviousPeriod = saved.PerformPreviousPeriod;
                    row.AccumulatedBeginingOfYear = saved.AccumulatedBeginingOfYear;
                }

                var dynamicParents = savedData.Where(x => !string.IsNullOrWhiteSpace(x.Code) &&
                                                       x.Code.StartsWith("TM_", StringComparison.OrdinalIgnoreCase) &&
                                                       !x.Code.EndsWith("_BL", StringComparison.OrdinalIgnoreCase) &&
                                                       !x.Code.EndsWith("_TT", StringComparison.OrdinalIgnoreCase)).ToList();

                var dynamicRows = new List<ReportDataImportModel>();
                foreach (var p in dynamicParents)
                {
                    dynamicRows.Add(new ReportDataImportModel
                    {
                        Targets = p.Targets,
                        Unit = p.Unit ?? "Triệu đồng",
                        Code = p.Code,
                        PerformInPeriod = p.PerformInPeriod,
                        PerformPreviousPeriod = p.PerformPreviousPeriod,
                        AccumulatedBeginingOfYear = p.AccumulatedBeginingOfYear,
                        ComparedSamePeriodLastYear = (_importCache.GetViaEnterpriseOnMonth(enterpriseId, null) ?? new List<ReportDataImportModel>())
                            .Where(prev => prev.ForMonth.HasValue && prev.ForMonth.Value.Year == reportMonth.Year && prev.ForMonth.Value.Month < reportMonth.Month &&
                                        string.Equals(prev.Code, p.Code, StringComparison.OrdinalIgnoreCase))
                            .Sum(prev => prev.PerformInPeriod ?? 0)
                    });

                    var bl = savedData.FirstOrDefault(x => string.Equals(x.Code, p.Code + "_BL", StringComparison.OrdinalIgnoreCase));
                    dynamicRows.Add(new ReportDataImportModel
                    {
                        Targets = "Trong đó: Bán lẻ",
                        Unit = "Triệu đồng",
                        Code = p.Code + "_BL",
                        PerformInPeriod = bl != null ? bl.PerformInPeriod : p.PerformInPeriod,
                        PerformPreviousPeriod = bl != null ? bl.PerformPreviousPeriod : p.PerformPreviousPeriod,
                        AccumulatedBeginingOfYear = bl != null ? bl.AccumulatedBeginingOfYear : p.AccumulatedBeginingOfYear
                    });

                    var tt = savedData.FirstOrDefault(x => string.Equals(x.Code, p.Code + "_TT", StringComparison.OrdinalIgnoreCase));
                    dynamicRows.Add(new ReportDataImportModel
                    {
                        Targets = "Trong đó: Nền tảng trực tuyến",
                        Unit = "Triệu đồng",
                        Code = p.Code + "_TT",
                        PerformInPeriod = tt != null ? tt.PerformInPeriod : 0,
                        PerformPreviousPeriod = tt != null ? tt.PerformPreviousPeriod : 0,
                        AccumulatedBeginingOfYear = tt != null ? tt.AccumulatedBeginingOfYear : 0
                    });
                }

                var otherGoodsIndex = rows.FindIndex(x => x.Code == "34");
                if (otherGoodsIndex >= 0) rows.InsertRange(otherGoodsIndex + 1, dynamicRows);
                else rows.AddRange(dynamicRows);
            }

            ApplyTradingHierarchy(rows);
            RecalculateTradingSummary(rows);
            ViewBag.ForMonth = reportMonth;
            return PartialView("_TradingReport", rows);
        }

        private static List<ReportDataImportModel> CreateTradingReportLines()
        {
            return new List<ReportDataImportModel>
            {
                CreateBusinessProductLine("I. Doanh thu thuần hoạt động bán buôn, bán lẻ", "Triệu đồng", "01"),
                CreateBusinessProductLine("Trong đó: Bán lẻ", "Triệu đồng", "02"),
                CreateBusinessProductLine("Trong đó: Nền tảng trực tuyến", "Triệu đồng", "03"),
                CreateBusinessProductLine("1. Lương thực, thực phẩm", "Triệu đồng", "04"),
                CreateBusinessProductLine("Trong đó: Bán lẻ", "Triệu đồng", "05"),
                CreateBusinessProductLine("Trong đó: Nền tảng trực tuyến", "Triệu đồng", "06"),
                CreateBusinessProductLine("2. Hàng may mặc", "Triệu đồng", "07"),
                CreateBusinessProductLine("Trong đó: Bán lẻ", "Triệu đồng", "08"),
                CreateBusinessProductLine("Trong đó: Nền tảng trực tuyến", "Triệu đồng", "09"),
                CreateBusinessProductLine("3. Đồ dùng, dụng cụ, trang thiết bị gia đình", "Triệu đồng", "10"),
                CreateBusinessProductLine("Trong đó: Bán lẻ", "Triệu đồng", "11"),
                CreateBusinessProductLine("Trong đó: Nền tảng trực tuyến", "Triệu đồng", "12"),
                CreateBusinessProductLine("4. Văn phòng phẩm, văn hóa, giáo dục", "Triệu đồng", "13"),
                CreateBusinessProductLine("Trong đó: Bán lẻ", "Triệu đồng", "14"),
                CreateBusinessProductLine("Trong đó: Nền tảng trực tuyến", "Triệu đồng", "15"),
                CreateBusinessProductLine("5. Gỗ và vật liệu xây dựng", "Triệu đồng", "16"),
                CreateBusinessProductLine("Trong đó: Bán lẻ", "Triệu đồng", "17"),
                CreateBusinessProductLine("Trong đó: Nền tảng trực tuyến", "Triệu đồng", "18"),
                CreateBusinessProductLine("6. Phân bón, thuốc trừ sâu", "Triệu đồng", "19"),
                CreateBusinessProductLine("Trong đó: Bán lẻ", "Triệu đồng", "20"),
                CreateBusinessProductLine("Trong đó: Nền tảng trực tuyến", "Triệu đồng", "21"),
                CreateBusinessProductLine("7. Ô tô các loại", "Triệu đồng", "22"),
                CreateBusinessProductLine("Trong đó: Bán lẻ", "Triệu đồng", "23"),
                CreateBusinessProductLine("Trong đó: Nền tảng trực tuyến", "Triệu đồng", "24"),
                CreateBusinessProductLine("8. Phương tiện đi lại (trừ ô tô)", "Triệu đồng", "25"),
                CreateBusinessProductLine("Trong đó: Bán lẻ", "Triệu đồng", "26"),
                CreateBusinessProductLine("Trong đó: Nền tảng trực tuyến", "Triệu đồng", "27"),
                CreateBusinessProductLine("9. Xăng, dầu các loại", "Triệu đồng", "28"),
                CreateBusinessProductLine("Trong đó: Bán lẻ", "Triệu đồng", "29"),
                CreateBusinessProductLine("Trong đó: Nền tảng trực tuyến", "Triệu đồng", "30"),
                CreateBusinessProductLine("10. Nhiên liệu khác (trừ xăng dầu)", "Triệu đồng", "31"),
                CreateBusinessProductLine("Trong đó: Bán lẻ", "Triệu đồng", "32"),
                CreateBusinessProductLine("Trong đó: Nền tảng trực tuyến", "Triệu đồng", "33"),
                CreateBusinessProductLine("11. Hàng hóa khác", "Triệu đồng", "34"),
                CreateBusinessProductLine("II. Doanh thu thuần hoạt động sửa chữa ô tô, mô tô, xe máy và xe có động cơ khác", "Triệu đồng", "40")
            };
        }

        private static void ApplyTradingHierarchy(List<ReportDataImportModel> rows)
        {
            var otherNumber = 0;
            foreach (var row in rows)
            {
                var code = row.Code ?? "";
                if (code == "01") row.Level = "1";
                else if (code == "02") row.Level = "1.1";
                else if (code == "03") row.Level = "1.2";
                else if (new[] { "04", "07", "10", "13", "16", "19", "22", "25", "28", "31", "34" }.Contains(code)) row.Level = "1." + ((Convert.ToInt32(code) - 1) / 3 + 2);
                else if (new[] { "05", "08", "11", "14", "17", "20", "23", "26", "29", "32" }.Contains(code)) row.Level = "1." + ((Convert.ToInt32(code) - 2) / 3 + 2) + ".1";
                else if (new[] { "06", "09", "12", "15", "18", "21", "24", "27", "30", "33" }.Contains(code)) row.Level = "1." + ((Convert.ToInt32(code) - 3) / 3 + 2) + ".2";
                else if (code == "40") row.Level = "2";
                else if (code.StartsWith("TM_", StringComparison.OrdinalIgnoreCase) || code.Contains(".TM_"))
                {
                    if (code.EndsWith("_BL", StringComparison.OrdinalIgnoreCase))
                        row.Level = "1.13." + otherNumber + ".1";
                    else if (code.EndsWith("_TT", StringComparison.OrdinalIgnoreCase))
                        row.Level = "1.13." + otherNumber + ".2";
                    else
                    {
                        otherNumber++;
                        row.Level = "1.13." + otherNumber;
                    }
                }
            }
            var index = 0;
            foreach (var row in rows) row.Index = index++;
        }

        private static void RecalculateTradingSummary(List<ReportDataImportModel> rows)
        {
            // Dynamic parents = BL + TT
            var dynamicParents = rows.Where(r => {
                var c = r.Code ?? "";
                return (c.StartsWith("TM_", StringComparison.OrdinalIgnoreCase) || c.Contains(".TM_")) && !c.EndsWith("_BL", StringComparison.OrdinalIgnoreCase) && !c.EndsWith("_TT", StringComparison.OrdinalIgnoreCase);
            }).ToList();

            foreach (var parent in dynamicParents)
            {
                var bl = rows.FirstOrDefault(r => string.Equals(r.Code, parent.Code + "_BL", StringComparison.OrdinalIgnoreCase));
                var tt = rows.FirstOrDefault(r => string.Equals(r.Code, parent.Code + "_TT", StringComparison.OrdinalIgnoreCase));
                parent.PerformInPeriod = (bl?.PerformInPeriod ?? 0) + (tt?.PerformInPeriod ?? 0);
                parent.PerformPreviousPeriod = (bl?.PerformPreviousPeriod ?? 0) + (tt?.PerformPreviousPeriod ?? 0);
                parent.AccumulatedBeginingOfYear = (bl?.AccumulatedBeginingOfYear ?? 0) + (tt?.AccumulatedBeginingOfYear ?? 0);
            }

            var blRows = rows.Where(x => (x.Code ?? "").EndsWith("_BL", StringComparison.OrdinalIgnoreCase)).ToList();
            var ttRows = rows.Where(x => (x.Code ?? "").EndsWith("_TT", StringComparison.OrdinalIgnoreCase)).ToList();

            // Row 34 = sum of dynamic BL + TT
            var row34 = rows.FirstOrDefault(x => x.Code == "34");
            if (row34 != null)
            {
                row34.PerformInPeriod = blRows.Sum(x => x.PerformInPeriod ?? 0) + ttRows.Sum(x => x.PerformInPeriod ?? 0);
                row34.PerformPreviousPeriod = blRows.Sum(x => x.PerformPreviousPeriod ?? 0) + ttRows.Sum(x => x.PerformPreviousPeriod ?? 0);
                row34.AccumulatedBeginingOfYear = blRows.Sum(x => x.AccumulatedBeginingOfYear ?? 0) + ttRows.Sum(x => x.AccumulatedBeginingOfYear ?? 0);
            }

            var sums = new[] {
                new[] { "04", "05", "06" }, new[] { "07", "08", "09" }, new[] { "10", "11", "12" },
                new[] { "13", "14", "15" }, new[] { "16", "17", "18" }, new[] { "19", "20", "21" },
                new[] { "22", "23", "24" }, new[] { "25", "26", "27" }, new[] { "28", "29", "30" },
                new[] { "31", "32", "33" }
            };
            foreach (var sum in sums)
            {
                var parent = rows.FirstOrDefault(x => x.Code == sum[0]);
                var retail = rows.FirstOrDefault(x => x.Code == sum[1]);
                var online = rows.FirstOrDefault(x => x.Code == sum[2]);
                if (parent == null || retail == null || online == null) continue;
                parent.PerformInPeriod = (retail.PerformInPeriod ?? 0) + (online.PerformInPeriod ?? 0);
                parent.PerformPreviousPeriod = (retail.PerformPreviousPeriod ?? 0) + (online.PerformPreviousPeriod ?? 0);
                parent.AccumulatedBeginingOfYear = (retail.AccumulatedBeginingOfYear ?? 0) + (online.AccumulatedBeginingOfYear ?? 0);
            }

            var totalRetail = rows.FirstOrDefault(x => x.Code == "02");
            var totalOnline = rows.FirstOrDefault(x => x.Code == "03");
            var retailRows = rows.Where(x => new[] { "05", "08", "11", "14", "17", "20", "23", "26", "29", "32" }.Contains(x.Code)).ToList();
            var onlineRows = rows.Where(x => new[] { "06", "09", "12", "15", "18", "21", "24", "27", "30", "33" }.Contains(x.Code)).ToList();
            if (totalRetail != null)
            {
                totalRetail.PerformInPeriod = retailRows.Sum(x => x.PerformInPeriod ?? 0) + blRows.Sum(x => x.PerformInPeriod ?? 0);
                totalRetail.PerformPreviousPeriod = retailRows.Sum(x => x.PerformPreviousPeriod ?? 0) + blRows.Sum(x => x.PerformPreviousPeriod ?? 0);
                totalRetail.AccumulatedBeginingOfYear = retailRows.Sum(x => x.AccumulatedBeginingOfYear ?? 0) + blRows.Sum(x => x.AccumulatedBeginingOfYear ?? 0);
            }
            if (totalOnline != null)
            {
                totalOnline.PerformInPeriod = onlineRows.Sum(x => x.PerformInPeriod ?? 0) + ttRows.Sum(x => x.PerformInPeriod ?? 0);
                totalOnline.PerformPreviousPeriod = onlineRows.Sum(x => x.PerformPreviousPeriod ?? 0) + ttRows.Sum(x => x.PerformPreviousPeriod ?? 0);
                totalOnline.AccumulatedBeginingOfYear = onlineRows.Sum(x => x.AccumulatedBeginingOfYear ?? 0) + ttRows.Sum(x => x.AccumulatedBeginingOfYear ?? 0);
            }
            var total = rows.FirstOrDefault(x => x.Code == "01");
            var mainGroupCodes = new[] { "04", "07", "10", "13", "16", "19", "22", "25", "28", "31", "34" };
            var mainGroupRows = rows.Where(x => mainGroupCodes.Contains(x.Code)).ToList();
            if (total != null)
            {
                total.PerformInPeriod = mainGroupRows.Sum(x => x.PerformInPeriod ?? 0);
                total.PerformPreviousPeriod = mainGroupRows.Sum(x => x.PerformPreviousPeriod ?? 0);
                total.AccumulatedBeginingOfYear = mainGroupRows.Sum(x => x.AccumulatedBeginingOfYear ?? 0);
            }
        }

        private PartialViewResult LoadImportExportReport(int? enterpriseId, DateTime? onMonth, string forMonth = null,
            List<ReportDataImportModel> savedData = null)
        {
            savedData = RestoreImportExportHierarchyCodes(savedData);
            DateTime reportMonth;
            if (!onMonth.HasValue && !string.IsNullOrWhiteSpace(forMonth) &&
                DateTime.TryParse(forMonth, out reportMonth))
                onMonth = reportMonth;
            reportMonth = onMonth ?? DateTime.Now;

            var rows = CreateImportExportReportLines(enterpriseId);

            if (savedData != null && savedData.Any())
            {
                foreach (var row in rows)
                {
                    var saved = savedData.FirstOrDefault(x => string.Equals(x.Code, row.Code, StringComparison.OrdinalIgnoreCase));
                    if (saved == null) continue;
                    row.PerformPreviousPeriod = saved.PerformPreviousPeriod;
                    row.ComparedSamePeriodLastYear = saved.ComparedSamePeriodLastYear;
                    row.PerformInPeriod = saved.PerformInPeriod;
                    row.AccumulatedBeginingOfYear = saved.AccumulatedBeginingOfYear;
                }

                var dynamicCountries = savedData.Where(x => !string.IsNullOrWhiteSpace(x.Code) &&
                                                            (x.Code.StartsWith("XK_QG_", StringComparison.OrdinalIgnoreCase) || (x.Level ?? "").StartsWith("1.1.")) &&
                                                            !string.Equals(x.Code, "XK_QG_HEADER", StringComparison.OrdinalIgnoreCase) &&
                                                            !string.Equals(x.Level, "1.1", StringComparison.OrdinalIgnoreCase))
                    .Select(x => new ReportDataImportModel
                    {
                        Targets = x.Targets,
                        // Dòng chia theo quốc gia dùng đơn vị mặc định Kg.
                        Unit = x.Unit ?? "Kg",
                        Code = x.Code,
                        Level = x.Level,
                        Index = x.Index,
                        PerformPreviousPeriod = x.PerformPreviousPeriod,
                        ComparedSamePeriodLastYear = x.ComparedSamePeriodLastYear,
                        PerformInPeriod = x.PerformInPeriod,
                        AccumulatedBeginingOfYear = x.AccumulatedBeginingOfYear
                    }).ToList();

                var xkMhHeaderIndex = rows.FindIndex(x => string.Equals(x.Code, "XK_MH_HEADER", StringComparison.OrdinalIgnoreCase));
                if (xkMhHeaderIndex >= 0)
                {
                    rows.InsertRange(xkMhHeaderIndex, dynamicCountries);
                }
                else
                {
                    rows.AddRange(dynamicCountries);
                }

                var dynamicProducts = savedData.Where(x => !string.IsNullOrWhiteSpace(x.Code) &&
                                                           (x.Code.StartsWith("XK_MH_", StringComparison.OrdinalIgnoreCase) || (x.Level ?? "").StartsWith("1.2.")) &&
                                                           !string.Equals(x.Code, "XK_MH_HEADER", StringComparison.OrdinalIgnoreCase) &&
                                                           !string.Equals(x.Level, "1.2", StringComparison.OrdinalIgnoreCase))
                    .Select(x => new ReportDataImportModel
                    {
                        Targets = x.Targets,
                        // Mặt hàng xuất khẩu trực tiếp chia theo quốc gia dùng Kg.
                        // Đơn vị riêng của danh mục doanh nghiệp chỉ áp dụng cho nhóm ủy thác.
                        Unit = "Kg",
                        Code = x.Code,
                        Level = x.Level,
                        Index = x.Index,
                        PerformPreviousPeriod = x.PerformPreviousPeriod,
                        ComparedSamePeriodLastYear = x.ComparedSamePeriodLastYear,
                        PerformInPeriod = x.PerformInPeriod,
                        AccumulatedBeginingOfYear = x.AccumulatedBeginingOfYear
                    }).ToList();

                var utXkIndex = rows.FindIndex(x => string.Equals(x.Code, "UT_XK", StringComparison.OrdinalIgnoreCase));
                if (utXkIndex >= 0)
                {
                    rows.InsertRange(utXkIndex, dynamicProducts);
                }
                else
                {
                    rows.AddRange(dynamicProducts);
                }
            }

            ApplyImportExportHierarchy(rows);
            RecalculateImportExportSummary(rows);

            ViewBag.ForMonth = reportMonth;
            ViewBag.ImportExportEnterpriseId = enterpriseId ?? 0;
            ViewBag.ListNationals = new List<CateNationalModel>();
            return PartialView("_ImportExportReport", rows);
        }

        private List<ReportDataImportModel> CreateImportExportReportLines(int? enterpriseId)
        {
            var lines = new List<ReportDataImportModel>
            {
                CreateBusinessProductLine("TỔNG GIÁ TRỊ (FOB) = I + II", "Kg", "FOB"),
                CreateBusinessProductLine("I.Tổng trị giá xuất khẩu trực tiếp", "Kg", "XK_TT"),
                new ReportDataImportModel { Targets = "Chia theo nước cuối cùng hàng đến", Code = "XK_QG_HEADER" },
                new ReportDataImportModel { Targets = "Mặt hàng xuất khẩu trực tiếp chia theo nước cuối cùng hàng đến", Code = "XK_MH_HEADER" },
                CreateBusinessProductLine("II. Trị giá ủy thác xuất khẩu", "Kg", "UT_XK"),
                new ReportDataImportModel { Targets = "Mặt hàng ủy thác xuất khẩu", Code = "UT_MH_HEADER" }
            };

            if (enterpriseId.HasValue && enterpriseId.Value > 0)
            {
                try
                {
                    var mainProducts = (_businessProductCache.GetViaEnterprise(enterpriseId.Value) ?? new List<CateBusinessProductModel>())
                        .Select(product => new ReportDataImportModel
                        {
                            Targets = product.ProductName,
                            Unit = product.Unit,
                            Code = !string.IsNullOrWhiteSpace(product.ProductCode)
                                ? product.ProductCode.Trim()
                                : string.Format("02{0:D4}", product.ProductId)
                        }).ToList();

                    lines.AddRange(mainProducts);
                }
                catch (Exception ex)
                {
                    AppProcessor.Logger.Message("CreateImportExportReportLines GetViaEnterprise error: " + ex.Message);
                }
            }

            return lines;
        }

        private static void ApplyImportExportHierarchy(List<ReportDataImportModel> rows)
        {
            var index = 0;
            var countryNumber = 0;
            var productNumber = 0;
            var trustNumber = 0;
            var inTrustSection = false;

            foreach (var row in rows)
            {
                if (string.Equals(row.Code, "FOB", StringComparison.OrdinalIgnoreCase))
                {
                    row.Level = "0";
                }
                else if (string.Equals(row.Code, "XK_TT", StringComparison.OrdinalIgnoreCase))
                {
                    row.Level = "1";
                }
                else if (string.Equals(row.Code, "XK_QG_HEADER", StringComparison.OrdinalIgnoreCase))
                {
                    row.Level = "1.1";
                }
                else if (!string.IsNullOrWhiteSpace(row.Code) && row.Code.StartsWith("XK_QG_", StringComparison.OrdinalIgnoreCase))
                {
                    row.Level = "1.1." + (++countryNumber);
                }
                else if (string.Equals(row.Code, "XK_MH_HEADER", StringComparison.OrdinalIgnoreCase))
                {
                    row.Level = "1.2";
                }
                else if (!string.IsNullOrWhiteSpace(row.Code) && row.Code.StartsWith("XK_MH_", StringComparison.OrdinalIgnoreCase))
                {
                    row.Level = "1.2." + (++productNumber);
                }
                else if (string.Equals(row.Code, "UT_XK", StringComparison.OrdinalIgnoreCase))
                {
                    row.Level = "2";
                }
                else if (string.Equals(row.Code, "UT_MH_HEADER", StringComparison.OrdinalIgnoreCase))
                {
                    row.Level = "2.1";
                    inTrustSection = true;
                }
                else if (inTrustSection && !string.IsNullOrWhiteSpace(row.Code))
                {
                    row.Level = "2.1." + (++trustNumber);
                }

                row.Index = index++;
            }
        }

        private static void RecalculateImportExportSummary(List<ReportDataImportModel> rows)
        {
            var directExportRows = rows.Where(x => !string.IsNullOrWhiteSpace(x.Code) &&
                                              (x.Code.StartsWith("XK_QG_", StringComparison.OrdinalIgnoreCase) || x.Code.StartsWith("XK_MH_", StringComparison.OrdinalIgnoreCase) || (x.Level ?? "").StartsWith("1.1.") || (x.Level ?? "").StartsWith("1.2.")) &&
                                              !string.Equals(x.Code, "XK_QG_HEADER", StringComparison.OrdinalIgnoreCase) &&
                                              !string.Equals(x.Code, "XK_MH_HEADER", StringComparison.OrdinalIgnoreCase) &&
                                              !string.Equals(x.Level, "1.1", StringComparison.OrdinalIgnoreCase) &&
                                              !string.Equals(x.Level, "1.2", StringComparison.OrdinalIgnoreCase)).ToList();

            var utHeaderIdx = rows.FindIndex(x => string.Equals(x.Code, "UT_MH_HEADER", StringComparison.OrdinalIgnoreCase));
            var trustRows = utHeaderIdx >= 0
                ? rows.Skip(utHeaderIdx + 1).Where(x => !string.IsNullOrWhiteSpace(x.Code)).ToList()
                : new List<ReportDataImportModel>();

            var xkTtRow = rows.FirstOrDefault(x => string.Equals(x.Code, "XK_TT", StringComparison.OrdinalIgnoreCase));
            if (xkTtRow != null)
            {
                xkTtRow.PerformPreviousPeriod = directExportRows.Sum(x => x.PerformPreviousPeriod ?? 0);
                xkTtRow.ComparedSamePeriodLastYear = directExportRows.Sum(x => x.ComparedSamePeriodLastYear ?? 0);
                xkTtRow.PerformInPeriod = directExportRows.Sum(x => x.PerformInPeriod ?? 0);
                xkTtRow.AccumulatedBeginingOfYear = directExportRows.Sum(x => x.AccumulatedBeginingOfYear ?? 0);
            }

            var utXkRow = rows.FirstOrDefault(x => string.Equals(x.Code, "UT_XK", StringComparison.OrdinalIgnoreCase));
            if (utXkRow != null)
            {
                utXkRow.PerformPreviousPeriod = trustRows.Sum(x => x.PerformPreviousPeriod ?? 0);
                utXkRow.ComparedSamePeriodLastYear = trustRows.Sum(x => x.ComparedSamePeriodLastYear ?? 0);
                utXkRow.PerformInPeriod = trustRows.Sum(x => x.PerformInPeriod ?? 0);
                utXkRow.AccumulatedBeginingOfYear = trustRows.Sum(x => x.AccumulatedBeginingOfYear ?? 0);
            }

            var fobRow = rows.FirstOrDefault(x => string.Equals(x.Code, "FOB", StringComparison.OrdinalIgnoreCase));
            if (fobRow != null && xkTtRow != null && utXkRow != null)
            {
                fobRow.PerformPreviousPeriod = (xkTtRow.PerformPreviousPeriod ?? 0) + (utXkRow.PerformPreviousPeriod ?? 0);
                fobRow.ComparedSamePeriodLastYear = (xkTtRow.ComparedSamePeriodLastYear ?? 0) + (utXkRow.ComparedSamePeriodLastYear ?? 0);
                fobRow.PerformInPeriod = (xkTtRow.PerformInPeriod ?? 0) + (utXkRow.PerformInPeriod ?? 0);
                fobRow.AccumulatedBeginingOfYear = (xkTtRow.AccumulatedBeginingOfYear ?? 0) + (utXkRow.AccumulatedBeginingOfYear ?? 0);
            }
        }

        // Code được lưu theo nhánh Level để báo cáo tổng hợp xác định được quan hệ cha - con: [Level].[Mã sản phẩm]
        private static void ApplyBusinessProductHierarchyCodes(IEnumerable<DataRow> rows)
        {
            foreach (var row in rows)
            {
                var code = Convert.ToString(row["Code"]) ?? string.Empty;
                var level = Convert.ToString(row["Level"]) ?? string.Empty;
                if (string.IsNullOrWhiteSpace(level) || string.IsNullOrWhiteSpace(code)) continue;

                // Các chỉ tiêu cố định:
                // 01 -> 1 (Tổng doanh thu)
                // 0101 -> 1.1 (Trong đó doanh thu công nghiệp)
                // 06 -> 6 (Kim ngạch xuất khẩu)
                // 07 -> 7 (Kim ngạch nhập khẩu)
                if (string.Equals(code, "01", StringComparison.OrdinalIgnoreCase) || string.Equals(code, "1", StringComparison.OrdinalIgnoreCase) || string.Equals(level, "1", StringComparison.OrdinalIgnoreCase))
                {
                    row["Code"] = "1";
                    continue;
                }
                if (string.Equals(code, "0101", StringComparison.OrdinalIgnoreCase) || string.Equals(code, "1.1", StringComparison.OrdinalIgnoreCase) || string.Equals(level, "1.1", StringComparison.OrdinalIgnoreCase))
                {
                    row["Code"] = "1.1";
                    continue;
                }
                if (string.Equals(code, "06", StringComparison.OrdinalIgnoreCase) || string.Equals(code, "6", StringComparison.OrdinalIgnoreCase) || string.Equals(level, "6", StringComparison.OrdinalIgnoreCase))
                {
                    row["Code"] = "6";
                    continue;
                }
                if (string.Equals(code, "07", StringComparison.OrdinalIgnoreCase) || string.Equals(code, "7", StringComparison.OrdinalIgnoreCase) || string.Equals(level, "7", StringComparison.OrdinalIgnoreCase))
                {
                    row["Code"] = "7";
                    continue;
                }
                if (string.Equals(code, "2", StringComparison.OrdinalIgnoreCase) || string.Equals(level, "2", StringComparison.OrdinalIgnoreCase))
                {
                    row["Code"] = "2";
                    continue;
                }
                if (string.Equals(code, "6.0", StringComparison.OrdinalIgnoreCase) || string.Equals(level, "6.0", StringComparison.OrdinalIgnoreCase))
                {
                    row["Code"] = "6.0";
                    continue;
                }
                if (string.Equals(code, "7.0", StringComparison.OrdinalIgnoreCase) || string.Equals(level, "7.0", StringComparison.OrdinalIgnoreCase))
                {
                    row["Code"] = "7.0";
                    continue;
                }

                // Dòng sản phẩm phân cấp: 2.x (sản phẩm chủ yếu), 6.x (xuất khẩu), 7.x (nhập khẩu)
                // Lưu theo quy tắc: [Cấp cha].[Mã sản phẩm từ DB]
                // Ví dụ: Level 2.1 Điện gió -> Cấp cha là 2 + . + 3512200 = 2.3512200
                // Level 6.1 XKB0010 -> Cấp cha là 6 + . + XKB0010 = 6.XKB0010
                // Level 7.1 NKB0031 -> Cấp cha là 7 + . + NKB0031 = 7.NKB0031
                if (level.StartsWith("2.") || (level.StartsWith("6.") && level != "6.0") || (level.StartsWith("7.") && level != "7.0"))
                {
                    var rawCode = code;
                    var lastDot = rawCode.LastIndexOf('.');
                    if (lastDot >= 0 && lastDot < rawCode.Length - 1)
                    {
                        rawCode = rawCode.Substring(lastDot + 1);
                    }

                    var parentLevel = level.Contains(".") ? level.Substring(0, level.LastIndexOf('.')) : level;
                    row["Code"] = parentLevel + "." + rawCode;
                }
            }
        }

        // Code được lưu theo nhánh Level để báo cáo tổng hợp xác định được quan hệ cha - con.
        // Phần hậu tố giữ mã nghiệp vụ cũ cho các dòng phát sinh động (quốc gia, mặt hàng).
        private static void ApplyTradingHierarchyCodes(IEnumerable<DataRow> rows)
        {
            foreach (var row in rows)
            {
                var code = Convert.ToString(row["Code"]) ?? string.Empty;
                var level = Convert.ToString(row["Level"]) ?? string.Empty;
                if (string.IsNullOrWhiteSpace(level)) continue;
                if (code.StartsWith("TM_", StringComparison.OrdinalIgnoreCase) || code.Contains(".TM_"))
                {
                    var rawCode = code;
                    var tmIdx = rawCode.IndexOf("TM_", StringComparison.OrdinalIgnoreCase);
                    if (tmIdx >= 0) rawCode = rawCode.Substring(tmIdx);
                    var parentLevel = level.Contains(".") ? level.Substring(0, level.LastIndexOf('.')) : level;
                    row["Code"] = parentLevel + "." + rawCode;
                }
                else
                {
                    row["Code"] = level;
                }
            }
        }

        private static void ApplyImportExportHierarchyCodes(IEnumerable<DataRow> rows)
        {
            foreach (var row in rows)
            {
                var code = Convert.ToString(row["Code"]) ?? string.Empty;
                var level = Convert.ToString(row["Level"]) ?? string.Empty;
                if (string.IsNullOrWhiteSpace(level)) continue;
                var isFixedRow = string.Equals(code, "FOB", StringComparison.OrdinalIgnoreCase) ||
                                 string.Equals(code, "XK_TT", StringComparison.OrdinalIgnoreCase) ||
                                 string.Equals(code, "XK_QG_HEADER", StringComparison.OrdinalIgnoreCase) ||
                                 string.Equals(code, "XK_MH_HEADER", StringComparison.OrdinalIgnoreCase) ||
                                 string.Equals(code, "UT_XK", StringComparison.OrdinalIgnoreCase) ||
                                 string.Equals(code, "UT_MH_HEADER", StringComparison.OrdinalIgnoreCase);
                if (isFixedRow)
                {
                    row["Code"] = level;
                }
                else
                {
                    var rawCode = code;
                    var lastDot = rawCode.LastIndexOf('.');
                    if (lastDot >= 0 && lastDot < rawCode.Length - 1)
                    {
                        rawCode = rawCode.Substring(lastDot + 1);
                    }
                    var parentLevel = level.Contains(".") ? level.Substring(0, level.LastIndexOf('.')) : level;
                    row["Code"] = parentLevel + "." + rawCode;
                }
            }
        }

        private static List<ReportDataImportModel> RestoreTradingHierarchyCodes(List<ReportDataImportModel> rows)
        {
            if (rows == null) return null;
            foreach (var row in rows)
            {
                var code = row.Code ?? string.Empty;
                var level = row.Level ?? string.Empty;
                if (string.IsNullOrWhiteSpace(level) || string.IsNullOrWhiteSpace(code)) continue;
                var tmIdx = code.IndexOf("TM_", StringComparison.OrdinalIgnoreCase);
                if (tmIdx >= 0)
                {
                    row.Code = code.Substring(tmIdx);
                    continue;
                }
                if (string.Equals(code, level, StringComparison.OrdinalIgnoreCase))
                    row.Code = GetTradingLegacyCode(level);
            }
            return rows;
        }

        private static string GetTradingLegacyCode(string level)
        {
            var codes = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase)
            {
                { "1", "01" }, { "1.1", "02" }, { "1.2", "03" },
                { "1.13", "34" }, { "2", "40" }
            };
            string code;
            if (codes.TryGetValue(level, out code)) return code;

            // Nhóm hàng 1.3 đến 1.12: cha, bán lẻ, nền tảng trực tuyến.
            var parts = level.Split('.');
            int group;
            int child;
            if (parts.Length >= 2 && parts[0] == "1" && int.TryParse(parts[1], out group) && group >= 3 && group <= 12)
            {
                var baseCode = 4 + (group - 3) * 3;
                if (parts.Length == 2) return baseCode.ToString("D2");
                if (parts.Length == 3 && int.TryParse(parts[2], out child) && (child == 1 || child == 2))
                    return (baseCode + child).ToString("D2");
            }
            return level;
        }

        private static List<ReportDataImportModel> RestoreImportExportHierarchyCodes(List<ReportDataImportModel> rows)
        {
            if (rows == null) return null;
            foreach (var row in rows)
            {
                var code = row.Code ?? string.Empty;
                var level = row.Level ?? string.Empty;
                if (string.IsNullOrWhiteSpace(level) || string.IsNullOrWhiteSpace(code)) continue;
                if (string.Equals(code, level, StringComparison.OrdinalIgnoreCase))
                {
                    row.Code = GetImportExportLegacyCode(level);
                    continue;
                }
                var lastDot = code.LastIndexOf('.');
                if (lastDot >= 0 && lastDot < code.Length - 1)
                {
                    row.Code = code.Substring(lastDot + 1);
                }
            }
            return rows;
        }

        private static string GetImportExportLegacyCode(string level)
        {
            if (level == "0") return "FOB";
            if (level == "1") return "XK_TT";
            if (level == "1.1") return "XK_QG_HEADER";
            if (level == "1.2") return "XK_MH_HEADER";
            if (level == "2") return "UT_XK";
            if (level == "2.1") return "UT_MH_HEADER";
            return level;
        }

        private static List<ReportDataImportModel> RestoreBusinessProductHierarchyCodes(List<ReportDataImportModel> rows)
        {
            if (rows == null) return null;
            foreach (var row in rows)
            {
                var code = row.Code ?? string.Empty;
                var level = row.Level ?? string.Empty;
                if (string.IsNullOrWhiteSpace(code)) continue;

                if (string.Equals(code, "01", StringComparison.OrdinalIgnoreCase) || string.Equals(code, "1", StringComparison.OrdinalIgnoreCase))
                {
                    row.Code = "1";
                    continue;
                }
                if (string.Equals(code, "0101", StringComparison.OrdinalIgnoreCase) || string.Equals(code, "1.1", StringComparison.OrdinalIgnoreCase))
                {
                    row.Code = "1.1";
                    continue;
                }
                if (string.Equals(code, "06", StringComparison.OrdinalIgnoreCase) || string.Equals(code, "6", StringComparison.OrdinalIgnoreCase))
                {
                    row.Code = "6";
                    continue;
                }
                if (string.Equals(code, "07", StringComparison.OrdinalIgnoreCase) || string.Equals(code, "7", StringComparison.OrdinalIgnoreCase))
                {
                    row.Code = "7";
                    continue;
                }
                if (string.Equals(code, "2", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(code, "6.0", StringComparison.OrdinalIgnoreCase) ||
                    string.Equals(code, "7.0", StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }

                if ((code.StartsWith("2.", StringComparison.OrdinalIgnoreCase) && code.Length > 2) ||
                    (code.StartsWith("6.", StringComparison.OrdinalIgnoreCase) && code != "6.0") ||
                    (code.StartsWith("7.", StringComparison.OrdinalIgnoreCase) && code != "7.0"))
                {
                    var lastDot = code.LastIndexOf('.');
                    if (lastDot >= 0 && lastDot < code.Length - 1)
                    {
                        row.Code = code.Substring(lastDot + 1);
                    }
                }
            }
            return rows;
        }

        private static ReportDataImportModel CreateBusinessProductHeader(string targets, string code)
        {
            return new ReportDataImportModel { Targets = targets, Code = code };
        }

        private static ReportDataImportModel CreateBusinessProductLine(string targets, string unit, string code)
        {
            return new ReportDataImportModel { Targets = targets, Unit = unit, Code = code };
        }

        private static void ApplyBusinessProductHierarchy(List<ReportDataImportModel> products)
        {
            var storageIndex = 0;
            var section = string.Empty;
            var mainProductNumber = 0;
            var exportProductNumber = 0;
            var importProductNumber = 0;

            foreach (var product in products)
            {
                product.Index = null;
                product.Level = null;

                switch (product.Targets)
                {
                    case "Tổng doanh thu":
                        product.Level = "1";
                        break;
                    case "Trong đó doanh thu công nghiệp":
                        product.Level = "1.1";
                        break;
                    case "Sản phẩm công nghiệp chủ yếu":
                        section = "MainProduct";
                        product.Level = "2";
                        break;
                    case "Lao động - Thu nhập":
                        section = "Labor";
                        product.Level = "3";
                        continue;
                    case "Tổng số lao động":
                        product.Level = "3.1";
                        break;
                    case "Thu nhập bình quân/người/tháng":
                        product.Level = "3.2";
                        break;
                    case "Nộp ngân sách":
                        section = string.Empty;
                        product.Level = "5";
                        break;
                    case "Kim ngạch xuất khẩu":
                        section = "Export";
                        product.Level = "6";
                        break;
                    case "Nhóm/mặt hàng xuất khẩu chủ yếu":
                        section = "Export";
                        product.Level = "6.0";
                        break;
                    case "Kim ngạch nhập khẩu":
                        section = "Import";
                        product.Level = "7";
                        break;
                    case "Nhóm/mặt hàng nhập khẩu chủ yếu":
                        section = "Import";
                        product.Level = "7.0";
                        break;
                }

                if (string.IsNullOrWhiteSpace(product.Code))
                    continue;

                if (section == "MainProduct" && string.IsNullOrWhiteSpace(product.Level))
                    product.Level = "2." + (++mainProductNumber);
                else if (section == "Export" && product.Code.StartsWith("XK", StringComparison.OrdinalIgnoreCase))
                    product.Level = "6." + (++exportProductNumber);
                else if (section == "Import" && product.Code.StartsWith("NK", StringComparison.OrdinalIgnoreCase))
                    product.Level = "7." + (++importProductNumber);

                product.Index = storageIndex++;
            }
        }

        private static List<ReportDataImportModel> MergeBusinessProductData(
            List<ReportDataImportModel> catalog, List<ReportDataImportModel> savedData)
        {
            savedData = RestoreBusinessProductHierarchyCodes(savedData) ?? new List<ReportDataImportModel>();
            foreach (var item in catalog.Where(x => !string.IsNullOrWhiteSpace(x.Code)))
            {
                // Kim ngạch XK và NK không nạp trực tiếp, chỉ tính từ tổng các mặt hàng bên trong
                if (item.Code == "6" || item.Code == "06" || item.Code == "7" || item.Code == "07" || item.Targets == "Kim ngạch xuất khẩu" || item.Targets == "Kim ngạch nhập khẩu")
                    continue;

                // Mã sản phẩm có thể trùng giữa ba nhóm danh mục, nên ưu tiên tên và đơn vị.
                var saved = savedData.FirstOrDefault(x =>
                                string.Equals(x.Targets, item.Targets, StringComparison.OrdinalIgnoreCase) &&
                                string.Equals(x.Unit, item.Unit, StringComparison.OrdinalIgnoreCase))
                            ?? savedData.FirstOrDefault(x =>
                                !string.IsNullOrWhiteSpace(x.Code) &&
                                (string.Equals(x.Code.Trim(), item.Code.Trim(), StringComparison.OrdinalIgnoreCase) ||
                                 (item.Code == "1" && x.Code == "01") || (item.Code == "01" && x.Code == "1") ||
                                 (item.Code == "1.1" && x.Code == "0101") || (item.Code == "0101" && x.Code == "1.1") ||
                                 (item.Code == "6" && x.Code == "06") || (item.Code == "06" && x.Code == "6") ||
                                 (item.Code == "7" && x.Code == "07") || (item.Code == "07" && x.Code == "7")));

                if (saved == null)
                    continue;

                item.PerformPreviousPeriod = saved.PerformPreviousPeriod;
                item.PerformInPeriod = saved.PerformInPeriod;
                item.AccumulatedBeginingOfYear = saved.AccumulatedBeginingOfYear ?? item.AccumulatedBeginingOfYear;
                item.ComparedSamePeriodLastYear = saved.ComparedSamePeriodLastYear;
            }

            InsertTradeIndicators(catalog, savedData, "Nhóm/mặt hàng xuất khẩu chủ yếu", "XK");
            InsertTradeIndicators(catalog, savedData, "Nhóm/mặt hàng nhập khẩu chủ yếu", "NK");
            ApplyBusinessProductHierarchy(catalog);
            RecalculateTradeSummaryInModel(catalog);

            return catalog;
        }

        private static void RecalculateTradeSummaryInModel(List<ReportDataImportModel> products)
        {
            if (products == null) return;
            var exportSummary = products.FirstOrDefault(p => string.Equals(p.Code, "6", StringComparison.OrdinalIgnoreCase) || string.Equals(p.Code, "06", StringComparison.OrdinalIgnoreCase) || string.Equals(p.Targets, "Kim ngạch xuất khẩu", StringComparison.OrdinalIgnoreCase));
            if (exportSummary != null)
            {
                var xkItems = products.Where(p => !string.IsNullOrWhiteSpace(p.Code) && p.Code.StartsWith("XK", StringComparison.OrdinalIgnoreCase)).ToList();
                exportSummary.AccumulatedBeginingOfYear = xkItems.Any() ? xkItems.Sum(x => x.AccumulatedBeginingOfYear ?? 0) : (double?)0;
                exportSummary.PerformPreviousPeriod = xkItems.Any() ? xkItems.Sum(x => x.PerformPreviousPeriod ?? 0) : (double?)0;
                exportSummary.PerformInPeriod = xkItems.Any() ? xkItems.Sum(x => x.PerformInPeriod ?? 0) : (double?)0;
            }

            var importSummary = products.FirstOrDefault(p => string.Equals(p.Code, "7", StringComparison.OrdinalIgnoreCase) || string.Equals(p.Code, "07", StringComparison.OrdinalIgnoreCase) || string.Equals(p.Targets, "Kim ngạch nhập khẩu", StringComparison.OrdinalIgnoreCase));
            if (importSummary != null)
            {
                var nkItems = products.Where(p => !string.IsNullOrWhiteSpace(p.Code) && p.Code.StartsWith("NK", StringComparison.OrdinalIgnoreCase)).ToList();
                importSummary.AccumulatedBeginingOfYear = nkItems.Any() ? nkItems.Sum(x => x.AccumulatedBeginingOfYear ?? 0) : (double?)0;
                importSummary.PerformPreviousPeriod = nkItems.Any() ? nkItems.Sum(x => x.PerformPreviousPeriod ?? 0) : (double?)0;
                importSummary.PerformInPeriod = nkItems.Any() ? nkItems.Sum(x => x.PerformInPeriod ?? 0) : (double?)0;
            }
        }

        private static void InsertTradeIndicators(List<ReportDataImportModel> catalog,
            List<ReportDataImportModel> savedData, string header, string codePrefix)
        {
            var configuredCodes = new HashSet<string>(catalog
                .Where(x => !string.IsNullOrWhiteSpace(x.Code) &&
                            x.Code.StartsWith(codePrefix, StringComparison.OrdinalIgnoreCase))
                .Select(x => x.Code.Trim()), StringComparer.OrdinalIgnoreCase);
            var rows = savedData.Where(x => !string.IsNullOrWhiteSpace(x.Code) &&
                                            x.Code.StartsWith(codePrefix, StringComparison.OrdinalIgnoreCase) &&
                                            !configuredCodes.Contains(x.Code.Trim())).ToList();
            if (!rows.Any()) return;
            var headerIndex = catalog.FindIndex(x => x.Targets == header && string.IsNullOrWhiteSpace(x.Code));
            if (headerIndex >= 0) catalog.InsertRange(headerIndex + 1, rows);
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult AddNational()
        {
            var lstNational = _nationalCache.GetAll();
            return PartialView("_AddNational", lstNational);
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult UploadSignedFile()
        {
            return PartialView("_UploadSignedFile", new ReportDataImportModel());
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult UploadBaseFile()
        {
            var serialKeyVNPTToken = ConfigurationManager.AppSettings["VNPT_Token_Serial"];
            return PartialView("_UploadBaseFile", new ReportDataImportModel { VNPTTokenSerialKey = serialKeyVNPTToken });
        }

        #endregion

        #region Extend Function

        private DataTable ReadDataImports(HttpPostedFileBase fileImport, out bool isSucess)
        {
            isSucess = true;

            #region Init Datatable

            var dataImport = new DataTable();
            dataImport.Columns.Add("RowIndex", typeof(long));
            dataImport.Columns.Add("Targets");
            dataImport.Columns.Add("Unit");
            dataImport.Columns.Add("Code");
            dataImport.Columns.Add("PerformPreviousPeriod", typeof(double));
            dataImport.Columns.Add("PerformInPeriod", typeof(double));
            dataImport.Columns.Add("AccumulatedBeginingOfYear", typeof(double));
            dataImport.Columns.Add("ComparedSamePeriodLastYear", typeof(double));

            #endregion

            try
            {
                var fileExtension = Path.GetExtension(fileImport.FileName);

                if (fileExtension != ".xls" && fileExtension != ".xlsx") return null;
                var excelReader = fileExtension == ".xls"
                    ? ExcelReaderFactory.CreateBinaryReader(fileImport.InputStream)
                    : ExcelReaderFactory.CreateOpenXmlReader(fileImport.InputStream);

                var ds = excelReader.AsDataSet();

                var dt = ds.Tables[0];
                dt.Rows.RemoveAt(0); // Title Column
                dt.Rows.RemoveAt(0); // Code Column
                int rowIdx = 0;

                foreach (DataRow row in dt.Rows)
                {
                    var dataCells = (row.ItemArray.Length > 5
                        ? row.ItemArray.ToList().Where((item, idx) => idx < 5).Select((c, idx) =>
                            idx >= 3 ? string.IsNullOrEmpty(c.ToString()) ? null : c : c).ToArray()
                        : row.ItemArray.Select((c, idx) => idx >= 3 ? string.IsNullOrEmpty(c.ToString()) ? null : c : c)
                            .ToArray()).ToList();
                    //dataCells.Insert(3, null);
                    dataCells.Insert(0, rowIdx);
                    dataCells.Insert(6, null);
                    dataImport.Rows.Add(dataCells.ToArray());
                    rowIdx += 1;
                }

                return dataImport;
            }
            catch (Exception e)
            {
                AppProcessor.Logger.Error(e);
                isSucess = false;
                return dataImport;
            }
        }

        private DataTable ReadDataImports(Stream fileStream, string fileExtension, out bool isSucess)
        {
            isSucess = true;

            #region Init Datatable

            var dataImport = new DataTable();
            dataImport.Columns.Add("RowIndex", typeof(long));
            dataImport.Columns.Add("Targets");
            dataImport.Columns.Add("Unit");
            dataImport.Columns.Add("Code");
            dataImport.Columns.Add("PerformPreviousPeriod", typeof(double));
            dataImport.Columns.Add("PerformInPeriod", typeof(double));
            dataImport.Columns.Add("AccumulatedBeginingOfYear", typeof(double));
            dataImport.Columns.Add("ComparedSamePeriodLastYear", typeof(double));

            #endregion

            try
            {
                if (fileExtension != "xls" && fileExtension != "xlsx")
                {
                    isSucess = false;
                    return null;
                }
                var excelReader = fileExtension == "xls"
                    ? ExcelReaderFactory.CreateBinaryReader(fileStream)
                    : ExcelReaderFactory.CreateOpenXmlReader(fileStream);

                var ds = excelReader.AsDataSet();

                var dt = ds.Tables[0];
                dt.Rows.RemoveAt(0); // Title Column
                dt.Rows.RemoveAt(0); // Code Column
                int rowIdx = 0;

                foreach (DataRow row in dt.Rows)
                {
                    var dataCells = (row.ItemArray.Length > 5
                        ? row.ItemArray.ToList().Where((item, idx) => idx < 5).Select((c, idx) =>
                            idx >= 3 ? string.IsNullOrEmpty(c.ToString()) ? null : c : c).ToArray()
                        : row.ItemArray.Select((c, idx) => idx >= 3 ? string.IsNullOrEmpty(c.ToString()) ? null : c : c)
                            .ToArray()).ToList();
                    //dataCells.Insert(3, null);
                    dataCells.Insert(0, rowIdx);
                    dataCells.Insert(6, null);
                    dataImport.Rows.Add(dataCells.ToArray());
                    rowIdx += 1;
                }

                return dataImport;
            }
            catch (Exception e)
            {
                AppProcessor.Logger.Error(e);
                isSucess = false;
                return dataImport;
            }
        }

        private List<ReportDataImportModel> CheckDataImport(DataTable dataImportModels, DateTime? onMonth,
            int? enterpriseId)
        {
            var dataImportChecked = _importCache.CheckDataImport(new ReportDataImportModel
            {
                EnterpriseId = enterpriseId,
                ForMonth = onMonth,
                DataImport = dataImportModels
            });

            return dataImportChecked;
        }

        private DataTable ReadFormData(NameValueCollection formData, int enterpriseId = 0)
        {
            #region Init Datatable

            var dartaFormReport = new DataTable();
            dartaFormReport.Columns.Add("Targets");
            dartaFormReport.Columns.Add("Unit");
            dartaFormReport.Columns.Add("Code");
            dartaFormReport.Columns.Add("Index", typeof(int));
            dartaFormReport.Columns.Add("Level");
            dartaFormReport.Columns.Add("PerformPreviousPeriod", typeof(double));
            dartaFormReport.Columns.Add("PerformInPeriod", typeof(double));
            dartaFormReport.Columns.Add("AccumulatedBeginingOfYear", typeof(double));
            dartaFormReport.Columns.Add("ComparedSamePeriodLastYear", typeof(double));

            #endregion

            var targetKeys = formData.AllKeys
                .Where(k => k != null && k.StartsWith("Target_"))
                .Select(k =>
                {
                    int id;
                    return int.TryParse(k.Substring("Target_".Length), out id) ? id : -1;
                })
                .Where(id => id > 0)
                .OrderBy(id => id)
                .ToList();

            var isBusinessProductReport = string.Equals(formData["BusinessProductReport"], "true",
                StringComparison.OrdinalIgnoreCase);
            var isTradingReport = string.Equals(formData["TradingReport"], "true", StringComparison.OrdinalIgnoreCase);
            var isImportExportReport = string.Equals(formData["ImportExportReport"], "true", StringComparison.OrdinalIgnoreCase);
            var dataIndex = 0;
            foreach (var idx in targetKeys)
            {
                var code = formData[$"Code_{idx}"];
                var target = formData[$"Target_{idx}"];
                // Mẫu sản xuất, kinh doanh phải lưu cả các dòng chỉ mục/tiêu đề nhóm (Code rỗng)
                // để khi xem lại hoặc chỉnh sửa giữ nguyên cấu trúc báo cáo.
                if ((isTradingReport || isImportExportReport) && string.IsNullOrWhiteSpace(code)) continue;
                if (isImportExportReport && string.IsNullOrWhiteSpace(target)) continue;

                dartaFormReport.Rows.Add(
                    target,
                    formData[$"Unit_{idx}"],
                    code,
                    dataIndex++,
                    formData[$"Level_{idx}"],
                    ParseFormattedNumber(formData[$"PerformPreviousPeriod_{idx}"]),
                    ParseFormattedNumber(formData[$"PerformInPeriod_{idx}"]),
                    ParseFormattedNumber(formData[$"AccumulatedBeginingOfYear_{idx}"]),
                    ParseFormattedNumber(formData[$"CompareSamePeriodLastYear_{idx}"]));
            }

            // Dòng mặt hàng được thêm động có thể nằm giữa bảng nhưng có tên field ở cuối form.
            // Sắp lại Index theo Level để thứ tự lưu luôn khớp với số thứ tự hiển thị (1, 1.1, 2.1...).
            if (isBusinessProductReport)
            {
                RecalculateTradeSummaryInDataTable(dartaFormReport);

                var orderedRows = dartaFormReport.AsEnumerable()
                    .OrderBy(row => GetBusinessProductSortKey(Convert.ToString(row["Level"])))
                    .ToList();
                for (var rowIndex = 0; rowIndex < orderedRows.Count; rowIndex++)
                    orderedRows[rowIndex]["Index"] = rowIndex;

                ApplyBusinessProductHierarchyCodes(orderedRows);

                var sortedTable = dartaFormReport.Clone();
                foreach (var r in orderedRows)
                {
                    sortedTable.ImportRow(r);
                }
                return sortedTable;
            }
            else if (isTradingReport)
            {
                var rowsToRemove = dartaFormReport.AsEnumerable()
                    .Where(r => {
                        var c = Convert.ToString(r["Code"]);
                        return c == "38" || c == "39";
                    }).ToList();
                foreach (var r in rowsToRemove) dartaFormReport.Rows.Remove(r);

                EnsureTradingDynamicCodes(dartaFormReport, enterpriseId);
                RecalculateTradingSummaryInDataTable(dartaFormReport);
                var rows = dartaFormReport.AsEnumerable().ToList();
                var child = 0;
                foreach (var row in rows)
                {
                    var code = Convert.ToString(row["Code"]) ?? "";
                    if (code == "01") row["Level"] = "1";
                    else if (code == "02") row["Level"] = "1.1";
                    else if (code == "03") row["Level"] = "1.2";
                    else if (new[] { "04", "07", "10", "13", "16", "19", "22", "25", "28", "31", "34" }.Contains(code)) row["Level"] = "1." + ((Convert.ToInt32(code) - 1) / 3 + 2);
                    else if (new[] { "05", "08", "11", "14", "17", "20", "23", "26", "29", "32" }.Contains(code)) row["Level"] = "1." + ((Convert.ToInt32(code) - 2) / 3 + 2) + ".1";
                    else if (new[] { "06", "09", "12", "15", "18", "21", "24", "27", "30", "33" }.Contains(code)) row["Level"] = "1." + ((Convert.ToInt32(code) - 3) / 3 + 2) + ".2";
                    else if (code == "40") row["Level"] = "2";
                    else if (code.StartsWith("TM_", StringComparison.OrdinalIgnoreCase) || code.Contains(".TM_"))
                    {
                        if (code.EndsWith("_BL", StringComparison.OrdinalIgnoreCase))
                            row["Level"] = "1.13." + child + ".1";
                        else if (code.EndsWith("_TT", StringComparison.OrdinalIgnoreCase))
                            row["Level"] = "1.13." + child + ".2";
                        else
                        {
                            child++;
                            row["Level"] = "1.13." + child;
                        }
                    }
                }

                var orderedRows = dartaFormReport.AsEnumerable()
                    .OrderBy(row => GetBusinessProductSortKey(Convert.ToString(row["Level"])))
                    .ToList();
                for (var rowIndex = 0; rowIndex < orderedRows.Count; rowIndex++)
                    orderedRows[rowIndex]["Index"] = rowIndex;
                ApplyTradingHierarchyCodes(orderedRows);

                var sortedTable = dartaFormReport.Clone();
                foreach (var r in orderedRows)
                {
                    sortedTable.ImportRow(r);
                }
                return sortedTable;
            }
            else if (isImportExportReport)
            {
                RecalculateImportExportSummaryInDataTable(dartaFormReport);
                var orderedRows = dartaFormReport.AsEnumerable()
                    .OrderBy(row => GetBusinessProductSortKey(Convert.ToString(row["Level"])))
                    .ToList();

                var countryNumber = 0;
                var productNumber = 0;
                var trustNumber = 0;
                var inTrustSection = false;

                for (var rowIndex = 0; rowIndex < orderedRows.Count; rowIndex++)
                {
                    var row = orderedRows[rowIndex];
                    var code = Convert.ToString(row["Code"]);
                    if (string.Equals(code, "FOB", StringComparison.OrdinalIgnoreCase))
                    {
                        row["Level"] = "0";
                    }
                    else if (string.Equals(code, "XK_TT", StringComparison.OrdinalIgnoreCase))
                    {
                        row["Level"] = "1";
                    }
                    else if (string.Equals(code, "XK_QG_HEADER", StringComparison.OrdinalIgnoreCase))
                    {
                        row["Level"] = "1.1";
                    }
                    else if (!string.IsNullOrWhiteSpace(code) && (code.StartsWith("XK_QG_", StringComparison.OrdinalIgnoreCase) || (Convert.ToString(row["Level"]) ?? "").StartsWith("1.1.")))
                    {
                        row["Level"] = "1.1." + (++countryNumber);
                    }
                    else if (string.Equals(code, "XK_MH_HEADER", StringComparison.OrdinalIgnoreCase))
                    {
                        row["Level"] = "1.2";
                    }
                    else if (!string.IsNullOrWhiteSpace(code) && !inTrustSection && (code.StartsWith("XK_MH_", StringComparison.OrdinalIgnoreCase) || (Convert.ToString(row["Level"]) ?? "").StartsWith("1.2.")))
                    {
                        row["Level"] = "1.2." + (++productNumber);
                    }
                    else if (string.Equals(code, "UT_XK", StringComparison.OrdinalIgnoreCase))
                    {
                        row["Level"] = "2";
                    }
                    else if (string.Equals(code, "UT_MH_HEADER", StringComparison.OrdinalIgnoreCase))
                    {
                        row["Level"] = "2.1";
                        inTrustSection = true;
                    }
                    else if (inTrustSection && !string.IsNullOrWhiteSpace(code))
                    {
                        row["Level"] = "2.1." + (++trustNumber);
                    }

                    row["Index"] = rowIndex;
                }

                var sortedTable = dartaFormReport.Clone();
                foreach (var r in orderedRows)
                {
                    sortedTable.ImportRow(r);
                }
                ApplyImportExportHierarchyCodes(sortedTable.AsEnumerable());
                return sortedTable;
            }

            return dartaFormReport;
        }

        private static double? ParseFormattedNumber(string raw)
        {
            if (string.IsNullOrWhiteSpace(raw)) return null;
            raw = raw.Trim();
            if (raw.Contains(",") && raw.Contains("."))
            {
                raw = raw.Replace(".", "").Replace(",", ".");
            }
            else if (raw.Contains(","))
            {
                raw = raw.Replace(",", ".");
            }
            else if (raw.Contains("."))
            {
                var dotCount = raw.Count(c => c == '.');
                if (dotCount > 1)
                {
                    raw = raw.Replace(".", "");
                }
                else
                {
                    var parts = raw.Split('.');
                    if (parts.Length > 1 && parts[1].Length == 3)
                    {
                        raw = raw.Replace(".", "");
                    }
                }
            }

            double result;
            if (double.TryParse(raw, System.Globalization.NumberStyles.Any, System.Globalization.CultureInfo.InvariantCulture, out result))
            {
                return result;
            }
            return null;
        }

        private static string GetBusinessProductSortKey(string level)
        {
            if (string.IsNullOrWhiteSpace(level)) return "99999";
            return string.Join(".", level.Split('.')
                .Select(part =>
                {
                    int number;
                    return int.TryParse(part, out number) ? number.ToString("D5") : "99999";
                }));
        }

        private static string GetTradeCatalogCodePrefix(string prefix)
        {
            if (string.Equals(prefix, "XK", StringComparison.OrdinalIgnoreCase)) return "XKB";
            if (string.Equals(prefix, "NK", StringComparison.OrdinalIgnoreCase)) return "NKB";
            return null;
        }

        private bool CanUnlockReport()
        {
            return AppProcessor.Author.IsAllow(User.UserName, "Report", "Import",
                EnumHelper.GetDescription(EnumActionType.Unlock));
        }

        private bool IsReportLocked(DateTime? forMonth)
        {
            if (!forMonth.HasValue) return false;

            // Admin mở khóa bằng cấu hình Enable_Report_Lock = 0.
            // Không có cấu hình thì vẫn giữ hành vi an toàn: báo cáo bị khóa theo hạn.
            var lockEnabled = _configCache.GetViaKey("Enable_Report_Lock");
            if (lockEnabled != null && string.Equals(lockEnabled.ConfigValue, "0", StringComparison.OrdinalIgnoreCase))
                return false;

            int lockDay;
            if (!int.TryParse(_configCache.GetViaKey("Day_Deadline_Send_Report")?.ConfigValue,
                    out lockDay) || lockDay <= 0)
                return false;

            var lastDayOfMonth = DateTime.DaysInMonth(forMonth.Value.Year, forMonth.Value.Month);
            var lockDate = new DateTime(forMonth.Value.Year, forMonth.Value.Month,
                Math.Min(lockDay, lastDayOfMonth));
            return DateTime.Today > lockDate;
        }

        private static string GetReportLockedMessage(DateTime? forMonth)
        {
            return $"Báo cáo tháng {forMonth?.ToString("MM/yyyy")} đã bị khóa, không thể sửa hoặc xóa thông tin.";
        }

        private static void RecalculateTradeSummaryInDataTable(DataTable table)
        {
            if (table == null) return;
            var rows = table.AsEnumerable().ToList();
            var exportRow = rows.FirstOrDefault(r => string.Equals(Convert.ToString(r["Code"]), "6", StringComparison.OrdinalIgnoreCase) || string.Equals(Convert.ToString(r["Code"]), "06", StringComparison.OrdinalIgnoreCase) || string.Equals(Convert.ToString(r["Targets"]), "Kim ngạch xuất khẩu", StringComparison.OrdinalIgnoreCase));
            if (exportRow != null)
            {
                var xkRows = rows.Where(r => (Convert.ToString(r["Code"]) ?? "").StartsWith("XK", StringComparison.OrdinalIgnoreCase)).ToList();
                exportRow["AccumulatedBeginingOfYear"] = xkRows.Any() ? xkRows.Sum(r => r["AccumulatedBeginingOfYear"] != DBNull.Value ? Convert.ToDouble(r["AccumulatedBeginingOfYear"]) : 0.0) : 0.0;
                exportRow["PerformPreviousPeriod"] = xkRows.Any() ? xkRows.Sum(r => r["PerformPreviousPeriod"] != DBNull.Value ? Convert.ToDouble(r["PerformPreviousPeriod"]) : 0.0) : 0.0;
                exportRow["PerformInPeriod"] = xkRows.Any() ? xkRows.Sum(r => r["PerformInPeriod"] != DBNull.Value ? Convert.ToDouble(r["PerformInPeriod"]) : 0.0) : 0.0;
            }

            var importRow = rows.FirstOrDefault(r => string.Equals(Convert.ToString(r["Code"]), "7", StringComparison.OrdinalIgnoreCase) || string.Equals(Convert.ToString(r["Code"]), "07", StringComparison.OrdinalIgnoreCase) || string.Equals(Convert.ToString(r["Targets"]), "Kim ngạch nhập khẩu", StringComparison.OrdinalIgnoreCase));
            if (importRow != null)
            {
                var nkRows = rows.Where(r => (Convert.ToString(r["Code"]) ?? "").StartsWith("NK", StringComparison.OrdinalIgnoreCase)).ToList();
                importRow["AccumulatedBeginingOfYear"] = nkRows.Any() ? nkRows.Sum(r => r["AccumulatedBeginingOfYear"] != DBNull.Value ? Convert.ToDouble(r["AccumulatedBeginingOfYear"]) : 0.0) : 0.0;
                importRow["PerformPreviousPeriod"] = nkRows.Any() ? nkRows.Sum(r => r["PerformPreviousPeriod"] != DBNull.Value ? Convert.ToDouble(r["PerformPreviousPeriod"]) : 0.0) : 0.0;
                importRow["PerformInPeriod"] = nkRows.Any() ? nkRows.Sum(r => r["PerformInPeriod"] != DBNull.Value ? Convert.ToDouble(r["PerformInPeriod"]) : 0.0) : 0.0;
            }
        }

        private static void RecalculateTradingSummaryInDataTable(DataTable table)
        {
            if (table == null) return;
            var rows = table.AsEnumerable().ToList();
            Func<DataRow, string, double> value = (row, field) => (row == null || row[field] == DBNull.Value) ? 0 : Convert.ToDouble(row[field]);
            var fields = new[] { "PerformInPeriod", "PerformPreviousPeriod", "AccumulatedBeginingOfYear" };

            // Dynamic products: parent = BL + TT
            var dynamicParents = rows.Where(r => {
                var c = Convert.ToString(r["Code"]) ?? "";
                return (c.StartsWith("TM_", StringComparison.OrdinalIgnoreCase) || c.Contains(".TM_")) && !c.EndsWith("_BL", StringComparison.OrdinalIgnoreCase) && !c.EndsWith("_TT", StringComparison.OrdinalIgnoreCase);
            }).ToList();

            foreach (var parent in dynamicParents)
            {
                var c = Convert.ToString(parent["Code"]);
                var bl = rows.FirstOrDefault(r => string.Equals(Convert.ToString(r["Code"]), c + "_BL", StringComparison.OrdinalIgnoreCase));
                var tt = rows.FirstOrDefault(r => string.Equals(Convert.ToString(r["Code"]), c + "_TT", StringComparison.OrdinalIgnoreCase));
                foreach (var f in fields)
                {
                    parent[f] = value(bl, f) + value(tt, f);
                }
            }

            var blRows = rows.Where(x => (Convert.ToString(x["Code"]) ?? "").EndsWith("_BL", StringComparison.OrdinalIgnoreCase)).ToList();
            var ttRows = rows.Where(x => (Convert.ToString(x["Code"]) ?? "").EndsWith("_TT", StringComparison.OrdinalIgnoreCase)).ToList();

            // Row 34 = sum of dynamic BL + TT
            var row34 = rows.FirstOrDefault(x => Convert.ToString(x["Code"]) == "34");
            if (row34 != null)
            {
                foreach (var f in fields) row34[f] = blRows.Sum(x => value(x, f)) + ttRows.Sum(x => value(x, f));
            }

            // Groups 1 to 10
            Action<DataRow, DataRow, DataRow> setSum = (parent, retail, online) => {
                if (parent == null || retail == null || online == null) return;
                foreach (var f in fields) parent[f] = value(retail, f) + value(online, f);
            };
            foreach (var codes in new[] {
                new[] { "04", "05", "06" }, new[] { "07", "08", "09" }, new[] { "10", "11", "12" },
                new[] { "13", "14", "15" }, new[] { "16", "17", "18" }, new[] { "19", "20", "21" },
                new[] { "22", "23", "24" }, new[] { "25", "26", "27" }, new[] { "28", "29", "30" },
                new[] { "31", "32", "33" }
            })
            {
                setSum(rows.FirstOrDefault(x => Convert.ToString(x["Code"]) == codes[0]),
                       rows.FirstOrDefault(x => Convert.ToString(x["Code"]) == codes[1]),
                       rows.FirstOrDefault(x => Convert.ToString(x["Code"]) == codes[2]));
            }

            var retailCodes = new[] { "05", "08", "11", "14", "17", "20", "23", "26", "29", "32" };
            var onlineCodes = new[] { "06", "09", "12", "15", "18", "21", "24", "27", "30", "33" };
            var retailTotal = rows.FirstOrDefault(x => Convert.ToString(x["Code"]) == "02");
            var onlineTotal = rows.FirstOrDefault(x => Convert.ToString(x["Code"]) == "03");
            foreach (var f in fields)
            {
                if (retailTotal != null) retailTotal[f] = rows.Where(x => retailCodes.Contains(Convert.ToString(x["Code"]))).Sum(x => value(x, f)) + blRows.Sum(x => value(x, f));
                if (onlineTotal != null) onlineTotal[f] = rows.Where(x => onlineCodes.Contains(Convert.ToString(x["Code"]))).Sum(x => value(x, f)) + ttRows.Sum(x => value(x, f));
            }

            var total = rows.FirstOrDefault(x => Convert.ToString(x["Code"]) == "01");
            var mainGroupCodes = new[] { "04", "07", "10", "13", "16", "19", "22", "25", "28", "31", "34" };
            var mainGroupRows = rows.Where(x => mainGroupCodes.Contains(Convert.ToString(x["Code"]))).ToList();
            if (total != null)
            {
                foreach (var f in fields)
                {
                    total[f] = mainGroupRows.Sum(x => value(x, f));
                }
            }
        }

        private static void RecalculateImportExportSummaryInDataTable(DataTable table)
        {
            if (table == null) return;
            var rows = table.AsEnumerable().ToList();
            Func<DataRow, string, double> value = (row, field) => row[field] == DBNull.Value ? 0 : Convert.ToDouble(row[field]);

            var directExportRows = rows.Where(x => {
                var code = Convert.ToString(x["Code"]);
                var level = Convert.ToString(x["Level"]);
                return !string.IsNullOrWhiteSpace(code) &&
                       (code.StartsWith("XK_QG_", StringComparison.OrdinalIgnoreCase) || code.StartsWith("XK_MH_", StringComparison.OrdinalIgnoreCase) || (level ?? "").StartsWith("1.1.") || (level ?? "").StartsWith("1.2.")) &&
                       !string.Equals(code, "XK_QG_HEADER", StringComparison.OrdinalIgnoreCase) &&
                       !string.Equals(code, "XK_MH_HEADER", StringComparison.OrdinalIgnoreCase) &&
                       !string.Equals(level, "1.1", StringComparison.OrdinalIgnoreCase) &&
                       !string.Equals(level, "1.2", StringComparison.OrdinalIgnoreCase);
            }).ToList();

            var utHeaderIdx = rows.FindIndex(x => string.Equals(Convert.ToString(x["Code"]), "UT_MH_HEADER", StringComparison.OrdinalIgnoreCase));
            var trustRows = utHeaderIdx >= 0
                ? rows.Skip(utHeaderIdx + 1).Where(x => !string.IsNullOrWhiteSpace(Convert.ToString(x["Code"]))).ToList()
                : new List<DataRow>();

            var xkTtRow = rows.FirstOrDefault(x => string.Equals(Convert.ToString(x["Code"]), "XK_TT", StringComparison.OrdinalIgnoreCase));
            if (xkTtRow != null)
            {
                foreach (var field in new[] { "PerformPreviousPeriod", "ComparedSamePeriodLastYear", "PerformInPeriod", "AccumulatedBeginingOfYear" })
                {
                    xkTtRow[field] = directExportRows.Sum(x => value(x, field));
                }
            }

            var utXkRow = rows.FirstOrDefault(x => string.Equals(Convert.ToString(x["Code"]), "UT_XK", StringComparison.OrdinalIgnoreCase));
            if (utXkRow != null)
            {
                foreach (var field in new[] { "PerformPreviousPeriod", "ComparedSamePeriodLastYear", "PerformInPeriod", "AccumulatedBeginingOfYear" })
                {
                    utXkRow[field] = trustRows.Sum(x => value(x, field));
                }
            }

            var fobRow = rows.FirstOrDefault(x => string.Equals(Convert.ToString(x["Code"]), "FOB", StringComparison.OrdinalIgnoreCase));
            if (fobRow != null && xkTtRow != null && utXkRow != null)
            {
                foreach (var field in new[] { "PerformPreviousPeriod", "ComparedSamePeriodLastYear", "PerformInPeriod", "AccumulatedBeginingOfYear" })
                {
                    fobRow[field] = value(xkTtRow, field) + value(utXkRow, field);
                }
            }
        }

        private static string GetTypeBusinessDisplayName(EnumTypeBusiness type)
        {
            string msgKey = EnumHelper.GetDescription(type);
            string msg = AppProcessor.Messagor.GetMessage(msgKey);
            if (string.IsNullOrWhiteSpace(msg) || msg == msgKey)
            {
                switch (type)
                {
                    case EnumTypeBusiness.Manufacturing:
                        return "Doanh nghiệp sản xuất, kinh doanh";
                    case EnumTypeBusiness.Trading:
                        return "Doanh nghiệp thương mại, dịch vụ";
                    case EnumTypeBusiness.ImportExport:
                        return "Doanh nghiệp xuất, nhập khẩu";
                    default:
                        return msgKey;
                }
            }
            return msg;
        }

        private static List<ListItem> GetListTypeBusinessItems()
        {
            return Enum.GetValues(typeof(EnumTypeBusiness))
                .Cast<EnumTypeBusiness>()
                .Select(x => new ListItem(GetTypeBusinessDisplayName(x), ((int)x).ToString()))
                .ToList();
        }

        private static bool ValidateRevenueConstraint(DataTable table, out string errorMessage)
        {
            errorMessage = string.Empty;
            if (table == null) return true;

            var rows = table.AsEnumerable().ToList();
            var totalRevRow = rows.FirstOrDefault(r => string.Equals(Convert.ToString(r["Code"]), "1", StringComparison.OrdinalIgnoreCase) || string.Equals(Convert.ToString(r["Code"]), "01", StringComparison.OrdinalIgnoreCase) || string.Equals(Convert.ToString(r["Targets"]), "Tổng doanh thu", StringComparison.OrdinalIgnoreCase));
            var industryRevRow = rows.FirstOrDefault(r => string.Equals(Convert.ToString(r["Code"]), "1.1", StringComparison.OrdinalIgnoreCase) || string.Equals(Convert.ToString(r["Code"]), "0101", StringComparison.OrdinalIgnoreCase) || string.Equals(Convert.ToString(r["Targets"]), "Trong đó doanh thu công nghiệp", StringComparison.OrdinalIgnoreCase));

            if (totalRevRow == null || industryRevRow == null) return true;

            var fields = new[]
            {
                new { Col = "AccumulatedBeginingOfYear", Label = "Kế hoạch năm" },
                new { Col = "PerformPreviousPeriod", Label = "Thực hiện tháng trước" },
                new { Col = "PerformInPeriod", Label = "Ước thực hiện tháng báo cáo" }
            };

            foreach (var f in fields)
            {
                double totalVal = totalRevRow[f.Col] != DBNull.Value ? Convert.ToDouble(totalRevRow[f.Col]) : 0.0;
                double indVal = industryRevRow[f.Col] != DBNull.Value ? Convert.ToDouble(industryRevRow[f.Col]) : 0.0;

                if (indVal > totalVal)
                {
                    errorMessage = string.Format("Doanh thu công nghiệp ({0:N2}) không được lớn hơn Tổng doanh thu ({1:N2}) ở cột {2}.", indVal, totalVal, f.Label);
                    return false;
                }
            }

            return true;
        }

        private static bool ValidateTradingDynamicConstraint(DataTable table, out string errorMessage)
        {
            errorMessage = string.Empty;
            if (table == null) return true;

            var rows = table.AsEnumerable().ToList();
            var dynamicParents = rows.Where(x => {
                var c = Convert.ToString(x["Code"]) ?? string.Empty;
                return (c.StartsWith("TM_", StringComparison.OrdinalIgnoreCase) || c.Contains(".TM_")) && !c.EndsWith("_BL", StringComparison.OrdinalIgnoreCase) && !c.EndsWith("_TT", StringComparison.OrdinalIgnoreCase);
            }).ToList();
            if (!dynamicParents.Any()) return true;

            if (dynamicParents.Any(x => string.IsNullOrWhiteSpace(Convert.ToString(x["Targets"]))))
            {
                errorMessage = "Vui lòng nhập tên cho tất cả các mặt hàng đã thêm ở mục '11. Hàng hóa khác'.";
                return false;
            }

            return true;
        }

        // Mặt hàng "Hàng hóa khác" được người dùng nhập tự do. Giữ lại mã cũ nếu cùng tên
        // đã từng được khai báo cho doanh nghiệp, nếu chưa có thì sinh mã nội bộ mới.
        private void EnsureTradingDynamicCodes(DataTable table, int enterpriseId)
        {
            if (table == null || enterpriseId <= 0) return;
            var dynamicRows = table.AsEnumerable()
                .Where(x =>
                {
                    var c = Convert.ToString(x["Code"]) ?? string.Empty;
                    return c.StartsWith("TM_NEW_", StringComparison.OrdinalIgnoreCase) || c.Contains(".TM_NEW_");
                })
                .ToList();
            if (!dynamicRows.Any()) return;

            var knownCodes = (_importCache.GetViaEnterpriseOnMonth(enterpriseId, null) ?? new List<ReportDataImportModel>())
                .Where(x => !string.IsNullOrWhiteSpace(x.Targets) && !string.IsNullOrWhiteSpace(x.Code) && (x.Code.StartsWith("TM_", StringComparison.OrdinalIgnoreCase) || x.Code.Contains(".TM_")) && !x.Code.EndsWith("_BL", StringComparison.OrdinalIgnoreCase) && !x.Code.EndsWith("_TT", StringComparison.OrdinalIgnoreCase))
                .GroupBy(x => x.Targets.Trim(), StringComparer.OrdinalIgnoreCase)
                .ToDictionary(x => x.Key, x =>
                {
                    var c = x.First().Code;
                    var tmIdx = c.IndexOf("TM_", StringComparison.OrdinalIgnoreCase);
                    return tmIdx >= 0 ? c.Substring(tmIdx) : c;
                }, StringComparer.OrdinalIgnoreCase);

            var groups = dynamicRows
                .Select(r => Convert.ToString(r["Code"]))
                .Select(c =>
                {
                    var tmIdx = c.IndexOf("TM_NEW_", StringComparison.OrdinalIgnoreCase);
                    var raw = tmIdx >= 0 ? c.Substring(tmIdx + "TM_NEW_".Length) : c;
                    var idx = raw.IndexOf('_');
                    return idx > 0 ? raw.Substring(0, idx) : raw;
                })
                .Distinct()
                .ToList();

            foreach (var grp in groups)
            {
                var parentRow = dynamicRows.FirstOrDefault(r =>
                {
                    var c = Convert.ToString(r["Code"]);
                    return c.EndsWith("TM_NEW_" + grp, StringComparison.OrdinalIgnoreCase);
                });
                var target = parentRow != null ? (Convert.ToString(parentRow["Targets"]) ?? string.Empty).Trim() : string.Empty;
                if (string.IsNullOrWhiteSpace(target)) continue;

                string baseCode;
                if (!knownCodes.TryGetValue(target, out baseCode))
                {
                    baseCode = "TM_" + Guid.NewGuid().ToString("N").Substring(0, 12).ToUpperInvariant();
                    knownCodes[target] = baseCode;
                }

                if (parentRow != null)
                {
                    var curCode = Convert.ToString(parentRow["Code"]);
                    var tmIdx = curCode.IndexOf("TM_NEW_", StringComparison.OrdinalIgnoreCase);
                    parentRow["Code"] = (tmIdx > 0 ? curCode.Substring(0, tmIdx) : "") + baseCode;
                }
                var blRow = dynamicRows.FirstOrDefault(r =>
                {
                    var c = Convert.ToString(r["Code"]);
                    return c.EndsWith("TM_NEW_" + grp + "_BL", StringComparison.OrdinalIgnoreCase);
                });
                if (blRow != null)
                {
                    var curCode = Convert.ToString(blRow["Code"]);
                    var tmIdx = curCode.IndexOf("TM_NEW_", StringComparison.OrdinalIgnoreCase);
                    blRow["Code"] = (tmIdx > 0 ? curCode.Substring(0, tmIdx) : "") + baseCode + "_BL";
                }
                var ttRow = dynamicRows.FirstOrDefault(r =>
                {
                    var c = Convert.ToString(r["Code"]);
                    return c.EndsWith("TM_NEW_" + grp + "_TT", StringComparison.OrdinalIgnoreCase);
                });
                if (ttRow != null)
                {
                    var curCode = Convert.ToString(ttRow["Code"]);
                    var tmIdx = curCode.IndexOf("TM_NEW_", StringComparison.OrdinalIgnoreCase);
                    ttRow["Code"] = (tmIdx > 0 ? curCode.Substring(0, tmIdx) : "") + baseCode + "_TT";
                }
            }
        }

        private static bool ValidateTradingRetailConstraint(DataTable table, out string errorMessage)
        {
            errorMessage = string.Empty;
            if (table == null) return true;
            var pairs = new[]
            {
                new { Total = "01", Retail = "02" }, new { Total = "03", Retail = "04" },
                new { Total = "05", Retail = "06" }, new { Total = "07", Retail = "08" },
                new { Total = "09", Retail = "10" }, new { Total = "11", Retail = "12" },
                new { Total = "14", Retail = "15" }, new { Total = "16", Retail = "17" },
                new { Total = "18", Retail = "19" }, new { Total = "20", Retail = "21" }
            };
            var fields = new[] { "PerformInPeriod", "PerformPreviousPeriod", "AccumulatedBeginingOfYear" };
            foreach (var pair in pairs)
            {
                var total = table.AsEnumerable().FirstOrDefault(x => Convert.ToString(x["Code"]) == pair.Total);
                var retail = table.AsEnumerable().FirstOrDefault(x => Convert.ToString(x["Code"]) == pair.Retail);
                if (total == null || retail == null) continue;
                foreach (var field in fields)
                {
                    var totalValue = total[field] == DBNull.Value ? 0 : Convert.ToDouble(total[field]);
                    var retailValue = retail[field] == DBNull.Value ? 0 : Convert.ToDouble(retail[field]);
                    if (retailValue > totalValue)
                    {
                        errorMessage = $"Chỉ tiêu '{Convert.ToString(retail["Targets"])}' không được lớn hơn '{Convert.ToString(total["Targets"])}'.";
                        return false;
                    }
                }
            }
            return true;
        }

        private byte[] CreateReport(DataTable data, string reportFilename, string urlPathReport, out string mimeType,
            out string fileExt)
        {
            #region Create Report

            // Variables
            Warning[] warnings;
            string[] streamIds;
            //string mimeType;
            string encoding;
            //string extension;

            // Setup the report viewer object and get the array of bytes
            var reportExcel = new ReportViewer { ProcessingMode = ProcessingMode.Local };

            reportExcel.LocalReport.ReportPath = urlPathReport;
            reportExcel.LocalReport.DataSources.Clear();
            reportExcel.LocalReport.DataSources.Add(new ReportDataSource("DataImport", data));
            reportExcel.LocalReport.DisplayName = reportFilename;

            //Chuyển sang Excel
            var bytes = reportExcel.LocalReport.Render("EXCELOPENXML", null, out mimeType, out encoding, out fileExt,
                out streamIds, out warnings);

            #endregion

            return bytes;
        }

        private bool CheckCorrectTemplate(HttpPostedFileBase fileImport, string typeBiz)
        {
            var lstKey = new Dictionary<string, string>{
                { "Tags", "ReportTourism"},
                { "Company","KHA_CenIT"}
            };

            Workbook workbook = new Workbook();
            workbook.LoadFromStream(fileImport.InputStream);
            BuiltInDocumentProperties p = workbook.DocumentProperties;
            for (int i = 0; i < p.Count; i++)
            {
                string pName = p[i].Name;
                if (!lstKey.ContainsKey(pName) && pName != "Category") continue;
                string pValue = p[i].Text;
                var lstTypeBiz = string.IsNullOrEmpty(pValue) ? new List<string>() : pValue.Split(';').ToList();
                if (pName == "Category" && !lstTypeBiz.Contains(typeBiz))
                {
                    return false;
                }
                if (pName == "Category") continue;
                if (lstKey[pName] != pValue)
                {
                    return false;
                }
            }

            return true;
        }

        private bool CheckCorrectTemplate(Stream streamFile, string typeBiz)
        {
            var lstKey = new Dictionary<string, string>{
                { "Tags", "ReportTourism"},
                { "Company","KHA_CenIT"}
            };

            Workbook workbook = new Workbook();
            workbook.LoadFromStream(streamFile);
            BuiltInDocumentProperties p = workbook.DocumentProperties;
            for (int i = 0; i < p.Count; i++)
            {
                string pName = p[i].Name;
                if (!lstKey.ContainsKey(pName) && pName != "Category") continue;
                string pValue = p[i].Text;
                var lstTypeBiz = string.IsNullOrEmpty(pValue) ? new List<string>() : pValue.Split(';').ToList();
                if (pName == "Category" && !lstTypeBiz.Contains(typeBiz))
                {
                    return false;
                }
                if (pName == "Category") continue;
                if (lstKey[pName] != pValue)
                {
                    return false;
                }
            }

            return true;
        }

        private bool HasSignature(HttpPostedFileBase fileImport)
        {
            using (SpreadsheetDocument spreadsheetDocument = SpreadsheetDocument.Open(fileImport.InputStream, false))
            {
                var signature = spreadsheetDocument.DigitalSignatureOriginPart;
                if (signature == null) return false;
            }
            return true;
        }

        #endregion

        #region Smart CA

        #region Properties

        private readonly string _digitalSignTitle = AppProcessor.Messagor.GetMessage("DigitalSign_Title");

        private readonly Dictionary<int, string> _transactionStatus = new Dictionary<int, string>
        {
            {1, "SUCCESS"},
            {4000, "WAITING_FOR_SIGNER_CONFIRM"},
            {4001, "EXPIRED"},
            {4002, "SIGNER_REJECTED"},
            {4003, "AUTHORIZE_KEY_FAILED"},
            {4004, "SIGN_FAILED"}
        };

        private readonly string _signedFilesPathFolder =
            ConfigurationManager.AppSettings["Modules_Sys_SignedDoc_FolderPath"] ??
            "/Contents/Modules/Report/ReportSignedDocs/";

        #endregion

        #region Login & Logout

        [ActionType(Type = EnumActionType.View)]
        [HttpGet]
        public ActionResult LoginSmartCA()
        {
            return PartialView("_Login", new LoginSmartCAModel());
        }

        [ActionType(Type = EnumActionType.Edit)]
        [HttpPost]
        public ActionResult LoginSmartCA(LoginSmartCAModel model)
        {
            if (!ModelState.IsValid) return PartialView("_LoginSmartCA", model);

            string sRefreshToken;
            UserInfoModel userInfo = null;

            var accessToken = VNPTSmartCAProvider.AuthToken(model.UserName, model.Password, out sRefreshToken);
            if (!string.IsNullOrEmpty(accessToken)) userInfo = VNPTSmartCAProvider.GetUserInfo(accessToken);

            if (string.IsNullOrEmpty(accessToken))
                return Json(new
                {
                    status = false,
                    message = CreateMessage(
                        $"{AppProcessor.Messagor.GetMessage("Login_SmartCA_Label")} thất bại. Tài khoản hoặc mật khẩu không đúng.",
                        EnumProcessType.NonFormat, EnumMsgIcon.Error)
                });

            if (userInfo != null)
                Session[$"VNPT-SmartCA-{User?.UserName}-UserInfo"] = userInfo;

            Session[$"VNPT-SmartCA-{User?.UserName}-AccessToken"] = accessToken;

            return Json(new
            {
                status = true,
                message = CreateMessage($"{AppProcessor.Messagor.GetMessage("Login_SmartCA_Label")} thành công",
                    EnumProcessType.NonFormat, EnumMsgIcon.Success)
            });
        }

        [ActionType(Type = EnumActionType.View)]
        [HttpGet]
        [AjaxOnly]
        public ActionResult SignOutSmartCA()
        {
            Session[$"VNPT-SmartCA-{User?.UserName}-AccessToken"] = null;
            Session[$"VNPT-SmartCA-{User?.UserName}-UserInfo"] = null;

            return Json(new
            {
                status = true,
                message = ""
            });
        }

        [ActionType(Type = EnumActionType.View)]
        //[HttpGet]
        public ActionResult UserInfo()
        {
            var userInfo = (UserInfoModel)Session[$"VNPT-SmartCA-{User?.UserName}-UserInfo"];

            return PartialView("_UserInfo", userInfo ?? new UserInfoModel());
        }

        #endregion

        #region Sign Doc

        /// <summary>
        ///     Ký văn bản
        /// </summary>
        /// <param name="accessToken"></param>
        /// <param name="fileImport"></param>
        /// <param name="fullSignedPath"></param>
        /// <returns>
        ///     - 0: thành công
        ///     - 1: ký thất bại
        ///     - 2: lỗi thông tin chữ ký số
        ///     - 3: người dùng không xác nhận ký số từ App
        ///     - 4: lỗi chữ ký
        ///     - 5: chữ ký không khớp
        /// </returns>
        private int SignHash(string accessToken, HttpPostedFileBase fileImport, string fullSignedPath)
        {
            var lstCredentials = VNPTSmartCAProvider.GetListCredentials(accessToken);
            var credentialId = lstCredentials?[0];
            var credentialInfo =
                VNPTSmartCAProvider.GetCredentialInfo(accessToken, credentialId, CTSType.Chain, true, true);
            var certBase64 = credentialInfo?.Cert?.Certificates?[0]?.Replace("\r\n", "");
            var fileData = StreamHelper.ReadFully(fileImport.InputStream);

            var typeExt = HashSignerFactory.OFFICE;
            //var fileNameWithoutExt = Path.GetFileNameWithoutExtension(fileImport.FileName);
            var fileExt = Path.GetExtension(fileImport.FileName);

            if (fileExt?.ToUpper() == ".PDF")
                typeExt = HashSignerFactory.PDF;
            else if (fileExt?.ToUpper() == ".XML") typeExt = HashSignerFactory.XML;

            IHashSigner signer;
            var tranId = VNPTSmartCAProvider.SignHash(out signer, accessToken, credentialId, certBase64, "",
                fileImport.FileName, fileData, typeExt);
            if (string.IsNullOrEmpty(tranId)) return 1;

            AppProcessor.Notifider.PushNotifyToUser("Sys", User.UserName, "Vui lòng xác nhận ký số trên ứng dụng.",
                EnumProcessType.NonFormat, EnumMsgIcon.Warning);

            var iCount = 1;
            var isConfirm = false;
            var datasigned = "";
            var tranStatus = -1;

            while (iCount <= 24 && !isConfirm)
            {
                AppProcessor.Logger.Message($"Chờ ký số lần {iCount}: ");

                AppProcessor.Notifider.PushNotifyToUser("Sys", User.UserName,
                    $"Chờ xác nhận ký số trên ứng dụng lần {iCount}", EnumProcessType.NonFormat, EnumMsgIcon.Warning);

                var tranInfo = VNPTSmartCAProvider.GetTranInfo(accessToken, tranId);
                tranStatus = tranInfo?.TranStatus ?? -1;

                if (tranInfo != null)
                {
                    if (tranInfo.TranStatus == 4000)
                    {
                        iCount = iCount + 1;
                        Thread.Sleep(5000);
                    }
                    else if (tranInfo.TranStatus == 4002)
                    {
                        datasigned = null;
                        break;
                    }
                    else
                    {
                        isConfirm = true;
                        datasigned = tranInfo.Documents[0].Sig;
                    }
                }
                else
                {
                    AppProcessor.Logger.Message("Lỗi nội dung");
                    return 2;
                }
            }

            var msgStatus = _transactionStatus[tranStatus];
            if (!isConfirm && datasigned == null)
            {
                AppProcessor.Logger.Message($"Từ chối ký số - {msgStatus}");
                return 6;
            }

            if (!isConfirm)
            {
                AppProcessor.Logger.Message($"Không xác nhận từ App - {msgStatus}");
                return 3;
            }

            if (string.IsNullOrEmpty(datasigned))
            {
                AppProcessor.Logger.Message($"Lỗi ký số - {msgStatus}");
                return 4;
            }

            if (!signer.CheckHashSignature(datasigned))
            {
                AppProcessor.Logger.Message($"Chữ ký số không khớp - {msgStatus}");
                return 5;
            }
            // ------------------------------------------------------------------------------------------
            AppProcessor.Logger.Message("Ký số thành công");

            // 3. Package external signature to signed file
            var signed = signer.Sign(datasigned);
            System.IO.File.WriteAllBytes(fullSignedPath, signed);
            return 0;
        }

        private int SignHash(string accessToken, byte[] dataImport, string fileNameWithExt, string fileExt,
            string fullSignedPath)
        {
            var lstCredentials = VNPTSmartCAProvider.GetListCredentials(accessToken);
            var credentialId = lstCredentials?[0];
            var credentialInfo =
                VNPTSmartCAProvider.GetCredentialInfo(accessToken, credentialId, CTSType.Chain, true, true);
            var certBase64 = credentialInfo?.Cert?.Certificates?[0]?.Replace("\r\n", "");

            var typeExt = HashSignerFactory.OFFICE;

            if (fileExt?.ToUpper() == ".PDF")
                typeExt = HashSignerFactory.PDF;
            else if (fileExt?.ToUpper() == ".XML") typeExt = HashSignerFactory.XML;

            IHashSigner signer;
            var tranId = VNPTSmartCAProvider.SignHash(out signer, accessToken, credentialId, certBase64, "",
                fileNameWithExt, dataImport, typeExt);
            if (string.IsNullOrEmpty(tranId)) return 1;

            AppProcessor.Notifider.PushNotifyToUser("Sys", User.UserName, "Vui lòng xác nhận ký số trên ứng dụng.",
                EnumProcessType.NonFormat, EnumMsgIcon.Warning);

            var iCount = 0;
            var isConfirm = false;
            var datasigned = "";
            var tranStatus = -1;

            while (iCount < 24 && !isConfirm)
            {
                AppProcessor.Logger.Message($"Chờ ký số lần {iCount}: ");

                AppProcessor.Notifider.PushNotifyToUser("Sys", User.UserName,
                    $"Chờ xác nhận ký số trên ứng dụng lần {iCount + 1}", EnumProcessType.NonFormat, EnumMsgIcon.Warning);

                var tranInfo = VNPTSmartCAProvider.GetTranInfo(accessToken, tranId);
                tranStatus = tranInfo?.TranStatus ?? -1;

                if (tranInfo != null)
                {
                    if (tranInfo.TranStatus == 4000)
                    {
                        iCount = iCount + 1;
                        Thread.Sleep(5000);
                    }
                    else if (tranInfo.TranStatus == 4002)
                    {
                        datasigned = null;
                        break;
                    }
                    else
                    {
                        isConfirm = true;
                        datasigned = tranInfo.Documents[0].Sig;
                    }
                }
                else
                {
                    AppProcessor.Logger.Message("Lỗi nội dung");
                    return 2;
                }
            }

            var msgStatus = _transactionStatus[tranStatus];
            if (!isConfirm && datasigned == null)
            {
                AppProcessor.Logger.Message($"Từ chối ký số - {msgStatus}");
                return 6;
            }

            if (!isConfirm)
            {
                AppProcessor.Logger.Message($"Không xác nhận từ App - {msgStatus}");
                return 3;
            }

            if (string.IsNullOrEmpty(datasigned))
            {
                AppProcessor.Logger.Message($"Lỗi ký số - {msgStatus}");
                return 4;
            }

            if (!signer.CheckHashSignature(datasigned))
            {
                AppProcessor.Logger.Message($"Chữ ký số không khớp - {msgStatus}");
                return 5;
            }
            // ------------------------------------------------------------------------------------------

            AppProcessor.Logger.Message("Ký số thành công");

            // 3. Package external signature to signed file
            var signed = signer.Sign(datasigned);
            System.IO.File.WriteAllBytes(fullSignedPath, signed);
            return 0;
        }

        /// <summary>
        ///     Ký văn bản
        /// </summary>
        /// <param name="accessToken"></param>
        /// <param name="fileImport"></param>
        /// <param name="fullSignedPath"></param>
        /// <returns>
        ///     - 0: thành công
        ///     - 1: ký thất bại
        ///     - 2: lỗi thông tin chữ ký số
        ///     - 3: người dùng không xác nhận ký số từ App
        ///     - 4: lỗi chữ ký
        ///     - 5: chữ ký không khớp
        /// </returns>
        private int Sign(string accessToken, HttpPostedFileBase fileImport, string fullSignedPath)
        {
            var lstCredentials = VNPTSmartCAProvider.GetListCredentials(accessToken);
            var credentialId = lstCredentials?[0];
            var fileData = StreamHelper.ReadFully(fileImport.InputStream);
            var tranId = VNPTSmartCAProvider.Sign(accessToken, credentialId, "", fileImport.FileName, fileData);
            if (string.IsNullOrEmpty(tranId)) return 1;

            AppProcessor.Notifider.PushNotifyToUser("Sys", User.UserName, "Vui lòng xác nhận ký số trên ứng dụng.",
                EnumProcessType.NonFormat, EnumMsgIcon.Warning);

            var iCount = 1;
            var isConfirm = false;
            var datasigned = "";
            var tranStatus = -1;

            while (iCount <= 24 && !isConfirm)
            {
                AppProcessor.Logger.Message($"Chờ ký số lần {iCount}: ");

                AppProcessor.Notifider.PushNotifyToUser("Sys", User.UserName,
                    $"Chờ xác nhận ký số trên ứng dụng lần {iCount}", EnumProcessType.NonFormat, EnumMsgIcon.Warning);

                var tranInfo = VNPTSmartCAProvider.GetTranInfo(accessToken, tranId);
                tranStatus = tranInfo?.TranStatus ?? -1;

                if (tranInfo != null)
                {
                    if (tranInfo.TranStatus == 4000)
                    {
                        iCount = iCount + 1;
                        Thread.Sleep(5000);
                    }
                    else if (tranInfo.TranStatus == 4002)
                    {
                        datasigned = null;
                        break;
                    }
                    else
                    {
                        isConfirm = true;
                        datasigned = tranInfo.Documents[0].DataSigned;
                    }
                }
                else
                {
                    AppProcessor.Logger.Message("Lỗi nội dung");
                    return 2;
                }
            }

            var msgStatus = _transactionStatus[tranStatus];
            if (!isConfirm && datasigned == null)
            {
                AppProcessor.Logger.Message($"Từ chối ký số - {msgStatus}");
                return 6;
            }

            if (!isConfirm)
            {
                AppProcessor.Logger.Message($"Không xác nhận từ App - {msgStatus}");
                return 3;
            }

            if (string.IsNullOrEmpty(datasigned))
            {
                AppProcessor.Logger.Message($"Lỗi ký số - {msgStatus}");
                return 4;
            }

            AppProcessor.Logger.Message("Ký số thành công");

            // 3. Package external signature to signed file
            System.IO.File.WriteAllBytes(fullSignedPath, Convert.FromBase64String(datasigned));
            return 0;
        }

        private int Sign(string accessToken, byte[] dataImport, string fileNameWithExt,
            string fullSignedPath, out string msgLogs)
        {
            msgLogs = string.Empty;
            StringBuilder logBuilder = new StringBuilder();

            var lstCredentials = VNPTSmartCAProvider.GetListCredentials(accessToken);
            var credentialId = lstCredentials?[0];
            var tranId = VNPTSmartCAProvider.Sign(accessToken, credentialId, "",
                fileNameWithExt, dataImport);
            if (string.IsNullOrEmpty(tranId)) return 1;

            AppProcessor.Notifider.PushNotifyToUser("Sys", User.UserName, "Vui lòng xác nhận ký số trên ứng dụng.",
                EnumProcessType.NonFormat, EnumMsgIcon.Warning);

            var iCount = 0;
            var isConfirm = false;
            var datasigned = "";
            var tranStatus = -1;

            while (iCount < 24 && !isConfirm)
            {
                logBuilder.AppendLine($"    * Chờ ký số lần: {iCount}");
                //AppProcessor.Logger.Message($"Chờ ký số lần {iCount}: ");

                AppProcessor.Notifider.PushNotifyToUser("Sys", User.UserName,
                    $"Chờ xác nhận ký số trên ứng dụng lần {iCount + 1}", EnumProcessType.NonFormat, EnumMsgIcon.Warning);

                var tranInfo = VNPTSmartCAProvider.GetTranInfo(accessToken, tranId);
                tranStatus = tranInfo?.TranStatus ?? -1;

                if (tranInfo != null)
                {
                    if (tranInfo.TranStatus == 4000)
                    {
                        iCount = iCount + 1;
                        Thread.Sleep(5000);
                    }
                    else if (tranInfo.TranStatus == 4002)
                    {
                        datasigned = null;
                        break;
                    }
                    else
                    {
                        isConfirm = true;
                        datasigned = tranInfo.Documents[0].DataSigned;
                    }
                }
                else
                {
                    //AppProcessor.Logger.Message("Lỗi nội dung");
                    logBuilder.AppendLine(" + Lỗi nội dung");
                    msgLogs = logBuilder.ToString();
                    return 2;
                }
            }

            var msgStatus = _transactionStatus[tranStatus];
            if (!isConfirm && datasigned == null)
            {
                //AppProcessor.Logger.Message($"Từ chối ký số - {msgStatus}");
                logBuilder.AppendLine($" + Từ chối ký số - {msgStatus}");
                msgLogs = logBuilder.ToString();
                return 6;
            }

            if (!isConfirm)
            {
                //AppProcessor.Logger.Message($"Không xác nhận từ App - {msgStatus}");
                logBuilder.AppendLine($" + Không xác nhận từ App - {msgStatus}");
                msgLogs = logBuilder.ToString();
                return 3;
            }

            if (string.IsNullOrEmpty(datasigned))
            {
                //AppProcessor.Logger.Message($"Lỗi ký số - {msgStatus}");
                logBuilder.AppendLine($" + Lỗi ký số - {msgStatus}");
                msgLogs = logBuilder.ToString();
                return 4;
            }

            //AppProcessor.Logger.Message("Ký số thành công");
            logBuilder.AppendLine(" + Ký số thành công");
            msgLogs = logBuilder.ToString();

            // 3. Package external signature to signed file
            System.IO.File.WriteAllBytes(fullSignedPath, Convert.FromBase64String(datasigned));
            return 0;
        }

        #endregion

        #endregion

        #region VNPT Token

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult SignToken()
        {
            var serialKeyVNPTToken = ConfigurationManager.AppSettings["VNPT_Token_Serial"];
            return PartialView("_SignToken", serialKeyVNPTToken);
        }

        //[AjaxOnly]
        //[HttpPost]
        //[ActionType(Type = EnumActionType.Add)]
        //public ActionResult CheckDataFileSignToken(DataFileSignTokenModel model)
        //{
        //    if (model.FileDataBase64 == null)
        //    {
        //        return Json(new
        //        {
        //            status = false,
        //            message = string.Empty
        //        });
        //    }

        //    var enterpriseModel = _enterpriseCache.GetById(model.EnterpriseId);
        //    if (enterpriseModel == null)
        //        return Json(new
        //        {
        //            status = false,
        //            message = CreateMessage($"{_enterpriseTitle}",
        //                EnumProcessType.DataNotExist, EnumMsgIcon.Error)
        //        });

        //    var arraBytes = Convert.FromBase64String(model.FileDataBase64);
        //    var streamDatas = new MemoryStream(arraBytes);

        //    if (!CheckCorrectTemplate(streamDatas, EnumHelper.GetDescription((EnumTypeBusiness)enterpriseModel.TypeBusiness)))
        //    {
        //        string sTypeBiz = _mappingReportTypeBiz[enterpriseModel.TypeBusiness];
        //        return Json(new
        //        {
        //            status = false,
        //            message = CreateMessage($"Tệp dữ liệu import không đúng loại báo cáo thuộc [{sTypeBiz}]",
        //                EnumProcessType.NonFormat, EnumMsgIcon.Error)
        //        });
        //    }

        //    #region Check Data Import

        //    bool isSuccessImport;
        //    var dataImports = ReadDataImports(streamDatas, model.FileExt, out isSuccessImport);
        //    if (!isSuccessImport)
        //        return Json(new
        //        {
        //            status = false,
        //            message = CreateMessage(AppProcessor.Messagor.GetMessage("ImportData_Message_Fail"),
        //                EnumProcessType.NonFormat, EnumMsgIcon.Error)
        //        });
        //    var lstDataImports = ModelProvider.CreateListFromTable<ReportDataImportModel>(dataImports);

        //    #endregion

        //    return Json(new
        //    {
        //        status = true,
        //        dataImport = lstDataImports.OrderBy(d => d.RowIndex),
        //        typeReport = enterpriseModel.TypeBusiness,
        //        message = ""
        //    });
        //}

        #endregion
    }
}
