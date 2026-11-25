using System.Globalization;
using System.Windows;
using System.Windows.Markup;
using Microsoft.Extensions.DependencyInjection;
using TechCare.Core.Contratos;
using TechCare.Core.Estoque;
using TechCare.Desktop.Infra;
using TechCare.Desktop.ViewModels;
using TechCare.Desktop.Views;

namespace TechCare.Desktop;

/// <summary>
/// Ponto de entrada. Monta o contêiner de INJEÇÃO DE DEPENDÊNCIA: cada classe recebe pronto o que
/// precisa (inversão de controle), o que facilita testes e troca de implementações.
/// </summary>
public partial class App : Application
{
    public static IServiceProvider Servicos { get; private set; } = null!;

    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // Formatos brasileiros (R$ 1.234,56 e dd/MM/aaaa). Sem isso, os StringFormat do XAML usam en-US.
        var ptBr = new CultureInfo("pt-BR");
        CultureInfo.DefaultThreadCurrentCulture = CultureInfo.DefaultThreadCurrentUICulture = ptBr;
        Thread.CurrentThread.CurrentCulture = Thread.CurrentThread.CurrentUICulture = ptBr;
        FrameworkElement.LanguageProperty.OverrideMetadata(typeof(FrameworkElement),
            new FrameworkPropertyMetadata(XmlLanguage.GetLanguage(ptBr.IetfLanguageTag)));
        FrameworkContentElement.LanguageProperty.OverrideMetadata(typeof(System.Windows.Documents.TextElement),
            new FrameworkPropertyMetadata(XmlLanguage.GetLanguage(ptBr.IetfLanguageTag)));

        var servicos = new ServiceCollection();
        servicos.AddSingleton<SessaoUsuario>();
        servicos.AddSingleton<ApiClient>();
        servicos.AddSingleton<IProdutoRepositorio, ProdutoRepositorioApi>();
        // Decorator: o repositório real fica "embrulhado" pelo cache.
        servicos.AddSingleton<IIndicadoresRepositorio>(sp =>
            new IndicadoresRepositorioComCache(
                new IndicadoresRepositorioApi(sp.GetRequiredService<ApiClient>()),
                TimeSpan.FromMinutes(2)));
        servicos.AddSingleton(new MonitorEstoque(limite: 5));
        servicos.AddTransient<LoginViewModel>();
        servicos.AddTransient<PainelViewModel>();
        servicos.AddTransient<EstoqueViewModel>();
        servicos.AddTransient<MainViewModel>();
        Servicos = servicos.BuildServiceProvider();

        var login = new LoginWindow(Servicos.GetRequiredService<LoginViewModel>());
        if (login.ShowDialog() != true)
        {
            Shutdown();
            return;
        }

        var principal = new MainWindow(Servicos.GetRequiredService<MainViewModel>());
        MainWindow = principal;
        ShutdownMode = ShutdownMode.OnMainWindowClose;
        principal.Show();
    }
}
