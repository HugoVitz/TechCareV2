namespace TechCare.Desktop.Infra;

/// <summary>
/// Dados do usuário logado. Registrada como SINGLETON no contêiner de injeção de dependência:
/// existe uma única instância compartilhada por todas as telas.
/// </summary>
public class SessaoUsuario
{
    public string ApiUrl { get; private set; } = "http://localhost:5000/api/";
    public string Token { get; private set; } = string.Empty;
    public string Usuario { get; private set; } = string.Empty;
    public string Perfil { get; private set; } = string.Empty;
    public string? Loja { get; private set; }

    public bool Autenticada => !string.IsNullOrEmpty(Token);

    public void DefinirServidor(string url)
    {
        var limpa = (url ?? string.Empty).Trim();
        if (!limpa.StartsWith("http://", StringComparison.OrdinalIgnoreCase) &&
            !limpa.StartsWith("https://", StringComparison.OrdinalIgnoreCase))
            limpa = "http://" + limpa;
        if (!limpa.TrimEnd('/').EndsWith("/api", StringComparison.OrdinalIgnoreCase))
            limpa = limpa.TrimEnd('/') + "/api";
        ApiUrl = limpa.TrimEnd('/') + "/";
    }

    public void Iniciar(string token, string usuario, string perfil, string? loja)
    {
        Token = token;
        Usuario = usuario;
        Perfil = perfil;
        Loja = loja;
    }

    public void Encerrar()
    {
        Token = string.Empty;
        Usuario = Perfil = string.Empty;
        Loja = null;
    }
}
