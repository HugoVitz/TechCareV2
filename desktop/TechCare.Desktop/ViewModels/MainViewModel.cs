using TechCare.Desktop.Infra;
using TechCare.Desktop.Mvvm;

namespace TechCare.Desktop.ViewModels;

/// <summary>Janela principal: compõe os módulos (painel e estoque) recebidos por injeção de dependência.</summary>
public class MainViewModel : ObservableObject
{
    private readonly SessaoUsuario _sessao;

    public MainViewModel(SessaoUsuario sessao, PainelViewModel painel, EstoqueViewModel estoque)
    {
        _sessao = sessao;
        Painel = painel;
        Estoque = estoque;
    }

    public PainelViewModel Painel { get; }
    public EstoqueViewModel Estoque { get; }

    public string Cabecalho => $"{_sessao.Loja ?? "TechCare"} · {_sessao.Usuario} ({_sessao.Perfil})";

    public async Task IniciarAsync()
    {
        await Painel.CarregarAsync();
        await Estoque.CarregarAsync();
    }
}
