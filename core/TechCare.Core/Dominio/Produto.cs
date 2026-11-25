namespace TechCare.Core.Dominio;

/// <summary>
/// Produto com ENCAPSULAMENTO: o estoque só muda pelos métodos que validam a regra
/// (nunca fica negativo), e não por atribuição direta de fora da classe.
/// </summary>
public class Produto : Entidade
{
    private int _estoque;

    public string Nome { get; private set; }
    public decimal Preco { get; private set; }
    public bool Ativo { get; private set; }
    public int Estoque => _estoque;

    public Produto(int id, string nome, decimal preco, int estoque, bool ativo = true) : base(id)
    {
        if (string.IsNullOrWhiteSpace(nome)) throw new RegraDeNegocioException("Informe o nome do produto.");
        if (preco < 0) throw new RegraDeNegocioException("O preço não pode ser negativo.");
        if (estoque < 0) throw new RegraDeNegocioException("O estoque não pode ser negativo.");
        Nome = nome.Trim();
        Preco = preco;
        _estoque = estoque;
        Ativo = ativo;
    }

    public bool EstoqueBaixo(int limite) => Ativo && _estoque <= limite;

    /// <summary>Entrada (quantidade positiva) ou saída (negativa) de estoque.</summary>
    public void AjustarEstoque(int quantidade)
    {
        if (quantidade == 0) throw new RegraDeNegocioException("Informe uma quantidade diferente de zero.");
        if (_estoque + quantidade < 0)
            throw new RegraDeNegocioException($"Estoque insuficiente de \"{Nome}\": há {_estoque} unidade(s).");
        _estoque += quantidade;
    }
}
