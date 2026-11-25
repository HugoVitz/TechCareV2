using TechCare.Core.Dominio;

namespace TechCare.Core.Estoque;

/// <summary>Dados do aviso de estoque baixo.</summary>
public sealed class EstoqueBaixoEventArgs : EventArgs
{
    public EstoqueBaixoEventArgs(Produto produto, int limite)
    {
        Produto = produto;
        Limite = limite;
    }

    public Produto Produto { get; }
    public int Limite { get; }
}

/// <summary>
/// Padrão OBSERVER com eventos do C#: quem se inscreve em <see cref="EstoqueBaixo"/>
/// (a tela do desktop, um e-mail, um log) é avisado sem que o monitor conheça os interessados.
/// </summary>
public class MonitorEstoque
{
    public MonitorEstoque(int limite = 5)
    {
        if (limite < 0) throw new ArgumentOutOfRangeException(nameof(limite));
        Limite = limite;
    }

    public int Limite { get; }

    public event EventHandler<EstoqueBaixoEventArgs>? EstoqueBaixo;

    /// <summary>Confere a lista e dispara um aviso para cada produto abaixo do limite.</summary>
    public int Verificar(IEnumerable<Produto> produtos)
    {
        var avisos = 0;
        foreach (var produto in produtos.Where(p => p.EstoqueBaixo(Limite)))
        {
            EstoqueBaixo?.Invoke(this, new EstoqueBaixoEventArgs(produto, Limite));
            avisos++;
        }
        return avisos;
    }
}
