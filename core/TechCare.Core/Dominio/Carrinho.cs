using TechCare.Core.Descontos;

namespace TechCare.Core.Dominio;

/// <summary>
/// Carrinho da Ordem de Serviço. Usa COMPOSIÇÃO (contém itens) e recebe a estratégia de
/// desconto de fora (padrão Strategy), então novas regras de desconto não exigem mudar esta classe.
/// </summary>
public class Carrinho
{
    private readonly List<ItemCarrinho> _itens = new();
    private IEstrategiaDesconto _desconto = new SemDesconto();

    public IReadOnlyList<ItemCarrinho> Itens => _itens.AsReadOnly();

    public void Adicionar(ItemCarrinho item) => _itens.Add(item ?? throw new ArgumentNullException(nameof(item)));

    public bool Remover(ItemCarrinho item) => _itens.Remove(item);

    public void AplicarDesconto(IEstrategiaDesconto estrategia) =>
        _desconto = estrategia ?? throw new ArgumentNullException(nameof(estrategia));

    public decimal Subtotal => _itens.Sum(i => i.Subtotal);

    public decimal ValorDesconto
    {
        get
        {
            var valor = Math.Round(_desconto.Calcular(Subtotal), 2);
            if (valor < 0 || valor > Subtotal)
                throw new RegraDeNegocioException("Desconto inválido: não pode ser negativo nem maior que o subtotal.");
            return valor;
        }
    }

    public decimal Total => Subtotal - ValorDesconto;

    public bool Vazio => _itens.Count == 0;
}
