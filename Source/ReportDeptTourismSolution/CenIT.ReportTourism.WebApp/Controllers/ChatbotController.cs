using System;
using System.Configuration;
using System.Data.SqlClient;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Http;
using System.Security.Authentication;
using System.Security.Cryptography;
using System.Text;
using System.Threading.Tasks;
using System.Web;
using System.Web.Helpers;
using System.Web.Mvc;
using System.Web.Security;
using CenIT.ReportTourism.Biz.Sys;
using CenIT.ReportTourism.WebApp.Chatbot;
using Newtonsoft.Json;
using Newtonsoft.Json.Linq;
using TSFramework.App.Processors;

namespace CenIT.ReportTourism.WebApp.Controllers
{
    /// <summary>Connects authenticated Sở Công Thương users to the Chatbot and executes approved read-only tools.</summary>
    public sealed class ChatbotController : Controller
    {
        private const int MaxRequestBytes = 16384;
        private const int MaxResponseBytes = 256 * 1024;
        // Redirects must not forward the integration secret to an unexpected endpoint.
        // The 4.5.2 HTTP compatibility mode can retain legacy TLS defaults.
        // Set TLS 1.2 on this client only; do not mutate process-wide protocols
        // used by SmartCA/other integrations or bypass certificate validation.
        private static readonly HttpClient Client = new HttpClient(new HttpClientHandler
        {
            AllowAutoRedirect = false,
            SslProtocols = SslProtocols.Tls12
        })
        {
            Timeout = TimeSpan.FromSeconds(10), MaxResponseContentBufferSize = MaxResponseBytes
        };

        /// <summary>Issues a viewer token using the existing, verified Forms Authentication login.</summary>
        /// <returns>A viewer token and expiry, or a JSON authentication/configuration/upstream error.</returns>
        [HttpPost]
        public async Task<ActionResult> Session()
        {
            NoStore();
            if (!ChatbotOptions.Enabled) return Error(503, "Chatbot is disabled.");
            try
            {
                var cookie = Request.Cookies[FormsAuthentication.FormsCookieName];
                var ticket = cookie == null ? null : FormsAuthentication.Decrypt(cookie.Value);
                if (ticket == null || ticket.Expired || string.IsNullOrWhiteSpace(ticket.Name))
                    return Error(401, "Login is required.");
                // Login tickets in this application do not reliably populate UserId, so resolve it server-side.
                var user = new SysUserBiz().GetByUserName(ticket.Name);
                if (user == null || !user.IsActive || user.UserId.GetValueOrDefault() <= 0)
                    return Error(401, "Login is no longer valid.");
                try
                {
                    AntiForgery.Validate(Request.Cookies[AntiForgeryConfig.CookieName]?.Value, Request.Headers["X-CSRF-Token"]);
                }
                catch (HttpAntiForgeryException) { return Error(400, "Invalid anti-forgery token."); }
                new ChatbotAccess(user.UserId.GetValueOrDefault(), user.UserName);
                var options = ChatbotOptions.Load();
                var expiry = new DateTimeOffset(ticket.Expiration.ToUniversalTime());
                if (expiry > DateTimeOffset.UtcNow.AddMinutes(15)) expiry = DateTimeOffset.UtcNow.AddMinutes(15);
                var capability = new ChatbotCapability
                {
                    UserId = user.UserId.Value, UserName = user.UserName, BotId = options.BotId, ExpiresAt = expiry
                };
                using (var request = new HttpRequestMessage(HttpMethod.Post, options.ViewerSessionUrl))
                {
                    request.Headers.Add("x-api-key", options.ApiKey);
                    request.Content = new StringContent(JsonConvert.SerializeObject(new
                    {
                        subjectId = user.UserId.Value.ToString(CultureInfo.InvariantCulture),
                        toolCapability = new { token = capability.Protect(), expiresAt = expiry }
                    }), Encoding.UTF8, "application/json");
                    using (var response = await Client.SendAsync(request))
                    {
                        if (!response.IsSuccessStatusCode)
                        {
                            AppProcessor.Logger.Message("Chatbot viewer-session upstream HTTP status: " + (int)response.StatusCode);
                            return Error(502, "Chatbot viewer-session request failed.");
                        }
                        var envelope = JObject.Parse(await response.Content.ReadAsStringAsync());
                        var data = envelope["data"] as JObject;
                        DateTimeOffset viewerExpiry;
                        var viewerToken = (string)data?["viewerToken"];
                        if (string.IsNullOrWhiteSpace(viewerToken) || viewerToken.Length > 4096 ||
                            !DateTimeOffset.TryParse((string)data?["expiresAt"], CultureInfo.InvariantCulture,
                                DateTimeStyles.AssumeUniversal, out viewerExpiry) || viewerExpiry <= DateTimeOffset.UtcNow)
                            return Error(502, "Chatbot returned an invalid viewer session.");
                        return Output(new { viewerToken, expiresAt = viewerExpiry < expiry ? viewerExpiry : expiry });
                    }
                }
            }
            catch (ConfigurationErrorsException exception) { LogFailure(exception); return Error(503, "Chatbot configuration is incomplete."); }
            catch (HttpException exception) { return Error(exception.GetHttpCode(), exception.Message); }
            catch (CryptographicException) { return Error(401, "Invalid login cookie."); }
            catch (ArgumentException) { return Error(401, "Invalid login cookie."); }
            catch (HttpRequestException exception) { LogTransportFailure(exception); return Error(502, "Chatbot is unavailable."); }
            catch (TaskCanceledException) { return Error(502, "Chatbot session request timed out."); }
            catch (JsonException) { return Error(502, "Chatbot returned an invalid response."); }
            catch (Exception exception) { LogFailure(exception); return DatabaseFailure(exception) ?? Error(500, "Could not create a Chatbot session."); }
        }

        /// <summary>Validates a capability and executes an approved tool using its server-issued user identity.</summary>
        /// <returns>A bounded JSON object with result, or a JSON validation/authorization error.</returns>
        [HttpPost]
        public async Task<ActionResult> Tools()
        {
            NoStore();
            if (!ChatbotOptions.Enabled) return Error(503, "Chatbot is disabled.");
            try
            {
                var authorization = Request.Headers["Authorization"];
                var capability = authorization != null && authorization.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                    ? ChatbotCapability.Read(authorization.Substring(7).Trim()) : null;
                if (capability == null) return Error(401, "Invalid or expired capability.");
                var options = ChatbotOptions.Load();
                if (capability.BotId != options.BotId) return Error(403, "Bot is not allowed.");
                if (Request.ContentType == null || !string.Equals(Request.ContentType.Split(';')[0].Trim(), "application/json", StringComparison.OrdinalIgnoreCase))
                    return Error(415, "Content-Type must be application/json.");
                if (Request.ContentLength > MaxRequestBytes) return Error(413, "Tool request is too large.");
                string body;
                using (var reader = new StreamReader(Request.InputStream, Encoding.UTF8))
                {
                    var buffer = new char[MaxRequestBytes + 1];
                    var count = await reader.ReadBlockAsync(buffer, 0, buffer.Length);
                    body = new string(buffer, 0, count);
                    if (Encoding.UTF8.GetByteCount(body) > MaxRequestBytes) return Error(413, "Tool request is too large.");
                }
                var call = JsonConvert.DeserializeObject<ToolCall>(body, new JsonSerializerSettings
                {
                    MissingMemberHandling = MissingMemberHandling.Error, MaxDepth = 10, DateParseHandling = DateParseHandling.None
                });
                if (call == null || call.Version != 1 || string.IsNullOrWhiteSpace(call.ToolCallId) || call.ToolCallId.Length > 200 ||
                    Request.Headers["Idempotency-Key"] != call.ToolCallId || call.Input == null)
                    return Error(400, "Invalid tool request or Idempotency-Key.");
                if (call.SubjectId != capability.UserId.ToString(CultureInfo.InvariantCulture))
                    return Error(401, "Capability does not belong to this subject.");
                if (call.BotId != capability.BotId || !ChatbotCatalog.Contains(call.ToolName))
                    return Error(403, "Bot or tool is not allowed.");
                // Only read-only tools are exposed; replay does not mutate application data.
                var execution = Task.Run(() =>
                {
                    var user = new SysUserBiz().GetById(capability.UserId);
                    if (user == null || !user.IsActive || user.UserId.GetValueOrDefault() != capability.UserId || user.UserName != capability.UserName)
                        throw new HttpException(401, "User is no longer active.");
                    return new ChatbotTools().Execute(call.ToolName, user.UserId.GetValueOrDefault(), user.UserName, call.Input);
                });
                if (await Task.WhenAny(execution, Task.Delay(TimeSpan.FromSeconds(12))) != execution)
                {
                    // Existing synchronous stored procedures cannot be cancelled. Observe eventual faults;
                    // never wait beyond the Chatbot deadline or run a write operation here.
                    var faultObserver = execution.ContinueWith(task => LogFailure(task.Exception), TaskContinuationOptions.OnlyOnFaulted);
                    return Error(504, "Tool query timed out; narrow the query and retry.");
                }
                return Output(new { result = await execution });
            }
            catch (ConfigurationErrorsException exception) { LogFailure(exception); return Error(503, "Chatbot configuration is incomplete."); }
            catch (JsonException) { return Error(400, "Invalid JSON tool request."); }
            catch (ArgumentException exception) { return Error(400, exception.Message); }
            catch (OverflowException) { return Error(400, "Input number is outside the supported range."); }
            catch (HttpException exception) { return Error(exception.GetHttpCode(), exception.Message); }
            catch (Exception exception)
            {
                LogFailure(exception);
                return DatabaseFailure(exception) ?? Error(500, "Tool execution failed.");
            }
        }

        private ActionResult DatabaseFailure(Exception exception)
        {
            for (var cause = exception; cause != null; cause = cause.InnerException)
            {
                var sql = cause as SqlException;
                if (sql == null) continue;
                if (sql.Number >= 50110 && sql.Number <= 50113)
                    return Error(403, "Account or enterprise access denied.");
                if (sql.Number == 2812 || sql.Number == 201 || sql.Number == 8144 || sql.Number == 207 || sql.Number == 208 || sql.Number == 4121)
                    return Error(503, "Chatbot database procedures are missing or incompatible. Apply the reviewed SQL deployment scripts.");
            }
            return null;
        }

        private void NoStore()
        {
            Response.SuppressFormsAuthenticationRedirect = true;
            Response.TrySkipIisCustomErrors = true;
            Response.Cache.SetCacheability(HttpCacheability.NoCache);
            Response.Cache.SetNoStore();
        }

        private ActionResult Output(object value)
        {
            var json = JsonConvert.SerializeObject(value, ChatbotTools.JsonSettings);
            if (Encoding.UTF8.GetByteCount(json) > MaxResponseBytes) return Error(413, "Tool result is too large; narrow the query.");
            return Content(json, "application/json", Encoding.UTF8);
        }

        private ActionResult Error(int status, string message)
        {
            Response.StatusCode = status;
            return Content(JsonConvert.SerializeObject(new { error = message }), "application/json", Encoding.UTF8);
        }

        private static void LogFailure(Exception exception) => AppProcessor.Logger.Message("Chatbot failure: " + exception.GetType().Name);

        private static void LogTransportFailure(Exception exception)
        {
            // Exception messages/requests can contain upstream URLs and credentials.
            // Record only exception types and the transport status for diagnosis.
            var diagnostic = new StringBuilder("Chatbot viewer-session transport failure [client TLS=Tls12]");
            for (var cause = exception; cause != null; cause = cause.InnerException)
            {
                diagnostic.Append(" -> ").Append(cause.GetType().Name);
                var webException = cause as WebException;
                if (webException != null) diagnostic.Append(" (").Append(webException.Status).Append(")");
            }
            AppProcessor.Logger.Message(diagnostic.ToString());
        }

        private sealed class ToolCall
        {
            public int Version { get; set; }
            public string BotId { get; set; }
            public string SubjectId { get; set; }
            public string ToolCallId { get; set; }
            public string ToolName { get; set; }
            public JObject Input { get; set; }
        }
    }
}
