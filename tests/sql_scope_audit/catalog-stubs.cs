using System;
using System.IO;
using Newtonsoft.Json.Linq;
namespace System.Web.Hosting {
 public static class HostingEnvironment {
  public static string Root;
  public static string MapPath(string path){return Path.Combine(Root,path.Substring(2));}
 }
}
public static class CatalogAssertions {
 public static string Run(string root){
  System.Web.Hosting.HostingEnvironment.Root=root;
  var names=new[]{"allowProvince","userId","roleIds","ignoreScope","procedure","sql"};
  foreach(var key in names){var input=new JObject();input[key]=1;try{CenIT.ReportTourism.WebApp.Chatbot.ChatbotCatalog.Validate("search_enterprises",input);throw new Exception("Tampered argument accepted: "+key);}catch(ArgumentException){}}
  CenIT.ReportTourism.WebApp.Chatbot.ChatbotCatalog.Validate("search_enterprises",new JObject());
  return "PASS: actual ChatbotCatalog rejects six scope/identity/SQL argument injections; valid empty search input accepted.";
 }
}
