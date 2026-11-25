using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;

namespace TechCare.Desktop.Infra;

/// <summary>Erro devolvido pela API, já com a mensagem pronta para o usuário.</summary>
public class ApiException : Exception
{
    public ApiException(string mensagem, HttpStatusCode? status = null) : base(mensagem) => Status = status;
    public HttpStatusCode? Status { get; }
}

/// <summary>
/// Cliente HTTP da API REST (camada de infraestrutura). Anexa o token JWT, converte JSON
/// e transforma respostas de erro em <see cref="ApiException"/> com mensagem legível.
/// </summary>
public class ApiClient
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    private readonly HttpClient _http = new() { Timeout = TimeSpan.FromSeconds(20) };
    private readonly SessaoUsuario _sessao;

    public ApiClient(SessaoUsuario sessao) => _sessao = sessao;

    public Task<T> GetAsync<T>(string caminho, CancellationToken ct = default) =>
        EnviarAsync<T>(new HttpRequestMessage(HttpMethod.Get, Url(caminho)), ct);

    public Task<T> PostAsync<T>(string caminho, object corpo, CancellationToken ct = default) =>
        EnviarAsync<T>(new HttpRequestMessage(HttpMethod.Post, Url(caminho)) { Content = JsonContent.Create(corpo, options: Json) }, ct);

    private Uri Url(string caminho) => new(new Uri(_sessao.ApiUrl), caminho.TrimStart('/'));

    private async Task<T> EnviarAsync<T>(HttpRequestMessage requisicao, CancellationToken ct)
    {
        if (_sessao.Autenticada)
            requisicao.Headers.Authorization = new AuthenticationHeaderValue("Bearer", _sessao.Token);

        HttpResponseMessage resposta;
        try
        {
            resposta = await _http.SendAsync(requisicao, ct);
        }
        catch (HttpRequestException)
        {
            throw new ApiException($"Não foi possível conectar à API em {_sessao.ApiUrl}. Verifique se o sistema está no ar.");
        }
        catch (TaskCanceledException) when (!ct.IsCancellationRequested)
        {
            throw new ApiException("A API demorou demais para responder. Tente novamente.");
        }

        using (resposta)
        {
            var texto = await resposta.Content.ReadAsStringAsync(ct);
            if (!resposta.IsSuccessStatusCode)
                throw new ApiException(ExtrairMensagem(texto, resposta.StatusCode), resposta.StatusCode);

            return JsonSerializer.Deserialize<T>(texto, Json)
                   ?? throw new ApiException("A API devolveu uma resposta vazia.");
        }
    }

    /// <summary>A API responde erros como texto, como {"mensagem": ...} ou como ProblemDetails.</summary>
    private static string ExtrairMensagem(string corpo, HttpStatusCode status)
    {
        try
        {
            using var doc = JsonDocument.Parse(corpo);
            var raiz = doc.RootElement;
            if (raiz.ValueKind == JsonValueKind.String) return raiz.GetString() ?? status.ToString();
            if (raiz.ValueKind == JsonValueKind.Object)
            {
                if (raiz.TryGetProperty("mensagem", out var m)) return m.GetString() ?? status.ToString();
                if (raiz.TryGetProperty("title", out var t)) return t.GetString() ?? status.ToString();
            }
        }
        catch (JsonException)
        {
            if (!string.IsNullOrWhiteSpace(corpo)) return corpo;
        }

        return status switch
        {
            HttpStatusCode.Unauthorized => "Sessão expirada ou usuário/senha inválidos. Entre novamente.",
            HttpStatusCode.Forbidden => "Seu perfil não tem acesso a esta função.",
            _ => $"A API respondeu {(int)status} ({status})."
        };
    }
}
