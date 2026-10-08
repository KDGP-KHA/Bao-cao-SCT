SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @Messages TABLE
(
    LabelKey nvarchar(100) NOT NULL PRIMARY KEY,
    [Message] nvarchar(max) NOT NULL
);

INSERT INTO @Messages (LabelKey, [Message]) VALUES
    (N'Dashboard_Showing', N'Hiển thị'),
    (N'Dashboard_SharesAllRows', N'Tỷ trọng tính trên tất cả các nhóm.'),
    (N'Dashboard_Breakdown', N'Cơ cấu'),
    (N'Dashboard_CoverageRate', N'Tỷ lệ DN có dữ liệu'),
    (N'Dashboard_ChartMode', N'Chế độ biểu đồ'),
    (N'Dashboard_CompleteThreeMetrics', N'Đủ 3 chỉ tiêu'),
    (N'Dashboard_CompleteMetrics', N'Đủ chỉ tiêu'),
    (N'Dashboard_FileLate', N'Tệp trễ'),
    (N'Dashboard_AllTypes', N'(mọi loại)'),
    (N'Dashboard_FilesAllTypes', N'Có tệp (mọi loại)'),
    (N'Dashboard_FileAnyTypeLabel', N'Tệp (mọi loại)'),
    (N'Dashboard_RateMode', N'Tỷ lệ %'),
    (N'Dashboard_EnterpriseFileCount', N'Số doanh nghiệp / tệp'),
    (N'Dashboard_EnterpriseCount', N'Số doanh nghiệp'),
    (N'Dashboard_CoverageTotal', N'Tỷ lệ / tổng DN'),
    (N'Dashboard_DataErrors', N'Lỗi dữ liệu'),
    (N'Dashboard_Reason', N'Giải trình'),
    (N'Dashboard_View', N'Xem'),
    (N'Dashboard_Retry', N'Thử lại'),
    (N'Dashboard_ProgressLoadFailed', N'Không tải được danh sách doanh nghiệp. Đang hiển thị kết quả của lần tải thành công gần nhất.'),
    (N'Dashboard_OutsideRegistry', N'Ngoài danh mục'),
    (N'Dashboard_IndustryScope', N'Ngành được phân quyền'),
    (N'Dashboard_ObservedEnterprises', N'DN có số liệu'),
    (N'Dashboard_Sector', N'Thành phần'),
    (N'Dashboard_NoEnterprisesOnPage', N'Trang này không có doanh nghiệp.'),
    (N'Dashboard_FirstPage', N'Về trang đầu'),
    (N'Dashboard_NoDeclineWarning', N'Không có cảnh báo giảm >10%.'),
    (N'Dashboard_WarningPagination', N'Phân trang doanh nghiệp cảnh báo'),
    (N'Dashboard_First', N'Đầu'),
    (N'Dashboard_Previous', N'Trước'),
    (N'Dashboard_Next', N'Sau'),
    (N'Dashboard_Last', N'Cuối'),
    (N'Dashboard_FullList', N'Xem danh sách đầy đủ'),
    (N'Dashboard_SkipFilters', N'Bỏ qua bộ lọc, đến nội dung báo cáo'),
    (N'Dashboard_ReportNavigation', N'Điều hướng báo cáo'),
    (N'Dashboard_Close', N'Đóng'),
    (N'Dashboard_EnterpriseIndicators', N'Chi tiết chỉ tiêu doanh nghiệp'),
    (N'Dashboard_Reset', N'Đặt lại'),
    (N'Dashboard_DataLabel', N'Số liệu'),
    (N'Dashboard_Months', N'tháng'),
    (N'Dashboard_DeclineTen', N'giảm >10%'),
    (N'Dashboard_InsufficientPeriod', N'Chưa đủ kỳ'),
    (N'Dashboard_DecliningEnterprises', N'doanh nghiệp giảm trên 10%'),
    (N'Dashboard_Page', N'Trang'),
    (N'Dashboard_NoEnterpriseIndicators', N'Chưa có dữ liệu chỉ tiêu cho doanh nghiệp, loại báo cáo và kỳ đã chọn.'),
    (N'Dashboard_RawValuesNote', N'Giá trị và đơn vị gốc do doanh nghiệp báo cáo. Các trường kỳ trước / kế hoạch là số khai báo, không thay thế dữ liệu lịch sử đã kiểm chứng.'),
    (N'Dashboard_Code', N'Mã'),
    (N'Dashboard_RawUnit', N'Đơn vị gốc'),
    (N'Dashboard_InPeriod', N'Trong kỳ'),
    (N'Dashboard_DeclaredPrevious', N'Kỳ trước khai báo'),
    (N'Dashboard_DeclaredAnnualPlan', N'Kế hoạch năm khai báo'),
    (N'Dashboard_IndustryGrantNote', N'Quyền ngành áp dụng cho toàn bộ doanh nghiệp có ít nhất một ngành được cấp; nhãn và chỉ tiêu có thể gồm các ngành khác của doanh nghiệp.'),
    -- Header / Navigation
    (N'Dashboard_Overview_Title', N'Tổng quan'),
    (N'Dashboard_Analysis_Title', N'Phân tích'),
    (N'Dashboard_Warnings_Title', N'Cảnh báo'),
    (N'Dashboard_Progress_Title', N'Tiến độ'),

    (N'Dashboard_Nav_Overview', N'Tổng quan'),
    (N'Dashboard_Nav_Warnings', N'Cảnh báo'),

    -- Report types
    (N'Dashboard_Type_Manufacturing', N'Sản xuất'),
    (N'Dashboard_Type_Trading', N'Thương mại'),
    (N'Dashboard_Type_ExportImport', N'Xuất nhập khẩu'),

    -- Metrics
    (N'Dashboard_Metric_IndustrialRevenue', N'Doanh thu CN'),
    (N'Dashboard_Metric_ExportValue', N'Xuất khẩu'),
    (N'Dashboard_Metric_ImportValue', N'Nhập khẩu'),
    (N'Dashboard_Metric_WholesaleRetailRevenue', N'Bán buôn, bán lẻ'),
    (N'Dashboard_Metric_VehicleRepairRevenue', N'Sửa chữa xe'),
    (N'Dashboard_Metric_RetailSubset', N'Bán lẻ'),
    (N'Dashboard_Metric_FobValue', N'Xuất khẩu FOB'),
    (N'Dashboard_Metric_DirectExport', N'Xuất khẩu trực tiếp'),
    (N'Dashboard_Metric_EntrustedExport', N'Xuất khẩu ủy thác'),

    -- Units
    (N'Dashboard_Unit_BillionVnd', N'Tỷ đồng'),
    (N'Dashboard_Unit_ThousandUsd', N'Nghìn USD'),
    (N'Dashboard_Unit_MillionVnd', N'Triệu đồng'),
    (N'Dashboard_Unit_Usd', N'USD'),

    -- Filters
    (N'Dashboard_Filter_Period', N'Kỳ'),
    (N'Dashboard_Filter_Year', N'Năm'),
    (N'Dashboard_Filter_ReportType', N'Báo cáo'),
    (N'Dashboard_Filter_Metric', N'Chỉ tiêu'),
    (N'Dashboard_Filter_Advanced', N'Bộ lọc'),
    (N'Dashboard_Filter_ActiveCount', N'Bộ lọc đang áp dụng'),
    (N'Dashboard_Filter_Apply', N'Áp dụng'),
    (N'Dashboard_Filter_Ward', N'Phường / xã'),
    (N'Dashboard_Filter_EconomicSector', N'Khu vực'),
    (N'Dashboard_Filter_Industry', N'Ngành'),
    (N'Dashboard_Filter_IndustryNote', N'Lọc theo mã ngành doanh nghiệp.'),
    (N'Dashboard_Filter_AllIndustries', N'Tất cả'),
    (N'Dashboard_Filter_IndustryCode', N'Mã ngành'),
    (N'Dashboard_Filter_AllAreas', N'Tất cả'),
    (N'Dashboard_Filter_AllSectors', N'Tất cả'),
    (N'Dashboard_Filter_AllEnterprises', N'Tất cả'),

    -- Common
    (N'Dashboard_UnknownArea', N'Chưa xác định'),
    (N'Dashboard_UnknownSector', N'Chưa xác định'),
    (N'Dashboard_Month', N'Tháng'),
    (N'Dashboard_Months12', N'12 tháng'),
    (N'Dashboard_Enterprise', N'Doanh nghiệp'),
    (N'Dashboard_Enterprises', N'DN'),
    (N'Dashboard_Area', N'Địa bàn'),
    (N'Dashboard_Value', N'Giá trị'),
    (N'Dashboard_Change', N'Biến động'),
    (N'Dashboard_Rate', N'Tỷ lệ'),
    (N'Dashboard_PreviousPeriod', N'Kỳ trước'),
    (N'Dashboard_CurrentPeriod', N'Kỳ này'),

    -- Chart
    (N'Dashboard_ChartValues', N'Xem số liệu'),
    (N'Dashboard_ChartEmpty', N'Chưa có dữ liệu.'),
    (N'Dashboard_ChartType1', N'Sản xuất'),
    (N'Dashboard_ChartType2', N'Thương mại'),
    (N'Dashboard_ChartType3', N'Xuất nhập khẩu'),
    (N'Dashboard_ChartDecliningEnterprises', N'Doanh nghiệp giảm'),
    (N'Dashboard_ChartReceived', N'Có dữ liệu'),

    -- Overview
    (N'Dashboard_Overview_Subtitle', N'Tổng hợp theo loại báo cáo'),
    (N'Dashboard_Overview_Type', N'Loại'),
    (N'Dashboard_Overview_AnalyzeReport', N'Phân tích'),
    (N'Dashboard_Overview_ReceivedAnalyze', N'DN đã nhập'),
    (N'Dashboard_Overview_ReceivedTitle', N'DN đã nhập'),
    (N'Dashboard_Overview_TrendSubtitle', N'12 tháng'),
    (N'Dashboard_Overview_TrendAria', N'Xu hướng dữ liệu 12 tháng'),
    (N'Dashboard_Overview_Classification', N'Cần phân loại'),
    (N'Dashboard_Overview_ProvinceWide', N'Toàn tỉnh'),
    (N'Dashboard_Overview_NeedsClassification', N'DN'),
    (N'Dashboard_Overview_MissingBusiness', N'Thiếu hồ sơ'),
    (N'Dashboard_Overview_MissingIndustry', N'Thiếu ngành'),
    (N'Dashboard_Overview_MissingReportType', N'Thiếu loại báo cáo'),
    (N'Dashboard_Overview_ClassificationNote', N'Các nhóm có thể trùng nhau.'),
    (N'Dashboard_Overview_LargestChanges', N'Biến động'),
    (N'Dashboard_Overview_ViewAnalysis', N'Xem chi tiết'),
    (N'Dashboard_Overview_NoComparison', N'Chưa đủ kỳ so sánh.'),
    (N'Dashboard_Overview_ChangeSize', N'Mức độ'),
    (N'Dashboard_Overview_ReceiptNote', N'Dữ liệu nhập không đồng nghĩa đã nộp báo cáo.'),
    (N'Dashboard_Overview_FutureRows', N'Kỳ tương lai:'),

    -- Analysis
    (N'Dashboard_Analysis_CurrentPeriodCode', N'Kỳ hiện tại'),
    (N'Dashboard_Analysis_Mom', N'So tháng trước'),
    (N'Dashboard_Analysis_Yoy', N'So cùng kỳ'),
    (N'Dashboard_Analysis_ComparedCoverage', N'DN so sánh'),
    (N'Dashboard_Analysis_YtdTitle', N'Lũy kế'),
    (N'Dashboard_Analysis_YtdNote', N'tháng có dữ liệu'),
    (N'Dashboard_Analysis_Trend', N'Xu hướng'),
    (N'Dashboard_Analysis_TrendAria', N'Xu hướng 12 tháng'),
    (N'Dashboard_Analysis_TrendNote', N'Tháng chưa có dữ liệu để trống.'),
    (N'Dashboard_Analysis_NoData', N'Chưa có dữ liệu'),
    (N'Dashboard_Analysis_SectorTitle', N'Theo khu vực'),
    (N'Dashboard_Analysis_Share', N'Tỷ trọng'),
    (N'Dashboard_Analysis_NoSectorValue', N'Chưa có số liệu.'),
    (N'Dashboard_Analysis_LargestEnterpriseChanges', N'Biến động'),
    (N'Dashboard_Analysis_ComparableGroup', N'Đủ 2 kỳ'),
    (N'Dashboard_Analysis_NoComparison', N'Chưa đủ dữ liệu.'),
    (N'Dashboard_Analysis_ComparisonNote', N'MoM/YoY chỉ tính doanh nghiệp có đủ hai kỳ.'),

    -- Warnings
    (N'Dashboard_Warnings_Decline10', N'Giảm >10%'),
    (N'Dashboard_Warnings_Decline20', N'Giảm >20%'),
    (N'Dashboard_Warnings_Decline30', N'Giảm >30%'),
    (N'Dashboard_Warnings_LargestChange', N'Biến động lớn nhất'),
    (N'Dashboard_Warnings_DecliningEnterprises', N'DN giảm'),
    (N'Dashboard_Warnings_InLargestList', N'trong nhóm biến động lớn'),
    (N'Dashboard_Warnings_Trend', N'Xu hướng giảm'),
    (N'Dashboard_Warnings_DeclineOver10', N'Giảm >10%'),
    (N'Dashboard_Warnings_DeclineMom', N'Giảm so tháng trước'),
    (N'Dashboard_Warnings_TrendAria', N'Xu hướng doanh nghiệp giảm'),
    (N'Dashboard_Warnings_NoPairs', N'Chưa đủ dữ liệu'),
    (N'Dashboard_Warnings_Comparable', N'Có thể so sánh'),
    (N'Dashboard_Warnings_Conflict', N'Cần đối chiếu'),
    (N'Dashboard_Warnings_ConflictDescription', N'doanh nghiệp có mã trùng'),
    (N'Dashboard_Warnings_DeclineList', N'Giảm >10%'),
    (N'Dashboard_Warnings_ChangeList', N'Biến động theo doanh nghiệp'),
    (N'Dashboard_Warnings_NoChanges', N'Chưa có dữ liệu phù hợp.'),
    (N'Dashboard_Warnings_Note', N'Biến động chỉ mang tính cảnh báo dữ liệu.'),

    -- Progress
    (N'Dashboard_Progress_CurrentClassification', N'theo phân loại hiện tại'),
    (N'Dashboard_Progress_ReceivedAssigned', N'Có dữ liệu / được phân loại'),
    (N'Dashboard_Progress_ObservedRatio', N'Tỷ lệ'),
    (N'Dashboard_Progress_PrimaryValues', N'Có chỉ tiêu chính'),
    (N'Dashboard_Progress_IncludingZero', N'Gồm giá trị 0'),
    (N'Dashboard_Progress_Duplicates', N'Mã trùng'),
    (N'Dashboard_Progress_NeedsReview', N'doanh nghiệp cần đối chiếu'),
    (N'Dashboard_Progress_FileAnyType', N'Có tệp'),
    (N'Dashboard_Progress_FileNote', N'Không đồng nghĩa đã nộp báo cáo'),
    (N'Dashboard_Progress_ReceiptTrend', N'Dữ liệu theo tháng'),
    (N'Dashboard_Progress_TrendAria', N'Xu hướng dữ liệu theo tháng'),
    (N'Dashboard_Progress_ReceivedEnterprise', N'DN đã nhập'),
    (N'Dashboard_Progress_MetricPresence', N'Độ phủ'),
    (N'Dashboard_Progress_MetricNote', N'Giá trị 0 vẫn được tính là có dữ liệu.'),
    (N'Dashboard_Progress_ReceivedAssignedShort', N'Đã nhập / tổng DN'),
    (N'Dashboard_Progress_NoAssigned', N'Không có DN.'),
    (N'Dashboard_Progress_ByArea', N'Theo địa bàn'),
    (N'Dashboard_Progress_Worklist', N'Doanh nghiệp'),
    (N'Dashboard_Progress_TypeData', N'Trạng thái'),
    (N'Dashboard_Progress_MissingCodes', N'Thiếu chỉ tiêu'),
    (N'Dashboard_Progress_DuplicateData', N'Dữ liệu trùng'),
    (N'Dashboard_Progress_HasData', N'Đã nhập'),
    (N'Dashboard_Progress_NoData', N'Chưa nhập'),
    (N'Dashboard_Progress_ThreeValues', N'Đủ'),
    (N'Dashboard_Progress_Review', N'Cần đối chiếu'),
    (N'Dashboard_Progress_First50', N'Hiển thị 50 doanh nghiệp đầu.'),
    (N'Dashboard_Progress_Note', N'Tỷ lệ phản ánh dữ liệu đã nhập, không phải tỷ lệ nộp báo cáo.');

-- UPDATE existing labels as well
-- Existing/customized message values are preserved.
INSERT INTO dbo.Sys_Messages (LangCode, LabelKey, [Message])
SELECT N'vi-VN', seed.LabelKey, seed.[Message]
FROM @Messages seed
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.Sys_Messages existing
    WHERE existing.LangCode = N'vi-VN'
      AND existing.LabelKey = seed.LabelKey
);

COMMIT TRANSACTION;