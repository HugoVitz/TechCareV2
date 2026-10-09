using System.Net;
using System.Net.Http.Headers;
using System.Text.Json;
using Microsoft.AspNetCore.Authentication;

namespace TechCare.Admin.Services
{
    public class UnauthorizedApiException : Exception { }

    public class ApiResult<T>
    {
        public bool Ok { get; init; }
        public T? Data { get; init; }
        public string? Error { get; init; }

        public static ApiResult<T> Success(T? data) => new() { Ok = true, Data = data };
        public static ApiResult<T> Fail(string error) => new() { Ok = false, Error = error };
    }

    /// <summary>Cliente HTTP tipado: anexa o JWT do cookie e traduz erros da API em mensagens amigáveis.</summary>
    public class ApiClient
    {
        private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
        private readonly HttpClient _http;
        private readonly IHttpContextAccessor _ctx;

        public ApiClient(HttpClient http, IHttpContextAccessor ctx)
        {
            _http = http;
            _ctx = ctx;
        }

        public Task<ApiResult<T>> GetAsync<T>(string path) => SendAsync<T>(HttpMethod.Get, path, null, true);
        public Task<ApiResult<T>> PostAsync<T>(string path, object body) => SendAsync<T>(HttpMethod.Post, path, body, true);
        public Task<ApiResult<T>> PutAsync<T>(string path, object body) => SendAsync<T>(HttpMethod.Put, path, body, true);
        public Task<ApiResult<bool>> DeleteAsync(string path) => SendAsync<bool>(HttpMethod.Delete, path, null, true);

        // Login não envia token e um 401 aqui significa "credenciais inválidas".
        public Task<ApiResult<T>> PostAnonymousAsync<T>(string path, object body) => SendAsync<T>(HttpMethod.Post, path, body, false);

        private async Task<ApiResult<T>> SendAsync<T>(HttpMethod method, string path, object? body, bool authenticated)
        {
            using var request = new HttpRequestMessage(method, path);

            if (authenticated)
            {
                var token = await _ctx.HttpContext!.GetTokenAsync("access_token");
                if (!string.IsNullOrEmpty(token))
                    request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            }

            if (body is not null)
                request.Content = JsonContent.Create(body, body.GetType(), options: Json);

            HttpResponseMessage response;
            try
            {
                response = await _http.SendAsync(request);
            }
            catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
            {
                return ApiResult<T>.Fail("Não foi possível conectar à API. Verifique se ela está em execução.");
            }

            using (response)
            {
                if (response.StatusCode == HttpStatusCode.Unauthorized && authenticated)
                    throw new UnauthorizedApiException();

                var text = await response.Content.ReadAsStringAsync();

                if (!response.IsSuccessStatusCode)
                    return ApiResult<T>.Fail(Friendly(response.StatusCode, text));

                if (response.StatusCode == HttpStatusCode.NoContent || string.IsNullOrWhiteSpace(text))
                    return ApiResult<T>.Success(typeof(T) == typeof(bool) ? (T)(object)true : default);

                try
                {
                    return ApiResult<T>.Success(JsonSerializer.Deserialize<T>(text, Json));
                }
                catch (JsonException)
                {
                    return ApiResult<T>.Fail("Resposta inesperada da API.");
                }
            }
        }

        private static string Friendly(HttpStatusCode status, string body)
        {
            if (status == HttpStatusCode.Forbidden) return "Você não tem permissão para esta ação.";
            if (status == HttpStatusCode.NotFound) return "Registro não encontrado.";
            if (status == HttpStatusCode.TooManyRequests) return "Muitas tentativas. Aguarde um minuto e tente novamente.";
            if (status == HttpStatusCode.Unauthorized) return "Usuário ou senha inválidos.";

            // ProblemDetails de validação: { "errors": { "Campo": ["mensagem"] } }
            try
            {
                using var doc = JsonDocument.Parse(body);
                if (doc.RootElement.ValueKind == JsonValueKind.Object &&
                    doc.RootElement.TryGetProperty("errors", out var errors))
                {
                    var msgs = errors.EnumerateObject()
                        .SelectMany(p => p.Value.EnumerateArray().Select(e => e.GetString()))
                        .Where(m => !string.IsNullOrWhiteSpace(m));
                    var joined = string.Join(" ", msgs);
                    if (joined.Length > 0) return joined;
                }
            }
            catch (JsonException) { /* corpo é texto puro */ }

            var plain = body.Trim().Trim('"');
            return string.IsNullOrWhiteSpace(plain) ? $"Erro {(int)status} ao chamar a API." : plain;
        }
    }
}
