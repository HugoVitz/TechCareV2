using TechCare.Core.Dominio;

namespace TechCare.Core.Contratos;

/// <summary>
/// Padrão REPOSITORY: a tela pede "produtos" sem saber se vêm da API REST, de um cache
/// ou de um banco local. A implementação concreta é injetada (injeção de dependência).
/// </summary>
public interface IProdutoRepositorio
{
    Task<IReadOnlyList<Produto>> ListarAsync(CancellationToken ct = default);
    Task<int> AjustarEstoqueAsync(int produtoId, int quantidade, string motivo, CancellationToken ct = default);
}

public interface IIndicadoresRepositorio
{
    Task<ResumoFaturamento> ResumoAsync(DateTime de, DateTime ate, CancellationToken ct = default);
    Task<IReadOnlyList<FaturamentoMensal>> MensalAsync(int meses, CancellationToken ct = default);
    Task<IReadOnlyList<Movimentacao>> MovimentacoesAsync(int? produtoId, int limite, CancellationToken ct = default);
}

/// <summary>Objetos de valor (records): imutáveis e comparados pelo conteúdo.</summary>
public sealed record ResumoFaturamento(long Ordens, decimal Faturamento, decimal TicketMedio, decimal Descontos);

public sealed record FaturamentoMensal(DateTime Mes, long Ordens, decimal Faturamento)
{
    public string MesFormatado => Mes.ToString("MMM/yyyy", new System.Globalization.CultureInfo("pt-BR"));
}

public sealed record Movimentacao(DateTime Data, string Produto, int Anterior, int Novo, int Diferenca, string Origem, string Usuario);
