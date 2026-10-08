using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
namespace System.Web {
 public class HttpException : Exception { public int Code; public HttpException(int code,string message):base(message){Code=code;} }
 public class HttpContext { public static HttpContext Current {get;set;} public Hashtable Items=new Hashtable(); }
}
namespace CenIT.ReportTourism.Models.Sys { public class SysSearchModel {public string Search,Order,OrderDir;public int StartIndex,PageSize;} }
namespace CenIT.ReportTourism.Models.Cate { public class CateEnterpriseModel {public int EnterpriseId;public string BusinessName,TaxCode,TypeBusiness;} }
namespace CenIT.ReportTourism.Models.Report { public class ReportDataImportModel {public int? EnterpriseId,TypeReport;public DateTime? ForMonth;public string TypeReportName,ReportFile,Reason,CreatedBy,SavedBy;public object DataImport;public int TotalRow;} }
namespace TSFramework.App.Processors {
 public static class AppProcessor { public static FakeProvider ProcedureProvider=new FakeProvider(); }
 public class FakeProvider {
  public string Name; public object[] Args;public int Calls;public int ReturnValue=7;public bool MissingProcedure;public bool OwnerMode;public bool OwnerCanWrite=true;
  public int? Execute(string n,string p,params object[] a){Name=n;Args=a;Calls++;return ReturnValue;}
  public List<T> ExecuteTypedList<T>(string n,string p,params object[] a) where T:new(){Name=n;Args=a;Calls++;return new List<T>();}
  public T ExecuteScalarObject<T>(string n,string p,params object[] a) where T:new(){Name=n;Args=a;Calls++;return new T();}
  public DataTable ExecuteProcedure(string n,string p,params object[] a){if(MissingProcedure)return null;if(n=="Report_DataImports_CheckOwnership"){var check=new DataTable();check.Columns.Add("CanWrite",typeof(bool));check.Rows.Add(OwnerCanWrite);return check;}
   var t=new DataTable();t.Columns.Add("RoleMappingSignature",typeof(string));t.Columns.Add("CanManageAllRecords",typeof(bool));
   t.Columns.Add("EnterpriseId",typeof(int));t.Columns.Add("BusinessName",typeof(string));t.Columns.Add("TaxCode",typeof(string));t.Columns.Add("TypeBusiness",typeof(string));t.Columns.Add("IsEnterpriseUser",typeof(bool));
   t.Columns.Add("IsRestricted",typeof(bool));t.Columns.Add("HasEnterpriseRole",typeof(bool));t.Columns.Add("HasFullAccess",typeof(bool));t.Columns.Add("HasIndustryRole",typeof(bool));
   var r=t.NewRow();r["RoleMappingSignature"]=CenIT.ReportTourism.Biz.Report.ReportRoleMapping.Current.Signature;
   r["CanManageAllRecords"]=!OwnerMode;r["EnterpriseId"]=7;r["BusinessName"]="Authorized";r["TaxCode"]="7";r["TypeBusiness"]="1";r["IsEnterpriseUser"]=true;r["IsRestricted"]=true;r["HasEnterpriseRole"]=false;r["HasFullAccess"]=false;r["HasIndustryRole"]=true;t.Rows.Add(r);return t;
  }
 }
}
public static class ContractAssertions {
 static void Require(bool value,string message){if(!value)throw new Exception(message);}
 static void InvalidConfig(string key,string value,bool remove=false){
  var path=System.IO.Path.Combine(AppDomain.CurrentDomain.BaseDirectory,"Configs","AppSettings.config");
  var original=System.IO.File.ReadAllText(path);
  try{var doc=new System.Xml.XmlDocument();doc.LoadXml(original);var n=(System.Xml.XmlElement)doc.SelectSingleNode("/appSettings/add[@key='"+key+"']");if(remove)n.ParentNode.RemoveChild(n);else n.SetAttribute("value",value);doc.Save(path);
   try{CenIT.ReportTourism.Biz.Report.ReportRoleMapping.Validate();throw new Exception("Invalid mapping accepted: "+key);}catch(InvalidOperationException){}
  }finally{System.IO.File.WriteAllText(path,original);}
 }
 public static string Run(){
  System.Web.HttpContext.Current=new System.Web.HttpContext();
  var op=CenIT.ReportTourism.Biz.Report.ReportDataImportScope.Begin("login");
  CenIT.ReportTourism.Biz.Report.ReportIndustryScope.Begin("login");
  var b=new CenIT.ReportTourism.Biz.Report.ReportDataImportBiz();var p=TSFramework.App.Processors.AppProcessor.ProcedureProvider;
  var m=new CenIT.ReportTourism.Models.Report.ReportDataImportModel {EnterpriseId=7,ForMonth=new DateTime(2026,9,1),TypeReport=1,CreatedBy="creator",SavedBy="audit@example.invalid",DataImport=new object()};
  Require(b.Import(m)==7,"Import return changed");Require(p.Name=="Report_DataImports_ImportDatas"&&p.Args.Length==8&&Equals(p.Args[7],"creator"),"Import signature/audit changed");
  Require(b.Delete(m),"Delete return changed");Require(p.Name=="Report_DataImports_Delete"&&p.Args.Length==4&&Equals(p.Args[3],"audit@example.invalid"),"Delete email audit changed");
  b.CheckDataImport(m);Require(p.Name=="Report_DataImports_CheckDataImport"&&p.Args.Length==3&&Equals(p.Args[2],m.DataImport),"Validation signature changed");
  int before=p.Calls;m.EnterpriseId=8;try {b.Import(m);throw new Exception("Unauthorized import accepted");}catch(System.Web.HttpException e){Require(e.Code==403,"Wrong denial contract");}Require(p.Calls==before,"Unauthorized write executed SQL");
  try {b.Delete(m);throw new Exception("Unauthorized delete accepted");}catch(System.Web.HttpException e){Require(e.Code==403,"Wrong delete denial");}
  try {b.CheckDataImport(m);throw new Exception("Unauthorized validation accepted");}catch(System.Web.HttpException e){Require(e.Code==403,"Wrong validation denial");}
  b.GetViaEnterpriseOnMonth(7,m.ForMonth);Require(p.Name=="Report_DataImports_GetDataImport_Operational"&&p.Args.Length==3&&Equals(p.Args[2],"login"),"Operational detail not isolated");
  b.GetForUserOnMonth("login",m.ForMonth);Require(p.Name=="Report_DataImports_GetForUserOnMonth_Operational"&&p.Args.Length==3,"Operational monthly contract changed");
  p.ReturnValue=0;m.EnterpriseId=7;Require(b.Import(m)==0&&!b.Delete(m),"Base failure return contract changed");
  p.OwnerMode=true;CenIT.ReportTourism.Biz.Report.ReportDataImportScope.Begin("login");p.OwnerCanWrite=false;
  try{b.Import(m);throw new Exception("Foreign ownership accepted");}catch(System.Web.HttpException e){Require(e.Code==403,"Wrong ownership denial");}
  p.OwnerCanWrite=true;Require(b.Import(m)==0,"Owned legacy update return changed");
  InvalidConfig("ReportRoles:ReportingRole2","1|industry|true");
  InvalidConfig("ReportRoles:ReportingRole2","2|unknown|true");
  InvalidConfig("ReportRoles:Enterprise","5|enterprise|true");
  InvalidConfig("ReportRoles:IndustryAdministrator","6|industry|True");
  InvalidConfig("ReportRoles:SystemAdministrator","",true);
  p.MissingProcedure=true;try{new CenIT.ReportTourism.Biz.Report.ReportBiz().GetDataReport("missing");throw new Exception("Missing report silently rendered empty");}catch(System.Web.HttpException e){Require(e.Code==503,"Missing report must fail explicitly");}
  return "PASS: actual Biz and scope source executed: 8/4/3 arguments, audit identities, return values, operational routing, and denied writes; Framework/IIS and SQL transactions not certified.";
 }
}
