using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;

namespace TechCarePro.Controllers
{
    /// <summary>Equipe da loja (atendentes e administradores ativos), para escolher o responsável em OS e agendamentos.</summary>
    [ApiController]
    [Authorize(Roles = Perfis.Loja)]
    [Route("api/equipe")]
    public class EquipeController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentTenant _tenant;

        public EquipeController(AppDbContext context, ICurrentTenant tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            var us = await _context.Usuarios.AsNoTracking()
                .Where(u => u.LojaId == _tenant.LojaId && u.Ativo && u.Perfil != Perfis.Dono)
                .ToListAsync();
            var ids = us.Select(u => u.Id).ToList();
            var perfis = await _context.UsuarioPerfis.AsNoTracking().Where(p => ids.Contains(p.UsuarioId)).ToListAsync();

            return Ok(us.Select(u =>
            {
                var p = perfis.FirstOrDefault(x => x.UsuarioId == u.Id);
                return new
                {
                    u.Id,
                    Nome = string.IsNullOrWhiteSpace(p?.Nome) ? u.UsuarioNome : p!.Nome,
                    Cargo = p?.Cargo ?? "",
                    u.Perfil
                };
            }).OrderBy(x => x.Nome));
        }
    }
}
