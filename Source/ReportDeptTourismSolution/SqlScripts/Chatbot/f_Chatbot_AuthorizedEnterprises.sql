-- Both Web and Chatbot use the canonical enterprise authorization primitive.
CREATE FUNCTION dbo.f_Chatbot_AuthorizedEnterprises(@UserId int,@ProvinceRoleIds varchar(500),@EnterpriseRoleIds varchar(500),@AllowProvince bit)
RETURNS TABLE AS RETURN (
 SELECT e.EnterpriseId FROM dbo.Sys_Users actor
 CROSS APPLY dbo.f_Chatbot_UserScope(@UserId,@ProvinceRoleIds,@EnterpriseRoleIds) validated
 CROSS APPLY dbo.f_Report_IndustryEnterprises(actor.UserName) e
 WHERE actor.UserId=@UserId
 AND (@AllowProvince=1 OR (e.IsApproved=1 AND EXISTS(
 SELECT 1 FROM dbo.Cate_EnterprisePermissions p WHERE p.ForUser=actor.UserName AND p.EnterpriseId=e.EnterpriseId)))
);
