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
    /// <summary>Catálogo de produtos. Todos da loja consultam (carrinho); só o Administrador cadastra.</summary>
    [ApiController]
    [Authorize(Roles = Perfis.Loja)]
    [Route("api/[controller]")]
    public class ProdutosController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentTenant _tenant;

        public ProdutosController(AppDbContext context, ICurrentTenant tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        [HttpGet]
        public async Task<ActionResult<List<Produto>>> Get()
        {
            var q = _context.Produtos.AsNoTracking().AsQueryable();
            // Atendente só enxerga produtos ativos; o Administrador vê todos (para gerenciar).
            if (_tenant.Perfil != Perfis.Admin) q = q.Where(p => p.Ativo);
            return Ok(await q.OrderBy(p => p.Nome).ToListAsync());
        }

        [Authorize(Roles = Perfis.Admin)]
        [HttpPost]
        public async Task<ActionResult<Produto>> Post(Produto produto)
        {
            produto.Id = 0;
            produto.Nome = produto.Nome.Trim();
            _context.Produtos.Add(produto);
            await _context.SaveChangesAsync();
            return Ok(produto);
        }

        [Authorize(Roles = Perfis.Admin)]
        [HttpPut("{id:int}")]
        public async Task<IActionResult> Put(int id, Produto produto)
        {
            if (id != produto.Id) return BadRequest("O id do body deve ser igual ao id da rota.");

            var existing = await _context.Produtos.FirstOrDefaultAsync(p => p.Id == id);
            if (existing is null) return NotFound();

            existing.Nome = produto.Nome.Trim();
            existing.Preco = produto.Preco;
            existing.Estoque = produto.Estoque;
            existing.Ativo = produto.Ativo;

            try
            {
                await _context.SaveChangesAsync();
            }
            catch (DbUpdateConcurrencyException)
            {
                // Uma venda baixou o estoque entre a abertura da tela e o salvamento.
                return Conflict(new { mensagem = "Este produto foi alterado por outra pessoa (provavelmente uma venda). Recarregue e tente de novo." });
            }
            return Ok(existing);
        }

        public class AjusteEstoqueInput
        {
            /// <summary>Positivo para entrada (compra), negativo para saída (perda, avaria, inventário).</summary>
            public int Quantidade { get; set; }
            public string Motivo { get; set; } = string.Empty;
        }

        /// <summary>
        /// Ajuste manual de estoque pela stored procedure sp_ajustar_estoque, que trava a linha do
        /// produto (SELECT ... FOR UPDATE), valida o saldo e registra a movimentação via trigger.
        /// Usado pelo módulo desktop e disponível no Swagger.
        /// </summary>
        [Authorize(Roles = Perfis.Admin)]
        [HttpPost("{id:int}/ajuste-estoque")]
        public async Task<IActionResult> AjustarEstoque(int id, AjusteEstoqueInput input)
        {
            if (input.Quantidade == 0 || Math.Abs(input.Quantidade) > 100_000)
                return BadRequest("Informe uma quantidade diferente de zero (até 100.000).");
            var motivo = (input.Motivo ?? string.Empty).Trim();
            if (motivo.Length is 0 or > 100)
                return BadRequest("Informe o motivo do ajuste (até 100 caracteres).");

            var conexao = (NpgsqlConnection)_context.Database.GetDbConnection();
            await _context.Database.OpenConnectionAsync();
            try
            {
                await using var cmd = new NpgsqlCommand(
                    "CALL sp_ajustar_estoque(@loja, @produto, @quantidade, @motivo::varchar, @usuario::varchar, NULL)", conexao);
                cmd.Parameters.AddWithValue("loja", NpgsqlDbType.Integer, _tenant.LojaId);
                cmd.Parameters.AddWithValue("produto", NpgsqlDbType.Integer, id);
                cmd.Parameters.AddWithValue("quantidade", NpgsqlDbType.Integer, input.Quantidade);
                cmd.Parameters.AddWithValue("motivo", NpgsqlDbType.Text, motivo);
                cmd.Parameters.AddWithValue("usuario", NpgsqlDbType.Text, _tenant.UsuarioNome);

                var estoqueFinal = Convert.ToInt32(await cmd.ExecuteScalarAsync());
                return Ok(new { id, estoque = estoqueFinal });
            }
            catch (PostgresException ex) when (ex.SqlState == PostgresErrorCodes.NoDataFound)
            {
                return NotFound(ex.MessageText);
            }
            catch (PostgresException ex) when (ex.SqlState is PostgresErrorCodes.CheckViolation or PostgresErrorCodes.InvalidParameterValue)
            {
                return BadRequest(ex.MessageText);
            }
            finally
            {
                await _context.Database.CloseConnectionAsync();
            }
        }

        [Authorize(Roles = Perfis.Admin)]
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var existing = await _context.Produtos.FirstOrDefaultAsync(p => p.Id == id);
            if (existing is null) return NotFound();

            // O histórico das OS guarda nome e preço da época, então apagar o produto não quebra nada.
            _context.Produtos.Remove(existing);
            await _context.SaveChangesAsync();
            return NoContent();
        }
    }
}
