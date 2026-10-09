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
    public class PacientesController : ControllerBase
    {
        private readonly AppDbContext _context;

        public PacientesController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<ActionResult<List<Paciente>>> Get()
        {
            return Ok(await _context.Pacientes.AsNoTracking().ToListAsync());
        }

        [HttpPost]
        public async Task<ActionResult<Paciente>> Post(Paciente paciente)
        {
            if (!Etnias.Valida(paciente.Etnia)) return BadRequest("Etnia inválida.");
            paciente.Etnia = Etnias.Normaliza(paciente.Etnia);

            _context.Pacientes.Add(paciente);
            await _context.SaveChangesAsync();
            return Ok(paciente);
        }


        [HttpPut("{id:int}")]
        public async Task<IActionResult> Put(int id, Paciente paciente)
        {
            if (id != paciente.Id) return BadRequest("O id do body deve ser igual ao id da rota.");

            if (!Etnias.Valida(paciente.Etnia)) return BadRequest("Etnia inválida.");

            var existing = await _context.Pacientes.FirstOrDefaultAsync(p => p.Id == id);
            if (existing is null) return NotFound();

            existing.Etnia = Etnias.Normaliza(paciente.Etnia);
            existing.Nome = paciente.Nome;
            existing.Email = paciente.Email;
            existing.Telefone = paciente.Telefone;
            existing.CPF = paciente.CPF;

            await _context.SaveChangesAsync();
            return Ok(existing);
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var existing = await _context.Pacientes.FirstOrDefaultAsync(p => p.Id == id);
            if (existing is null) return NotFound();

            _context.Pacientes.Remove(existing);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}

