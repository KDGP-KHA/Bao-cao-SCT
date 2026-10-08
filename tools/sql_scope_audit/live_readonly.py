"""SELECT-only TDS 7.0 evidence. Credential JSON stdin, never command-line/output."""
import argparse,json,sys,re,hashlib,datetime
from pathlib import Path
import xml.etree.ElementTree as ET
import pytds
from tools.sql_scope_audit.inventory import definitions,ROOT

def query(c,sql,p=None):
 cur=c.cursor();cur.execute(sql,p)
 while cur.description is None:
  if not cur.nextset():return []
 return cur.fetchall()
def connect(item):
 v={k.lower():x for k,x in item['values'].items()};host=v.get('data source',v.get('server'));port=None
 if host.lower().startswith('tcp:'):host=host[4:]
 if ',' in host:host,port=host.rsplit(',',1);port=int(port)
 kw=dict(server=host,database=v.get('initial catalog',v.get('database')),user=v.get('user id',v.get('uid')),password=v.get('password',v.get('pwd')),tds_version=pytds.tds_base.TDS70,login_timeout=8,timeout=30,autocommit=True,as_dict=True,appname='SqlScopeAuditReadOnly')
 if port:kw['port']=port
 if str(v.get('encrypt','false')).lower() in ('true','yes','mandatory','strict'):
  import ssl,os
  ca=os.environ.get('REPORT_SQL_CA_FILE') or ssl.get_default_verify_paths().cafile
  if not ca:raise RuntimeError('Trusted SQL TLS CA required')
  kw.update(cafile=ca,validate_host=True)
 return pytds.connect(**kw)
def digest(x):return hashlib.sha256(json.dumps(x,ensure_ascii=False,sort_keys=True,default=str).encode()).hexdigest()
def main():
 a=argparse.ArgumentParser();a.add_argument('--output',required=True);args=a.parse_args();out=Path(args.output);out.mkdir(parents=True,exist_ok=True)
 cfg={x['name']:x for x in json.load(sys.stdin)};objs=definitions();roles=[]
 for e in ET.parse(ROOT/'Source/ReportDeptTourismSolution/CenIT.ReportTourism.WebApp/Configs/AppSettings.config').findall('add'):
  if e.get('key','').startswith('ReportRoles:'):
   i,scope,t=e.get('value').split('|');key=e.get('key')[len('ReportRoles:'):]
   if not re.fullmatch(r'[A-Za-z][A-Za-z0-9_]{0,79}',key):raise ValueError('Invalid role setting')
   roles.append((key,int(i),scope,int(t=='true')))
 with connect(cfg['BaseApp']) as cat,connect(cfg['ReportTourismDB']) as rep:
  assert cat.tds_version==pytds.tds_base.TDS70 and rep.tds_version==pytds.tds_base.TDS70
  catdb=query(cat,'SELECT DB_NAME() Name')[0]['Name'];repdb=query(rep,'SELECT DB_NAME() Name')[0]['Name'];catref='['+catdb.replace(']',']]')+']'
  snapshot=lambda: {'roles':query(cat,'SELECT RoleId,Name,IsDeleted FROM dbo.Sys_Roles ORDER BY RoleId'),'assignments':query(cat,'SELECT ForUser,EnterpriseId FROM dbo.Cate_EnterprisePermissions ORDER BY ForUser,EnterpriseId'),'userRoles':query(cat,'SELECT UserId,RoleId FROM dbo.Sys_UserRoles ORDER BY UserId,RoleId'),'permissions':query(cat,'SELECT RoleId,FunctionId,Action FROM dbo.Sys_Permissions ORDER BY RoleId,FunctionId,Action'),'industries':query(cat,'SELECT UserId,IndustryId FROM dbo.Report_UserBusinessIndustryPermissions ORDER BY UserId,IndustryId')}
  before=snapshot();result={'tds':'0x70000000','categoryDatabase':catdb,'reportDatabase':repdb,'mode':'SELECT_ONLY','beforeHashes':{k:digest(v) for k,v in before.items()},'roles':before['roles']}
  result['roleGroups']=query(cat,"SELECT ur.RoleId,COUNT(DISTINCT u.UserId) Users FROM dbo.Sys_Users u JOIN dbo.Sys_UserRoles ur ON ur.UserId=u.UserId WHERE u.IsActive=1 AND u.IsDeleted=0 AND ISNULL(u.IsLocked,0)=0 GROUP BY ur.RoleId")
  fixtures=query(cat,"SELECT UserId,UserName FROM dbo.Sys_Users WHERE UserName='trunglc.kha' AND IsActive=1 AND IsDeleted=0 AND ISNULL(IsLocked,0)=0")
  fixtures+=query(cat,"""SELECT TOP(1) u.UserId,u.UserName FROM dbo.Sys_Users u JOIN dbo.Sys_UserRoles ur ON ur.UserId=u.UserId AND ur.RoleId=5
 WHERE u.IsActive=1 AND u.IsDeleted=0 AND ISNULL(u.IsLocked,0)=0 AND u.UserName NOT LIKE '%[^0-9]%'
 AND NOT EXISTS(SELECT 1 FROM dbo.Sys_UserRoles other WHERE other.UserId=u.UserId AND other.RoleId<>5)
 AND (SELECT COUNT(DISTINCT p.EnterpriseId) FROM dbo.Cate_EnterprisePermissions p WHERE p.ForUser=u.UserName)=1 ORDER BY u.UserId""")
  fixtures+=query(cat,"SELECT TOP(1) u.UserId,u.UserName FROM dbo.Sys_Users u JOIN dbo.Sys_UserRoles ur ON ur.UserId=u.UserId AND ur.RoleId=6 WHERE u.IsActive=1 AND u.IsDeleted=0 AND ISNULL(u.IsLocked,0)=0 ORDER BY u.UserId")
  result['fixtures']=[]
  values=' UNION ALL '.join("SELECT '%s' SemanticKey,%d RoleId,'%s' ScopeMode,%d IsIndustryEditorTarget"%r for r in roles)
  def expression(name):
   return re.search(r'RETURNS\s+TABLE\s+AS\s+RETURN\s*\((.*)\)\s*;?$',objs[name]['sql'],re.S|re.I)[1]
  us=re.sub(r'\bdbo\.',catref+'.dbo.',expression('f_Report_IndustryUserScope')).replace(catref+'.dbo.Report_RoleMappings','RoleMap')
  population=re.sub(r'\bdbo\.',catref+'.dbo.',expression('f_Report_IndustryEnterprises')).replace(catref+'.dbo.f_Report_IndustryUserScope(@UserName)','UserScope')
  operational=expression('f_Report_DataImportEnterprises').replace('[baocaosct.khanhhoa.gov.vn.cate]',catref).replace(catref+'.dbo.Report_RoleMappings','RoleMap')
  cte=';WITH RoleMap AS ('+values+'),UserScope AS ('+us+'),Authorized AS ('+population+'),Operational AS ('+operational+') '
  for u in fixtures:
   p=(u['UserName'],);prefix='DECLARE @UserName varchar(255)=%s;'
   scopes=query(rep,prefix+cte+"SELECT 'report' Kind,EnterpriseId FROM Authorized UNION ALL SELECT 'operation',EnterpriseId FROM Operational",p)
   assigned={x['EnterpriseId'] for x in before['assignments'] if x['ForUser']==u['UserName']};rs={x['EnterpriseId'] for x in scopes if x['Kind']=='report'};ops={x['EnterpriseId'] for x in scopes if x['Kind']=='operation'}
   records=query(rep,prefix+cte+"""SELECT TOP(50001) r.EnterpriseId,r.ForMonth,r.TypeReport,r.TypeReportName,r.IsLate,su.FullName CreatedBy,
 DATEADD(millisecond,-DATEPART(millisecond,r.CreatedDate),r.CreatedDate) CreatedDate
 FROM dbo.Report_DataImports r LEFT JOIN """+catref+""".dbo.Sys_Users su ON su.UserName=r.CreatedBy WHERE r.IsDeleted=0 AND r.ForMonth>='20260901' AND r.ForMonth<'20261001'
 AND (EXISTS(SELECT 1 FROM Authorized a WHERE a.EnterpriseId=r.EnterpriseId) OR EXISTS(SELECT 1 FROM Operational a WHERE a.EnterpriseId=r.EnterpriseId))
 GROUP BY r.EnterpriseId,r.ForMonth,r.TypeReport,r.TypeReportName,r.IsLate,su.FullName,DATEADD(millisecond,-DATEPART(millisecond,r.CreatedDate),r.CreatedDate)""",p)
   if len(records)>50000:raise RuntimeError('Monthly comparison exceeds bound')
   keys=lambda selected:{digest(x) for x in records if x['EnterpriseId'] in selected}
   initial=keys(rs);report_month=keys(rs&assigned);op_month=keys(ops&assigned)
   result['fixtures'].append(dict(u,assignedEnterpriseIds=sorted(assigned),reportingPopulation=len(rs),operationalPopulation=len(ops),month='2026-09',initialCandidateMonthlyEntries=len(initial),correctedReportingMonthlyEntries=len(report_month),correctedOperationalMonthlyEntries=len(op_month),reportingMonthlyLost=len(initial-report_month),reportingMonthlyGained=len(report_month-initial),operationalMonthlyLost=len(initial-op_month),operationalMonthlyGained=len(op_month-initial)))
  result['baseWriteSignatures']=query(rep,"SELECT o.name,p.parameter_id,p.name ParameterName,TYPE_NAME(p.user_type_id) TypeName,p.max_length FROM sys.objects o JOIN sys.parameters p ON p.object_id=o.object_id WHERE o.name IN('p_Report_DataImports_ImportDatas','p_Report_DataImports_Delete','p_Report_DataImports_CheckDataImport') ORDER BY o.name,p.parameter_id")
  result['auditDependencies']=query(rep,"SELECT o.name,d.referenced_database_name,d.referenced_schema_name,d.referenced_entity_name FROM sys.sql_expression_dependencies d JOIN sys.objects o ON o.object_id=d.referencing_id WHERE o.name IN('p_Report_DataImports_ImportDatas','p_Report_DataImports_Delete','p_Report_DataImports_CheckDataImport')")
  after=snapshot();result['afterHashes']={k:digest(v) for k,v in after.items()};result['authorizationRecordsUnchanged']=result['beforeHashes']==result['afterHashes']
  (out/'live-readonly.json').write_text(json.dumps(result,ensure_ascii=False,indent=2,default=str)+'\n');print(json.dumps({'status':'PASS_READONLY','fixtures':result['fixtures'],'authorizationRecordsUnchanged':result['authorizationRecordsUnchanged']},ensure_ascii=False))
if __name__=='__main__':
 try:main()
 except Exception as e:print(json.dumps({'status':'BLOCKED','errorType':type(e).__name__,'sqlErrorNumber':getattr(e,'number',None)}));sys.exit(1)
