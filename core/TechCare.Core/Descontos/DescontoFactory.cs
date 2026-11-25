namespace TechCare.Core.Descontos;

/// <summary>
/// Padrão FACTORY: a tela informa só o tipo escolhido e o valor digitado; a fábrica decide
/// qual estratégia criar. Quem usa não conhece as classes concretas.
/// </summary>
public static class DescontoFactory
{
    public const string Nenhum = "nenhum";
    public const string Reais = "reais";
    public const string Percentual = "percentual";
    public const string Progressivo = "progressivo";

    public static IEstrategiaDesconto Criar(string? tipo, decimal valor = 0) =>
        (tipo ?? Nenhum).Trim().ToLowerInvariant() switch
        {
            Nenhum or "" => new SemDesconto(),
            Reais => new DescontoEmReais(valor),
            Percentual => new DescontoPercentual(valor),
            Progressivo => new DescontoProgressivo(),
            _ => throw new ArgumentException($"Tipo de desconto desconhecido: {tipo}", nameof(tipo))
        };
}
