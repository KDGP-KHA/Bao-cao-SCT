# Complete SQL scope inventory

Authoritative generated inventory: **53 procedures, 8 functions**. Counts exclude CREATE stubs and repeated verifier text. Every source definition matches a distinct bundle definition. Database labels resolve through generated target names in sql-object-manifest.json. Existing/create state requires DB metadata; CREATE-if-missing does not prove an object is new.

| SP | DB / schema | Operation | Scope / assignments | Caller evidence | Decision |
|---|---|---|---|---|---|
| p_Report_IndustryPermissions_Save | Category.dbo | ADMINISTRATION | administrative role/action checks / none | UserController.IndustryPermissions (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.SysModule/Areas/Sys/Controllers/UserController.cs:67) | KEEP |
| p_Report_IndustryPermissions_Get | Category.dbo | READ/operational (see caller matrix) | administrative role/action checks / none | UserController.LoadIndustryPermissions (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.SysModule/Areas/Sys/Controllers/UserController.cs:126) | KEEP |
| p_Report_IndustryPermissions_Scope | Report.dbo | READ/operational (see caller matrix) | canonical / via function | ReportIndustryScope.Begin (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportIndustryScope.cs:27) | KEEP |
| p_Report_IndustryPermissions_Enterprises | Report.dbo | READ/operational (see caller matrix) | canonical / via function | ReportIndustryScope.GetEnterprises (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportIndustryScope.cs:44) | KEEP |
| p_Report_Dashboard_FilterOptions_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:76)<br>ReportDashboardBiz.GetFilterOptions (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDashboardBiz.cs:404) | CHANGE |
| p_Report_Dashboard_IndustrialSnapshot_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:74)<br>ChatbotAnalytics.Read (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:160)<br>ReportDashboardBiz.GetRows (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDashboardBiz.cs:269) | CHANGE |
| p_Report_Dashboard_OverviewSummary_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:75)<br>ChatbotAnalytics.Execute (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43)<br>ReportDashboardBiz.Breakdown (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDashboardBiz.cs:391)<br>ReportDashboardBiz.GetSummary (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDashboardBiz.cs:250) | CHANGE |
| p_Report_Dashboard_ProgressDetails_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:77)<br>ChatbotTools.RegistryTool (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326)<br>ReportDashboardBiz.ReadDetails (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDashboardBiz.cs:455) | CHANGE |
| p_Report_Dashboard_StatisticEnterprise_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | CHANGE |
| p_Report_Dashboard_StatisticIncome_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_Dashboard_StatisticMapVisitor_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_Dashboard_StatisticTypeBusiness_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | CHANGE |
| p_Report_Dashboard_StatisticVisitor_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_DataImports_GenerateSaleOfTourism_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | delegated/none / none | ReportGenerateSaleBiz.GetGenerateSaleOnMonth (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportGenerateSaleBiz.cs:16) | KEEP |
| p_Report_DataImports_Get_IndustryScope | Report.dbo | READ/operational (see caller matrix) | canonical / explicit | ReportDataImportBiz.Get (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:36) | CHANGE |
| p_Report_DataImports_GetDataImport_IndustryScope | Report.dbo | READ/operational (see caller matrix) | canonical / via function | DashboardController.EnterpriseDetail (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/DashboardController.cs:92)<br>ReportDataImportBiz.GetViaEnterpriseOnMonth (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:68) | KEEP |
| p_Report_DataImports_GetForUserOnMonth_IndustryScope | Report.dbo | READ/operational (see caller matrix) | canonical / explicit | ReportDataImportBiz.GetForUserOnMonth (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:52) | CHANGE |
| p_Report_DataImports_GetViaEnterpriseOnMonth_IndustryScope | Report.dbo | READ/operational (see caller matrix) | canonical / via function | Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:20 | KEEP |
| p_Report_GenerateSaleOfTourism_ByCode_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_GenerateSaleOfTourism_Sum_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_GenerateSaleOfTourism_SumAmount_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_GenerateSaleOfTourism_SumPercentForAVG_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_GenerateSaleOfTourism_SumPercentForOther_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_Industry_Enterprises_SearchSelect2 | Report.dbo | READ/operational (see caller matrix) | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_Reports_01_UocKetQuaHoatDongKinhDoanh_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | delegated/none / none | Source/ReportDeptTourismSolution/CenIT.ReportTourism.Reports.UocKetQuaHoatDongKinhDoanh/_01UocKetQuaHoatDongKinhDoanh.cs:34 | KEEP |
| p_Report_Reports_02_ThongKeQuocTichKhachDuLich_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Source/ReportDeptTourismSolution/CenIT.ReportTourism.Reports.ThongKeQuocTichKhachDuLich/_02ThongKeQuocTichKhachDuLich.cs:41 | KEEP |
| p_Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_ThongKe_CongSuatPhong_TrungBinh_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_ThongKe_TongDoanhThu_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_ThongKe_TongKhachDuLich_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope | Report.dbo | STATISTICS/REPORT/EXPORT | canonical / via function | Indirect SQL / mapping below | KEEP |
| p_Report_DataImports_OperationalScope | Report.dbo | READ/operational (see caller matrix) | operational (no industry restriction) / via function | ReportDataImportScope.Begin (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportScope.cs:28) | CHANGE |
| p_Report_DataImports_Get_Operational | Report.dbo | READ/operational (see caller matrix) | operational (no industry restriction) / explicit | ReportDataImportBiz.Get (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:36) | CHANGE |
| p_Report_DataImports_GetDataImport_Operational | Report.dbo | READ/operational (see caller matrix) | operational (no industry restriction) / via function | DashboardController.EnterpriseDetail (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/DashboardController.cs:92)<br>ReportDataImportBiz.GetViaEnterpriseOnMonth (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:68) | CHANGE |
| p_Report_DataImports_GetViaEnterpriseOnMonth_Operational | Report.dbo | READ/operational (see caller matrix) | operational (no industry restriction) / via function | Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:20 | CHANGE |
| p_Report_DataImports_GetForUserOnMonth_Operational | Report.dbo | READ/operational (see caller matrix) | operational (no industry restriction) / explicit | ReportDataImportBiz.GetForUserOnMonth (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:52) | CHANGE |
| p_Report_DataImports_Enterprises_SearchSelect2 | Report.dbo | READ/operational (see caller matrix) | operational (no industry restriction) / via function | ImportController.SearchEnterprisesSelect2 (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:172) | CHANGE |
| p_Report_DataImports_CheckOwnership | Report.dbo | VALIDATION (write-set ownership, read-only) | operational (no industry restriction) / via function | ReportDataImportScope.DemandWrite (Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportScope.cs:59) | CHANGE |
| p_Cate_Chatbot_EnterpriseProducts | Category.dbo | CHATBOT | canonical / via function | ChatbotAccess.Products (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:66) | KEEP |
| p_Cate_Chatbot_EnterpriseScope | Category.dbo | CHATBOT | canonical / via function | ChatbotAccess.Assigned (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:57)<br>ChatbotAccess.Category (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:51)<br>ChatbotAccess.Enterprise (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:63) | KEEP |
| p_Report_Chatbot_FilterOptions | Report.dbo | CHATBOT | canonical / via function | ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:71)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:74)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:75)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:76)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:77)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:78)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:79)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:81) | CHANGE |
| p_Report_Chatbot_IndicatorData | Report.dbo | CHATBOT | canonical / via function | ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:78)<br>ChatbotQueries.Execute (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74) | KEEP |
| p_Report_Chatbot_Metadata | Report.dbo | CHATBOT | canonical / via function | ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:78)<br>ChatbotQueries.Execute (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51) | KEEP |
| p_Report_Chatbot_ProgressDetails | Report.dbo | CHATBOT | canonical / via function | ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:71)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:74)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:75)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:76)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:77)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:78)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:79)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:81) | KEEP |
| p_Report_Chatbot_ReportFiles | Report.dbo | CHATBOT | canonical / via function | ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:78)<br>ChatbotQueries.Execute (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70) | KEEP |
| p_Report_Chatbot_Snapshot | Report.dbo | CHATBOT | canonical / via function | ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:71)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:74)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:75)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:76)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:77)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:78)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:79)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:81) | KEEP |
| p_Report_Chatbot_Summary | Report.dbo | CHATBOT | canonical / via function | ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:71)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:74)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:75)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:76)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:77)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:78)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:79)<br>ChatbotAccess.Report (Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:81) | KEEP |

## p_Report_IndustryPermissions_Save
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/01_CategoryPermissions.sql:64`; bundle `Deploy_SCT_All.sql:735`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: True; accepts: IndustryIds, SavedBy, UserId.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.CateModule/App_Data/Modules/Cate_StoredProcedures.xml`: `Report_IndustryPermissions_Save`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Cate_StoredProcedures.xml`: `Report_IndustryPermissions_Save`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.SysModule/Areas/Sys/Controllers/UserController.cs:67
- Calls: none; functions: none.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_IndustryPermissions_Get
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/01_CategoryPermissions.sql:109`; bundle `Deploy_SCT_All.sql:780`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: RequestedBy, UserId.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.CateModule/App_Data/Modules/Cate_StoredProcedures.xml`: `Report_IndustryPermissions_Get`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Cate_StoredProcedures.xml`: `Report_IndustryPermissions_Get`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.SysModule/Areas/Sys/Controllers/UserController.cs:126
- Calls: none; functions: none.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_IndustryPermissions_Scope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/02_ReportScope.sql:17`; bundle `Deploy_SCT_All.sql:824`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: UserName.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_IndustryPermissions_Scope`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_IndustryPermissions_Scope`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportIndustryScope.cs:27; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/IndustryScopedReportController.cs:16 (OnActionExecuting)
- Calls: none; functions: f_Report_IndustryUserScope.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_IndustryPermissions_Enterprises
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/02_ReportScope.sql:21`; bundle `Deploy_SCT_All.sql:828`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: UserName.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_IndustryPermissions_Enterprises`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_IndustryPermissions_Enterprises`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportIndustryScope.cs:44; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.CateModule/Controllers/MyEnterpriseController.cs:36 (Index)
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Dashboard_FilterOptions_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:5`; bundle `Deploy_SCT_All.sql:836`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Dashboard_FilterOptions`; persisted writes: False; accepts: IndustryUserName, OptionKind, Page, PageSize, Search, TypeReport.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_FilterOptions` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_FilterOptions` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_FilterOptions_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_FilterOptions_IndustryScope` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDashboardBiz.cs:404; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:76; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDashboardCache.cs:71 (GetEnterpriseOptions); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/DashboardController.cs:81 (EnterpriseOptions); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:160 (Read); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:255 (ReportedReasons); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:302 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:356 (ResolveDashboardOption); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:77 (ExecuteScoped)
- Calls: none; functions: f_Report_IndustryEnterprises, f_Report_IndustryUserScope.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Dashboard_IndustrialSnapshot_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:76`; bundle `Deploy_SCT_All.sql:907`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Dashboard_IndustrialSnapshot`; persisted writes: False; accepts: EconomicSectorId, EnterpriseId, ForMonth, IndustryId, IndustryUserName, TypeReport, WardId.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_IndustrialSnapshot` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_IndustrialSnapshot` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_IndustrialSnapshot_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_IndustrialSnapshot_IndustryScope` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDashboardBiz.cs:14; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:74; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:19; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:160 (Read); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:77 (ExecuteScoped)
- Calls: none; functions: f_Report_IndustryEnterprises, f_Report_IndustryUserScope.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Dashboard_OverviewSummary_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:182`; bundle `Deploy_SCT_All.sql:1013`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Dashboard_OverviewSummary`; persisted writes: False; accepts: EconomicSectorId, EnterpriseId, ForMonth, GroupBy, IndustryId, IndustryUserName, WardId.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_OverviewSummary` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_OverviewSummary` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_OverviewSummary_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_OverviewSummary_IndustryScope` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDashboardBiz.cs:15; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:75; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:160 (Read); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:77 (ExecuteScoped)
- Calls: none; functions: f_Report_IndustryEnterprises, f_Report_IndustryUserScope.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Dashboard_ProgressDetails_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:267`; bundle `Deploy_SCT_All.sql:1098`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Dashboard_ProgressDetails`; persisted writes: False; accepts: EconomicSectorId, EnterpriseId, ForMonth, IndustryId, IndustryUserName, Page, PageSize, Search, Status, TypeReport, WardId.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_ProgressDetails` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_ProgressDetails` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_ProgressDetails_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_ProgressDetails_IndustryScope` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDashboardBiz.cs:455; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:77; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:160 (Read); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:77 (ExecuteScoped)
- Calls: none; functions: f_Report_IndustryEnterprises, f_Report_IndustryUserScope.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Dashboard_StatisticEnterprise_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:393`; bundle `Deploy_SCT_All.sql:1224`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Dashboard_StatisticEnterprise`; persisted writes: False; accepts: IndustryUserName, OnMonth.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticEnterprise` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticEnterprise` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticEnterprise_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticEnterprise_IndustryScope` + server-selected scope suffix
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises, f_Report_IndustryUserScope.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Dashboard_StatisticIncome_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:467`; bundle `Deploy_SCT_All.sql:1298`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Dashboard_StatisticIncome`; persisted writes: False; accepts: IndustryUserName, OnMonth, TypeStatistic.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticIncome` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticIncome` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticIncome_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticIncome_IndustryScope` + server-selected scope suffix
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Dashboard_StatisticMapVisitor_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:614`; bundle `Deploy_SCT_All.sql:1445`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Dashboard_StatisticMapVisitor`; persisted writes: False; accepts: IndustryUserName, OnMonth.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticMapVisitor` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticMapVisitor` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticMapVisitor_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticMapVisitor_IndustryScope` + server-selected scope suffix
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Dashboard_StatisticTypeBusiness_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:650`; bundle `Deploy_SCT_All.sql:1481`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Dashboard_StatisticTypeBusiness`; persisted writes: False; accepts: IndustryUserName, OnMonth.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticTypeBusiness` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticTypeBusiness` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticTypeBusiness_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticTypeBusiness_IndustryScope` + server-selected scope suffix
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises, f_Report_IndustryUserScope.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Dashboard_StatisticVisitor_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:719`; bundle `Deploy_SCT_All.sql:1550`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Dashboard_StatisticVisitor`; persisted writes: False; accepts: IndustryUserName, OnMonth.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticVisitor` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticVisitor` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticVisitor_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Dashboard_StatisticVisitor_IndustryScope` + server-selected scope suffix
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_DataImports_GenerateSaleOfTourism_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:766`; bundle `Deploy_SCT_All.sql:1597`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_DataImports_GenerateSaleOfTourism`; persisted writes: False; accepts: ForMonth, IndustryUserName.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GenerateSaleOfTourism` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GenerateSaleOfTourism` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GenerateSaleOfTourism_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GenerateSaleOfTourism_IndustryScope` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportGenerateSaleBiz.cs:11; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportGeneratSaleCache.cs:22 (GetGenerateSaleOnMonth); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportGeneratSaleCache.cs:28 (GetGenerateSaleOnMonth)
- Calls: p_Report_GenerateSaleOfTourism_ByCode_IndustryScope, p_Report_GenerateSaleOfTourism_SumAmount_IndustryScope, p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope, p_Report_GenerateSaleOfTourism_SumPercentForAVG_IndustryScope, p_Report_GenerateSaleOfTourism_SumPercentForOther_IndustryScope, p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope, p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope, p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope, p_Report_GenerateSaleOfTourism_Sum_IndustryScope; functions: none.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_DataImports_Get_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:849`; bundle `Deploy_SCT_All.sql:1680`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_DataImports_Get`; persisted writes: False; accepts: EnterpriseIds, ForEmp, FromMonth, IndustryUserName, Order, OrderDir, PageIndex, PageSize, Search, ToMonth, TypeBusinessIds.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_Get` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_Get` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_Get_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_Get_IndustryScope` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:15; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDataImportCache.cs:25 (Get); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDataImportCache.cs:38 (Get); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:232 (Get); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:173 (ReportTool)
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_DataImports_GetDataImport_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:1005`; bundle `Deploy_SCT_All.sql:1836`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_DataImports_GetDataImport`; persisted writes: False; accepts: EnterpriseId, ForMonth, IndustryUserName.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetDataImport` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetDataImport` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetDataImport_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetDataImport_IndustryScope` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:16; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/DashboardController.cs:92; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDataImportCache.cs:75 (GetViaEnterpriseOnMonth); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDataImportCache.cs:81 (GetViaEnterpriseOnMonth); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:1140 (View); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:1221 (GetDataImport); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:1694 (Edit); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:1830 (Edit); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:2376 (LoadViewTypeReport); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:2452 (LoadTradingReport); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:2490 (LoadTradingReport); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:262 (DownloadSignedDoc); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:3992 (EnsureTradingDynamicCodes); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:125 (ReportTool)
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_DataImports_GetForUserOnMonth_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:1060`; bundle `Deploy_SCT_All.sql:1891`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_DataImports_GetForUserOnMonth`; persisted writes: False; accepts: ForUser, IndustryUserName, OnMonth.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetForUserOnMonth` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetForUserOnMonth` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetForUserOnMonth_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetForUserOnMonth_IndustryScope` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:17; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDataImportCache.cs:47 (GetForUserOnMonth); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDataImportCache.cs:53 (GetForUserOnMonth); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:129 (Index); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:318 (DownloadTemplate); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:375 (ViewAction); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:424 (ImportData); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:473 (UploadData); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:642 (UploadData); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:145 (ReportTool)
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_DataImports_GetViaEnterpriseOnMonth_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:1129`; bundle `Deploy_SCT_All.sql:1960`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_DataImports_GetViaEnterpriseOnMonth`; persisted writes: False; accepts: EnterpriseId, ForMonth, IndustryUserName.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetViaEnterpriseOnMonth` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetViaEnterpriseOnMonth` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetViaEnterpriseOnMonth_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetViaEnterpriseOnMonth_IndustryScope` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:20
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_GenerateSaleOfTourism_ByCode_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:1198`; bundle `Deploy_SCT_All.sql:1613`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_GenerateSaleOfTourism_ByCode`; persisted writes: False; accepts: Code, ForMonth, IndustryUserName, Level, Title.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_GenerateSaleOfTourism_Sum_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:1279`; bundle `Deploy_SCT_All.sql:1612`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_GenerateSaleOfTourism_Sum`; persisted writes: False; accepts: Code1, Code2, Code3, ForMonth, IndustryUserName, Level, Title.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_GenerateSaleOfTourism_SumAmount_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:1368`; bundle `Deploy_SCT_All.sql:1631`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_GenerateSaleOfTourism_SumAmount`; persisted writes: False; accepts: Code, ForMonth, IndustryUserName, Level, Title, Unit.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:1489`; bundle `Deploy_SCT_All.sql:1671`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_GenerateSaleOfTourism_SumCustomer`; persisted writes: False; accepts: Code1, Code2, Code3, ForMonth, IndustryUserName, Level, Title.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_GenerateSaleOfTourism_SumPercentForAVG_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:1545`; bundle `Deploy_SCT_All.sql:1623`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_GenerateSaleOfTourism_SumPercentForAVG`; persisted writes: False; accepts: ForMonth, IndustryUserName, Level, Title, Unit.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_GenerateSaleOfTourism_SumPercentForOther_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:1715`; bundle `Deploy_SCT_All.sql:1629`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_GenerateSaleOfTourism_SumPercentForOther`; persisted writes: False; accepts: ForMonth, IndustryUserName, Level, Title, Unit.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_GenerateSaleOfTourism_SumPercentForStart_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:1893`; bundle `Deploy_SCT_All.sql:1624`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_GenerateSaleOfTourism_SumPercentForStart`; persisted writes: False; accepts: Class, ForMonth, IndustryUserName, Level, Title, Unit.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:2056`; bundle `Deploy_SCT_All.sql:1674`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_GenerateSaleOfTourism_SumRevenue`; persisted writes: False; accepts: Code1, Code2, ForMonth, IndustryUserName, Level, Title, Unit.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:2201`; bundle `Deploy_SCT_All.sql:1646`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_GenerateSaleOfTourism_SumViaShip`; persisted writes: False; accepts: ForMonth, IndustryUserName, Level, Title.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryExtendInfos.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Industry_Enterprises_SearchSelect2
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:2278`; bundle `Deploy_SCT_All.sql:3109`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: IndustryUserName, Keyword, PageIndex, PageSize, TypeBusiness.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Industry_Enterprises_SearchSelect2`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Industry_Enterprises_SearchSelect2`
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Reports_01_UocKetQuaHoatDongKinhDoanh_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:2303`; bundle `Deploy_SCT_All.sql:3134`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Reports_01_UocKetQuaHoatDongKinhDoanh`; persisted writes: False; accepts: ForMonth, IndustryUserName.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_01_UocKetQuaHoatDongKinhDoanh` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_01_UocKetQuaHoatDongKinhDoanh` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_01_UocKetQuaHoatDongKinhDoanh_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_01_UocKetQuaHoatDongKinhDoanh_IndustryScope` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Reports.UocKetQuaHoatDongKinhDoanh/_01UocKetQuaHoatDongKinhDoanh.cs:34
- Calls: p_Report_GenerateSaleOfTourism_SumCustomer_IndustryScope, p_Report_GenerateSaleOfTourism_SumRevenue_IndustryScope, p_Report_GenerateSaleOfTourism_SumViaShip_IndustryScope, p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope, p_Report_ThongKe_CongSuatPhong_TrungBinh_IndustryScope, p_Report_ThongKe_TongDoanhThu_IndustryScope, p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope, p_Report_ThongKe_TongKhachDuLich_IndustryScope; functions: none.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Reports_02_ThongKeQuocTichKhachDuLich_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:2531`; bundle `Deploy_SCT_All.sql:3362`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Reports_02_ThongKeQuocTichKhachDuLich`; persisted writes: False; accepts: ForMonth, IndustryUserName.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_02_ThongKeQuocTichKhachDuLich` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_02_ThongKeQuocTichKhachDuLich` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_02_ThongKeQuocTichKhachDuLich_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_02_ThongKeQuocTichKhachDuLich_IndustryScope` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Reports.ThongKeQuocTichKhachDuLich/_02ThongKeQuocTichKhachDuLich.cs:41
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:2709`; bundle `Deploy_SCT_All.sql:3540`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Reports_03_DoanhNghiepChuaGuiBaoCao`; persisted writes: False; accepts: ForMonth, IndustryUserName.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_03_DoanhNghiepChuaGuiBaoCao` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_03_DoanhNghiepChuaGuiBaoCao` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_03_DoanhNghiepChuaGuiBaoCao_IndustryScope` + server-selected scope suffix
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:2758`; bundle `Deploy_SCT_All.sql:3589`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_Reports_04_BaoCaoHoatDongDoanhNghiep`; persisted writes: False; accepts: EnterpriseId, ForMonth, IndustryUserName.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_04_BaoCaoHoatDongDoanhNghiep` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_04_BaoCaoHoatDongDoanhNghiep` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Reports_04_BaoCaoHoatDongDoanhNghiep_IndustryScope` + server-selected scope suffix
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_ThongKe_CongSuatPhong_ByStar_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:2816`; bundle `Deploy_SCT_All.sql:3199`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_ThongKe_CongSuatPhong_ByStar`; persisted writes: False; accepts: BaseListCodes, Class, ForMonth, IndustryUserName, Level, SellListCodes, Title, Unit.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_ThongKe_CongSuatPhong_TrungBinh_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:3020`; bundle `Deploy_SCT_All.sql:3197`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_ThongKe_CongSuatPhong_TrungBinh`; persisted writes: False; accepts: BaseListCodes, ForMonth, IndustryUserName, Level, SellListCodes, Title, Unit.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_ThongKe_TongDoanhThu_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:3204`; bundle `Deploy_SCT_All.sql:3212`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_ThongKe_TongDoanhThu`; persisted writes: False; accepts: ForMonth, IndustryUserName, Level, ListCodes, Title, Unit.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_ThongKe_TongKhachDuLich_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:3346`; bundle `Deploy_SCT_All.sql:3181`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_ThongKe_TongKhachDuLich`; persisted writes: False; accepts: ForMonth, IndustryUserName, Level, ListCodes, Title, TypeReports, Unit.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_ThongKe_TongKhachDuLich_ByCode_IndustryScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/03_ScopedReportProcedures.sql:3459`; bundle `Deploy_SCT_All.sql:3183`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_ThongKe_TongKhachDuLich_ByCode`; persisted writes: False; accepts: ForMonth, IndustryUserName, Level, ListCodes, Title, TypeReports, Unit.
- XML: 
- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.
- Calls: none; functions: f_Report_IndustryEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_DataImports_OperationalScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/06_DataImportOperations.sql:38`; bundle `Deploy_SCT_All.sql:4431`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: ForUser.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_OperationalScope`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_OperationalScope`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportScope.cs:28; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:51 (OnActionExecuting)
- Calls: none; functions: f_Report_DataImportEnterprises.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_DataImports_Get_Operational
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/06_DataImportOperations.sql:57`; bundle `Deploy_SCT_All.sql:4450`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_DataImports_Get`; persisted writes: False; accepts: EnterpriseIds, ForEmp, FromMonth, IndustryUserName, Order, OrderDir, PageIndex, PageSize, Search, ToMonth, TypeBusinessIds.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_Get` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_Get` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_Get_Operational` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_Get_Operational` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:15; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDataImportCache.cs:25 (Get); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDataImportCache.cs:38 (Get); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:232 (Get); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:173 (ReportTool)
- Calls: none; functions: f_Report_DataImportEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_DataImports_GetDataImport_Operational
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/06_DataImportOperations.sql:213`; bundle `Deploy_SCT_All.sql:4606`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_DataImports_GetDataImport`; persisted writes: False; accepts: EnterpriseId, ForMonth, IndustryUserName.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetDataImport` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetDataImport` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetDataImport_Operational` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetDataImport_Operational` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:16; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/DashboardController.cs:92; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDataImportCache.cs:75 (GetViaEnterpriseOnMonth); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDataImportCache.cs:81 (GetViaEnterpriseOnMonth); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:1140 (View); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:1221 (GetDataImport); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:1694 (Edit); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:1830 (Edit); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:2376 (LoadViewTypeReport); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:2452 (LoadTradingReport); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:2490 (LoadTradingReport); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:262 (DownloadSignedDoc); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:3992 (EnsureTradingDynamicCodes); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:125 (ReportTool)
- Calls: none; functions: f_Report_DataImportEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_DataImports_GetViaEnterpriseOnMonth_Operational
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/06_DataImportOperations.sql:268`; bundle `Deploy_SCT_All.sql:4661`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_DataImports_GetViaEnterpriseOnMonth`; persisted writes: False; accepts: EnterpriseId, ForMonth, IndustryUserName.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetViaEnterpriseOnMonth` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetViaEnterpriseOnMonth` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetViaEnterpriseOnMonth_Operational` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetViaEnterpriseOnMonth_Operational` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:20
- Calls: none; functions: f_Report_DataImportEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_DataImports_GetForUserOnMonth_Operational
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/06_DataImportOperations.sql:337`; bundle `Deploy_SCT_All.sql:4730`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `p_Report_DataImports_GetForUserOnMonth`; persisted writes: False; accepts: ForUser, IndustryUserName, OnMonth.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetForUserOnMonth` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetForUserOnMonth` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetForUserOnMonth_Operational` + server-selected scope suffix; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_GetForUserOnMonth_Operational` + server-selected scope suffix
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs:17; Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDataImportCache.cs:47 (GetForUserOnMonth); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Caches/Report/ReportDataImportCache.cs:53 (GetForUserOnMonth); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:129 (Index); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:318 (DownloadTemplate); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:375 (ViewAction); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:424 (ImportData); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:473 (UploadData); Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:642 (UploadData); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:145 (ReportTool)
- Calls: none; functions: f_Report_DataImportEnterprises.
- Authorization change: Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_DataImports_Enterprises_SearchSelect2
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/06_DataImportOperations.sql:406`; bundle `Deploy_SCT_All.sql:4799`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: IndustryUserName, Keyword, PageIndex, PageSize, TypeBusiness.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_Enterprises_SearchSelect2`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_Enterprises_SearchSelect2`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs:172
- Calls: none; functions: f_Report_DataImportEnterprises.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_DataImports_CheckOwnership
- Source: `Source/ReportDeptTourismSolution/SqlScripts/2. New Report Permission/06_DataImportOperations.sql:433`; bundle `Deploy_SCT_All.sql:4825`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: EnterpriseId, ForMonth, Operation, TypeReport, UserName.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_CheckOwnership`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_DataImports_CheckOwnership`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.Biz/Report/ReportDataImportScope.cs:59
- Calls: none; functions: f_Report_DataImportEnterprises.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Cate_Chatbot_EnterpriseProducts
- Source: `Source/ReportDeptTourismSolution/SqlScripts/Chatbot/p_Cate_Chatbot_EnterpriseProducts.sql:3`; bundle `Deploy_SCT_All.sql:5018`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: ChatbotUserId, EnterpriseId, EnterpriseRoleIds, Limit, Offset, ProvinceRoleIds.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.CateModule/App_Data/Modules/Cate_StoredProcedures.xml`: `Cate_Chatbot_EnterpriseProducts`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Cate_StoredProcedures.xml`: `Cate_Chatbot_EnterpriseProducts`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:66; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:86 (Products); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:106 (EnterpriseTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:287 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:291 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:99 (EnterpriseTool)
- Calls: none; functions: f_Chatbot_AuthorizedEnterprises, f_Chatbot_UserScope.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Cate_Chatbot_EnterpriseScope
- Source: `Source/ReportDeptTourismSolution/SqlScripts/Chatbot/p_Cate_Chatbot_EnterpriseScope.sql:2`; bundle `Deploy_SCT_All.sql:4948`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: ChatbotUserId, EnterpriseId, EnterpriseRoleIds, Mode, ProvinceRoleIds.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.CateModule/App_Data/Modules/Cate_StoredProcedures.xml`: `Cate_Chatbot_EnterpriseScope`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Cate_StoredProcedures.xml`: `Cate_Chatbot_EnterpriseScope`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:51; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:57; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:63; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:284 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:93 (Assigned)
- Calls: none; functions: f_Chatbot_AuthorizedEnterprises, f_Chatbot_UserScope.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Chatbot_FilterOptions
- Source: `Source/ReportDeptTourismSolution/SqlScripts/Chatbot/p_Report_Chatbot_FilterOptions.sql:3`; bundle `Deploy_SCT_All.sql:5486`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: ChatbotUserId, EnterpriseRoleIds, OptionKind, Page, PageSize, ProvinceRoleIds, Search, TypeReport.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_FilterOptions`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_FilterOptions`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:76; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:160 (Read); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:77 (ExecuteScoped)
- Calls: none; functions: f_Chatbot_AuthorizedEnterprises, f_Chatbot_UserScope.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Chatbot_IndicatorData
- Source: `Source/ReportDeptTourismSolution/SqlScripts/Chatbot/p_Report_Chatbot_IndicatorData.sql:3`; bundle `Deploy_SCT_All.sql:5894`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: ChatbotUserId, Code, CodePrefix, EconomicSectorId, EnterpriseId, EnterpriseRoleIds, FromMonth, IndustryId, Limit, Offset, ProvinceRoleIds, Search, ToMonth, TypeReport, WardId.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_IndicatorData`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_IndicatorData`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:78; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:160 (Read); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:77 (ExecuteScoped)
- Calls: none; functions: f_Chatbot_AuthorizedEnterprises, f_Chatbot_UserScope.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Chatbot_Metadata
- Source: `Source/ReportDeptTourismSolution/SqlScripts/Chatbot/p_Report_Chatbot_Metadata.sql:2`; bundle `Deploy_SCT_All.sql:6014`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: ChatbotUserId, EnterpriseRoleIds, Kind, Limit, Offset, ProvinceRoleIds, Search, TypeReport.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_Metadata`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_Metadata`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:78; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:160 (Read); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:77 (ExecuteScoped)
- Calls: none; functions: f_Chatbot_AuthorizedEnterprises, f_Chatbot_UserScope.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Chatbot_ProgressDetails
- Source: `Source/ReportDeptTourismSolution/SqlScripts/Chatbot/p_Report_Chatbot_ProgressDetails.sql:3`; bundle `Deploy_SCT_All.sql:5638`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: ChatbotUserId, EconomicSectorId, EnterpriseId, EnterpriseRoleIds, ForMonth, IndustryId, Page, PageSize, ProvinceRoleIds, Search, Status, TypeReport, WardId.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_ProgressDetails`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_ProgressDetails`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:77; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:160 (Read); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:77 (ExecuteScoped)
- Calls: none; functions: f_Chatbot_AuthorizedEnterprises, f_Chatbot_UserScope.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Chatbot_ReportFiles
- Source: `Source/ReportDeptTourismSolution/SqlScripts/Chatbot/p_Report_Chatbot_ReportFiles.sql:2`; bundle `Deploy_SCT_All.sql:6126`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: ChatbotUserId, EnterpriseId, EnterpriseRoleIds, FromMonth, Limit, Offset, ProvinceRoleIds, ToMonth.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_ReportFiles`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_ReportFiles`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:78; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:160 (Read); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:77 (ExecuteScoped)
- Calls: none; functions: f_Chatbot_AuthorizedEnterprises, f_Chatbot_UserScope.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Chatbot_Snapshot
- Source: `Source/ReportDeptTourismSolution/SqlScripts/Chatbot/p_Report_Chatbot_Snapshot.sql:3`; bundle `Deploy_SCT_All.sql:5092`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: ChatbotUserId, EconomicSectorId, EnterpriseId, EnterpriseRoleIds, ForMonth, IndustryId, ProvinceRoleIds, TypeReport, WardId.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_Snapshot`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_Snapshot`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:74; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:160 (Read); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:77 (ExecuteScoped)
- Calls: none; functions: f_Chatbot_AuthorizedEnterprises, f_Chatbot_UserScope.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.

## p_Report_Chatbot_Summary
- Source: `Source/ReportDeptTourismSolution/SqlScripts/Chatbot/p_Report_Chatbot_Summary.sql:3`; bundle `Deploy_SCT_All.sql:5308`.
- Install: CREATE-if-missing/ALTER; existing DB state unverified; base: `none`; persisted writes: False; accepts: ChatbotUserId, EconomicSectorId, EnterpriseId, EnterpriseRoleIds, ForMonth, GroupBy, IndustryId, ProvinceRoleIds, WardId.
- XML: `Source/ReportDeptTourismSolution/CenIT.ReportTourism.Modules.ReportModule/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_Summary`; `Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/App_Data/Modules/Report_StoredProcedures.xml`: `Report_Chatbot_Summary`
- C#/controllers: Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAccess.cs:75; Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:160 (Read); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotAnalytics.cs:43 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:51 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:70 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotQueries.cs:74 (Execute); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:326 (RegistryTool); Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Chatbot/ChatbotTools.cs:77 (ExecuteScoped)
- Calls: none; functions: f_Chatbot_AuthorizedEnterprises, f_Chatbot_UserScope.
- Authorization change: New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.
- Intent: Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.
