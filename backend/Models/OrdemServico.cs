namespace TechCarePro.Models
{
    public class OrdemServico : ITenantEntity
    {
        public int Id { get; set; }

        /// <summary>Loja dona do registro (preenchido pela API; o valor enviado pelo cliente é ignorado).</summary>
        public int LojaId { get; set; }

        public int ClienteId { get; set; }
        public string ClienteNome { get; set; } = string.Empty;
        public string ClienteTelefone { get; set; } = string.Empty;
        public string ClienteCPF { get; set; } = string.Empty;
        public string ClienteEmail { get; set; } = string.Empty;

        public int ProfissionalId { get; set; }
        public string ProfissionalNome { get; set; } = string.Empty;

        public string Titulo { get; set; } = string.Empty;
        public string Descricao { get; set; } = string.Empty;

        public DateTime DataAbertura { get; set; }
        public DateTime? DataPrevista { get; set; }
        public DateTime? DataConclusao { get; set; }

        public string Status { get; set; } = string.Empty;
        public string? Garantia { get; set; }

        /// <summary>Desconto em reais aplicado sobre o subtotal do carrinho.</summary>
        public decimal Desconto { get; set; }

        /// <summary>Pix, Cartão ou Dinheiro.</summary>
        public string? FormaPagamento { get; set; }

        /// <summary>Quem registrou a venda (usado no ranking do mês).</summary>
        public int? VendedorId { get; set; }
        public string? VendedorNome { get; set; }

        public ICollection<OrdemServicoItem> Itens { get; set; } = new List<OrdemServicoItem>();

        public ICollection<OrdemServicoProduto> Produtos { get; set; } = new List<OrdemServicoProduto>();

        public ICollection<OrdemServicoImagem> Imagens { get; set; } = new List<OrdemServicoImagem>();
    }
}

