using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.IO;
using System.Linq;
using System.Web.Mvc;
using System.Web.UI.WebControls;
using CenIT.ReportTourism.Caches.Cate;
using CenIT.ReportTourism.Core.Apps;
using CenIT.ReportTourism.Core.Conts;
using CenIT.ReportTourism.Models.Cate;
using CenIT.ReportTourism.Models.Search;
using CenIT.ReportTourism.Modules.CateModule.Areas.Cate.Models;
using ExcelDataReader;
using FastMember;
using TSFramework.App.Attributes;
using TSFramework.App.Processors;
using TSFramework.Core.Enums;
using TSFramework.Core.Helpers;

namespace CenIT.ReportTourism.Modules.CateModule.Areas.Cate.Controllers
{
    public class EnterpriseController : AppController
    {
        private readonly CateEnterpriseCache _enterpriseCache = new CateEnterpriseCache();
        private readonly CateProvinceCache _provinceCache = new CateProvinceCache();
        private readonly CateWardCache _wardCache = new CateWardCache();
        private readonly CateBusinessIndustryCache _industryCache = new CateBusinessIndustryCache();
        private readonly CateEnterpriseTypeCache _enterpriseTypeCache = new CateEnterpriseTypeCache();
        private readonly CateEconomicSectorCache _economicSectorCache = new CateEconomicSectorCache();
        private readonly CateEnterpriseStatusCache _enterpriseStatusCache = new CateEnterpriseStatusCache();
        private readonly CateBusinessProductCache _businessProductCache = new CateBusinessProductCache();

        // Sản phẩm chính: chỉ chọn sản phẩm cấp 7 (Cate_BusinessProduct.IsLevel) thuộc các ngành của doanh nghiệp
        private const int MainProductLevel = 7;

        private readonly int _defaultProvinceId = 23;
        private readonly string _enterpriseFolder = "Enterprise";
        private readonly CateEnterpriseRegisterNotifyCache _enterpriseRegisterNotifyCache = new CateEnterpriseRegisterNotifyCache();
        private readonly string _enterpriseTitle = AppProcessor.Messagor.GetMessage("Enterprise_Label");

        private readonly string _moduleRefDocsPathFolder =
            ConfigurationManager.AppSettings["AttachmentFolderPath"] ?? "/Contents/Modules/Cate/Attachments/";

        private readonly string _pathTemplateFolder = "~/Contents/Modules/Cate/Templates/";

        // GET: Modules
        [ActionType(Type = EnumActionType.View)]
        [HttpGet]
        public ActionResult Index()
        {
            var searchModel = new SearchEnterpriseModel
            {
                ListTypeBusiness = Enum.GetValues(typeof(EnumTypeBusiness))
                    .Cast<EnumTypeBusiness>()
                    .Select(x => new ListItem(AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(x)),
                        ((int)x).ToString()))
                    .ToList(),

                ListWards = _wardCache.GetAll(_defaultProvinceId)
                    .OrderBy(d => d.WardName)
                    .Select(d => new ListItem(d.WardName, d.WardId.ToString())).ToList(),

                ListProvinces = _provinceCache.GetAll()
                    .OrderBy(d => d.ProvinceName)
                    .Select(d => new ListItem(d.ProvinceName, d.ProvinceId.ToString())).ToList(),

                ListMainIndustry = GetListBusinessIndustry(),

                ListEnterpriseType = _enterpriseTypeCache.GetAll()
                    .OrderBy(d => d.Name)
                    .Select(d => new ListItem(d.Name, d.EnterpriseTypeId.ToString())).ToList(),
                ListEconomicSector = _economicSectorCache.GetAll()
                    .OrderBy(d => d.Name)
                    .Select(d => new ListItem(d.Name, d.EconomicSectorId.ToString())).ToList(),
                ListStatus = _enterpriseStatusCache.GetAll()
                    .OrderBy(d => d.Name)
                    .Select(d => new ListItem(d.Name, d.EnterpriseStatusId.ToString())).ToList(),
            };
            return View(searchModel);
        }

        #region Enterprise

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult Get(SearchEnterpriseModel searchModel)
        {
            var search = Request.Form.GetValues("search[value]")?[0];
            var draw = Request.Form.GetValues("draw")?[0];
            var order = Request.Form.GetValues("order[0][column]")?[0];
            var orderDir = Request.Form.GetValues("order[0][dir]")?[0];
            var startRec = Convert.ToInt32(Request.Form.GetValues("start")?[0]);
            var pageSize = Convert.ToInt32(Request.Form.GetValues("length")?[0]);

            
            searchModel.ForUser = User.UserName;
            searchModel.Search = string.IsNullOrEmpty(search) ? null : search;
            searchModel.Order = order;
            searchModel.OrderDir = orderDir;
            searchModel.StartIndex = startRec;
            searchModel.PageSize = pageSize;

            searchModel.TypeBusinessIds =
                string.IsNullOrEmpty(searchModel.TypeBusinessIds) ? null : searchModel.TypeBusinessIds;
            searchModel.WardIds = string.IsNullOrEmpty(searchModel.WardIds) ? null : searchModel.WardIds;
            searchModel.ProvinceIds = string.IsNullOrEmpty(searchModel.ProvinceIds) ? null : searchModel.ProvinceIds;
            searchModel.MainIndustryIds = string.IsNullOrEmpty(searchModel.MainIndustryIds) ? null : searchModel.MainIndustryIds;
            searchModel.EnterpriseTypeIds = string.IsNullOrEmpty(searchModel.EnterpriseTypeIds) ? null : searchModel.EnterpriseTypeIds;
            searchModel.EconomicSectorIds = string.IsNullOrEmpty(searchModel.EconomicSectorIds) ? null : searchModel.EconomicSectorIds;
            searchModel.StatusIds = string.IsNullOrEmpty(searchModel.StatusIds) ? null : searchModel.StatusIds;

            int total;
            var data = _enterpriseCache.Get(out total, searchModel);

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
            //var provinceModel = _provinceCache.GetAll().FirstOrDefault();
            var enterpriseModel = new CateEnterpriseModel
            {
                ListProvinces = _provinceCache.GetAll()
                    .OrderBy(d => d.ProvinceName)
                    .Select(d => new ListItem(d.ProvinceName, d.ProvinceId.ToString())).ToList(),

                ListWards = new List<ListItem>(),

                ListBusinessIndustry = GetListBusinessIndustry(),
                ListEnterpriseType = _enterpriseTypeCache.GetAll()
                    .OrderBy(d => d.Name)
                    .Select(d => new ListItem(d.Name, d.EnterpriseTypeId.ToString())).ToList(),
                ListEconomicSector = _economicSectorCache.GetAll()
                    .OrderBy(d => d.Name)
                    .Select(d => new ListItem(d.Name, d.EconomicSectorId.ToString())).ToList(),
                ListEnterpriseStatus = _enterpriseStatusCache.GetAll()
                    .OrderBy(d => d.Name)
                    .Select(d => new ListItem(d.Name, d.EnterpriseStatusId.ToString())).ToList(),

                ListTypeBusiness = Enum.GetValues(typeof(EnumTypeBusiness))
                    .Cast<EnumTypeBusiness>()
                    .Select(x => new ListItem(AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(x)),
                        ((int)x).ToString()))
                    .ToList(),

                Reason = "Thêm mới"
            };
            return PartialView("_Add", enterpriseModel);
        }

        [ActionType(Type = EnumActionType.View)]
        [HttpPost]
        public ActionResult Add(CateEnterpriseModel model)
        {
            var industryIds = JoinIds(model.ListIndustryId);
            ValidateMainProduct(model.MainProductId, industryIds);

            if (!ModelState.IsValid)
            {
                // Hiển thị lại đúng các ngành vừa chọn (khớp với danh sách sản phẩm chính)
                ModelState.Remove("IndustryIds");
                model.IndustryIds = industryIds;

                model.ListProvinces = _provinceCache.GetAll()
                    .OrderBy(d => d.ProvinceName)
                    .Select(d => new ListItem(d.ProvinceName, d.ProvinceId.ToString())).ToList();
                model.ListWards = new List<ListItem>();
                model.ListBusinessIndustry = GetListBusinessIndustry();
                model.ListMainProduct = GetListMainProduct(industryIds);
                model.ListEnterpriseType = _enterpriseTypeCache.GetAll()
                    .OrderBy(d => d.Name)
                    .Select(d => new ListItem(d.Name, d.EnterpriseTypeId.ToString())).ToList();
                model.ListEconomicSector = _economicSectorCache.GetAll()
                    .OrderBy(d => d.Name)
                    .Select(d => new ListItem(d.Name, d.EconomicSectorId.ToString())).ToList();
                model.ListEnterpriseStatus = _enterpriseStatusCache.GetAll()
                    .OrderBy(d => d.Name)
                    .Select(d => new ListItem(d.Name, d.EnterpriseStatusId.ToString())).ToList();

                model.ListTypeBusiness = Enum.GetValues(typeof(EnumTypeBusiness))
                    .Cast<EnumTypeBusiness>()
                    .Select(x => new ListItem(AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(x)),
                        ((int)x).ToString()))
                    .ToList();
                return PartialView("_Enterprise", model);
            }

            var enterpriseId = _enterpriseCache.Save(new CateEnterpriseModel
            {
                EnterpriseId = 0,
                OwnerEnterpriseName = model.OwnerEnterpriseName,
                BusinessName = model.BusinessName,
                TaxCode = model.TaxCode,
                BusinessAddress = model.BusinessAddress,
                StreetName = model.StreetName,
                WardId = model.WardId,
                WardName = model.WardName,
                
                LegalRepresentationName = model.LegalRepresentationName,
                LegalRepresentationPhone = model.LegalRepresentationPhone,
                LegalRepresentationEmail = model.LegalRepresentationEmail,
                Website = model.Website,
                Phone = model.Phone,
                Email = model.Email,
                Reason = model.Reason,

                //MainIndustryId = model.MainIndustryId,
                TypeBusiness = model.ListTypeBusinessId != null && model.ListTypeBusinessId.Count > 0 ? string.Join(",", model.ListTypeBusinessId) : null,
                IndustryIds = model.ListIndustryId != null && model.ListIndustryId.Count > 0 ? string.Join(",", model.ListIndustryId) : null,
                EnterpriseTypeId = model.EnterpriseTypeId,
                EconomicSectorId = model.EconomicSectorId,
                EnterpriseStatusId = model.EnterpriseStatusId,
                CapacityMWp = model.CapacityMWp,
                CapacityMW = model.CapacityMW,

                SavedBy = User.Email
            });

            if (enterpriseId == -9)
            {
                var errMessage =
                    CreateMessage($"{AppProcessor.Messagor.GetMessage("Enterprise_Label_TaxCode")} [{model.TaxCode}]",
                        EnumProcessType.DataExisted, EnumMsgIcon.Error);
                return Json(new { status = true, message = errMessage });
            }

            if (enterpriseId > 0 && model.MainProductId.HasValue &&
                _enterpriseCache.SaveMainProduct(enterpriseId, model.MainProductId, User.Email) < 0)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{AppProcessor.Messagor.GetMessage("Enterprise_MainProduct")} [{model.BusinessName}]",
                        EnumProcessType.Add, EnumMsgIcon.Error)
                });

            if (enterpriseId > 0)
            {
                model.EnterpriseId = enterpriseId;
                var businessCetificatesId = SaveUploadFile(model);
                if (businessCetificatesId == -7)
                    return Json(new
                    {
                        status = true,
                        message = CreateMessage($"{_enterpriseTitle}",
                            EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                    });
            }

            var response = CreateMessage($"{_enterpriseTitle} [{model.OwnerEnterpriseName} - {model.BusinessName}]",
                EnumProcessType.Add,
                enterpriseId > 0 ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = true, message = response });
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Edit(int id = 0)
        {
            var model = _enterpriseCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            var provinceModel = _provinceCache.GetViaWard(model.WardId);
            model.ProvinceId = provinceModel?.ProvinceId;
            model.ProvinceName = provinceModel?.ProvinceName;
            model.ListProvinces = _provinceCache.GetAll()
                .OrderBy(d => d.ProvinceName)
                .Select(d => new ListItem(d.ProvinceName, d.ProvinceId.ToString())).ToList();
            model.ListWards = _wardCache.GetByProvinceId(model.ProvinceId).OrderBy(d => d.WardName)
                .Select(d => new ListItem(d.WardName, d.WardId.ToString())).ToList();

            if (model.ProvinceId != null)
            {
                int totalWards;
                model.ListWards = _wardCache.GetByProvinceId(model.ProvinceId, out totalWards)
                    .OrderBy(w => w.WardName)
                    .Select(d => new ListItem(d.WardName, d.WardId.ToString())).ToList();
            }

            model.ListBusinessIndustry = GetListBusinessIndustry();
            model.MainProductId = GetMainProductId(model.EnterpriseId);
            model.ListMainProduct = GetListMainProduct(model.IndustryIds);
            model.ListEnterpriseType = _enterpriseTypeCache.GetAll()
                .OrderBy(d => d.Name)
                .Select(d => new ListItem(d.Name, d.EnterpriseTypeId.ToString())).ToList();
            model.ListEconomicSector = _economicSectorCache.GetAll()
                .OrderBy(d => d.Name)
                .Select(d => new ListItem(d.Name, d.EconomicSectorId.ToString())).ToList();
            model.ListEnterpriseStatus = _enterpriseStatusCache.GetAll()
                .OrderBy(d => d.Name)
                .Select(d => new ListItem(d.Name, d.EnterpriseStatusId.ToString())).ToList();

            model.ListTypeBusiness = Enum.GetValues(typeof(EnumTypeBusiness))
                .Cast<EnumTypeBusiness>()
                .Select(x => new ListItem(AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(x)),
                    ((int)x).ToString()))
                .ToList();
            return PartialView("_Edit", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ValidateAntiForgeryToken]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Edit(CateEnterpriseModel model)
        {
            var industryIds = JoinIds(model.ListIndustryId);
            ValidateMainProduct(model.MainProductId, industryIds);

            if (!ModelState.IsValid)
            {
                // Hiển thị lại đúng các ngành vừa chọn (khớp với danh sách sản phẩm chính)
                ModelState.Remove("IndustryIds");
                model.IndustryIds = industryIds;

                var provinceModel = _provinceCache.GetAll().FirstOrDefault();
                model.ProvinceId = provinceModel?.ProvinceId;
                model.ProvinceName = provinceModel?.ProvinceName;

                model.ListProvinces = _provinceCache.GetAll()
                    .OrderBy(d => d.ProvinceName)
                    .Select(d => new ListItem(d.ProvinceName, d.ProvinceId.ToString())).ToList();
                model.ListWards = _wardCache.GetByProvinceId(model.ProvinceId).OrderBy(d => d.WardName)
                    .Select(d => new ListItem(d.WardName, d.WardId.ToString())).ToList();

                model.ListBusinessIndustry = GetListBusinessIndustry();
                model.ListMainProduct = GetListMainProduct(industryIds);
                model.ListEnterpriseType = _enterpriseTypeCache.GetAll()
                    .OrderBy(d => d.Name)
                    .Select(d => new ListItem(d.Name, d.EnterpriseTypeId.ToString())).ToList();
                model.ListEconomicSector = _economicSectorCache.GetAll()
                    .OrderBy(d => d.Name)
                    .Select(d => new ListItem(d.Name, d.EconomicSectorId.ToString())).ToList();
                model.ListEnterpriseStatus = _enterpriseStatusCache.GetAll()
                    .OrderBy(d => d.Name)
                    .Select(d => new ListItem(d.Name, d.EnterpriseStatusId.ToString())).ToList();

                model.ListTypeBusiness = Enum.GetValues(typeof(EnumTypeBusiness))
                    .Cast<EnumTypeBusiness>()
                    .Select(x => new ListItem(AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(x)),
                        ((int)x).ToString()))
                    .ToList();
                return PartialView("_Enterprise", model);
            }

            var enterpriseId = _enterpriseCache.Save(new CateEnterpriseModel
            {
                EnterpriseId = model.EnterpriseId,
                OwnerEnterpriseName = model.OwnerEnterpriseName,
                BusinessName = model.BusinessName,
                TaxCode = model.TaxCode,
                BusinessAddress = model.BusinessAddress,
                StreetName = model.StreetName,
                WardId = model.WardId,
                WardName = model.WardName,
                
                LegalRepresentationName = model.LegalRepresentationName,
                LegalRepresentationPhone = model.LegalRepresentationPhone,
                LegalRepresentationEmail = model.LegalRepresentationEmail,
                Website = model.Website,
                Phone = model.Phone,
                Email = model.Email,
                Reason = model.Reason,

                //MainIndustryId = model.MainIndustryId,
                TypeBusiness = model.ListTypeBusinessId != null && model.ListTypeBusinessId.Count > 0 ? string.Join(",", model.ListTypeBusinessId) : null,
                IndustryIds = model.ListIndustryId != null && model.ListIndustryId.Count > 0 ? string.Join(",", model.ListIndustryId) : null,
                EnterpriseTypeId = model.EnterpriseTypeId,
                EconomicSectorId = model.EconomicSectorId,
                EnterpriseStatusId = model.EnterpriseStatusId,
                CapacityMWp = model.CapacityMWp,
                CapacityMW = model.CapacityMW,

                SavedBy = User.Email
            });

            if (enterpriseId == -9)
            {
                var errMessage =
                    CreateMessage($"{AppProcessor.Messagor.GetMessage("Enterprise_Label_TaxCode")} [{model.TaxCode}]",
                        EnumProcessType.DataExisted, EnumMsgIcon.Error);
                return Json(new { status = true, message = errMessage });
            }

            // Chỉ lưu khi sản phẩm chính thay đổi => không xoá dòng cũ không hiển thị được (sản phẩm đã bị xoá)
            if (enterpriseId > 0 && model.MainProductId != GetMainProductId(enterpriseId) &&
                _enterpriseCache.SaveMainProduct(enterpriseId, model.MainProductId, User.Email) < 0)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{AppProcessor.Messagor.GetMessage("Enterprise_MainProduct")} [{model.BusinessName}]",
                        EnumProcessType.Edit, EnumMsgIcon.Error)
                });

            if (enterpriseId > 0)
            {
                var businessCetificatesId = SaveUploadFile(model);
                if (businessCetificatesId == -7)
                    return Json(new
                    {
                        status = true,
                        message = CreateMessage($"{_enterpriseTitle}",
                            EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                    });
            }

            var response = CreateMessage($"{_enterpriseTitle} [{model.OwnerEnterpriseName} - {model.BusinessName}]",
                EnumProcessType.Edit,
                enterpriseId > 0 ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = true, message = response }, JsonRequestBehavior.AllowGet);
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult Delete(int id = 0)
        {
            var model = _enterpriseCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            ViewBag.ConfirmMessage = string.Format(AppProcessor.Messagor.GetMessage("Common_ConfirmMessage"),
                $"<b>{_enterpriseTitle} [{model.OwnerEnterpriseName} - {model.BusinessName}]</b>");
            return PartialView("_Delete", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult Delete(CateEnterpriseModel model)
        {
            model.SavedBy = User.Email;
            var deleted = _enterpriseCache.Delete(model);

            var response = CreateMessage($"{_enterpriseTitle} [{model.OwnerEnterpriseName} - {model.BusinessName}]",
                EnumProcessType.Delete, deleted ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = true, message = response });
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult ChangeStatus(int id = 0)
        {
            var model = _enterpriseCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            ViewBag.ConfirmMessage = string.Format(
                AppProcessor.Messagor.GetMessage("Common_MessageConfirm_ChangeStatus"),
                $"<b>{_enterpriseTitle} [{model.OwnerEnterpriseName} - {model.BusinessName}]</b>");
            return PartialView("_ChangeStatus", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult ChangeStatus(CateEnterpriseModel model)
        {
            model.SavedBy = User.Email;
            var isSucess = _enterpriseCache.ChangeStatus(model);

            var response = CreateMessage($"{_enterpriseTitle} [{model.OwnerEnterpriseName} - {model.BusinessName}]",
                EnumProcessType.Edit, isSucess ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = true, message = response });
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult WardViaProvince(int provinceId = 0)
        {
            int total;
            var lstWardViaProvinces =
                _wardCache.GetByProvinceId(provinceId, out total).OrderBy(d => d.WardName).ToList();
            return Json(new { Wards = lstWardViaProvinces });
        }

        /// <summary>
        ///     Danh sách sản phẩm chính theo các ngành công nghiệp đang chọn (industryIds: "1,2,3")
        /// </summary>
        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult MainProductViaIndustries(string industryIds)
        {
            var products = GetListMainProduct(industryIds).Select(d => new { d.Value, d.Text }).ToList();
            return Json(new { Products = products });
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Review(int id = 0)
        {
            var model = _enterpriseCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            var provinceModel = _provinceCache.GetViaWard(model.WardId);
            model.ProvinceId = provinceModel?.ProvinceId;
            model.ProvinceName = provinceModel?.ProvinceName;

            model.ListProvinces = _provinceCache.GetAll()
                .OrderBy(d => d.ProvinceName)
                .Select(d => new ListItem(d.ProvinceName, d.ProvinceId.ToString())).ToList();
            model.ListWards = _wardCache.GetByProvinceId(model.ProvinceId).OrderBy(d => d.WardName)
                .Select(d => new ListItem(d.WardName, d.WardId.ToString())).ToList();

            if (model.ProvinceId != null)
            {
                int total;
                model.ListWards = _wardCache.GetByProvinceId(model.ProvinceId, out total)
                    .OrderBy(w => w.WardName)
                    .Select(d => new ListItem(d.WardName, d.WardId.ToString())).ToList();
            }

            model.ListBusinessIndustry = GetListBusinessIndustry();
            model.MainProductId = GetMainProductId(model.EnterpriseId);
            model.ListMainProduct = GetListMainProduct(model.IndustryIds);
            model.ListEnterpriseType = _enterpriseTypeCache.GetAll()
                .OrderBy(d => d.Name)
                .Select(d => new ListItem(d.Name, d.EnterpriseTypeId.ToString())).ToList();
            model.ListEconomicSector = _economicSectorCache.GetAll()
                .OrderBy(d => d.Name)
                .Select(d => new ListItem(d.Name, d.EconomicSectorId.ToString())).ToList();
            model.ListEnterpriseStatus = _enterpriseStatusCache.GetAll()
                .OrderBy(d => d.Name)
                .Select(d => new ListItem(d.Name, d.EnterpriseStatusId.ToString())).ToList();
            model.ListTypeBusiness = Enum.GetValues(typeof(EnumTypeBusiness))
                .Cast<EnumTypeBusiness>()
                .Select(x => new ListItem(AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(x)),
                    ((int)x).ToString()))
                .ToList();

            //_enterpriseRegisterNotifyCache.Save(new CateEnterpriseRegisterNotifyModel
            //{
            //    BusinessName = model.BusinessName,
            //    CompletedBy = User.UserName,
            //    EnterpriseID = model.EnterpriseId,
            //    HasProcessed = true,
            //    OwnerEnterpriseName = model.OwnerEnterpriseName,
            //    SaveBy = User.UserName
            //});

            return PartialView("_Review", model);
        }

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Delete)]
        public ActionResult Approve(int id = 0)
        {
            var model = _enterpriseCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            return PartialView("_Approve", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ValidateAntiForgeryToken]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Approve(CateEnterpriseModel model)
        {
            var existEnterpriseModel = _enterpriseCache.GetById(model.EnterpriseId);
            if (existEnterpriseModel == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            var isSucess = _enterpriseRegisterNotifyCache.Save(new CateEnterpriseRegisterNotifyModel
            {
                BusinessName = model.BusinessName,
                CompletedBy = User.UserName,
                EnterpriseID = model.EnterpriseId,
                HasProcessed = true,
                IsConfirm = model.IsConfirm,
                OwnerEnterpriseName = model.OwnerEnterpriseName,
                SaveBy = User.UserName
            }) > 0;

            var response = CreateMessage($"{_enterpriseTitle} [{model.OwnerEnterpriseName} - {model.BusinessName}]",
                EnumProcessType.Edit, isSucess ? EnumMsgIcon.Success : EnumMsgIcon.Error);
            return Json(new { status = true, message = response });
        }

        #endregion

        #region Import Data

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Add)]
        public ActionResult Import()
        {
            var model = new EnterpriseImportModel
            {
                ListTypeBusiness = Enum.GetValues(typeof(EnumTypeBusiness))
                    .Cast<EnumTypeBusiness>()
                    .Select(x => new ListItem(AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(x)),
                        ((int)x).ToString()))
                    .ToList()
            };

            return PartialView("_Import", model);
        }

        [HttpPost]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Import(EnterpriseImportModel model)
        {
            if (!ModelState.IsValid)
            {
                model.ListTypeBusiness = Enum.GetValues(typeof(EnumTypeBusiness))
                    .Cast<EnumTypeBusiness>()
                    .Select(x => new ListItem(AppProcessor.Messagor.GetMessage(EnumHelper.GetDescription(x)),
                        ((int)x).ToString()))
                    .ToList();
                return PartialView("_ImportView", model);
            }

            bool isSuccessImport;

            var dataImport = ProcessDataImport(model, out isSuccessImport);
            dataImport.Columns.RemoveAt(0);
            if (!isSuccessImport)
                return Json(new
                {
                    status = false,
                    message = CreateMessage(AppProcessor.Messagor.GetMessage("ImportData_Message_Failed"),
                        EnumProcessType.NonFormat, EnumMsgIcon.Error)
                });

            var importResult =
                _enterpriseCache.Import(model.TypeBusiness, model.TypeBusinessName, dataImport, User.UserName);

            if (importResult >= 1)
                return Json(new
                {
                    status = true,
                    message = CreateMessage(AppProcessor.Messagor.GetMessage("ImportData_Message_Successful"),
                        EnumProcessType.NonFormat, EnumMsgIcon.Success)
                });
            return Json(new
            {
                status = false,
                message = CreateMessage(AppProcessor.Messagor.GetMessage("ImportData_Message_Failed"),
                    EnumProcessType.NonFormat, EnumMsgIcon.Error)
            });
        }

        [HttpGet]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult DownloadTemplate()
        {
            #region Download Template

            var templateName = "Mẫu import Doanh Nghiệp.xlsx";
            var fullPathAttachDocsFolder = Server.MapPath(_pathTemplateFolder);

            var attachDocPath = Path.Combine(fullPathAttachDocsFolder, templateName);
            var arrBytes = System.IO.File.ReadAllBytes(attachDocPath);

            #endregion

            return File(arrBytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
                templateName);
        }

        #endregion

        #region Extend Function

        /// <summary>
        ///     Danh sách ngành công nghiệp, hiển thị dạng "Mã - Tên"
        /// </summary>
        private List<ListItem> GetListBusinessIndustry()
        {
            return _industryCache.GetAll()
                .OrderBy(d => d.IndustryCode, StringComparer.Ordinal)
                .Select(d => new ListItem(FormatCodeName(d.IndustryCode, d.IndustryName), d.IndustryId.ToString()))
                .ToList();
        }

        /// <summary>
        ///     Danh sách sản phẩm chính thuộc các ngành industryIds ("1,2,3"), hiển thị dạng "Mã - Tên"
        /// </summary>
        private List<ListItem> GetListMainProduct(string industryIds)
        {
            // Chỉ nhận IndustryId hợp lệ, bỏ trùng, sắp xếp => tham số procedure và key cache ổn định
            var ids = string.Join(",", SplitIds(industryIds).Distinct().OrderBy(id => id));
            return _businessProductCache.GetByIndustries(ids, MainProductLevel)
                .Select(d => new ListItem(FormatCodeName(d.ProductCode, d.ProductName), d.ProductId.ToString()))
                .ToList();
        }

        private int? GetMainProductId(int enterpriseId)
        {
            var mainProduct = _enterpriseCache.GetMainProduct(enterpriseId);
            return mainProduct != null && mainProduct.ProductId > 0 ? mainProduct.ProductId : (int?)null;
        }

        /// <summary>
        ///     Sản phẩm chính phải thuộc danh sách sản phẩm của các ngành đã chọn
        /// </summary>
        private void ValidateMainProduct(int? mainProductId, string industryIds)
        {
            if (!mainProductId.HasValue) return;
            var productId = mainProductId.Value.ToString();
            if (GetListMainProduct(industryIds).Any(d => d.Value == productId)) return;
            ModelState.AddModelError("MainProductId", "Sản phẩm chính không thuộc ngành công nghiệp đã chọn");
        }

        private static string FormatCodeName(string code, string name)
        {
            return string.IsNullOrWhiteSpace(code) ? name : $"{code} - {name}";
        }

        private static string JoinIds(IEnumerable<int?> ids)
        {
            return ids == null ? null : string.Join(",", ids.Where(id => id.HasValue));
        }

        private static List<int> SplitIds(string ids)
        {
            var result = new List<int>();
            if (string.IsNullOrEmpty(ids)) return result;
            foreach (var item in ids.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries))
            {
                int id;
                if (int.TryParse(item.Trim(), out id) && id > 0) result.Add(id);
            }
            return result;
        }

        private DataTable ProcessDataImport(EnterpriseImportModel model, out bool isSucess)
        {
            isSucess = true;

            #region Init Datatable

            var dataImport = new DataTable();

            dataImport.Columns.Add("Index");
            dataImport.Columns.Add("TaxCode");
            dataImport.Columns.Add("OwnerEnterpriseName");
            dataImport.Columns.Add("BusinessName");
            //
            dataImport.Columns.Add("TypeBusinessName");
            dataImport.Columns.Add("MainIndustryName");
            dataImport.Columns.Add("EconomicSectorName");
            dataImport.Columns.Add("EnterpriseTypeName");
            //
            dataImport.Columns.Add("BusinessAddress");
            dataImport.Columns.Add("StreetName");
            dataImport.Columns.Add("WardName");
            dataImport.Columns.Add("ProvinceName");
            dataImport.Columns.Add("Phone");
            dataImport.Columns.Add("Website");
            dataImport.Columns.Add("Email");
            dataImport.Columns.Add("LegalRepresentationName");
            dataImport.Columns.Add("LegalRepresentationPhone");
            dataImport.Columns.Add("LegalRepresentationEmail");

            #endregion

            try
            {
                var fileExtension = Path.GetExtension(model.FileImportData.FileName);

                if (fileExtension != ".xls" && fileExtension != ".xlsx") return null;
                var excelReader = fileExtension == ".xls"
                    ? ExcelReaderFactory.CreateBinaryReader(model.FileImportData.InputStream)
                    : ExcelReaderFactory.CreateOpenXmlReader(model.FileImportData.InputStream);

                var ds = excelReader.AsDataSet();

                var dt = ds.Tables[0];
                dt.Rows.RemoveAt(0); // Title Column
                dt.Rows.RemoveAt(0); // Title Column

                foreach (DataRow row in dt.Rows)
                    dataImport.Rows.Add(row.ItemArray.Length > dataImport.Columns.Count
                        ? row.ItemArray.ToList().Where((item, idx) => idx < dataImport.Columns.Count)
                            .Select(c => string.IsNullOrEmpty(c.ToString()) ? null : c).ToArray()
                        : row.ItemArray.Select(c => string.IsNullOrEmpty(c.ToString()) ? null : c).ToArray());

                return dataImport;
            }
            catch (Exception e)
            {
                AppProcessor.Logger.Error(e);
                isSucess = false;
                return dataImport;
            }
        }

        private int SaveUploadFile(CateEnterpriseModel model)
        {
            if (model.ListCertificateFiles == null || model.ListCertificateFiles.Count == 0 ||
                model.EnterpriseId <= 0) return -7;

            var lstDocs = new List<CateDocModel>();

            var moduleRefDocsPathFolder = string.Concat(_moduleRefDocsPathFolder, _enterpriseFolder, "/",
                model.EnterpriseId.ToString());
            var moduleRefDocsAbsolutePathFolder = Server.MapPath(moduleRefDocsPathFolder);

            if (!Directory.Exists(moduleRefDocsAbsolutePathFolder))
                Directory.CreateDirectory(moduleRefDocsAbsolutePathFolder);
            model.ListCertificateFiles.ForEach(f =>
            {
                if (f == null) return;
                var unionResolutionDoc = new CateDocModel
                {
                    FileId = Guid.NewGuid(),
                    FilePath = moduleRefDocsPathFolder,
                    FileName = Path.GetFileNameWithoutExtension(f.FileName),
                    FileExt = Path.GetExtension(f.FileName),
                    ContentType = f.ContentType
                };

                f.SaveAs(string.Concat(moduleRefDocsAbsolutePathFolder, "/",
                    unionResolutionDoc.FileId.ToString().ToUpper(), unionResolutionDoc.FileExt));
                lstDocs.Add(unionResolutionDoc);
            });
            if (lstDocs.Count <= 0) return 0;
            var regulationId = _enterpriseCache.SaveDocs(new CateEnterpriseModel
            {
                EnterpriseId = model.EnterpriseId,
                CertificateFiles = CreateDataRefDocs(lstDocs),
                Reason = model.Reason,
                SavedBy = User.Email
            });

            return regulationId;
        }

        private DataTable CreateDataRefDocs(List<CateDocModel> lstDocs)
        {
            var dataRefDocs = new DataTable();
            using (var reader =
                   ObjectReader.Create(lstDocs, "FileId", "FilePath", "FileName", "FileExt", "ContentType"))
            {
                dataRefDocs.Load(reader);
            }

            return dataRefDocs;
        }

        #endregion
    }
}