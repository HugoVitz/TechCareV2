using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Security;
using TechCarePro.Models;

namespace TechCarePro.Controllers
{
    [ApiController]
    [Authorize(Roles = Perfis.Loja)]
    [Route("api/[controller]")]
    public class ServicosController : ControllerBase
    {
        private readonly AppDbContext _context;

        public ServicosController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<ActionResult<List<Servico>>> Get()
        {
            return Ok(await _context.Servicos.AsNoTracking().ToListAsync());
        }

        [Authorize(Roles = Perfis.Admin)]
        [HttpPost]
        public async Task<ActionResult<Servico>> Post(Servico servico)
        {
            _context.Servicos.Add(servico);
            await _context.SaveChangesAsync();
            return Ok(servico);
        }

        [Authorize(Roles = Perfis.Admin)]
        [HttpPut("{id:int}")]
        public async Task<IActionResult> Put(int id, Servico servico)
        {
            if (id != servico.Id) return BadRequest("O id do body deve ser igual ao id da rota.");

            var existing = await _context.Servicos.FirstOrDefaultAsync(s => s.Id == id);
            if (existing is null) return NotFound();

            existing.Titulo = servico.Titulo;
            existing.Descricao = servico.Descricao;
            existing.Valor = servico.Valor;

            await _context.SaveChangesAsync();
            return Ok(existing);
        }

        [Authorize(Roles = Perfis.Admin)]
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var existing = await _context.Servicos.FirstOrDefaultAsync(s => s.Id == id);
            if (existing is null) return NotFound();

            _context.Servicos.Remove(existing);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}

