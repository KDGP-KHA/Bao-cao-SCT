using System;
using System.IO;
using System.Linq;
using System.Web.Hosting;
using Newtonsoft.Json.Linq;

namespace CenIT.ReportTourism.WebApp.Chatbot
{
    internal static class ChatbotCatalog
    {
        private static readonly Lazy<JArray> Tools = new Lazy<JArray>(() =>
            (JArray)JObject.Parse(File.ReadAllText(HostingEnvironment.MapPath("~/Chatbot/external-tools.json")))["tools"]);

        internal static bool Contains(string name) => Tools.Value.Any(t => (string)t["name"] == name);

        // Validate the scalar subset used by our catalog, keeping executable inputs and exported schemas together.
        internal static void Validate(string name, JObject input)
        {
            var tool = Tools.Value.Single(t => (string)t["name"] == name);
            var properties = (JObject)tool["inputSchema"]["properties"];
            foreach (var property in input.Properties())
            {
                var schema = properties[property.Name];
                if (schema == null) throw new ArgumentException("Unknown input: " + property.Name);
                var type = (string)schema["type"];
                var value = property.Value;
                if (type == "string")
                {
                    if (value.Type != JTokenType.String || string.IsNullOrWhiteSpace((string)value) ||
                        ((string)value).Length > (int)schema["maxLength"])
                        throw new ArgumentException("Invalid string: " + property.Name);
                }
                else if (type == "integer")
                {
                    if (value.Type != JTokenType.Integer || value.Value<long>() < (long)schema["minimum"] ||
                        value.Value<long>() > (long)schema["maximum"])
                        throw new ArgumentException("Invalid integer: " + property.Name);
                }
                else throw new InvalidOperationException("Unsupported catalog input type.");
                var choices = schema["enum"] as JArray;
                if (choices != null && !choices.Any(c => JToken.DeepEquals(c, value)))
                    throw new ArgumentException("Invalid choice: " + property.Name);
            }
        }
    }
}
