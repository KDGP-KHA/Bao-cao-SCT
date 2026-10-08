using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.IO;
using System.Linq;
using System.Web;
using System.Web.Mvc;
using System.Web.UI.WebControls;
using CenIT.ReportTourism.Caches.Cate;
using CenIT.ReportTourism.Biz.Report;
using CenIT.ReportTourism.Core.Apps;
using CenIT.ReportTourism.Core.Conts;
using CenIT.ReportTourism.Models.Cate;
using CenIT.ReportTourism.Modules.CateModule.Models;
using FastMember;
using TSFramework.App.Attributes;
using TSFramework.App.Processors;
using TSFramework.Core.Enums;
using TSFramework.Core.Helpers;

namespace CenIT.ReportTourism.Modules.CateModule.Controllers
{
    public class MyEnterpriseController : AppController
    {
        private ReportIndustryScope IndustryScope
        {
            get { return ReportIndustryScope.Current ?? ReportIndustryScope.Begin(User.UserName); }
        }

        // GET: MyEnterprise
        public ActionResult Index()
        {
            var searchModel = new MyEnterpiseSearchModel
            {
                ListEnterprises = IndustryScope.GetEnterprises()
                    .Select(e => new ListItem(e.BusinessName, e.EnterpriseId.ToString())).ToList()
            };
            return View(searchModel);
        }

        #region Enterprise


        private readonly CateEnterpriseCache _enterpriseCache = new CateEnterpriseCache();
        private readonly CateWardCache _wardCache = new CateWardCache();
        private readonly CateProvinceCache _provinceCache = new CateProvinceCache();
        private readonly CateBusinessIndustryCache _industryCache = new CateBusinessIndustryCache();
        private readonly CateEnterpriseTypeCache _enterpriseTypeCache = new CateEnterpriseTypeCache();
        private readonly CateEconomicSectorCache _economicSectorCache = new CateEconomicSectorCache();
        private readonly CateEnterpriseStatusCache _enterpriseStatusCache = new CateEnterpriseStatusCache();
        private readonly CateBusinessProductCache _businessProductCache = new CateBusinessProductCache();

        // Sản phẩm chính: chỉ chọn sản phẩm cấp 7 (Cate_BusinessProduct.IsLevel) thuộc các ngành của doanh nghiệp
        private const int MainProductLevel = 7;

        private readonly string _enterpriseFolder = "Enterprise";
        private readonly string _enterpriseTitle = AppProcessor.Messagor.GetMessage("Enterprise_Title");

        private readonly string _moduleRefDocsPathFolder =
            ConfigurationManager.AppSettings["AttachmentFolderPath"] ?? @"/Contents/Modules/Cate/Attachments/";

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Info(int id = 0)
        {
            IndustryScope.Demand(id);
            var model = _enterpriseCache.GetById(id);
            if (model == null)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });
            var provinceModel = _provinceCache.GetViaWard(model.WardId);
            model.ListProvinces = _provinceCache.GetAll()
                .OrderBy(d => d.ProvinceName)
                .Select(d => new ListItem(d.ProvinceName, d.ProvinceId.ToString()))
                .Distinct().ToList();

            model.ListWards = _wardCache.GetAll(provinceModel?.ProvinceId)
                .OrderBy(d => d.WardName)
                .Select(d => new ListItem(d.WardName, d.WardId.ToString()))
                .Distinct().ToList();

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

            if (provinceModel == null) return PartialView("_Info", model);
            model.ProvinceId = provinceModel.ProvinceId;
            model.ProvinceName = provinceModel.ProvinceName;
            return PartialView("_Info", model);
        }

        [AjaxOnly]
        [HttpPost]
        [ValidateAntiForgeryToken]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult Info(CateEnterpriseModel model)
        {
            IndustryScope.Demand(model.EnterpriseId);
            // Tạm thời bỏ ràng buộc bắt buộc nhập "Lý do"
            RemoveModelState("Reason");

            var current = _enterpriseCache.GetById(model.EnterpriseId);
            if (current == null || current.EnterpriseId <= 0)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{_enterpriseTitle}",
                        EnumProcessType.DataNotExist, EnumMsgIcon.Error)
                });

            // Trường bị disable (hoặc ẩn) ở view thì trình duyệt không gửi lên => giữ nguyên giá trị hiện tại.
            // Trường được gửi lên thì cập nhật bình thường => muốn cho doanh nghiệp sửa chỉ cần bỏ disabled ở view.
            KeepCurrentValuesIfNotPosted(model, current);

            // Dropdown "Sản phẩm chính" bị disable (không gửi lên) thì giữ nguyên, không lưu lại
            var isMainProductPosted = IsPosted("MainProductId");
            if (isMainProductPosted) ValidateMainProduct(model.MainProductId, model.IndustryIds);

            if (!ModelState.IsValid)
            {
                model.ListProvinces = _provinceCache.GetAll()
                    .OrderBy(d => d.ProvinceName)
                    .Select(d => new ListItem(d.ProvinceName, d.ProvinceId.ToString()))
                    .Distinct().ToList();

                model.ListWards = _wardCache.GetAll(model.ProvinceId)
                    .OrderBy(d => d.WardName)
                    .Select(d => new ListItem(d.WardName, d.WardId.ToString()))
                    .Distinct().ToList();

                model.ListBusinessIndustry = GetListBusinessIndustry();
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
                return PartialView("_Info", model);
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

                //TypeBusiness = model.TypeBusiness,
                //TypeBusinessName = model.TypeBusinessName,
                
                LegalRepresentationName = model.LegalRepresentationName,
                LegalRepresentationPhone = model.LegalRepresentationPhone,
                LegalRepresentationEmail = model.LegalRepresentationEmail,
                Website = model.Website,
                Phone = model.Phone,
                Email = model.Email,
                Reason = model.Reason,

                TypeBusiness = model.ListTypeBusinessId != null && model.ListTypeBusinessId.Count > 0 ? string.Join(",", model.ListTypeBusinessId) : null,
                IndustryIds = model.ListIndustryId != null && model.ListIndustryId.Count > 0 ? string.Join(",", model.ListIndustryId) : null,
                EnterpriseTypeId = model.EnterpriseTypeId,
                EconomicSectorId = model.EconomicSectorId,
                EnterpriseStatusId = model.EnterpriseStatusId,

                SavedBy = User.Email
            });

            if (enterpriseId == -9)
            {
                var errMessage =
                    CreateMessage($"{_enterpriseTitle} [{model.TaxCode} - {model.BusinessName}]",
                        EnumProcessType.DataExisted, EnumMsgIcon.Error);
                return Json(new { status = true, message = errMessage });
            }

            // Chỉ lưu khi sản phẩm chính thay đổi => không xoá dòng cũ không hiển thị được (sản phẩm đã bị xoá)
            if (enterpriseId > 0 && isMainProductPosted && model.MainProductId != GetMainProductId(enterpriseId) &&
                _enterpriseCache.SaveMainProduct(enterpriseId, model.MainProductId, User.Email) < 0)
                return Json(new
                {
                    status = true,
                    message = CreateMessage($"{AppProcessor.Messagor.GetMessage("Enterprise_MainProduct")} [{model.BusinessName}]",
                        EnumProcessType.Edit, EnumMsgIcon.Error)
                });

            if (enterpriseId > 0 && model.ListCertificateFiles != null && model.ListCertificateFiles.Count > 0)
            {
                var businessCetificatesId = SaveUploadFile(model.EnterpriseId, model.ListCertificateFiles,
                    _enterpriseFolder, model.Reason);
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

        /// <summary>
        ///     Trường không có trong dữ liệu gửi lên (input bị disabled/ẩn ở view) thì lấy lại giá trị hiện tại
        ///     và bỏ qua validate của trường đó; trường có gửi lên thì giữ nguyên giá trị người dùng nhập
        /// </summary>
        private void KeepCurrentValuesIfNotPosted(CateEnterpriseModel model, CateEnterpriseModel current)
        {
            if (!IsPosted("OwnerEnterpriseName"))
            {
                RemoveModelState("OwnerEnterpriseName");
                model.OwnerEnterpriseName = current.OwnerEnterpriseName;
            }

            if (!IsPosted("BusinessName"))
            {
                RemoveModelState("BusinessName");
                model.BusinessName = current.BusinessName;
            }

            if (!IsPosted("TaxCode"))
            {
                RemoveModelState("TaxCode");
                model.TaxCode = current.TaxCode;
            }

            if (!IsPosted("EconomicSectorId"))
            {
                RemoveModelState("EconomicSectorId", "EconomicSectorName");
                model.EconomicSectorId = current.EconomicSectorId;
                model.EconomicSectorName = current.EconomicSectorName;
            }

            if (!IsPosted("EnterpriseTypeId"))
            {
                RemoveModelState("EnterpriseTypeId", "EnterpriseTypeName");
                model.EnterpriseTypeId = current.EnterpriseTypeId;
                model.EnterpriseTypeName = current.EnterpriseTypeName;
            }

            if (!IsPosted("EnterpriseStatusId"))
            {
                RemoveModelState("EnterpriseStatusId", "EnterpriseStatusName");
                model.EnterpriseStatusId = current.EnterpriseStatusId;
                model.EnterpriseStatusName = current.EnterpriseStatusName;
            }

            if (!IsPosted("BusinessAddress"))
            {
                RemoveModelState("BusinessAddress");
                model.BusinessAddress = current.BusinessAddress;
            }

            if (!IsPosted("StreetName"))
            {
                RemoveModelState("StreetName");
                model.StreetName = current.StreetName;
            }

            if (!IsPosted("WardId"))
            {
                RemoveModelState("WardId", "WardName");
                model.WardId = current.WardId;
                model.WardName = current.WardName;
            }

            // Tỉnh được xác định theo Xã/Phường khi lưu (SP), nên chỉ lấy lại để hiển thị/validate
            if (!IsPosted("ProvinceId"))
            {
                RemoveModelState("ProvinceId", "ProvinceName");
                var province = _provinceCache.GetViaWard(model.WardId);
                model.ProvinceId = province?.ProvinceId ?? current.ProvinceId;
                model.ProvinceName = province?.ProvinceName ?? current.ProvinceName;
            }

            // Lưu ý: multi-select không chọn giá trị nào cũng không được gửi lên => được giữ nguyên giá trị hiện tại
            RemoveModelState("IndustryIds");
            if (!IsPosted("ListIndustryId"))
            {
                RemoveModelState("ListIndustryId");
                model.ListIndustryId = SplitIds(current.IndustryIds).Select(id => (int?)id).ToList();
            }
            model.IndustryIds = model.ListIndustryId != null && model.ListIndustryId.Count > 0
                ? string.Join(",", model.ListIndustryId)
                : null;

            RemoveModelState("TypeBusiness");
            if (!IsPosted("ListTypeBusinessId"))
            {
                RemoveModelState("ListTypeBusinessId");
                model.ListTypeBusinessId = SplitIds(current.TypeBusiness);
            }
            model.TypeBusiness = model.ListTypeBusinessId != null && model.ListTypeBusinessId.Count > 0
                ? string.Join(",", model.ListTypeBusinessId)
                : null;

            if (!IsPosted("MainProductId"))
            {
                RemoveModelState("MainProductId");
                model.MainProductId = GetMainProductId(current.EnterpriseId);
            }
        }

        private bool IsPosted(string key)
        {
            return Request.Form[key] != null;
        }

        private void RemoveModelState(params string[] propertyNames)
        {
            foreach (var propertyName in propertyNames)
            {
                var keys = ModelState.Keys.Where(k => k == propertyName
                                                      || k.StartsWith(propertyName + "[")
                                                      || k.StartsWith(propertyName + ".")).ToList();
                foreach (var key in keys) ModelState.Remove(key);
            }
        }

        private static List<int> SplitIds(string ids)
        {
            var result = new List<int>();
            if (string.IsNullOrEmpty(ids)) return result;
            foreach (var item in ids.Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries))
            {
                int id;
                if (int.TryParse(item.Trim(), out id)) result.Add(id);
            }
            return result;
        }

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
            var ids = string.Join(",", SplitIds(industryIds).Where(id => id > 0).Distinct().OrderBy(id => id));
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

        //[AjaxOnly]
        //[HttpGet]
        //[ActionType(Type = EnumActionType.Edit)]
        //public ActionResult TypeBusinessInfo(int id = 0)
        //{
        //    var model = _enterpriseCache.GetById(id);
        //    if (model == null)
        //        return Json(new
        //        {
        //            status = true,
        //            message = CreateMessage($"{_enterpriseTitle}",
        //                EnumProcessType.DataNotExist, EnumMsgIcon.Error)
        //        });
        //    switch ((EnumTypeBusiness)model.TypeBusiness)
        //    {
        //        case EnumTypeBusiness.Accommodation:
        //            {
        //                return RedirectToAction("Info", "Accommodation",
        //                    new
        //                    {
        //                        enterpriseId = id
        //                    });
        //            }

        //        case EnumTypeBusiness.ServicesForTourists:
        //            {
        //                return RedirectToAction("Info", "ServicesForTourist",
        //                    new
        //                    {
        //                        enterpriseId = id
        //                    });
        //            }

        //        case EnumTypeBusiness.TouristAttraction:
        //            {
        //                return RedirectToAction("Info", "TouristAttraction",
        //                    new
        //                    {
        //                        enterpriseId = id
        //                    });
        //            }

        //        case EnumTypeBusiness.TransportTourists:
        //            {
        //                return RedirectToAction("Info", "TransportTourists",
        //                    new
        //                    {
        //                        enterpriseId = id
        //                    });
        //            }

        //        case EnumTypeBusiness.Traveling:
        //            {
        //                return RedirectToAction("Info", "Traveling",
        //                    new
        //                    {
        //                        enterpriseId = id
        //                    });
        //            }

        //        default:
        //            return RedirectToAction("Info", "Accommodation",
        //                new
        //                {
        //                    enterpriseId = id
        //                });
        //    }
        //}

        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.View)]
        public ActionResult WardViaProvince(int provinceId = 0)
        {
            int total;

            var lstWardViaProvinces = _wardCache.GetByProvinceId(provinceId, out total).OrderBy(d => d.ProvinceName).ToList();
            return Json(new { Wards = lstWardViaProvinces });
        }

        /// <summary>
        ///     Danh sách sản phẩm chính theo các ngành công nghiệp đang chọn (industryIds: "1,2,3")
        /// </summary>
        [AjaxOnly]
        [HttpGet]
        [ActionType(Type = EnumActionType.Edit)]
        public ActionResult MainProductViaIndustries(string industryIds)
        {
            var products = GetListMainProduct(industryIds).Select(d => new { d.Value, d.Text }).ToList();
            return Json(new { Products = products });
        }

        #endregion

        #region Extend Function

        //private int SaveUploadFile(CateEnterpriseModel model)
        private int SaveUploadFile(int enterpriseId, List<HttpPostedFileBase> lstFiles, string moduleFolderPath,
            string sReason)
        {
            if (lstFiles == null || lstFiles.Count == 0 || enterpriseId <= 0) return -7;

            var lstDocs = new List<CateDocModel>();

            var moduleRefDocsPathFolder =
                string.Concat(_moduleRefDocsPathFolder, moduleFolderPath, "/", enterpriseId.ToString());
            var moduleRefDocsAbsolutePathFolder = Server.MapPath(moduleRefDocsPathFolder);

            if (!Directory.Exists(moduleRefDocsAbsolutePathFolder))
                Directory.CreateDirectory(moduleRefDocsAbsolutePathFolder);
            lstFiles.ForEach(f =>
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
                EnterpriseId = enterpriseId,
                CertificateFiles = CreateDataRefDocs(lstDocs),
                Reason = sReason,
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