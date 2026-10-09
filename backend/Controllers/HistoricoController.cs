using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Models;

namespace TechCarePro.Controllers
{
    /// <summary>Histórico de ordens de serviço com filtros e totais (somente Administrador). Alimenta as telas e as exportações Excel/PDF.</summary>
    [ApiController]
    [Authorize(Roles = Perfis.Admin)]
    [Route("api/historico")]
    public class HistoricoController : ControllerBase
    {
        private readonly AppDbContext _context;

        public HistoricoController(AppDbContext context)
        {
            _context = context;
        }

        [HttpGet]
        public async Task<IActionResult> Get(
            [FromQuery] DateTime? de = null,
            [FromQuery] DateTime? ate = null,
            [FromQuery] string? status = null,
            [FromQuery] string? pagamento = null,
            [FromQuery] int? vendedorId = null,
            [FromQuery] string? q = null)
        {
            var query = _context.OrdemServicos.AsNoTracking()
                .Include(o => o.Itens).ThenInclude(i => i.Servico)
                .Include(o => o.Produtos)
                .AsQueryable();

            if (de.HasValue) query = query.Where(o => o.DataAbertura >= de.Value.Date);
            if (ate.HasValue) query = query.Where(o => o.DataAbertura < ate.Value.Date.AddDays(1));
            if (!string.IsNullOrWhiteSpace(status)) query = query.Where(o => o.Status == status);
            if (!string.IsNullOrWhiteSpace(pagamento)) query = query.Where(o => o.FormaPagamento == pagamento);
            if (vendedorId.HasValue) query = query.Where(o => o.VendedorId == vendedorId.Value);
            if (!string.IsNullOrWhiteSpace(q))
            {
                var t = q.Trim();
                query = query.Where(o => o.ClienteNome.Contains(t) || o.Titulo.Contains(t) || o.Descricao.Contains(t));
            }

            var lista = await query.OrderByDescending(o => o.DataAbertura).Take(5000).ToListAsync();

            var linhas = lista.Select(o =>
            {
                var subtotal = o.Itens.Sum(i => i.Quantidade * i.ValorUnitario) + o.Produtos.Sum(p => p.Quantidade * p.ValorUnitario);
                var itens = o.Itens.Select(i => $"{i.Quantidade}x {i.Servico?.Titulo ?? "Serviço"}")
                    .Concat(o.Produtos.Select(p => $"{p.Quantidade}x {p.Nome}"));
                return new
                {
                    o.Id,
                    o.ClienteNome,
                    o.Titulo,
                    o.Status,
                    o.DataAbertura,
                    o.DataConclusao,
                    o.FormaPagamento,
                    Vendedor = o.VendedorNome,
                    Itens = string.Join("; ", itens),
                    Subtotal = subtotal,
                    o.Desconto,
                    Total = Math.Max(0, subtotal - o.Desconto)
                };
            }).ToList();

            // Faturamento = só concluídas; canceladas não entram em nenhum valor.
            var validas = linhas.Where(l => !l.Status.StartsWith("Cancel", StringComparison.OrdinalIgnoreCase)).ToList();
            var concluidas = linhas.Where(l => l.Status.StartsWith("Conclu", StringComparison.OrdinalIgnoreCase)).ToList();

            return Ok(new
            {
                Resumo = new
                {
                    Quantidade = linhas.Count,
                    Concluidas = concluidas.Count,
                    Faturamento = concluidas.Sum(l => l.Total),
                    TicketMedio = concluidas.Count == 0 ? 0m : concluidas.Sum(l => l.Total) / concluidas.Count,
                    Descontos = validas.Sum(l => l.Desconto),
                    PorPagamento = new[] { "Pix", "Cartão", "Dinheiro" }.Select(f => new
                    {
                        Forma = f,
                        Total = concluidas.Where(l => l.FormaPagamento == f).Sum(l => l.Total)
                    })
                },
                Itens = linhas
            });
        }
    }
}
