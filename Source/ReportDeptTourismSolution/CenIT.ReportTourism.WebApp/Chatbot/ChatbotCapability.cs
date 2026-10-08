using System;
using System.Security.Cryptography;
using System.Text;
using System.Web;
using System.Web.Security;
using Newtonsoft.Json;

namespace CenIT.ReportTourism.WebApp.Chatbot
{
    // Separate from login tickets; only this tool executor can unprotect the capability.
    internal sealed class ChatbotCapability
    {
        public int UserId { get; set; }
        public string UserName { get; set; }
        public string BotId { get; set; }
        public DateTimeOffset ExpiresAt { get; set; }

        internal string Protect() => HttpServerUtility.UrlTokenEncode(MachineKey.Protect(
            Encoding.UTF8.GetBytes(JsonConvert.SerializeObject(this)), "SCT.Chatbot.Tools", "v1"));

        internal static ChatbotCapability Read(string token)
        {
            if (string.IsNullOrWhiteSpace(token) || token.Length > 8192) return null;
            try
            {
                var bytes = HttpServerUtility.UrlTokenDecode(token);
                if (bytes == null) return null;
                var data = MachineKey.Unprotect(bytes, "SCT.Chatbot.Tools", "v1");
                if (data == null) return null;
                var capability = JsonConvert.DeserializeObject<ChatbotCapability>(Encoding.UTF8.GetString(data));
                return capability != null && capability.UserId > 0 && !string.IsNullOrWhiteSpace(capability.UserName) &&
                    !string.IsNullOrWhiteSpace(capability.BotId) && capability.ExpiresAt > DateTimeOffset.UtcNow &&
                    capability.ExpiresAt <= DateTimeOffset.UtcNow.AddMinutes(15) ? capability : null;
            }
            catch (CryptographicException) { return null; }
            catch (FormatException) { return null; }
            catch (ArgumentException) { return null; }
            catch (JsonException) { return null; }
        }
    }
}
