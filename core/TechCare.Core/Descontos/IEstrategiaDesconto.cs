namespace TechCare.Core.Descontos;

/// <summary>Padrão STRATEGY: cada forma de desconto é uma classe intercambiável.</summary>
public interface IEstrategiaDesconto
{
    string Descricao { get; }
    decimal Calcular(decimal subtotal);
}

public sealed class SemDesconto : IEstrategiaDesconto
{
    public string Descricao => "Sem desconto";
    public decimal Calcular(decimal subtotal) => 0m;
}

public sealed class DescontoEmReais : IEstrategiaDesconto
{
    private readonly decimal _valor;
    public DescontoEmReais(decimal valor) => _valor = valor;
    public string Descricao => $"Desconto de R$ {_valor:N2}";
    public decimal Calcular(decimal subtotal) => _valor;
}

public sealed class DescontoPercentual : IEstrategiaDesconto
{
    private readonly decimal _percentual;

    public DescontoPercentual(decimal percentual)
    {
        if (percentual is < 0m or > 100m) throw new ArgumentOutOfRangeException(nameof(percentual), "Use de 0 a 100%.");
        _percentual = percentual;
    }

    public string Descricao => $"Desconto de {_percentual:N1}%";
    public decimal Calcular(decimal subtotal) => subtotal * _percentual / 100m;
}

/// <summary>
/// Desconto progressivo por volume (exemplo de nova regra adicionada SEM alterar o carrinho):
/// 5% a partir de R$ 300 e 10% a partir de R$ 600.
/// </summary>
public sealed class DescontoProgressivo : IEstrategiaDesconto
{
    public string Descricao => "Desconto progressivo (5% acima de R$ 300; 10% acima de R$ 600)";
    public decimal Calcular(decimal subtotal) => subtotal switch
    {
        >= 600m => subtotal * 0.10m,
        >= 300m => subtotal * 0.05m,
        _ => 0m
    };
}
