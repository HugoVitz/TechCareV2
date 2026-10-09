using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;
using TechCarePro.Services;

namespace TechCarePro.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    [EnableRateLimiting("auth")]
    public class AuthController : ControllerBase
    {
        private const int HorasDeSessao = 8;

        private readonly AppDbContext _context;
        private readonly IConfiguration _config;

        public AuthController(AppDbContext context, IConfiguration config)
        {
            _context = context;
            _config = config;
        }

        public class LoginRequest
        {
            public string Usuario { get; set; } = string.Empty;
            public string Senha { get; set; } = string.Empty;
        }

        public class TrocarSenhaRequest
        {
            public string? SenhaAtual { get; set; }
            public string NovaSenha { get; set; } = string.Empty;
        }

        // "token" é o que o front HTML e o app leem; o restante ajuda a montar a interface.
        public record AuthResponse(string Token, string Usuario, string Perfil, string? LojaNome, bool DeveTrocarSenha);

        [AllowAnonymous]
        [HttpPost("login")]
        public async Task<IActionResult> Login([FromBody] LoginRequest request)
        {
            var nome = request.Usuario?.Trim() ?? string.Empty;
            if (string.IsNullOrWhiteSpace(nome) || string.IsNullOrWhiteSpace(request.Senha))
                return BadRequest("Usuário e senha são obrigatórios.");

            var usuario = await _context.Usuarios.FirstOrDefaultAsync(u => u.UsuarioNome == nome);
            if (usuario is null || !PasswordHasher.Verify(request.Senha, usuario.SenhaHash))
                return Unauthorized("Usuário ou senha inválidos.");

            if (!usuario.Ativo)
                return StatusCode(StatusCodes.Status403Forbidden,
                    "Seu acesso está bloqueado. Fale com o administrador.");

            Loja? loja = null;
            if (usuario.LojaId.HasValue)
            {
                loja = await _context.Lojas.FirstOrDefaultAsync(l => l.Id == usuario.LojaId.Value);
                var bloqueio = await LojaRegras.VerificarAsync(_context, loja);
                if (bloqueio is not null)
                    return StatusCode(StatusCodes.Status403Forbidden, bloqueio);
            }

            return Ok(await IniciarSessaoAsync(usuario, loja));
        }

        /// <summary>Encerra a sessão atual (o token deixa de valer no servidor).</summary>
        [Authorize]
        [HttpPost("logout")]
        public async Task<IActionResult> Logout()
        {
            var sid = User.FindFirst("tc_sid")?.Value;
            var sessao = await _context.Sessoes.FirstOrDefaultAsync(s => s.Id == sid);
            if (sessao is not null && !sessao.Revogada)
            {
                LojaRegras.Revogar(sessao, "Sessão encerrada pelo usuário.");
                await _context.SaveChangesAsync();
            }
            return NoContent();
        }

        /// <summary>Troca a própria senha. Se a senha atual é temporária, não exige informá-la.</summary>
        [Authorize]
        [HttpPost("trocar-senha")]
        public async Task<IActionResult> TrocarSenha([FromBody] TrocarSenhaRequest request)
        {
            if (!int.TryParse(User.FindFirst(ClaimTypes.NameIdentifier)?.Value, out var uid))
                return Unauthorized();

            var usuario = await _context.Usuarios.FirstOrDefaultAsync(u => u.Id == uid);
            if (usuario is null) return Unauthorized();

            if (string.IsNullOrWhiteSpace(request.NovaSenha) || request.NovaSenha.Length < 6)
                return BadRequest("A nova senha deve conter no mínimo 6 caracteres.");

            if (!usuario.DeveTrocarSenha)
            {
                if (string.IsNullOrEmpty(request.SenhaAtual) ||
                    !PasswordHasher.Verify(request.SenhaAtual, usuario.SenhaHash))
                    return BadRequest("Senha atual incorreta.");
            }

            if (PasswordHasher.Verify(request.NovaSenha, usuario.SenhaHash))
                return BadRequest("A nova senha deve ser diferente da atual.");

            usuario.SenhaHash = PasswordHasher.Hash(request.NovaSenha);
            usuario.DeveTrocarSenha = false;

            // Derruba todas as sessões antigas (inclusive esta) e abre uma nova.
            await LojaRegras.RevogarSessoesDoUsuarioAsync(_context, usuario.Id, "Senha alterada. Entre novamente.");

            Loja? loja = usuario.LojaId.HasValue
                ? await _context.Lojas.FirstOrDefaultAsync(l => l.Id == usuario.LojaId.Value)
                : null;

            return Ok(await IniciarSessaoAsync(usuario, loja));
        }

        private async Task<AuthResponse> IniciarSessaoAsync(Usuario usuario, Loja? loja)
        {
            var agora = DateTime.UtcNow;
            var sessao = new Sessao
            {
                UsuarioId = usuario.Id,
                LojaId = usuario.LojaId,
                CriadaEm = agora,
                UltimaAtividade = agora,
                ExpiraEm = agora.AddHours(HorasDeSessao),
                Ip = HttpContext.Connection.RemoteIpAddress?.ToString(),
                Agente = Truncar(Request.Headers.UserAgent.ToString(), 200)
            };
            _context.Sessoes.Add(sessao);
            usuario.UltimoAcessoEm = agora;
            await _context.SaveChangesAsync();

            return new AuthResponse(CriarJwt(usuario, sessao), usuario.UsuarioNome, usuario.Perfil,
                loja?.Nome, usuario.DeveTrocarSenha);
        }

        private string CriarJwt(Usuario usuario, Sessao sessao)
        {
            var signingKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Key"]!));
            var creds = new SigningCredentials(signingKey, SecurityAlgorithms.HmacSha256);

            var claims = new List<Claim>
            {
                new(ClaimTypes.NameIdentifier, usuario.Id.ToString()),
                new(JwtRegisteredClaimNames.Sub, usuario.Id.ToString()),
                new(JwtRegisteredClaimNames.UniqueName, usuario.UsuarioNome),
                new(ClaimTypes.Name, usuario.UsuarioNome),
                new(ClaimTypes.Role, usuario.Perfil),
                new("tc_sid", sessao.Id),
                new("loja_id", (usuario.LojaId ?? 0).ToString())
            };
            if (usuario.DeveTrocarSenha) claims.Add(new Claim("must_change", "1"));

            var token = new JwtSecurityToken(
                issuer: _config["Jwt:Issuer"],
                audience: _config["Jwt:Audience"],
                claims: claims,
                expires: sessao.ExpiraEm,
                signingCredentials: creds);

            return new JwtSecurityTokenHandler().WriteToken(token);
        }

        private static string? Truncar(string? texto, int max) =>
            string.IsNullOrEmpty(texto) ? null : (texto.Length <= max ? texto : texto[..max]);
    }
}
