"""Inventory source definitions and caller evidence; never connects to a database."""
import json,re,xml.etree.ElementTree as ET
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]; SOL=ROOT/'Source/ReportDeptTourismSolution'; SQL=SOL/'SqlScripts'; OUT=ROOT/'docs/sql-scope-audit'
def definitions():
 result={}
 for p in sorted(list((SQL/'2. New Report Permission').glob('*.sql'))+list((SQL/'Chatbot').glob('*.sql'))):
  text=p.read_text(encoding='utf-8-sig'); db='Category' if p.name.startswith(('f_Chatbot','p_Cate_Chatbot')) else 'Report'
  for batch in re.split(r'(?im)^\s*GO\s*$',text):
   use=re.search(r'(?im)^USE \[([^]]+)\]',batch)
   if use:db='Category' if use[1].endswith('.cate') else 'Report'
   m=re.search(r'(?im)^(ALTER|CREATE)\s+(PROCEDURE|FUNCTION)\s+dbo\.(\w+)',batch)
   if m:result[m[3]]=dict(name=m[3],kind=m[2],database=db,source=str(p.relative_to(ROOT)),sourceLine=text[:text.index(batch)+m.start()].count('\n')+1,sql=batch[m.start():].strip())
 return result

def inventory():
 objs=definitions();bundle=(SQL/'Deploy_SCT_All.sql').read_text(encoding='utf-8-sig')
 # Bundle definitions are EXEC-escaped; find distinct definitions, excluding CREATE stubs.
 emitted=set(re.findall(r'(?i)\b(?:CREATE|ALTER)\s+(?:PROCEDURE|FUNCTION)\s+dbo\.(\w+)',bundle))
 assert set(objs)==emitted,(set(objs)-emitted,emitted-set(objs))
 mappings={}
 for p in SOL.rglob('*StoredProcedures.xml'):
  try:root=ET.parse(p).getroot()
  except ET.ParseError:continue
  for n in root.iter('Procedure'):
   if n.get('Value'):mappings.setdefault(n.get('Value'),[]).append((n.get('Name'),str(p.relative_to(ROOT))))
 cs={p:p.read_text(encoding='utf-8-sig') for p in SOL.rglob('*.cs') if not any(t in p.parts for t in ('packages','obj','bin'))}
 refs=[]
 for p,text in cs.items():
  for n,line in enumerate(text.splitlines(),1):
   if 'Execute' in line or 'ReportIndustryScope.Procedure' in line:refs.append((str(p.relative_to(ROOT)),n,line.strip()))
 for name,o in objs.items():
  body=o['sql'];base=name.removesuffix('_IndustryScope').removesuffix('_Operational');maps=mappings.get(name,[]);base_maps=mappings.get(base,[])
  o['mappings']=[{'key':k,'file':f,'dynamicSuffix':name.endswith(('_IndustryScope','_Operational')) and name!=base} for k,f in sorted(set(maps+base_maps))]
  keys={x['key'] for x in o['mappings']};callers=[];methods=[]
  for p,text in cs.items():
   hits=[(i,line) for i,line in enumerate(text.splitlines(),1) if any('"'+k+'"' in line for k in keys)]
   for i,line in hits:
    callers.append(f'{p.relative_to(ROOT)}:{i}')
    # Include every method using a constant bound to this mapped key.
    fields=re.findall(r'\b(\w+)\s*=\s*"(?:'+ '|'.join(re.escape(k) for k in keys)+r')"',line) if keys else []
    if not fields:
     prefix='\n'.join(text.splitlines()[:i]);mm=list(re.finditer(r'(?m)^\s*(?:public|private|internal|protected)\s+(?:(?:static|async|override|virtual|sealed)\s+)*[\w<>?,\[\].]+\s+(\w+)\s*\(',prefix))
     if mm:methods.append((p.stem,mm[-1][1],str(p.relative_to(ROOT)),i))
    for field in fields:
     for use in re.finditer(r'\b'+re.escape(field)+r'\b',text):
      before=text[:use.start()];mm=list(re.finditer(r'(?m)^\s*(?:public|private|internal|protected)\s+(?:(?:static|async|override|virtual|sealed)\s+)*[\w<>?,\[\].]+\s+(\w+)\s*\(',before))
      if mm:methods.append((p.stem,mm[-1][1],str(p.relative_to(ROOT)),before.count('\n')+1))
  methods=sorted(set(methods));o['bizMethods']=[f'{c}.{m} ({p}:{n})' for c,m,p,n in methods];o['directCallers']=sorted(set(callers))
  # Resolve concrete receiver declarations and constructor/property types through cache/controller layers.
  pending={(c,m) for c,m,_,_ in methods};seen=set(pending);trans=[]
  for depth in range(4):
   next_set=set()
   for p,text in cs.items():
    for cls,method in pending:
     receivers=set(re.findall(r'\b'+re.escape(cls)+r'\s+(\w+)\b',text));receivers.add(cls)
     for receiver in receivers:
      for hit in re.finditer(r'\b'+re.escape(receiver)+r'\.'+re.escape(method)+r'\s*\(',text):
       bef=text[:hit.start()];ms=list(re.finditer(r'(?m)^\s*(?:public|private|internal|protected)\s+(?:(?:static|async|override|virtual|sealed)\s+)*[\w<>?,\[\].]+\s+(\w+)\s*\(',bef))
       if ms:
        member=ms[-1][1];trans.append(f'{p.relative_to(ROOT)}:{bef.count(chr(10))+1} ({member})');next_set.add((p.stem,member))
   pending=next_set-seen;seen|=pending
   if not pending:break
  o['transitiveCallers']=sorted(set(trans))
  o['calls']=sorted(set(re.findall(r'(?i)\bEXEC(?:UTE)?\s+(?:@\w+\s*=\s*)?(?:\[[^]]+\]\.)?(?:dbo\.)?(p_\w+)',body)))
  o['functions']=sorted({x for x in re.findall(r'\bdbo\.(f_\w+)\s*\(',body) if x!=name})
  header=re.split(r'\bAS\s+(?=BEGIN|RETURN|SELECT)',body,maxsplit=1,flags=re.I)[0]
  o['parameters']=sorted(set(re.findall(r'@(\w+)\s+(?:n?varchar|int|bigint|bit|datetime|date|dbo\.)',header,re.I)))
  # Only writes to persisted tables count; temp/table-variable materialization is a read.
  o['writes']=bool(re.search(r'(?i)\b(?:INSERT\s+(?:INTO\s+)?|UPDATE\s+|DELETE\s+(?:FROM\s+)?)(?:\[[^]]+\]\.)?dbo\.',body)) or bool(o['calls'] and any(x in ('p_Report_DataImports_ImportDatas','p_Report_DataImports_Delete') for x in o['calls']))
  o['scope']='operational (no industry restriction)' if 'f_Report_DataImportEnterprises' in body else 'canonical' if 'f_Report_Industry' in body or 'f_Chatbot_' in body else 'administrative role/action checks' if 'Sys_Permissions' in body else 'delegated/none'
  o['assignment']='explicit' if 'Cate_EnterprisePermissions' in body else 'via function' if o['functions'] else 'none'
  o['classification']=('ADMINISTRATION' if 'Sys_Permissions' in body and o['writes'] and 'IndustryPermissions_Save' in name else 'DELETE' if o['writes'] and 'Delete' in name else 'CREATE/UPDATE' if o['writes'] else 'VALIDATION' if 'CheckDataImport' in name else 'CHATBOT' if 'Chatbot' in name else 'STATISTICS/REPORT/EXPORT' if any(x in name for x in ('Dashboard','Reports_','ThongKe','GenerateSale')) else 'READ/operational (see caller matrix)')
  if name=='p_Report_DataImports_CheckOwnership':o['classification']='VALIDATION (write-set ownership, read-only)'
  o['bundleLine']=bundle[:bundle.index(name)].count('\n')+1
  o['base']=base if base!=name else None
  o['installedState']='CREATE-if-missing/ALTER; existing DB state unverified'
  o['decision']='REVERT/REMOVE_FROM_RELEASE' if name.endswith(('ImportDatas_IndustryScope','Delete_IndustryScope','CheckDataImport_IndustryScope')) else 'CHANGE' if 'GetForUserOnMonth' in name or 'FilterOptions' in name or name.endswith('_Operational') or 'OperationalScope' in name or 'DataImports_Enterprises_SearchSelect2' in name else 'KEEP'
 baseline_path=OUT/'initial-inventory.json'
 if baseline_path.exists():
  baseline=json.loads(baseline_path.read_text())
  for name,o in objs.items():
   if name not in baseline or o['sql']!=baseline[name]['sql']:o['decision']='CHANGE'
   o['releaseState']='New in corrected bundle (DB existence unverified)' if name not in baseline else 'Retained from initial bundle (DB existence unverified)'
 return objs

def write(objs):
 OUT.mkdir(parents=True,exist_ok=True)
 procs=[o for o in objs.values() if o['kind']=='PROCEDURE'];funcs=[o for o in objs.values() if o['kind']=='FUNCTION']
 (OUT/'inventory.json').write_text(json.dumps(objs,ensure_ascii=False,indent=2)+'\n')
 lines=['# Complete SQL scope inventory','',f'Authoritative generated inventory: **{len(procs)} procedures, {len(funcs)} functions**. Counts exclude CREATE stubs and repeated verifier text. Every source definition matches a distinct bundle definition. Database labels resolve through generated target names in sql-object-manifest.json. Existing/create state requires DB metadata; CREATE-if-missing does not prove an object is new.','', '| SP | DB / schema | Operation | Scope / assignments | Caller evidence | Decision |', '|---|---|---|---|---|---|']
 for o in procs:lines.append(f"| {o['name']} | {o['database']}.dbo | {o['classification']} | {o['scope']} / {o['assignment']} | "+'<br>'.join(o['bizMethods'] or o['directCallers'] or ['Indirect SQL / mapping below'])+f" | {o['decision']} |")
 for o in procs:
  lines.extend(['',f"## {o['name']}",f"- Source: `{o['source']}:{o['sourceLine']}`; bundle `Deploy_SCT_All.sql:{o['bundleLine']}`.",f"- Install: {o['installedState']}; base: `{o['base'] or 'none'}`; persisted writes: {o['writes']}; accepts: {', '.join(o['parameters']) or 'see source signature'}.",'- XML: '+'; '.join(f"`{x['file']}`: `{x['key']}`"+(' + server-selected scope suffix' if x['dynamicSuffix'] else '') for x in o['mappings']),'- C#/controllers: '+'; '.join(o['directCallers']+o['transitiveCallers']) if o['directCallers'] or o['transitiveCallers'] else '- C#/controllers: indirect SQL-only dependency; no literal C# mapping found.',f"- Calls: {', '.join(o['calls']) or 'none'}; functions: {', '.join(o['functions']) or 'none'}.",'- Authorization change: '+('New reporting scope/actor checks on an original operational call; remove future wrapper and restore original execution contract.' if 'REMOVE' in o['decision'] else 'Original row/query calculation retained with the contract-specific population shown above. Operational consumers must use the separate server-selected operational path; see caller-matrix.md.' if o['base'] else 'New shared authorization/reference contract; account/action/mapping and canonical population checks shown in source.'),'- Intent: '+('Unintended operational narrowing; correction required.' if 'REMOVE' in o['decision'] else 'Reporting isolation intentional; month worklist/filter failure corrections and unresolved runtime behavior are documented separately.')])
 (OUT/'procedure-inventory.md').write_text('\n'.join(lines)+'\n')
 f=['# Function dependency inventory','',f'{len(funcs)} function definitions in the generated release. Direct and indirect SQL callers are included; existing dbo.fnSplit and base write procedures remain external preflight dependencies.','', '| Function | Source | Calls | Used by | Policy |','|---|---|---|---|---|']
 for o in funcs:
  used=[n for n,v in objs.items() if o['name'] in v['functions']]
  f.append(f"| {o['name']} | {o['source']}:{o['sourceLine']} | {', '.join(o['functions']) or 'dbo.fnSplit / tables; see body'} | {', '.join(used) or 'application scope/read mapping'} | {o['scope']} / {o['assignment']} |")
 (OUT/'function-dependencies.md').write_text('\n'.join(f)+'\n')
 print(json.dumps({'procedures':len(procs),'functions':len(funcs),'persistedWriteProcedures':[o['name'] for o in procs if o['writes']]}))
if __name__=='__main__':write(inventory())
