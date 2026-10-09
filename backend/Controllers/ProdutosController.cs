using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
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

            await _context.SaveChangesAsync();
            return Ok(existing);
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
