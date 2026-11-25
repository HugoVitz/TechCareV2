using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Npgsql;
using NpgsqlTypes;
using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;

namespace TechCarePro.Controllers
{
    /// <summary>
    /// Indicadores calculados por FUNCTIONS do PostgreSQL (o cálculo pesado fica no banco,
    /// perto dos dados). Consumido pelo módulo desktop e pelo painel do Administrador.
    /// </summary>
    [ApiController]
    [Authorize(Roles = Perfis.Admin)]
    [Route("api/indicadores")]
    public class IndicadoresController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentTenant _tenant;

        public IndicadoresController(AppDbContext context, ICurrentTenant tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        /// <summary>Resumo do faturamento no período (fn_resumo_faturamento).</summary>
        [HttpGet("resumo")]
        public async Task<IActionResult> Resumo([FromQuery] DateTime? de, [FromQuery] DateTime? ate)
        {
            var fim = (ate ?? DateTime.Today).Date;
            var inicio = (de ?? fim.AddDays(-29)).Date;
            if (inicio > fim) return BadRequest("A data inicial deve ser anterior à final.");

            var linhas = await ConsultarAsync(
                "SELECT ordens, faturamento, ticket_medio, descontos FROM fn_resumo_faturamento(@loja, @de::date, @ate::date)",
                r => new
                {
                    ordens = r.GetInt64(0),
                    faturamento = r.GetDecimal(1),
                    ticketMedio = r.GetDecimal(2),
                    descontos = r.GetDecimal(3)
                },
                ("de", NpgsqlDbType.Timestamp, inicio), ("ate", NpgsqlDbType.Timestamp, fim));

            return Ok(new { de = inicio, ate = fim, resumo = linhas.FirstOrDefault() });
        }

        /// <summary>Faturamento mês a mês (fn_faturamento_mensal).</summary>
        [HttpGet("mensal")]
        public async Task<IActionResult> Mensal([FromQuery] int meses = 6)
        {
            meses = Math.Clamp(meses, 1, 24);
            var linhas = await ConsultarAsync(
                "SELECT mes, ordens, faturamento FROM fn_faturamento_mensal(@loja, @meses)",
                r => new { mes = r.GetDateTime(0), ordens = r.GetInt64(1), faturamento = r.GetDecimal(2) },
                ("meses", NpgsqlDbType.Integer, meses));
            return Ok(linhas);
        }

        /// <summary>Produtos ativos que precisam de reposição (fn_produtos_estoque_baixo).</summary>
        [HttpGet("estoque-baixo")]
        public async Task<IActionResult> EstoqueBaixo([FromQuery] int limite = 5)
        {
            limite = Math.Clamp(limite, 0, 10_000);
            var linhas = await ConsultarAsync(
                "SELECT id, nome, estoque, preco FROM fn_produtos_estoque_baixo(@loja, @limite)",
                r => new { id = r.GetInt32(0), nome = r.GetString(1), estoque = r.GetInt32(2), preco = r.GetDecimal(3) },
                ("limite", NpgsqlDbType.Integer, limite));
            return Ok(linhas);
        }

        /// <summary>Histórico de entradas e saídas de estoque gravado pela trigger trg_produtos_movimentacao.</summary>
        [HttpGet("movimentacoes")]
        public async Task<IActionResult> Movimentacoes([FromQuery] int? produtoId, [FromQuery] int limite = 100)
        {
            limite = Math.Clamp(limite, 1, 1000);
            var linhas = await ConsultarAsync(
                @"SELECT m.""Data"", m.""ProdutoId"", COALESCE(p.""Nome"", '(excluído)'), m.""EstoqueAnterior"",
                         m.""EstoqueNovo"", m.""Diferenca"", m.""Origem"", COALESCE(m.""Usuario"", '')
                    FROM ""MovimentacoesEstoque"" m
                    LEFT JOIN ""Produtos"" p ON p.""Id"" = m.""ProdutoId""
                   WHERE m.""LojaId"" = @loja AND (@produto = 0 OR m.""ProdutoId"" = @produto)
                   ORDER BY m.""Data"" DESC, m.""Id"" DESC
                   LIMIT @limite",
                r => new
                {
                    data = r.GetDateTime(0),
                    produtoId = r.GetInt32(1),
                    produto = r.GetString(2),
                    anterior = r.GetInt32(3),
                    novo = r.GetInt32(4),
                    diferenca = r.GetInt32(5),
                    origem = r.GetString(6),
                    usuario = r.GetString(7)
                },
                ("produto", NpgsqlDbType.Integer, produtoId ?? 0), ("limite", NpgsqlDbType.Integer, limite));
            return Ok(linhas);
        }

        /// <summary>
        /// Executa um SELECT parametrizado (nunca concatena valores do usuário: evita SQL injection)
        /// sempre filtrado pela loja do usuário autenticado.
        /// </summary>
        private async Task<List<T>> ConsultarAsync<T>(string sql, Func<NpgsqlDataReader, T> mapear,
            params (string Nome, NpgsqlDbType Tipo, object Valor)[] parametros)
        {
            var conexao = (NpgsqlConnection)_context.Database.GetDbConnection();
            await _context.Database.OpenConnectionAsync();
            try
            {
                await using var cmd = new NpgsqlCommand(sql, conexao);
                cmd.Parameters.AddWithValue("loja", NpgsqlDbType.Integer, _tenant.LojaId);
                foreach (var (nome, tipo, valor) in parametros)
                    cmd.Parameters.AddWithValue(nome, tipo, valor);

                var lista = new List<T>();
                await using var reader = await cmd.ExecuteReaderAsync();
                while (await reader.ReadAsync())
                    lista.Add(mapear(reader));
                return lista;
            }
            finally
            {
                await _context.Database.CloseConnectionAsync();
            }
        }
    }
}
