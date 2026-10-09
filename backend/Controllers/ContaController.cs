using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using TechCarePro.Api.Data;
using TechCarePro.Models;

namespace TechCarePro.Controllers
{
    [ApiController]
    [Route("api/conta")]
    public class ContaController : ControllerBase
    {
        private readonly AppDbContext _context;

        public ContaController(AppDbContext context)
        {
            _context = context;
        }

        private const int FotoMaxChars = 700_000; // ~500 KB em base64

        private int GetUsuarioId()
        {
            var idClaim =
                User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                ?? User.FindFirst("sub")?.Value
                ?? User.FindFirst(JwtRegisteredClaimNames.Sub)?.Value;

            if (!int.TryParse(idClaim, out var id))
                throw new UnauthorizedAccessException("Usuário não autenticado.");

            return id;
        }

        public class AtualizarPerfilRequest
        {
            public string Nome { get; set; } = string.Empty;
            public string Cargo { get; set; } = string.Empty;
            public string? Etnia { get; set; }
        }

        public class AtualizarFotoRequest
        {
            // Espera base64 como data URL ou base64 puro
            public string FotoPerfilBase64 { get; set; } = string.Empty;
        }

        /// <summary>Batimento de presença: o site/app avisa a cada ~30 s que a pessoa está com o sistema aberto.</summary>
        [Authorize]
        [HttpPost("presenca")]
        public async Task<IActionResult> Presenca()
        {
            var sessao = await SessaoAtualAsync();
            if (sessao is null) return NoContent();
            sessao.UltimaAtividade = DateTime.UtcNow;
            await _context.SaveChangesAsync();
            return NoContent();
        }

        /// <summary>Chamado ao fechar a página/app: a pessoa some de "online" na hora. A sessão continua válida (reabrir não pede login).</summary>
        [Authorize]
        [HttpPost("saiu")]
        public async Task<IActionResult> Saiu()
        {
            var sessao = await SessaoAtualAsync();
            if (sessao is null) return NoContent();
            sessao.UltimaAtividade = DateTime.UtcNow.AddHours(-1);
            await _context.SaveChangesAsync();
            return NoContent();
        }

        private async Task<Sessao?> SessaoAtualAsync()
        {
            var sid = User.FindFirst("tc_sid")?.Value;
            return string.IsNullOrWhiteSpace(sid) ? null : await _context.Sessoes.FirstOrDefaultAsync(s => s.Id == sid);
        }

        [Authorize]
        [HttpGet("me")]
        public async Task<ActionResult<object>> GetMe()
        {
            var usuarioId = GetUsuarioId();

            var perfil = await _context.UsuarioPerfis
                .FirstOrDefaultAsync(p => p.UsuarioId == usuarioId);

            var usuario = await _context.Usuarios
                .AsNoTracking()
                .FirstOrDefaultAsync(u => u.Id == usuarioId);

            if (usuario is null)
                return Unauthorized();

            var loja = usuario.LojaId.HasValue
                ? await _context.Lojas.AsNoTracking().FirstOrDefaultAsync(l => l.Id == usuario.LojaId.Value)
                : null;

            var liderId = usuario.LojaId.HasValue
                ? await TechCarePro.Services.RankingService.LiderDoMesAsync(_context, usuario.LojaId.Value)
                : null;

            return Ok(new
            {
                usuarioId = usuarioId,
                lider = liderId == usuarioId,
                nome = perfil?.Nome ?? usuario.UsuarioNome,
                cargo = perfil?.Cargo ?? "",
                fotoPerfilBase64 = perfil?.FotoPerfilBase64,
                etnia = perfil?.Etnia,
                usuario = usuario.UsuarioNome,
                perfil = usuario.Perfil,
                lojaId = usuario.LojaId,
                lojaNome = loja?.Nome,
                deveTrocarSenha = usuario.DeveTrocarSenha
            });
        }

        [Authorize]
        [HttpPut("me")]
        public async Task<IActionResult> AtualizarPerfil(
            [FromBody] AtualizarPerfilRequest request)
        {
            var usuarioId = GetUsuarioId();

            request.Nome = request.Nome?.Trim() ?? string.Empty;
            request.Cargo = request.Cargo?.Trim() ?? string.Empty;

            if (string.IsNullOrWhiteSpace(request.Nome))
                return BadRequest("Nome é obrigatório.");
            if (!Etnias.Valida(request.Etnia))
                return BadRequest("Etnia inválida.");

            var perfil = await _context.UsuarioPerfis
                .FirstOrDefaultAsync(p => p.UsuarioId == usuarioId);

            if (perfil is null)
            {
                perfil = new UsuarioPerfil
                {
                    UsuarioId = usuarioId,
                    Nome = request.Nome,
                    Cargo = request.Cargo,
                    Etnia = Etnias.Normaliza(request.Etnia)
                };

                _context.UsuarioPerfis.Add(perfil);
            }
            else
            {
                perfil.Nome = request.Nome;
                perfil.Cargo = request.Cargo;
                perfil.Etnia = Etnias.Normaliza(request.Etnia);
            }

            await _context.SaveChangesAsync();

            return NoContent();
        }

        [Authorize]
        [HttpPut("foto")]
        public async Task<IActionResult> AtualizarFoto(
            [FromBody] AtualizarFotoRequest request)
        {
            var usuarioId = GetUsuarioId();

            request.FotoPerfilBase64 =
                request.FotoPerfilBase64?.Trim() ?? string.Empty;

            // Vazio = remover a foto.
            if (request.FotoPerfilBase64.Length > FotoMaxChars)
                return BadRequest("Imagem muito grande. Escolha uma foto menor.");
            if (request.FotoPerfilBase64.Length > 0 && !request.FotoPerfilBase64.StartsWith("data:image/"))
                return BadRequest("Envie uma imagem válida.");
            var novaFoto = request.FotoPerfilBase64.Length == 0 ? null : request.FotoPerfilBase64;

            var perfil = await _context.UsuarioPerfis
                .FirstOrDefaultAsync(p => p.UsuarioId == usuarioId);

            if (perfil is null)
            {
                perfil = new UsuarioPerfil
                {
                    UsuarioId = usuarioId,
                    Nome = "",
                    Cargo = "",
                    FotoPerfilBase64 = novaFoto
                };

                _context.UsuarioPerfis.Add(perfil);
            }
            else
            {
                perfil.FotoPerfilBase64 = novaFoto;
            }

            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}