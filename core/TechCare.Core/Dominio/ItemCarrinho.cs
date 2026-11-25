namespace TechCare.Core.Dominio;

/// <summary>
/// Item do carrinho da Ordem de Serviço. HERANÇA e POLIMORFISMO: serviços e produtos
/// compartilham quantidade e preço, mas cada tipo descreve a si mesmo e decide se
/// movimenta estoque.
/// </summary>
public abstract class ItemCarrinho
{
    public int ReferenciaId { get; }
    public string Descricao { get; }
    public int Quantidade { get; }
    public decimal ValorUnitario { get; }

    protected ItemCarrinho(int referenciaId, string descricao, int quantidade, decimal valorUnitario)
    {
        if (quantidade <= 0) throw new RegraDeNegocioException("A quantidade deve ser maior que zero.");
        if (valorUnitario < 0) throw new RegraDeNegocioException("O valor unitário não pode ser negativo.");
        ReferenciaId = referenciaId;
        Descricao = descricao;
        Quantidade = quantidade;
        ValorUnitario = valorUnitario;
    }

    public virtual decimal Subtotal => Quantidade * ValorUnitario;

    /// <summary>Texto mostrado no resumo do carrinho (cada subclasse sobrescreve).</summary>
    public abstract string Rotulo { get; }

    /// <summary>Só produtos baixam estoque; serviços não.</summary>
    public virtual bool MovimentaEstoque => false;
}

public sealed class ItemServico : ItemCarrinho
{
    public ItemServico(int servicoId, string titulo, int quantidade, decimal valor)
        : base(servicoId, titulo, quantidade, valor) { }

    public override string Rotulo => $"Serviço: {Descricao}";
}

public sealed class ItemProduto : ItemCarrinho
{
    public ItemProduto(Produto produto, int quantidade)
        : base(produto.Id, produto.Nome, quantidade, produto.Preco)
    {
        if (!produto.Ativo) throw new RegraDeNegocioException($"O produto \"{produto.Nome}\" está inativo.");
        if (produto.Estoque < quantidade)
            throw new RegraDeNegocioException($"Estoque insuficiente de \"{produto.Nome}\" (disponível: {produto.Estoque}).");
    }

    public override string Rotulo => $"Produto: {Descricao} x{Quantidade}";
    public override bool MovimentaEstoque => true;
}
