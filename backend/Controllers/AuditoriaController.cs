using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;

namespace TechCarePro.Controllers
{
    [ApiController]
    [Authorize(Roles = Perfis.Gestores)]
    [Route("api/auditoria")]
    public class AuditoriaController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentTenant _tenant;

        public AuditoriaController(AppDbContext context, ICurrentTenant tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        [HttpGet]
        public async Task<IActionResult> Listar([FromQuery] int limite = 100)
        {
            limite = Math.Clamp(limite, 1, 500);
            var q = _context.Auditorias.AsNoTracking().AsQueryable();
            if (_tenant.Perfil != Perfis.Dono) q = q.Where(a => a.LojaId == _tenant.LojaId);

            var lista = await q.OrderByDescending(a => a.Data).Take(limite).ToListAsync();
            return Ok(lista);
        }
    }
}
