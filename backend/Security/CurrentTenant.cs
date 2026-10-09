using System.Security.Claims;

namespace TechCarePro.Security
{
    /// <summary>Quem está fazendo a requisição (lido do JWT já validado).</summary>
    public interface ICurrentTenant
    {
        /// <summary>Loja do usuário logado. 0 = sem loja (Dono, login, inicialização).</summary>
        int LojaId { get; }
        int UsuarioId { get; }
        string UsuarioNome { get; }
        string Perfil { get; }
        string? SessaoId { get; }
    }

    public class CurrentTenant : ICurrentTenant
    {
        private readonly IHttpContextAccessor _http;

        public CurrentTenant(IHttpContextAccessor http) => _http = http;

        private ClaimsPrincipal? User => _http.HttpContext?.User;

        private string? Claim(string type) => User?.FindFirst(type)?.Value;

        public int LojaId => int.TryParse(Claim("loja_id"), out var v) ? v : 0;
        public int UsuarioId => int.TryParse(Claim(ClaimTypes.NameIdentifier), out var v) ? v : 0;
        public string UsuarioNome => Claim(ClaimTypes.Name) ?? string.Empty;
        public string Perfil => Claim(ClaimTypes.Role) ?? string.Empty;
        public string? SessaoId => Claim("tc_sid");
    }
}
