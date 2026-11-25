using TechCare.Desktop.Infra;
using TechCare.Desktop.Mvvm;

namespace TechCare.Desktop.ViewModels;

/// <summary>Tela de login. A senha chega como parâmetro (o PasswordBox do WPF não permite binding, por segurança).</summary>
public class LoginViewModel : ObservableObject
{
    private sealed record LoginResposta(string Token, string Usuario, string Perfil, string? LojaNome, bool DeveTrocarSenha);

    private readonly ApiClient _api;
    private readonly SessaoUsuario _sessao;
    private string _servidor = "http://localhost:5000";
    private string _usuario = string.Empty;
    private string _mensagem = string.Empty;
    private bool _ocupado;

    public LoginViewModel(ApiClient api, SessaoUsuario sessao)
    {
        _api = api;
        _sessao = sessao;
    }

    public string Servidor { get => _servidor; set => SetProperty(ref _servidor, value); }
    public string Usuario { get => _usuario; set => SetProperty(ref _usuario, value); }
    public string Mensagem { get => _mensagem; set => SetProperty(ref _mensagem, value); }
    public bool Ocupado { get => _ocupado; set => SetProperty(ref _ocupado, value); }

    /// <summary>Retorna true quando o login foi aceito e o usuário é Administrador.</summary>
    public async Task<bool> EntrarAsync(string senha)
    {
        if (string.IsNullOrWhiteSpace(Usuario) || string.IsNullOrEmpty(senha))
        {
            Mensagem = "Informe usuário e senha.";
            return false;
        }

        Ocupado = true;
        Mensagem = "Entrando...";
        try
        {
            _sessao.DefinirServidor(Servidor);
            var r = await _api.PostAsync<LoginResposta>("auth/login", new { usuario = Usuario.Trim(), senha });

            if (r.DeveTrocarSenha)
            {
                Mensagem = "Sua senha é provisória. Defina uma nova senha pelo sistema web antes de usar o desktop.";
                return false;
            }
            if (!string.Equals(r.Perfil, "Admin", StringComparison.OrdinalIgnoreCase))
            {
                Mensagem = "O módulo desktop é exclusivo do Administrador da loja.";
                return false;
            }

            _sessao.Iniciar(r.Token, r.Usuario, r.Perfil, r.LojaNome);
            Mensagem = string.Empty;
            return true;
        }
        catch (ApiException ex)
        {
            Mensagem = ex.Message;
            return false;
        }
        finally
        {
            Ocupado = false;
        }
    }
}
