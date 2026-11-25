using System.Collections.Concurrent;
using System.Globalization;
using TechCare.Core.Contratos;
using TechCare.Core.Dominio;

namespace TechCare.Desktop.Infra;

/// <summary>Repositório de produtos que lê e grava pela API REST (implementa o contrato do Core).</summary>
public class ProdutoRepositorioApi : IProdutoRepositorio
{
    private sealed record ProdutoDto(int Id, string Nome, decimal Preco, int Estoque, bool Ativo);
    private sealed record AjusteResposta(int Id, int Estoque);

    private readonly ApiClient _api;

    public ProdutoRepositorioApi(ApiClient api) => _api = api;

    public async Task<IReadOnlyList<Produto>> ListarAsync(CancellationToken ct = default)
    {
        var dtos = await _api.GetAsync<List<ProdutoDto>>("produtos", ct);
        return dtos.Select(d => new Produto(d.Id, d.Nome, d.Preco, d.Estoque, d.Ativo)).ToList();
    }

    public async Task<int> AjustarEstoqueAsync(int produtoId, int quantidade, string motivo, CancellationToken ct = default)
    {
        var resposta = await _api.PostAsync<AjusteResposta>($"produtos/{produtoId}/ajuste-estoque",
            new { quantidade, motivo }, ct);
        return resposta.Estoque;
    }
}

/// <summary>Indicadores calculados pelas functions do PostgreSQL, obtidos pela API.</summary>
public class IndicadoresRepositorioApi : IIndicadoresRepositorio
{
    private sealed record ResumoDto(long Ordens, decimal Faturamento, decimal TicketMedio, decimal Descontos);
    private sealed record ResumoResposta(DateTime De, DateTime Ate, ResumoDto? Resumo);
    private sealed record MensalDto(DateTime Mes, long Ordens, decimal Faturamento);
    private sealed record MovimentacaoDto(DateTime Data, int ProdutoId, string Produto, int Anterior, int Novo,
                                          int Diferenca, string Origem, string Usuario);

    private readonly ApiClient _api;

    public IndicadoresRepositorioApi(ApiClient api) => _api = api;

    public async Task<ResumoFaturamento> ResumoAsync(DateTime de, DateTime ate, CancellationToken ct = default)
    {
        var resposta = await _api.GetAsync<ResumoResposta>(
            $"indicadores/resumo?de={Data(de)}&ate={Data(ate)}", ct);
        var r = resposta.Resumo;
        return r is null
            ? new ResumoFaturamento(0, 0, 0, 0)
            : new ResumoFaturamento(r.Ordens, r.Faturamento, r.TicketMedio, r.Descontos);
    }

    public async Task<IReadOnlyList<FaturamentoMensal>> MensalAsync(int meses, CancellationToken ct = default)
    {
        var lista = await _api.GetAsync<List<MensalDto>>($"indicadores/mensal?meses={meses}", ct);
        return lista.Select(m => new FaturamentoMensal(m.Mes, m.Ordens, m.Faturamento)).ToList();
    }

    public async Task<IReadOnlyList<Movimentacao>> MovimentacoesAsync(int? produtoId, int limite, CancellationToken ct = default)
    {
        var filtro = produtoId is int id ? $"produtoId={id}&" : string.Empty;
        var lista = await _api.GetAsync<List<MovimentacaoDto>>($"indicadores/movimentacoes?{filtro}limite={limite}", ct);
        return lista.Select(m => new Movimentacao(m.Data, m.Produto, m.Anterior, m.Novo, m.Diferenca, m.Origem, m.Usuario)).ToList();
    }

    private static string Data(DateTime d) => d.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);
}

/// <summary>
/// Padrão DECORATOR: envolve outro repositório e guarda os indicadores em memória por alguns
/// minutos, reduzindo chamadas à API e ao banco. A tela não percebe a diferença, porque
/// o decorador implementa a mesma interface.
/// </summary>
public class IndicadoresRepositorioComCache : IIndicadoresRepositorio
{
    private readonly IIndicadoresRepositorio _interno;
    private readonly TimeSpan _validade;
    private readonly ConcurrentDictionary<string, (DateTime Expira, object Valor)> _cache = new();

    public IndicadoresRepositorioComCache(IIndicadoresRepositorio interno, TimeSpan validade)
    {
        _interno = interno;
        _validade = validade;
    }

    public Task<ResumoFaturamento> ResumoAsync(DateTime de, DateTime ate, CancellationToken ct = default) =>
        ObterAsync($"resumo:{de:yyyyMMdd}:{ate:yyyyMMdd}", () => _interno.ResumoAsync(de, ate, ct));

    public Task<IReadOnlyList<FaturamentoMensal>> MensalAsync(int meses, CancellationToken ct = default) =>
        ObterAsync($"mensal:{meses}", () => _interno.MensalAsync(meses, ct));

    // Movimentações mudam a todo momento: sempre vão direto para a API.
    public Task<IReadOnlyList<Movimentacao>> MovimentacoesAsync(int? produtoId, int limite, CancellationToken ct = default) =>
        _interno.MovimentacoesAsync(produtoId, limite, ct);

    public void Limpar() => _cache.Clear();

    private async Task<T> ObterAsync<T>(string chave, Func<Task<T>> buscar) where T : notnull
    {
        if (_cache.TryGetValue(chave, out var item) && item.Expira > DateTime.UtcNow)
            return (T)item.Valor;

        var valor = await buscar();
        _cache[chave] = (DateTime.UtcNow.Add(_validade), valor);
        return valor;
    }
}
