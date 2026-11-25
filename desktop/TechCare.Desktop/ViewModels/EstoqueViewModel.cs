using System.Collections.ObjectModel;
using TechCare.Core.Contratos;
using TechCare.Core.Dominio;
using TechCare.Core.Estoque;
using TechCare.Desktop.Infra;
using TechCare.Desktop.Mvvm;

namespace TechCare.Desktop.ViewModels;

/// <summary>Linha da grade de produtos.</summary>
public sealed record ProdutoLinha(int Id, string Nome, decimal Preco, int Estoque, bool Ativo, bool Alerta);

/// <summary>
/// Gestão de estoque: lista os produtos, avisa os que estão acabando (MonitorEstoque, padrão Observer)
/// e faz ajustes pela procedure sp_ajustar_estoque, mostrando as movimentações gravadas pela trigger.
/// </summary>
public class EstoqueViewModel : ObservableObject
{
    private readonly IProdutoRepositorio _produtos;
    private readonly IIndicadoresRepositorio _indicadores;
    private readonly MonitorEstoque _monitor;
    private ProdutoLinha? _selecionado;
    private string _quantidade = "1";
    private string _motivo = "Entrada de mercadoria";
    private string _mensagem = string.Empty;

    public EstoqueViewModel(IProdutoRepositorio produtos, IIndicadoresRepositorio indicadores, MonitorEstoque monitor)
    {
        _produtos = produtos;
        _indicadores = indicadores;
        _monitor = monitor;
        _monitor.EstoqueBaixo += (_, e) =>
            Alertas.Add($"{e.Produto.Nome}: {e.Produto.Estoque} unidade(s) (limite {e.Limite})");

        CarregarCommand = new AsyncRelayCommand(CarregarAsync);
        AjustarCommand = new AsyncRelayCommand(AjustarAsync, () => Selecionado is not null);
    }

    public ObservableCollection<ProdutoLinha> Produtos { get; } = new();
    public ObservableCollection<string> Alertas { get; } = new();
    public ObservableCollection<Movimentacao> Movimentacoes { get; } = new();

    public ProdutoLinha? Selecionado
    {
        get => _selecionado;
        set
        {
            if (SetProperty(ref _selecionado, value))
                _ = CarregarMovimentacoesAsync();
        }
    }

    public string Quantidade { get => _quantidade; set => SetProperty(ref _quantidade, value); }
    public string Motivo { get => _motivo; set => SetProperty(ref _motivo, value); }
    public string Mensagem { get => _mensagem; set => SetProperty(ref _mensagem, value); }
    public AsyncRelayCommand CarregarCommand { get; }
    public AsyncRelayCommand AjustarCommand { get; }

    public async Task CarregarAsync()
    {
        try
        {
            var lista = await _produtos.ListarAsync();
            var idSelecionado = Selecionado?.Id;

            Produtos.Clear();
            foreach (var p in lista.OrderBy(p => p.Nome))
                Produtos.Add(new ProdutoLinha(p.Id, p.Nome, p.Preco, p.Estoque, p.Ativo, p.EstoqueBaixo(_monitor.Limite)));

            Alertas.Clear();
            _monitor.Verificar(lista);

            Selecionado = Produtos.FirstOrDefault(p => p.Id == idSelecionado);
            Mensagem = $"{Produtos.Count} produto(s) carregado(s); {Alertas.Count} com estoque baixo.";
        }
        catch (ApiException ex)
        {
            Mensagem = ex.Message;
        }
    }

    private async Task AjustarAsync()
    {
        if (Selecionado is not { } produto) return;
        if (!int.TryParse(Quantidade, out var qtd) || qtd == 0)
        {
            Mensagem = "Quantidade inválida. Use um número positivo (entrada) ou negativo (saída).";
            return;
        }

        try
        {
            // Validação local com a mesma regra do Core antes de chamar o servidor.
            var dominio = new Produto(produto.Id, produto.Nome, produto.Preco, produto.Estoque, produto.Ativo);
            dominio.AjustarEstoque(qtd);

            var saldo = await _produtos.AjustarEstoqueAsync(produto.Id, qtd, Motivo);
            Mensagem = $"Estoque de \"{produto.Nome}\" ajustado para {saldo} unidade(s).";
            await CarregarAsync();
        }
        catch (RegraDeNegocioException ex)
        {
            Mensagem = ex.Message;
        }
        catch (ApiException ex)
        {
            Mensagem = ex.Message;
        }
    }

    private async Task CarregarMovimentacoesAsync()
    {
        Movimentacoes.Clear();
        if (Selecionado is null) return;
        try
        {
            foreach (var m in await _indicadores.MovimentacoesAsync(Selecionado.Id, 30))
                Movimentacoes.Add(m);
        }
        catch (ApiException ex)
        {
            Mensagem = ex.Message;
        }
    }
}
