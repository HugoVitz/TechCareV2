using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;
using TechCarePro.Services;

namespace TechCarePro.Controllers
{
    [ApiController]
    [Authorize(Roles = Perfis.Loja)]
    [Route("api/ranking")]
    public class RankingController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentTenant _tenant;

        public RankingController(AppDbContext context, ICurrentTenant tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        /// <summary>Ranking do mês (padrão: mês atual). Atendente vê posição e vendas; é o que motiva a equipe.</summary>
        [HttpGet]
        public async Task<IActionResult> Get([FromQuery] string? mes = null)
        {
            var hoje = DateTime.Now;
            int ano = hoje.Year, m = hoje.Month;
            if (!string.IsNullOrWhiteSpace(mes))
            {
                var partes = mes.Split('-');
                if (partes.Length != 2 || !int.TryParse(partes[0], out ano) || !int.TryParse(partes[1], out m) || m < 1 || m > 12 || ano < 2000 || ano > 2100)
                    return BadRequest("Mês inválido. Use o formato AAAA-MM.");
            }

            var itens = await RankingService.CalcularAsync(_context, _tenant.LojaId, ano, m, true);
            var lider = itens.FirstOrDefault(i => i.TotalVendido > 0)?.UsuarioId;

            // Valores em dinheiro ficam só na aba Financeiro (Administrador): aqui só posição e quantidade de OS.
            foreach (var i in itens) i.TotalVendido = 0;

            return Ok(new
            {
                Mes = $"{ano:0000}-{m:00}",
                LiderId = lider,
                MeuId = _tenant.UsuarioId,
                Itens = itens
            });
        }
    }
}
