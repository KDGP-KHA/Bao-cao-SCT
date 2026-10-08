using System;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Web;
using System.Web.Http;
using System.Web.Mvc;
using System.Web.Optimization;
using System.Web.Routing;
using CenIT.ReportTourism.Caches.Sys;
using Microsoft.AspNet.SignalR;
using TSFramework.App.BaseApps;
using TSFramework.Core.Providers;

namespace CenIT.ReportTourism.WebApp
{
    public class WebApiApplication : BaseHttpApplication
    {
        protected void Application_Start()
        {
            CenIT.ReportTourism.Biz.Report.ReportRoleMapping.Validate();
            AreaRegistration.RegisterAllAreas();
            GlobalConfiguration.Configure(WebApiConfig.Register);
            FilterConfig.RegisterGlobalFilters(GlobalFilters.Filters);
            RouteConfig.RegisterRoutes(RouteTable.Routes);
            BundleConfig.RegisterBundles(BundleTable.Bundles);
            GlobalHost.DependencyResolver.Register(typeof(IUserIdProvider), () => new SignalRUserProvider());
            RegisterScheduleJobs();
        }

        protected void Application_BeginRequest(object sender, EventArgs e)
        {
            if (ConfigurationManager.AppSettings["MaintenanceMode"] != "true")
            {
                var ipRequestCache = new SysIpRequestCache();
                var ipRequestModel = ipRequestCache.GetByIp(Request.UserHostAddress);
                if (ipRequestModel == null || !ipRequestModel.IsLock) return;

                Response.Clear();
                Response.Status = "301 Moved Permanently";
            }

            if (!Request.IsLocal) HttpContext.Current.RewritePath("AppOffline.htm");
        }

        private void RegisterScheduleJobs()
        {
            #region Schedule Job

            var jobFolder = "Jobs";
            var jobLibrariesPathFolder = ConfigurationManager.AppSettings["AttachmentFolderPath"] ??
                                         @"/Contents/Modules/Sys/Attachments/";

            var sysJob = new SysJobCache();
            sysJob.GetAll()?.ToList().ForEach(p =>
            {
                var fileExt = Path.GetExtension(p.JobLibrary);
                if (fileExt != ".dll") return;
                var jobLibrariesAbsolutePathFolder = Server.MapPath("~/" + jobLibrariesPathFolder);
                var jobLibrariesAbsoluteFilePath =
                    Path.Combine(jobLibrariesAbsolutePathFolder, jobFolder, p.JobLibrary);
                if (!File.Exists(jobLibrariesAbsoluteFilePath)) return;

                var emailScheduleJob = JobPlugableProvider.GetJobPlugable(jobLibrariesAbsoluteFilePath);
                var instanceJob = emailScheduleJob?.BuildJob(p.JobId.ToString(), p.JobDescription, p.CronExpression);
                if (instanceJob == null) return;
                instanceJob.MainJob.IsActive = p.IsActive;
                JobSchedulerProvider.RegisterJobScheduler(instanceJob.JobType, instanceJob.MainJob);
            });

            #endregion
        }
    }
}