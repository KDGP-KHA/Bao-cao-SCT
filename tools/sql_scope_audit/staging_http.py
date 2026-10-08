"""Execute operator-supplied fixtures against isolated HTTPS staging; no deployment/SQL."""
import argparse,json,os,ssl,sys,urllib.request,urllib.error,urllib.parse
from pathlib import Path
class NoRedirect(urllib.request.HTTPRedirectHandler):
 def redirect_request(self,*args,**kwargs):return None

def main():
 p=argparse.ArgumentParser();p.add_argument('--origin',required=True);p.add_argument('--cases',required=True);p.add_argument('--output',required=True);p.add_argument('--confirm-isolated-staging',action='store_true');a=p.parse_args()
 u=urllib.parse.urlsplit(a.origin)
 if not a.confirm_isolated_staging or u.scheme!='https' or not u.netloc or u.username or u.password or u.path not in ('','/') or u.query or u.fragment:p.error('An isolated HTTPS staging origin and explicit confirmation are required')
 cases=json.loads(Path(a.cases).read_text());prepared=[]
 if not 1<=len(cases)<=100:p.error('Supply 1–100 fixture cases')
 for c in cases:
  path=urllib.parse.urlsplit(c['path']);method=c.get('method','GET')
  if method not in ('GET','POST') or path.scheme or path.netloc or path.fragment or not path.path.startswith(('/Report/','/MyEnterprise/','/Chatbot/')):p.error('Only explicit application fixture routes are supported')
  cookie=os.environ.get(c['cookieEnv']);body=None
  if not cookie:p.error('Missing fixture cookie environment variable')
  if method=='POST':
   if not c.get('bodyFile'):p.error('POST requires a private bodyFile, including the actual CSRF token and valid fixture payload')
   body=Path(c['bodyFile']).read_bytes()
  prepared.append((c,method,cookie,body))
 results=[];opener=urllib.request.build_opener(NoRedirect,urllib.request.HTTPSHandler(context=ssl.create_default_context()))
 for c,method,cookie,body in prepared:
  result={'case':c['name'],'pass':False};request=urllib.request.Request(a.origin.rstrip('/')+c['path'],data=body,method=method,headers={'Cookie':cookie,'Content-Type':c.get('contentType','application/x-www-form-urlencoded'),'Accept':'application/json,text/html'})
  try:
   try:response=opener.open(request,timeout=30)
   except urllib.error.HTTPError as e:response=e
   with response:
    result['httpStatus']=response.code;payload=response.read(8*1024*1024+1)
    if len(payload)>8*1024*1024:raise ValueError('Response size exceeded fixture limit')
    ok=response.code==c['expectedHttpStatus']
    if c.get('expectedJson'):
     data=json.loads(payload)
     for key,expected in c['expectedJson'].items():
      value=data
      for segment in key.split('.'):value=value[segment]
      ok=ok and value==expected
    result['pass']=ok
  except Exception as e:result['errorType']=type(e).__name__
  results.append(result)
 Path(a.output).write_text(json.dumps(results,indent=2)+'\n');print(json.dumps({'passed':sum(c['pass'] for c in results),'total':len(results)}));return 0 if all(c['pass'] for c in results) else 1
if __name__=='__main__':sys.exit(main())
