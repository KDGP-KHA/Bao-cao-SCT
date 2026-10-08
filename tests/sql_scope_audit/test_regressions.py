import json,re,subprocess,unittest,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; SOL=ROOT/'Source/ReportDeptTourismSolution';SQL=SOL/'SqlScripts'
class ReleaseRegression(unittest.TestCase):
 def test_no_reporting_wrappers_on_operational_writes(self):
  body=(SOL/'CenIT.ReportTourism.Biz/Report/ReportDataImportBiz.cs').read_text(encoding='utf-8-sig')
  for field in ['ImportDatas','Delete','CheckDataImport']:
   self.assertNotIn('ReportIndustryScope.Procedure(_reportDataImports'+field+')',body)
  bundle=(SQL/'Deploy_SCT_All.sql').read_text(encoding='utf-8-sig')
  for n in ['ImportDatas','Delete','CheckDataImport']:self.assertNotIn('p_Report_DataImports_'+n+'_IndustryScope',bundle)
 def test_monthly_worklist_requires_assignment(self):
  from tools.sql_scope_audit.inventory import definitions
  body=definitions()['p_Report_DataImports_GetForUserOnMonth_IndustryScope']['sql']
  self.assertRegex(body,r'(?s)WHERE\s+rdi.IsDeleted\s*=\s*0.*EXISTS\s*\(.*Cate_EnterprisePermissions')
  self.assertNotIn('@HasExplicitPermissions',body)
  for claim in ['@UserFullName','@UserEmail','ce.TaxCode = @ForUser']:self.assertNotIn(claim,body)
 def test_filter_resolution_failure_is_explicit(self):
  from tools.sql_scope_audit.inventory import definitions
  body=definitions()['p_Report_Dashboard_FilterOptions_IndustryScope']['sql']
  self.assertRegex(body,r'(?s)IF\s+@ReportScopeRestricted\s+IS NULL\s+THROW')
 def test_labels_preserve_custom_text(self):
  for name in ['Seed_Dashboard_SysMessages.sql','Seed_UserIndustryPermissions_SysMessages.sql']:
   body=(SQL/'Scripts'/name).read_text(encoding='utf-8-sig');self.assertNotRegex(body,r'(?i)UPDATE\s+target');self.assertIn('NOT EXISTS',body)
  verifier=(SQL/'Verify_SCT_IndustryChatbot.sql').read_text(encoding='utf-8-sig');self.assertNotIn('text differs',verifier);self.assertNotIn('m.Message) COLLATE',verifier)
 def test_xml_and_bundle_dependencies(self):
  from tools.sql_scope_audit.inventory import inventory
  objects=inventory(); self.assertGreater(len(objects),40)
  removed={f'p_Report_DataImports_{x}_IndustryScope' for x in ['ImportDatas','Delete','CheckDataImport']}
  for p in SOL.rglob('*StoredProcedures.xml'):
   for n in ET.parse(p).getroot().iter('Procedure'):self.assertNotIn(n.get('Value'),removed)
  for o in objects.values():self.assertFalse(removed.intersection(o['calls']))
 def test_operations_do_not_inherit_reporting_controller(self):
  body=(SOL/'CenIT.ReportTourism.Modules.ReportModule/Areas/Report/Controllers/ImportController.cs').read_text()
  self.assertIn('class ImportController : AppController',body);self.assertIn('ReportDataImportScope.Begin(User.UserName)',body)
 def test_role_configuration_unchanged(self):
  config=ET.parse(SOL/'CenIT.ReportTourism.WebApp/Configs/AppSettings.config')
  roles={int(n.get('value').split('|')[0]):n.get('value').split('|')[1] for n in config.findall('add') if n.get('key','').startswith('ReportRoles:')}
  self.assertEqual(roles,{1:'all',2:'industry',3:'industry',4:'industry',5:'enterprise',6:'industry'})
 def test_no_destructive_cleanup(self):
  body=(SQL/'Deploy_SCT_All.sql').read_text(encoding='utf-8-sig');self.assertNotRegex(body,r'(?i)DROP\s+(?:TABLE|PROCEDURE|FUNCTION)')
if __name__=='__main__':unittest.main()
