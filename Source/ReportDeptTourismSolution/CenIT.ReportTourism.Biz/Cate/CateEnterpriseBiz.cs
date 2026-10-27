using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using CenIT.ReportTourism.Models.Cate;
using CenIT.ReportTourism.Models.Search;
using TSFramework.App.Processors;

namespace CenIT.ReportTourism.Biz.Cate
{
    public class CateEnterpriseBiz
    {
        private const string DATA_PROVIDER_NAME = "SysProvider";
        private readonly string _cateEnterpriseDelete = "Cate_Enterprises_Delete";
        private readonly string _cateEnterpriseGet = "Cate_Enterprises_Get";
        private readonly string _cateEnterpriseGetById = "Cate_Enterprises_GetByID";
        private readonly string _cateEnterprisePermissionsDetele = "Cate_EnterprisePermissions_Detele";
        private readonly string _cateEnterprisePermissionsGet = "Cate_EnterprisePermissions_Get";
        private readonly string _cateEnterprisePermissionsSave = "Cate_EnterprisePermissions_Save";
        private readonly string _cateEnterpriseRegister = "Cate_Enterprises_Register";
        private readonly string _cateEnterpriseSave = "Cate_Enterprises_Save";
        private readonly string _cateEnterprisesChangeStatus = "Cate_Enterprises_ChangeStatus";
        private readonly string _cateEnterprisesGetNotSumitReportYet = "Cate_Enterprises_GetNotSumitReportYet";
        private readonly string _cateEnterprisesGetViaUser = "Cate_Enterprises_GetViaUser";
        private readonly string _cateEnterprisesImport = "Cate_Enterprises_Import";
        private readonly string _cateEnterprisesSaveDocs = "Cate_Enterprises_SaveDocs";
        private readonly string _cateEnterprisesSearch = "Cate_Enterprises_Search";
        private readonly string _cateEnterpriseMainProductGet = "Cate_BusinessEnterpriseProduct_GetMainProduct";
        private readonly string _cateEnterpriseMainProductSave = "Cate_BusinessEnterpriseProduct_SaveMainProduct";

        public List<CateEnterpriseModel> Get(out int total, SearchEnterpriseModel search)
        {
            search = search ?? new SearchEnterpriseModel
            {
                Search = null,
                Order = "1",
                OrderDir = "ASC",
                StartIndex = 0,
                PageSize = -1
            };
            var dataEnterprise = AppProcessor.ProcedureProvider.ExecuteTypedList<CateEnterpriseModel>(
                _cateEnterpriseGet, DATA_PROVIDER_NAME,
                search.ForUser, 
                search.TypeBusinessIds,
                search.WardIds,
                search.ProvinceIds,
                search.MainIndustryIds,
                search.EnterpriseTypeIds,
                search.EconomicSectorIds,
                search.StatusIds,
                //
                search.Search,
                search.Order,
                search.OrderDir,
                search.StartIndex,
                search.PageSize);
            total = 0;
            if (dataEnterprise != null && dataEnterprise.Count > 0)
                total = int.Parse(dataEnterprise.First().TotalRow.ToString());
            return dataEnterprise;
        }

        public List<CateEnterpriseModel> GetAll(SearchEnterpriseModel search = null)
        {
            int total;
            var listenterprises = Get(out total, search);
            return listenterprises;
        }

        public List<CateEnterpriseModel> GetViaUser(string forUser)
        {
            var dataEnterprise =
                AppProcessor.ProcedureProvider.ExecuteTypedList<CateEnterpriseModel>(_cateEnterprisesGetViaUser,
                    DATA_PROVIDER_NAME, forUser);
            return dataEnterprise;
        }

        public List<CateEnterpriseModel> GetNotSumitReportYet(DateTime? forMonth)
        {
            var dataEnterprise =
                AppProcessor.ProcedureProvider.ExecuteTypedList<CateEnterpriseModel>(
                    _cateEnterprisesGetNotSumitReportYet, DATA_PROVIDER_NAME, forMonth);
            return dataEnterprise;
        }

        public CateEnterpriseModel GetById(int? enterpriseId)
        {
            var enterprise =
                AppProcessor.ProcedureProvider.ExecuteScalarObject<CateEnterpriseModel>(_cateEnterpriseGetById,
                    DATA_PROVIDER_NAME, enterpriseId);
            return enterprise;
        }

        public int Save(CateEnterpriseModel model)
        {
            var result = AppProcessor.ProcedureProvider.Execute(_cateEnterpriseSave, DATA_PROVIDER_NAME,
                model.EnterpriseId,
                model.OwnerEnterpriseName,
                model.BusinessName,
                model.TaxCode,
                model.BusinessAddress,
                model.StreetName,
                model.WardId,
                model.WardName,
                //model.TypeBusiness,
                //model.TypeBusinessName,
                model.IndustryIds,
                model.TypeBusiness,
                model.EnterpriseTypeId,
                model.EconomicSectorId,
                model.EnterpriseStatusId,
                model.CapacityMWp,
                model.CapacityMW,
                model.LegalRepresentationName,
                model.LegalRepresentationPhone,
                model.LegalRepresentationEmail,
                model.Website,
                model.Phone,
                model.Email,
                model.Reason,
                model.SavedBy
            );
            return result.GetValueOrDefault(0);
        }


        public CateBusinessProductModel GetMainProduct(int enterpriseId)
        {
            return AppProcessor.ProcedureProvider.ExecuteScalarObject<CateBusinessProductModel>(
                _cateEnterpriseMainProductGet, DATA_PROVIDER_NAME, enterpriseId);
        }

        /// <summary>
        ///     Lưu sản phẩm chính của doanh nghiệp (productId null => bỏ sản phẩm chính).
        ///     Trả về: productId (0 nếu bỏ sản phẩm chính), -3 sản phẩm không tồn tại, -1 lỗi
        /// </summary>
        public int SaveMainProduct(int enterpriseId, int? productId, string savedBy)
        {
            var result = AppProcessor.ProcedureProvider.Execute(_cateEnterpriseMainProductSave, DATA_PROVIDER_NAME,
                enterpriseId, productId, savedBy);
            return result.GetValueOrDefault(-1);
        }

        public int Register(CateEnterpriseModel model)
        {
            var result = AppProcessor.ProcedureProvider.Execute(_cateEnterpriseRegister, DATA_PROVIDER_NAME,
                model.EnterpriseId,
                model.OwnerEnterpriseName,
                model.BusinessName,
                model.TaxCode,
                model.BusinessAddress,
                model.StreetName,
                model.WardId,
                model.WardName,
                //model.TypeBusiness,
                //model.TypeBusinessName,
                //
                model.IndustryIds,
                model.TypeBusiness,
                model.EnterpriseTypeId,
                model.EconomicSectorId,
                model.EnterpriseStatusId,
                //
                model.LegalRepresentationName,
                model.LegalRepresentationPhone,
                model.LegalRepresentationEmail,
                model.Website,
                model.Phone,
                model.Email,
                model.Password,
                model.Salt,
                model.Reason,
                model.SavedBy
            );
            return result.GetValueOrDefault(0);
        }

        public int Import(int? typeBusiness, string typeBusinessName, DataTable dataImport, string importBy)
        {
            var result = AppProcessor.ProcedureProvider.Execute(_cateEnterprisesImport, DATA_PROVIDER_NAME,
                typeBusiness,
                typeBusinessName,
                dataImport,
                importBy
            );
            return result.GetValueOrDefault(0);
        }

        public int SaveDocs(CateEnterpriseModel model)
        {
            var result = AppProcessor.ProcedureProvider.Execute(_cateEnterprisesSaveDocs, DATA_PROVIDER_NAME,
                model.EnterpriseId,
                model.CertificateFiles,
                model.Reason,
                model.SavedBy
            );
            return result.GetValueOrDefault(0);
        }

        public bool Delete(CateEnterpriseModel model)
        {
            var result = AppProcessor.ProcedureProvider.Execute(_cateEnterpriseDelete, DATA_PROVIDER_NAME,
                model.EnterpriseId, model.Reason, model.SavedBy);
            return result == model.EnterpriseId;
        }

        public int SaveEnterprisePermissions(CateEnterprisePermissionsModel model)
        {
            var result = AppProcessor.ProcedureProvider.Execute(_cateEnterprisePermissionsSave, DATA_PROVIDER_NAME,
                //EString.SplitToTable(model.EnterpriseIds, new[] { ',' }),
                model.EnterpriseIds,
                model.ForUser);
            return result.GetValueOrDefault(0);
        }

        public List<CateEnterprisePermissionsModel> GetCateEnterprisePermissions(string userName)
        {
            var dataEnterprise = AppProcessor.ProcedureProvider.ExecuteTypedList<CateEnterprisePermissionsModel>(
                _cateEnterprisePermissionsGet, DATA_PROVIDER_NAME,
                userName);
            return dataEnterprise;
        }

        public void DeleteCateEnterprisePermissions(CateEnterprisePermissionsModel model)
        {
            var result = AppProcessor.ProcedureProvider.Execute(_cateEnterprisePermissionsDetele, DATA_PROVIDER_NAME,
                model.EnterpriseId, model.ForUser);
        }

        public bool ChangeStatus(CateEnterpriseModel model)
        {
            var result = AppProcessor.ProcedureProvider.Execute(_cateEnterprisesChangeStatus, DATA_PROVIDER_NAME,
                model.EnterpriseId, !model.IsActive, model.Reason, model.SavedBy);
            return result == model.EnterpriseId;
        }

        public List<CateEnterpriseModel> Search(string taxCode, string email, string businessName)
        {
            var dataEnterprises = AppProcessor.ProcedureProvider.ExecuteTypedList<CateEnterpriseModel>(
                _cateEnterprisesSearch, DATA_PROVIDER_NAME, taxCode, email, businessName);
            return dataEnterprises;
        }
    }
}