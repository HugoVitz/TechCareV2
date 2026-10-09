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
    public class AgendamentosController : ControllerBase
    {
        private readonly AppDbContext _context;

        public AgendamentosController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<ActionResult<List<Agendamento>>> Get()
        {
            return Ok(await _context.Agendamentos.AsNoTracking().ToListAsync());
        }

        [HttpPost]
        public async Task<ActionResult<Agendamento>> Post(Agendamento agendamento)
        {
            _context.Agendamentos.Add(agendamento);
            await _context.SaveChangesAsync();
            return Ok(agendamento);
        }

        [HttpPut("{id:int}")]
        public async Task<IActionResult> Put(int id, Agendamento agendamento)
        {
            if (id != agendamento.Id) return BadRequest("O id do body deve ser igual ao id da rota.");

            var existing = await _context.Agendamentos.FirstOrDefaultAsync(a => a.Id == id);
            if (existing is null) return NotFound();

            existing.PacienteNome = agendamento.PacienteNome;
            existing.ProfissionalNome = agendamento.ProfissionalNome;
            existing.DataHora = agendamento.DataHora;
            existing.Status = agendamento.Status;

            await _context.SaveChangesAsync();
            return Ok(existing);
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var existing = await _context.Agendamentos.FirstOrDefaultAsync(a => a.Id == id);
            if (existing is null) return NotFound();

            _context.Agendamentos.Remove(existing);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}

