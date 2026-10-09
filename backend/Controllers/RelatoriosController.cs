using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;

namespace TechCarePro.Controllers
{
    /// <summary>
    /// Relatório de diversidade com números agregados (sem nomes). A etnia é autodeclarada,
    /// opcional e usada só para este fim (LGPD, art. 11).
    /// </summary>
    [ApiController]
    [Authorize(Roles = Perfis.Gestores)]
    [Route("api/relatorios")]
    public class RelatoriosController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentTenant _tenant;

        public RelatoriosController(AppDbContext context, ICurrentTenant tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        private static List<object> Agrupar(IEnumerable<string?> valores)
        {
            var lista = valores.ToList();
            var grupos = Etnias.Todas
                .Select(e => new { Etnia = e, Quantidade = lista.Count(v => v == e) })
                .ToList();
            var semDeclaracao = lista.Count(v => string.IsNullOrWhiteSpace(v));

            var saida = grupos.Select(g => (object)g).ToList();
            saida.Add(new { Etnia = "Não declarada", Quantidade = semDeclaracao });
            return saida;
        }

        [HttpGet("diversidade")]
        public async Task<IActionResult> Diversidade([FromQuery] int? lojaId = null)
        {
            var dono = _tenant.Perfil == Perfis.Dono;

            IQueryable<Paciente> clientes = dono ? _context.Pacientes.IgnoreQueryFilters() : _context.Pacientes;
            if (dono && lojaId.HasValue) clientes = clientes.Where(c => c.LojaId == lojaId.Value);

            var etniasClientes = await clientes.AsNoTracking().Select(c => c.Etnia).ToListAsync();

            var usuarios = _context.Usuarios.AsNoTracking().Where(u => u.Perfil != Perfis.Dono);
            if (dono) { if (lojaId.HasValue) usuarios = usuarios.Where(u => u.LojaId == lojaId.Value); }
            else usuarios = usuarios.Where(u => u.LojaId == _tenant.LojaId);

            var etniasEquipe = await (from u in usuarios
                                      join p in _context.UsuarioPerfis.AsNoTracking() on u.Id equals p.UsuarioId into pj
                                      from p in pj.DefaultIfEmpty()
                                      select p == null ? null : p.Etnia).ToListAsync();

            return Ok(new
            {
                Clientes = new { Total = etniasClientes.Count, PorEtnia = Agrupar(etniasClientes) },
                Equipe = new { Total = etniasEquipe.Count, PorEtnia = Agrupar(etniasEquipe) },
                Observacao = "Dados autodeclarados e opcionais, exibidos apenas de forma agregada, para apoiar ações de inclusão e diversidade."
            });
        }
    }
}
