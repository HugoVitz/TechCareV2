using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;

namespace TechCarePro.Controllers
{
    /// <summary>Endpoint público para o app, o painel e o front testarem se a API e o banco estão no ar.</summary>
    [ApiController]
    [AllowAnonymous]
    [Route("api/health")]
    public class HealthController : ControllerBase
    {
        private readonly AppDbContext _context;

        public HealthController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> Get()
        {
            bool bancoOk;
            try
            {
                bancoOk = await _context.Database.CanConnectAsync();
            }
            catch
            {
                bancoOk = false;
            }

            var resposta = new
            {
                api = "ok",
                banco = bancoOk ? "ok" : "erro",
                hora = DateTime.UtcNow
            };

            return bancoOk ? Ok(resposta) : StatusCode(StatusCodes.Status503ServiceUnavailable, resposta);
        }
    }
}
