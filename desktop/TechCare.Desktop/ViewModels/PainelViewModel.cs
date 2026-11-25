using System.Collections.ObjectModel;
using TechCare.Core.Contratos;
using TechCare.Desktop.Infra;
using TechCare.Desktop.Mvvm;

namespace TechCare.Desktop.ViewModels;

/// <summary>Uma barra do gráfico de faturamento mensal (largura proporcional ao maior mês).</summary>
public sealed record BarraMensal(string Mes, decimal Faturamento, long Ordens, double Largura);

/// <summary>Painel de indicadores: dados das functions fn_resumo_faturamento e fn_faturamento_mensal.</summary>
public class PainelViewModel : ObservableObject
{
    private const double LarguraMaxima = 360;
    private readonly IIndicadoresRepositorio _indicadores;
    private DateTime _de = DateTime.Today.AddDays(-29);
    private DateTime _ate = DateTime.Today;
    private ResumoFaturamento _resumo = new(0, 0, 0, 0);
    private string _mensagem = string.Empty;

    public PainelViewModel(IIndicadoresRepositorio indicadores)
    {
        _indicadores = indicadores;
        CarregarCommand = new AsyncRelayCommand(CarregarAsync);
    }

    public DateTime De { get => _de; set => SetProperty(ref _de, value); }
    public DateTime Ate { get => _ate; set => SetProperty(ref _ate, value); }
    public ResumoFaturamento Resumo { get => _resumo; private set => SetProperty(ref _resumo, value); }
    public string Mensagem { get => _mensagem; set => SetProperty(ref _mensagem, value); }
    public ObservableCollection<BarraMensal> Meses { get; } = new();
    public AsyncRelayCommand CarregarCommand { get; }

    public async Task CarregarAsync()
    {
        if (De > Ate)
        {
            Mensagem = "A data inicial deve ser anterior à final.";
            return;
        }

        Mensagem = "Carregando...";
        try
        {
            Resumo = await _indicadores.ResumoAsync(De, Ate);
            var mensal = await _indicadores.MensalAsync(6);
            var maior = mensal.Count == 0 ? 0m : mensal.Max(m => m.Faturamento);

            Meses.Clear();
            foreach (var m in mensal)
            {
                var largura = maior == 0 ? 0 : (double)(m.Faturamento / maior) * LarguraMaxima;
                Meses.Add(new BarraMensal(m.MesFormatado, m.Faturamento, m.Ordens, largura));
            }
            Mensagem = $"Atualizado às {DateTime.Now:HH:mm:ss}.";
        }
        catch (ApiException ex)
        {
            Mensagem = ex.Message;
        }
    }
}
