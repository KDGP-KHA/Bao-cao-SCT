using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Web;
using System.Xml;
using System.Text.RegularExpressions;

namespace CenIT.ReportTourism.Biz.Report
{
    // One deployment artifact is consumed by both application and SQL bundle generation.
    public sealed class ReportRoleMapping
    {
        private const string ContextKey = "CenIT.Reports.RoleMapping";
        private readonly List<XmlElement> _roles;

        private ReportRoleMapping()
        {
            var document = new XmlDocument { XmlResolver = null };
            using (var reader = XmlReader.Create(Path.Combine(AppDomain.CurrentDomain.BaseDirectory,
                "Configs", "AppSettings.config"), new XmlReaderSettings { DtdProcessing = DtdProcessing.Prohibit, XmlResolver = null }))
                document.Load(reader);
            _roles = new List<XmlElement>();
            foreach (XmlElement setting in document.SelectNodes("/appSettings/add[starts-with(@key, 'ReportRoles:')]"))
            {
                var values = setting.GetAttribute("value").Split('|');
                if (values.Length != 3) throw new InvalidOperationException("Invalid report role setting.");
                var role = document.CreateElement("role");
                role.SetAttribute("key", setting.GetAttribute("key").Substring("ReportRoles:".Length));
                role.SetAttribute("id", values[0]);
                role.SetAttribute("scope", values[1]);
                role.SetAttribute("industryEditorTarget", values[2]);
                _roles.Add(role);
            }
            var ids = new HashSet<int>();
            var keys = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            foreach (var role in _roles)
            {
                int id;
                bool target;
                if (!int.TryParse(role.GetAttribute("id"), NumberStyles.None, CultureInfo.InvariantCulture, out id) || id <= 0 ||
                    !ids.Add(id) || !Regex.IsMatch(role.GetAttribute("key"), "^[A-Za-z][A-Za-z0-9_]{0,79}$") || !keys.Add(role.GetAttribute("key")) ||
                    !new[] { "all", "industry", "enterprise" }.Contains(role.GetAttribute("scope")) ||
                    !new[] { "true", "false" }.Contains(role.GetAttribute("industryEditorTarget")) ||
                    !bool.TryParse(role.GetAttribute("industryEditorTarget"), out target) ||
                    role.GetAttribute("scope") == "enterprise" && target)
                    throw new InvalidOperationException("Invalid report role mapping.");
            }
            if (ReportingRoleIds.Length > 500 || EnterpriseRoleIds.Length > 500)
                throw new InvalidOperationException("Report role mapping exceeds the SQL parameter contract.");
            if (!_roles.Any(role => role.GetAttribute("key") == "SystemAdministrator") || !_roles.Any(role => role.GetAttribute("key") == "Enterprise") ||
                _roles.Single(role => role.GetAttribute("key") == "SystemAdministrator").GetAttribute("scope") != "all" ||
                _roles.Single(role => role.GetAttribute("key") == "Enterprise").GetAttribute("scope") != "enterprise")
                throw new InvalidOperationException("Required report role semantics are missing.");
        }

        /// <summary>Validates the packaged role mapping before accepting application traffic.</summary>
        public static void Validate() { new ReportRoleMapping(); }

        public static ReportRoleMapping Current
        {
            get
            {
                var context = HttpContext.Current;
                var mapping = context == null ? null : context.Items[ContextKey] as ReportRoleMapping;
                if (mapping == null)
                {
                    mapping = new ReportRoleMapping();
                    if (context != null) context.Items[ContextKey] = mapping;
                }
                return mapping;
            }
        }

        private static bool Flag(XmlElement role, string flag) { return bool.Parse(role.GetAttribute(flag)); }
        public int SystemAdministratorId { get { return int.Parse(_roles.Single(role => role.GetAttribute("key") == "SystemAdministrator").GetAttribute("id"), CultureInfo.InvariantCulture); } }
        public bool IsIndustryEditorTarget(int id) { return _roles.Any(role => role.GetAttribute("id") == id.ToString(CultureInfo.InvariantCulture) && Flag(role, "industryEditorTarget")); }
        public string ReportingRoleIds { get { return Ids("all", "industry"); } }
        public string EnterpriseRoleIds { get { return Ids("enterprise"); } }
        public string Signature
        {
            get { return string.Join("|", _roles.OrderBy(role => int.Parse(role.GetAttribute("id"), CultureInfo.InvariantCulture))
                .Select(role => role.GetAttribute("key") + ":" + int.Parse(role.GetAttribute("id"), CultureInfo.InvariantCulture).ToString(CultureInfo.InvariantCulture) + ":" + role.GetAttribute("scope") + ":" + (Flag(role, "industryEditorTarget") ? "1" : "0"))); }
        }
        private string Ids(params string[] scopes) { return string.Join(",", _roles.Where(role => scopes.Contains(role.GetAttribute("scope"))).Select(role => int.Parse(role.GetAttribute("id"), CultureInfo.InvariantCulture)).OrderBy(id => id)); }
    }
}
