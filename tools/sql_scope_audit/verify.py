"""Run offline release verification and save exact commands/exit codes. No SQL connection."""
import argparse,hashlib,json,os,subprocess,sys,tempfile
from pathlib import Path
from tools.sql_scope_audit.inventory import ROOT,SQL,write,inventory

def main():
 p=argparse.ArgumentParser();p.add_argument('--pwsh',required=True);p.add_argument('--scriptdom',required=True);a=p.parse_args()
 out=ROOT/'docs/sql-scope-audit/evidence';out.mkdir(parents=True,exist_ok=True);results=[]
 env=dict(os.environ,PYTHONPYCACHEPREFIX='/tmp/report-audit-pycache')
 def run(name,cmd):
  done=subprocess.run(cmd,cwd=ROOT,env=env,capture_output=True,text=True);(out/(name+'.txt')).write_text(done.stdout+done.stderr)
  results.append(dict(name=name,command=cmd,exitCode=done.returncode,status='PASS' if done.returncode==0 else 'FAIL',evidence=str((out/(name+'.txt')).relative_to(ROOT))))
  if done.returncode:raise RuntimeError('Verification failed: '+name)
 ps=[a.pwsh,'-NoLogo','-NoProfile','-File']
 builder=str(SQL/'Scripts/Build_SCT_IndustryChatbot_Deployment.ps1')
 files=['Deploy_SCT_All.sql','Deploy_SCT_IndustryChatbot.sql','Deploy_SCT_ReportPerformanceIndexes.sql','Preflight_SCT_IndustryChatbot.sql','Verify_SCT_IndustryChatbot.sql','sql-object-manifest.json']
 hashes=lambda:{f:hashlib.sha256((SQL/f).read_bytes()).hexdigest() for f in files}
 try:
  run('generate',ps+[builder]);before=hashes();run('regenerate',ps+[builder]);after=hashes()
  if before!=after:raise RuntimeError('Nondeterministic generation')
  (out/'determinism.json').write_text(json.dumps({'identical':True,'sha256':after},indent=2)+'\n')
  run('fixtures-generate',[sys.executable,'-m','tools.sql_scope_audit.build_fixtures'])
  run('source-regressions',[sys.executable,'-m','unittest','discover','-s','tests/sql_scope_audit','-v'])
  run('sql-2012-parse',ps+['tests/sql_scope_audit/validate-sql.ps1','-ScriptDomPath',a.scriptdom])
  run('csharp-contracts',ps+['tests/sql_scope_audit/run-contracts.ps1'])
  run('chatbot-tampering',ps+['tests/sql_scope_audit/run-catalog.ps1'])
  with tempfile.TemporaryDirectory(prefix='scope-portability-') as folder:
   run('alternate-names',ps+[builder,'-CategoryDatabase','Audit Category.v2','-ReportDatabase','Audit Report.v2','-OutputDirectory',folder])
   generated=Path(folder,'Deploy_All.sql').read_text(encoding='utf-8-sig')
   assert '[Audit Category.v2]' in generated and '[Audit Report.v2]' in generated
   assert '[baocao.sct.cenit.vn' not in generated and '[baocaosct.khanhhoa.gov.vn' not in generated
   assert not Path(folder,'AppSettings.config').exists()
   bad=subprocess.run(ps+[builder,'-CategoryDatabase','Unsafe];DROP DATABASE x;--','-ReportDatabase','SafeReport','-OutputDirectory',folder],cwd=ROOT,env=env,capture_output=True,text=True)
   assert bad.returncode!=0
   (out/'identifier-rejection.json').write_text(json.dumps({'rejected':True,'exitCode':bad.returncode,'case':'bracket/semicolon database injection'},indent=2)+'\n')
  write(inventory())
 finally:(out/'verification-results.json').write_text(json.dumps(results,indent=2)+'\n')
 print('PASS: deterministic/portable generation, source guards, actual C# contracts/catalog and SQL Server 2012 syntax. Native SQL/IIS checks remain separate.')
if __name__=='__main__':main()
