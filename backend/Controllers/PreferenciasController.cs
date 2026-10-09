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
    [Route("api/preferencias")]
    public class PreferenciasController : ControllerBase
    {
        private readonly AppDbContext _context;

        public PreferenciasController(AppDbContext context)
        {
            _context = context;
        }

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

        public class AtualizarPreferenciasRequest
        {
            public string Tema { get; set; } = "light";
            public string CorPrincipal { get; set; } = "#2563eb";
            public bool CompactarTabelas { get; set; } = false;
            public double FatorFonte { get; set; } = 1.0;
            public bool Libras { get; set; } = false;
            public bool AltoContraste { get; set; } = false;
        }

        [Authorize]
        [HttpGet("me")]
        public async Task<ActionResult<UsuarioPreferencias>> GetMe()
        {
            var usuarioId = GetUsuarioId();

            var prefs = await _context.UsuarioPreferencias
                .FirstOrDefaultAsync(p => p.UsuarioId == usuarioId);

            if (prefs is null)
            {
                prefs = new UsuarioPreferencias
                {
                    UsuarioId = usuarioId
                };

                _context.UsuarioPreferencias.Add(prefs);
                await _context.SaveChangesAsync();
            }

            return Ok(prefs);
        }

        [Authorize]
        [HttpPut("me")]
        public async Task<IActionResult> AtualizarMe(
            [FromBody] AtualizarPreferenciasRequest request)
        {
            var usuarioId = GetUsuarioId();

            var prefs = await _context.UsuarioPreferencias
                .FirstOrDefaultAsync(p => p.UsuarioId == usuarioId);

            if (prefs is null)
            {
                prefs = new UsuarioPreferencias
                {
                    UsuarioId = usuarioId
                };

                _context.UsuarioPreferencias.Add(prefs);
            }

            prefs.Tema =
                string.IsNullOrWhiteSpace(request.Tema)
                    ? "light"
                    : request.Tema;

            prefs.CorPrincipal =
                string.IsNullOrWhiteSpace(request.CorPrincipal)
                    ? "#2563eb"
                    : request.CorPrincipal;

            prefs.CompactarTabelas = request.CompactarTabelas;
            prefs.FatorFonte = request.FatorFonte <= 0 ? 1.0 : request.FatorFonte;
            prefs.Libras = request.Libras;
            prefs.AltoContraste = request.AltoContraste;

            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}