namespace TechCarePro.Models
{
    /// <summary>
    /// Linha de produto do carrinho de uma OS. Guarda o nome e o preço da época da venda,
    /// então mudar ou apagar o produto depois não altera o histórico.
    /// </summary>
    public class OrdemServicoProduto
    {
        public int Id { get; set; }

        public int OrdemServicoId { get; set; }
        public OrdemServico? OrdemServico { get; set; }

        /// <summary>Referência simples (sem chave estrangeira) para devolver ao estoque.</summary>
        public int ProdutoId { get; set; }

        public string Nome { get; set; } = string.Empty;
        public int Quantidade { get; set; } = 1;
        public decimal ValorUnitario { get; set; }

        public decimal ValorTotal => Quantidade * ValorUnitario;
    }
}
