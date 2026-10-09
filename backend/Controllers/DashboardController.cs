using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;

namespace TechCarePro.Controllers
{
    /// <summary>Resumo operacional (sem valores em dinheiro: esses ficam na aba Financeiro).</summary>
    [ApiController]
    [Authorize(Roles = Perfis.Loja)]
    [Route("api/dashboard")]
    public class DashboardController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentTenant _tenant;

        public DashboardController(AppDbContext context, ICurrentTenant tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var porStatus = await _context.OrdemServicos.AsNoTracking()
                .GroupBy(o => o.Status)
                .Select(g => new { Status = g.Key, Quantidade = g.Count() })
                .ToListAsync();

            object? online = null;
            if (_tenant.Perfil == Perfis.Admin)
            {
                var limite = DateTime.UtcNow.AddSeconds(-90);
                var agora = DateTime.UtcNow;
                var ativos = await _context.Sessoes.AsNoTracking()
                    .Where(s => s.LojaId == _tenant.LojaId && !s.Revogada && s.ExpiraEm > agora && s.UltimaAtividade > limite)
                    .Select(s => s.UsuarioId).Distinct().ToListAsync();
                var us = await _context.Usuarios.AsNoTracking().Where(u => ativos.Contains(u.Id)).ToListAsync();
                var perfis = await _context.UsuarioPerfis.AsNoTracking().Where(p => ativos.Contains(p.UsuarioId)).ToListAsync();
                var total = await _context.Usuarios.CountAsync(u => u.LojaId == _tenant.LojaId && u.Ativo && u.Perfil != Perfis.Dono);
                online = new
                {
                    Total = total,
                    Agora = us.Select(u =>
                    {
                        var p = perfis.FirstOrDefault(x => x.UsuarioId == u.Id);
                        return new { u.Id, Nome = string.IsNullOrWhiteSpace(p?.Nome) ? u.UsuarioNome : p!.Nome, u.Perfil, Foto = p?.FotoPerfilBase64 };
                    }).ToList()
                };
            }

            return Ok(new
            {
                Clientes = await _context.Pacientes.CountAsync(),
                Equipe = await _context.Usuarios.CountAsync(u => u.LojaId == _tenant.LojaId && u.Ativo && u.Perfil != Perfis.Dono),
                Servicos = await _context.Servicos.CountAsync(),
                Agendamentos = await _context.Agendamentos.CountAsync(),
                OrdensServico = porStatus.Sum(x => x.Quantidade),
                OrdensPorStatus = porStatus,
                Online = online
            });
        }
    }
}
