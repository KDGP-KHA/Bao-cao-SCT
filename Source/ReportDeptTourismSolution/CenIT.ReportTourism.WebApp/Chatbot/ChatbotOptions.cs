using System;
using System.Configuration;

namespace CenIT.ReportTourism.WebApp.Chatbot
{
    /// <summary>Server configuration for the authenticated Sở Công Thương Chatbot integration.</summary>
    public sealed class ChatbotOptions
    {
        /// <summary>Configured Chatbot identifier.</summary>
        public string BotId { get; private set; }
        internal string ApiKey { get; private set; }
        internal Uri BaseUrl { get; private set; }
        /// <summary>Public module loader URL rendered in the authenticated layout.</summary>
        public Uri WidgetLoaderUrl { get; private set; }
        /// <summary>Whether the server administrator enabled the integration.</summary>
        public static bool Enabled => string.Equals(Read("Enabled"), "true", StringComparison.OrdinalIgnoreCase);

        /// <summary>Loads and validates server settings, preferring environment variables.</summary>
        /// <returns>Validated options; missing or unsafe settings raise a configuration error.</returns>
        public static ChatbotOptions Load()
        {
            var baseUrl = HttpsUrl(Required("BaseUrl"));
            var loaderUrl = HttpsUrl(Required("WidgetLoaderUrl"));
            if (baseUrl.GetLeftPart(UriPartial.Authority) != loaderUrl.GetLeftPart(UriPartial.Authority))
                throw new ConfigurationErrorsException("Chatbot widget loader must share the Chatbot origin.");
            return new ChatbotOptions
            {
                BotId = Required("BotId"), ApiKey = Required("ApiKey"),
                BaseUrl = baseUrl, WidgetLoaderUrl = loaderUrl
            };
        }

        internal Uri ViewerSessionUrl => new Uri(BaseUrl.AbsoluteUri.TrimEnd('/') +
            "/public/bots/" + Uri.EscapeDataString(BotId) + "/viewer-session");

        private static string Read(string name) => Environment.GetEnvironmentVariable("CHATBOT_" + name.ToUpperInvariant())
            ?? ConfigurationManager.AppSettings["Chatbot:" + name];

        private static string Required(string name)
        {
            var value = Read(name);
            if (string.IsNullOrWhiteSpace(value)) throw new ConfigurationErrorsException("Missing Chatbot:" + name);
            return value.Trim();
        }

        private static Uri HttpsUrl(string value)
        {
            Uri uri;
            if (!Uri.TryCreate(value, UriKind.Absolute, out uri) || uri.Scheme != Uri.UriSchemeHttps ||
                !string.IsNullOrEmpty(uri.UserInfo) || !string.IsNullOrEmpty(uri.Fragment) || !string.IsNullOrEmpty(uri.Query))
                throw new ConfigurationErrorsException("Chatbot URLs must be absolute HTTPS URLs without credentials, query or fragment.");
            return uri;
        }
    }
}
