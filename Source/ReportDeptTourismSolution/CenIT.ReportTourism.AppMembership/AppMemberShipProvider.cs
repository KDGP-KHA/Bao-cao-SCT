using System;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.Security;
using CenIT.ReportTourism.Caches.Sys;
using CenIT.ReportTourism.Models.Sys;
using TSFramework.App.Principals;

namespace CenIT.ReportTourism.AppMembership
{
    public class AppMemberShipProvider : MembershipProvider
    {
        private readonly SysUserCache _userApi;
        private readonly SysPermissionCache _permissionApi;

        public AppMemberShipProvider()
        {
            _userApi = new SysUserCache();
            _permissionApi = new SysPermissionCache();
        }

        public override bool EnablePasswordRetrieval { get; }
        public override bool EnablePasswordReset { get; }
        public override bool RequiresQuestionAndAnswer { get; }
        public override string ApplicationName { get; set; }
        public override int MaxInvalidPasswordAttempts { get; }
        public override int PasswordAttemptWindow { get; }
        public override bool RequiresUniqueEmail { get; }
        public override MembershipPasswordFormat PasswordFormat { get; }
        public override int MinRequiredPasswordLength { get; }
        public override int MinRequiredNonAlphanumericCharacters { get; }
        public override string PasswordStrengthRegularExpression { get; }

        public override MembershipUser CreateUser(string username, string password, string email,
            string passwordQuestion,
            string passwordAnswer, bool isApproved, object providerUserKey, out MembershipCreateStatus status)
        {
            var newUser = new SysUserModel
            {
                Email = email,
                IsActive = true,
                Password = password,
                UserName = username,
                CreatedDate = DateTime.Now
            };
            var userId = _userApi.Save(newUser, "SysProvider");
            status = MembershipCreateStatus.ProviderError;
            if (userId > 0)
                status = MembershipCreateStatus.Success;

            newUser.UserId = userId;
            return new AppMembershipUser(newUser);
        }

        public override bool ChangePasswordQuestionAndAnswer(string username, string password,
            string newPasswordQuestion,
            string newPasswordAnswer)
        {
            throw new NotImplementedException();
        }

        public override string GetPassword(string username, string answer)
        {
            throw new NotImplementedException();
        }

        public override bool ChangePassword(string username, string oldPassword, string newPassword)
        {
            throw new NotImplementedException();
        }

        public override string ResetPassword(string username, string answer)
        {
            throw new NotImplementedException();
        }

        public override void UpdateUser(MembershipUser user)
        {
            throw new NotImplementedException();
        }

        public override bool ValidateUser(string email, string password)
        {
            var userModel = _userApi.Login(email, password);
            if (userModel == null) return false;
            var user = (AppMembershipUser) GetUser(userModel.UserName, false);
            if (user == null || user.UserId.GetValueOrDefault() <= 0) return false;
            if (HttpContext.Current == null) return false;
            var loginUser = new AppPrincipalSerializeModel
            {
                UserId = user.UserId.Value,
                FullName = user.FullName,
                UserName = user.UserName,
                Email = user.Email,
                CreatedDate = user.CreationDate
            };

            var serializer = new JavaScriptSerializer();

            var userData = serializer.Serialize(loginUser);
            var authTicket = new FormsAuthenticationTicket(
                1,
                loginUser.UserName,
                DateTime.Now,
                DateTime.Now.AddMinutes(30),
                true,
                userData);

            var encTicket = FormsAuthentication.Encrypt(authTicket);
            var faCookie = new HttpCookie(FormsAuthentication.FormsCookieName, encTicket);
            HttpContext.Current.Response.Cookies.Add(faCookie);
            return true;
        }

        public override bool UnlockUser(string userName)
        {
            throw new NotImplementedException();
        }

        public override MembershipUser GetUser(object providerUserKey, bool userIsOnline)
        {
            throw new NotImplementedException();
        }

        public override MembershipUser GetUser(string email, bool userIsOnline)
        {
            var userOnline = _userApi.GetByUserName(email);
            return userOnline == null ? null : new AppMembershipUser(userOnline);
        }

        public override string GetUserNameByEmail(string email)
        {
            throw new NotImplementedException();
        }

        public override bool DeleteUser(string username, bool deleteAllRelatedData)
        {
            HttpContext.Current.Session.Clear();
            HttpContext.Current.Session.Abandon();
            FormsAuthentication.SignOut();
            return true;
        }

        public override MembershipUserCollection GetAllUsers(int pageIndex, int pageSize, out int totalRecords)
        {
            throw new NotImplementedException();
        }

        public override int GetNumberOfUsersOnline()
        {
            throw new NotImplementedException();
        }

        public override MembershipUserCollection FindUsersByName(string usernameToMatch, int pageIndex, int pageSize,
            out int totalRecords)
        {
            throw new NotImplementedException();
        }

        public override MembershipUserCollection FindUsersByEmail(string emailToMatch, int pageIndex, int pageSize,
            out int totalRecords)
        {
            throw new NotImplementedException();
        }
    }

    public class AppMembershipUser : MembershipUser
    {
        public AppMembershipUser(SysUserModel user) : base("AppMembership", user.UserName, user.UserId, user.Email,
            string.Empty, string.Empty, true, false, user.CreatedDate.GetValueOrDefault(), DateTime.Now, DateTime.Now,
            DateTime.Now, DateTime.Now)
        {
            UserId = user.UserId;
            Email = user.Email;
            FullName = user.FullName;
            UserName = user.UserName;
            CreationDate = user.CreatedDate.GetValueOrDefault();
        }

        #region User Properties

        public int? UserId { get; set; }
        public sealed override string Email { get; set; }
        public string FullName { get; set; }
        public override string UserName { get; }
        public override DateTime CreationDate { get; }

        #endregion
    }
}
