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
    [Route("api/ordens-servico")]
    public class OrdensServicoController : ControllerBase

    {
        private readonly AppDbContext _context;
        private readonly ICurrentTenant _tenant;

        public OrdensServicoController(AppDbContext context, ICurrentTenant tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public class OrdemServicoImagemInput
        {
            public string NomeArquivo { get; set; } = string.Empty;
            public string ConteudoBase64 { get; set; } = string.Empty;
        }

        public class OrdemServicoItemInput
        {
            public int ServicoId { get; set; }
            public int Quantidade { get; set; } = 1;
            public decimal ValorUnitario { get; set; }
        }

        public class OrdemServicoProdutoInput
        {
            public int ProdutoId { get; set; }
            public int Quantidade { get; set; } = 1;
        }

        public class OrdemServicoInput
        {
            public int ClienteId { get; set; }
            public int ProfissionalId { get; set; }
            public string Titulo { get; set; } = string.Empty;
            public string Descricao { get; set; } = string.Empty;
            public DateTime DataAbertura { get; set; }
            public DateTime? DataPrevista { get; set; }
            public DateTime? DataConclusao { get; set; }
            public string Status { get; set; } = string.Empty;
            public string? Garantia { get; set; }

            /// <summary>Desconto em reais (o site/app converte % em reais antes de enviar).</summary>
            public decimal Desconto { get; set; }

            /// <summary>Pix, Cartão ou Dinheiro.</summary>
            public string FormaPagamento { get; set; } = string.Empty;

            public List<OrdemServicoItemInput> Itens { get; set; } = new();
            public List<OrdemServicoProdutoInput> Produtos { get; set; } = new();
            public List<OrdemServicoImagemInput> Imagens { get; set; } = new();
        }

        public class StatusInput
        {
            public string Status { get; set; } = string.Empty;
            public DateTime? DataConclusao { get; set; }
        }

        private static readonly string[] FormasPagamento = { "Pix", "Cartão", "Dinheiro" };

        private static decimal Subtotal(OrdemServico o) =>
            o.Itens.Sum(i => i.Quantidade * i.ValorUnitario) + o.Produtos.Sum(p => p.Quantidade * p.ValorUnitario);

        private static decimal Total(OrdemServico o) => Math.Max(0, Subtotal(o) - o.Desconto);

        private static bool Cancelada(string? status) =>
            (status ?? string.Empty).StartsWith("Cancel", StringComparison.OrdinalIgnoreCase);

        // Lista resumida (sem imagens em base64, que são pesadas) para app e painel.
        [HttpGet]
        public async Task<IActionResult> GetAll([FromQuery] string? status = null)
        {
            var query = _context.OrdemServicos.AsNoTracking().Include(o => o.Itens).Include(o => o.Produtos).AsQueryable();
            if (!string.IsNullOrWhiteSpace(status))
                query = query.Where(o => o.Status == status);

            var lista = await query.OrderByDescending(o => o.DataAbertura).ToListAsync();

            // Soma em memória: o provider SQLite não agrega decimal no servidor.
            return Ok(lista.Select(o => new
            {
                o.Id,
                o.ClienteId,
                o.ClienteNome,
                o.ProfissionalId,
                o.ProfissionalNome,
                o.Titulo,
                o.Descricao,
                o.Status,
                o.DataAbertura,
                o.DataPrevista,
                o.DataConclusao,
                o.Garantia,
                Subtotal = Subtotal(o),
                o.Desconto,
                o.FormaPagamento,
                ValorTotal = Total(o)
            }));
        }

        [HttpPut("{id:int}/status")]
        public async Task<IActionResult> AtualizarStatus(int id, [FromBody] StatusInput input)
        {
            if (string.IsNullOrWhiteSpace(input.Status) || input.Status.Length > 50)
                return BadRequest("Status inválido.");

            var os = await _context.OrdemServicos.Include(o => o.Produtos).FirstOrDefaultAsync(o => o.Id == id);
            if (os is null) return NotFound();

            var estavaCancelada = Cancelada(os.Status);
            var ficaraCancelada = Cancelada(input.Status);
            if (!estavaCancelada && ficaraCancelada)
            {
                await MoverEstoqueAsync(os.Produtos, +1); // cancelou: produtos voltam ao estoque
            }
            else if (estavaCancelada && !ficaraCancelada)
            {
                var falta = await MoverEstoqueAsync(os.Produtos, -1);
                if (falta is not null) return BadRequest(falta);
            }

            os.Status = input.Status.Trim();
            var concluida = os.Status.StartsWith("Conclu", StringComparison.OrdinalIgnoreCase);
            os.DataConclusao = concluida ? (input.DataConclusao ?? DateTime.Now) : null;

            await _context.SaveChangesAsync();
            return Ok(new { os.Id, os.Status, os.DataConclusao });
        }

        [HttpGet("{id:int}")]
        public async Task<ActionResult<OrdemServico>> GetById(int id)
        {
            var os = await _context.OrdemServicos
                .Include(o => o.Itens)
                    .ThenInclude(i => i.Servico)
                .Include(o => o.Produtos)
                .Include(o => o.Imagens)
                .FirstOrDefaultAsync(o => o.Id == id);

            if (os is null) return NotFound();
            return Ok(os);
        }

        [HttpPost]
        public async Task<ActionResult<OrdemServico>> Post([FromBody] OrdemServicoInput input)
        {

            var cliente = await _context.Pacientes.AsNoTracking().FirstOrDefaultAsync(c => c.Id == input.ClienteId);
            if (cliente is null) return BadRequest("Cliente inválido.");
            // O responsável pela OS é um atendente/administrador da própria loja.
            var responsavel = await _context.Usuarios.AsNoTracking().FirstOrDefaultAsync(u =>
                u.Id == input.ProfissionalId && u.LojaId == _tenant.LojaId && u.Ativo && u.Perfil != Perfis.Dono);
            if (responsavel is null) return BadRequest("Responsável inválido.");
            var respPerfil = await _context.UsuarioPerfis.AsNoTracking().FirstOrDefaultAsync(p => p.UsuarioId == responsavel.Id);
            var respNome = string.IsNullOrWhiteSpace(respPerfil?.Nome) ? responsavel.UsuarioNome : respPerfil!.Nome;

            var forma = FormasPagamento.FirstOrDefault(f => string.Equals(f, input.FormaPagamento?.Trim(), StringComparison.OrdinalIgnoreCase));
            if (forma is null) return BadRequest("Informe a forma de pagamento (Pix, Cartão ou Dinheiro).");

            var os = new OrdemServico
            {
                ClienteId = input.ClienteId,
                ClienteNome = cliente.Nome,
                ClienteTelefone = cliente.Telefone,
                ClienteCPF = cliente.CPF,
                ClienteEmail = cliente.Email,
                ProfissionalId = responsavel.Id,
                ProfissionalNome = respNome,
                Titulo = input.Titulo,
                Descricao = input.Descricao,
                Garantia = string.IsNullOrWhiteSpace(input.Garantia) ? null : input.Garantia.Trim(),
                DataAbertura = input.DataAbertura,
                DataPrevista = input.DataPrevista,
                DataConclusao = input.DataConclusao,
                Status = string.IsNullOrWhiteSpace(input.Status) ? "Aberta" : input.Status,
                FormaPagamento = forma,
                VendedorId = _tenant.UsuarioId,
                VendedorNome = _tenant.UsuarioNome
            };

            // Serviços do carrinho (o preço sempre vem do cadastro, nunca do cliente).
            foreach (var item in input.Itens)
            {
                var servico = await _context.Servicos.AsNoTracking().FirstOrDefaultAsync(s => s.Id == item.ServicoId);
                if (servico is null) continue;

                os.Itens.Add(new OrdemServicoItem
                {
                    ServicoId = item.ServicoId,
                    Quantidade = item.Quantidade <= 0 ? 1 : item.Quantidade,
                    ValorUnitario = servico.Valor
                });
            }

            // Produtos do carrinho: preço do cadastro e baixa no estoque.
            foreach (var linha in input.Produtos.Where(p => p.Quantidade > 0))
            {
                var produto = await _context.Produtos.FirstOrDefaultAsync(p => p.Id == linha.ProdutoId);
                if (produto is null) return BadRequest("Um dos produtos do carrinho não existe mais.");
                if (!produto.Ativo) return BadRequest($"O produto \"{produto.Nome}\" está inativo.");

                var jaNoCarrinho = os.Produtos.Where(x => x.ProdutoId == produto.Id).Sum(x => x.Quantidade);
                if (produto.Estoque < jaNoCarrinho + linha.Quantidade)
                    return BadRequest($"Estoque insuficiente de \"{produto.Nome}\" (disponível: {produto.Estoque}).");

                os.Produtos.Add(new OrdemServicoProduto
                {
                    ProdutoId = produto.Id,
                    Nome = produto.Nome,
                    Quantidade = linha.Quantidade,
                    ValorUnitario = produto.Preco
                });
            }

            if (os.Itens.Count == 0 && os.Produtos.Count == 0)
                return BadRequest("O carrinho está vazio.");

            var subtotal = Subtotal(os);
            if (input.Desconto < 0 || input.Desconto > subtotal)
                return BadRequest("Desconto inválido: não pode ser negativo nem maior que o subtotal.");
            os.Desconto = Math.Round(input.Desconto, 2);

            if (!Cancelada(os.Status))
            {
                var falta = await MoverEstoqueAsync(os.Produtos, -1);
                if (falta is not null) return BadRequest(falta);
            }

            // Imagens (base64)
            foreach (var img in input.Imagens)
            {
                if (string.IsNullOrWhiteSpace(img.ConteudoBase64)) continue;
                os.Imagens.Add(new OrdemServicoImagem
                {
                    NomeArquivo = img.NomeArquivo ?? string.Empty,
                    ConteudoBase64 = img.ConteudoBase64
                });
            }

            _context.OrdemServicos.Add(os);
            await _context.SaveChangesAsync();

            // Carregar para retorno consistente
            os = await _context.OrdemServicos
                .Include(o => o.Itens)
                    .ThenInclude(i => i.Servico)
                .Include(o => o.Produtos)
                .Include(o => o.Imagens)
                .FirstOrDefaultAsync(o => o.Id == os.Id);

            return Ok(os);
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Delete(int id)
        {
            var existing = await _context.OrdemServicos.Include(o => o.Produtos).FirstOrDefaultAsync(o => o.Id == id);
            if (existing is null) return NotFound();

            if (!Cancelada(existing.Status))
                await MoverEstoqueAsync(existing.Produtos, +1); // excluir a OS devolve os produtos ao estoque

            _context.OrdemServicos.Remove(existing);
            await _context.SaveChangesAsync();
            return NoContent();
        }

        /// <summary>
        /// Soma (+1) ou subtrai (-1) do estoque as quantidades das linhas.
        /// Na subtração retorna uma mensagem se algum produto não tiver saldo (e nada é alterado).
        /// </summary>
        private async Task<string?> MoverEstoqueAsync(IEnumerable<OrdemServicoProduto> linhas, int sinal)
        {
            var porProduto = linhas.GroupBy(l => l.ProdutoId).ToDictionary(g => g.Key, g => g.Sum(x => x.Quantidade));
            var ids = porProduto.Keys.ToList();
            var produtos = await _context.Produtos.Where(p => ids.Contains(p.Id)).ToListAsync();

            if (sinal < 0)
            {
                foreach (var p in produtos)
                    if (p.Estoque < porProduto[p.Id])
                        return $"Estoque insuficiente de \"{p.Nome}\" (disponível: {p.Estoque}).";
            }

            foreach (var p in produtos)
                p.Estoque += sinal * porProduto[p.Id];

            return null;
        }
    }
}

