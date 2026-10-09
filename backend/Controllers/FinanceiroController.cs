using System.Globalization;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;
using TechCarePro.Services;

namespace TechCarePro.Controllers
{
    /// <summary>Tudo que é dinheiro: faturamento por dia/semana/mês/ano, formas de pagamento, ranking com valores. Somente Administrador.</summary>
    [ApiController]
    [Authorize(Roles = Perfis.Admin)]
    [Route("api/financeiro")]
    public class FinanceiroController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentTenant _tenant;

        public FinanceiroController(AppDbContext context, ICurrentTenant tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        private static DateTime InicioSemana(DateTime d)
        {
            var dif = ((int)d.DayOfWeek + 6) % 7; // semana começa na segunda
            return d.Date.AddDays(-dif);
        }

        private static DateTime Inicio(DateTime d, string agrupar) => agrupar switch
        {
            "dia" => d.Date,
            "semana" => InicioSemana(d),
            "ano" => new DateTime(d.Year, 1, 1),
            _ => new DateTime(d.Year, d.Month, 1)
        };

        private static DateTime Proximo(DateTime d, string agrupar) => agrupar switch
        {
            "dia" => d.AddDays(1),
            "semana" => d.AddDays(7),
            "ano" => d.AddYears(1),
            _ => d.AddMonths(1)
        };

        private static string Rotulo(DateTime d, string agrupar)
        {
            var pt = new CultureInfo("pt-BR");
            return agrupar switch
            {
                "dia" => d.ToString("dd/MM", pt),
                "semana" => $"{d:dd/MM} a {d.AddDays(6):dd/MM}",
                "ano" => d.ToString("yyyy", pt),
                _ => d.ToString("MMM/yy", pt)
            };
        }

        /// <param name="agrupar">dia | semana | mes | ano</param>
        /// <param name="de">início (opcional; padrão: últimos 30 dias / 12 semanas / 12 meses / 5 anos)</param>
        /// <param name="ate">fim (opcional; padrão: hoje)</param>
        [HttpGet]
        public async Task<IActionResult> Get([FromQuery] string agrupar = "mes", [FromQuery] DateTime? de = null, [FromQuery] DateTime? ate = null)
        {
            agrupar = (agrupar ?? "mes").ToLowerInvariant();
            if (agrupar is not ("dia" or "semana" or "mes" or "ano"))
                return BadRequest("Agrupamento inválido. Use dia, semana, mes ou ano.");

            var fim = (ate ?? DateTime.Now).Date;
            var inicio = de?.Date ?? agrupar switch
            {
                "dia" => fim.AddDays(-29),
                "semana" => InicioSemana(fim).AddDays(-7 * 11),
                "ano" => new DateTime(fim.Year - 4, 1, 1),
                _ => new DateTime(fim.Year, fim.Month, 1).AddMonths(-11)
            };
            if (inicio > fim) return BadRequest("A data inicial deve ser anterior à final.");

            var primeiro = Inicio(inicio, agrupar);
            var limiteFim = fim.AddDays(1);

            // Faturamento = OS concluídas, na data de conclusão (ou de abertura, se não houver).
            var os = await _context.OrdemServicos.AsNoTracking()
                .Include(o => o.Itens).Include(o => o.Produtos)
                .Where(o => o.Status.StartsWith("Conclu"))
                .ToListAsync();
            var noPeriodo = os.Where(o =>
            {
                var d = o.DataConclusao ?? o.DataAbertura;
                return d >= inicio && d < limiteFim;
            }).ToList();

            var serie = new List<object>();
            var atual = primeiro;
            var guard = 0;
            while (atual <= fim && guard++ < 400)
            {
                var prox = Proximo(atual, agrupar);
                var grupo = noPeriodo.Where(o =>
                {
                    var d = o.DataConclusao ?? o.DataAbertura;
                    return d >= atual && d < prox;
                }).ToList();
                serie.Add(new { Inicio = atual, Rotulo = Rotulo(atual, agrupar), Total = grupo.Sum(o => RankingService.Total(o)), Ordens = grupo.Count });
                atual = prox;
            }

            var faturamento = noPeriodo.Sum(o => RankingService.Total(o));
            var bruto = noPeriodo.Sum(o => o.Itens.Sum(i => i.Quantidade * i.ValorUnitario) + o.Produtos.Sum(p => p.Quantidade * p.ValorUnitario));

            // Ranking com valores, no mesmo período.
            var usuarios = await _context.Usuarios.AsNoTracking()
                .Where(u => u.LojaId == _tenant.LojaId && u.Ativo && u.Perfil != Perfis.Dono).ToListAsync();
            var ids = usuarios.Select(u => u.Id).ToList();
            var perfis = await _context.UsuarioPerfis.AsNoTracking().Where(p => ids.Contains(p.UsuarioId)).ToListAsync();
            var ranking = usuarios.Select(u =>
            {
                var p = perfis.FirstOrDefault(x => x.UsuarioId == u.Id);
                var minhas = noPeriodo.Where(o => o.VendedorId == u.Id).ToList();
                return new
                {
                    UsuarioId = u.Id,
                    Nome = string.IsNullOrWhiteSpace(p?.Nome) ? u.UsuarioNome : p!.Nome,
                    Foto = p?.FotoPerfilBase64,
                    Total = minhas.Sum(o => RankingService.Total(o)),
                    Ordens = minhas.Count
                };
            }).OrderByDescending(r => r.Total).ThenBy(r => r.Nome).ToList();

            return Ok(new
            {
                Agrupar = agrupar,
                De = inicio,
                Ate = fim,
                Resumo = new
                {
                    Faturamento = faturamento,
                    Ordens = noPeriodo.Count,
                    TicketMedio = noPeriodo.Count == 0 ? 0m : faturamento / noPeriodo.Count,
                    Descontos = bruto - faturamento,
                    PorPagamento = new[] { "Pix", "Cartão", "Dinheiro" }.Select(f => new
                    {
                        Forma = f,
                        Total = noPeriodo.Where(o => o.FormaPagamento == f).Sum(o => RankingService.Total(o))
                    })
                },
                Serie = serie,
                Ranking = ranking
            });
        }
    }
}
