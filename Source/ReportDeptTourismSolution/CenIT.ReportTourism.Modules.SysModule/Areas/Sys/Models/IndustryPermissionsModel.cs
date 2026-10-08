using System.Collections.Generic;
using System.ComponentModel.DataAnnotations;
using System.Web.Mvc;

namespace CenIT.ReportTourism.Modules.SysModule.Areas.Sys.Models
{
    public sealed class IndustryPermissionsModel
    {
        [Range(1, int.MaxValue)]
        public int UserId { get; set; }
        public string UserName { get; set; }
        public string FullName { get; set; }
        public int[] IndustryIds { get; set; }
        public bool ConfirmRestoreScope { get; set; }
        public List<SelectListItem> Industries { get; set; }
    }
}
