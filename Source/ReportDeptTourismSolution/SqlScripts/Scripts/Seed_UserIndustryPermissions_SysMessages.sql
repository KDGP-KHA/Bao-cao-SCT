-- Run in the database selected by AppMessageTypeDataProvider (Sys_Messages).
-- Re-runnable; synchronizes the vi-VN labels used by the industry permission editor.
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRANSACTION;

DECLARE @Messages TABLE
(
    LabelKey nvarchar(100) NOT NULL PRIMARY KEY,
    [Message] nvarchar(max) NOT NULL
);
INSERT INTO @Messages (LabelKey, [Message]) VALUES
    (N'User_IndustryPermissions_Title', N'Phân quyền ngành báo cáo'),
    (N'User_IndustryPermissions_Industries', N'Ngành được phép xem'),
    (N'User_IndustryPermissions_ScopeHelp', N'Áp dụng cho dashboard, báo cáo và chatbot; vẫn giữ quyền chức năng và phân công doanh nghiệp.'),
    (N'User_IndustryPermissions_SelectionHelp', N'Giữ Ctrl hoặc Command để chọn nhiều ngành. Doanh nghiệp nhiều ngành chỉ tính một lần.'),
    (N'User_IndustryPermissions_RestoreWarning', N'Bỏ hết ngành sẽ khôi phục phạm vi trước đây, không chặn truy cập.'),
    (N'User_IndustryPermissions_RestoreConfirmation', N'Khôi phục phạm vi trước đây khi không chọn ngành.'),
    (N'User_IndustryPermissions_RestrictedHelp', N'Tài khoản giới hạn ngành không xem hoặc xuất thông tin bổ sung toàn tỉnh.'),
    (N'User_IndustryPermissions_InvalidSelection', N'Danh sách ngành không hợp lệ.'),
    (N'User_IndustryPermissions_InactiveSelection', N'Ngành không tồn tại hoặc đã ngừng hoạt động. Vui lòng bỏ chọn.'),
    (N'User_IndustryPermissions_RestoreRequired', N'Xác nhận khôi phục phạm vi trước đây khi bỏ hết ngành.'),
    (N'User_IndustryPermissions_DataChanged', N'Tài khoản hoặc ngành đã thay đổi. Đóng và mở lại biểu mẫu trước khi lưu.'),
    (N'User_IndustryPermissions_Saved', N'Đã lưu quyền ngành báo cáo.'),
    (N'User_IndustryPermissions_InactiveIndustry', N'(ngừng hoạt động; sẽ bỏ khi lưu)');

-- Existing/customized message values are preserved.
INSERT INTO dbo.Sys_Messages (LangCode, LabelKey, [Message])
SELECT N'vi-VN', seed.LabelKey, seed.[Message]
FROM @Messages seed
WHERE NOT EXISTS
(
    SELECT 1 FROM dbo.Sys_Messages existing WITH (UPDLOCK, HOLDLOCK)
    WHERE existing.LangCode = N'vi-VN' AND existing.LabelKey = seed.LabelKey
);

COMMIT TRANSACTION;
