using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;
using TechCarePro.Services;

namespace TechCarePro.Controllers
{
    /// <summary>Usuários conectados agora (sessões ativas) e botão de derrubar.</summary>
    [ApiController]
    [Authorize(Roles = Perfis.Gestores)]
    [Route("api/sessoes")]
    public class SessoesController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentTenant _tenant;

        public SessoesController(AppDbContext context, ICurrentTenant tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        private bool EhDono => _tenant.Perfil == Perfis.Dono;

        private IQueryable<Sessao> Escopo(int? lojaId)
        {
            var q = _context.Sessoes.AsQueryable();
            if (EhDono) return lojaId.HasValue ? q.Where(s => s.LojaId == lojaId.Value) : q;
            return q.Where(s => s.LojaId == _tenant.LojaId);
        }

        [HttpGet]
        public async Task<IActionResult> Listar([FromQuery] int? lojaId = null)
        {
            var agora = DateTime.UtcNow;
            var sessoes = await Escopo(lojaId).AsNoTracking()
                .Where(s => !s.Revogada && s.ExpiraEm > agora)
                .OrderByDescending(s => s.UltimaAtividade)
                .ToListAsync();

            var ids = sessoes.Select(s => s.UsuarioId).Distinct().ToList();
            var usuarios = await _context.Usuarios.AsNoTracking()
                .Where(u => ids.Contains(u.Id))
                .Select(u => new { u.Id, u.UsuarioNome, u.Perfil })
                .ToListAsync();
            var perfis = await _context.UsuarioPerfis.AsNoTracking()
                .Where(p => ids.Contains(p.UsuarioId))
                .Select(p => new { p.UsuarioId, p.Nome, p.Cargo })
                .ToListAsync();
            var lojas = await _context.Lojas.AsNoTracking().ToDictionaryAsync(l => l.Id, l => l.Nome);

            return Ok(sessoes.Select(s =>
            {
                var u = usuarios.FirstOrDefault(x => x.Id == s.UsuarioId);
                var p = perfis.FirstOrDefault(x => x.UsuarioId == s.UsuarioId);
                return new
                {
                    s.Id,
                    s.UsuarioId,
                    UsuarioNome = u?.UsuarioNome ?? "?",
                    Nome = string.IsNullOrWhiteSpace(p?.Nome) ? u?.UsuarioNome : p!.Nome,
                    Cargo = p?.Cargo ?? "",
                    Perfil = u?.Perfil,
                    LojaNome = s.LojaId.HasValue && lojas.TryGetValue(s.LojaId.Value, out var ln) ? ln : null,
                    s.CriadaEm,
                    s.UltimaAtividade,
                    Online = s.UltimaAtividade > agora.AddMinutes(-5),
                    s.Ip,
                    s.Agente,
                    Atual = s.Id == _tenant.SessaoId
                };
            }));
        }

        [HttpDelete("{id}")]
        public async Task<IActionResult> Derrubar(string id)
        {
            var sessao = await Escopo(null).FirstOrDefaultAsync(s => s.Id == id);
            if (sessao is null) return NotFound();
            if (sessao.Id == _tenant.SessaoId)
                return BadRequest("Para encerrar a sua própria sessão use o botão Sair.");

            LojaRegras.Revogar(sessao, "Sua sessão foi encerrada pelo administrador.");
            AuditoriaService.Registrar(_context, _tenant, "Sessão derrubada", $"sessão de usuário #{sessao.UsuarioId}", sessao.LojaId);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}
