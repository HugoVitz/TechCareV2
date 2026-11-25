using TechCare.Core.Descontos;
using TechCare.Core.Dominio;
using Xunit;

namespace TechCare.Tests;

/// <summary>Regras do carrinho da Ordem de Serviço (polimorfismo dos itens e estratégias de desconto).</summary>
public class CarrinhoTests
{
    private static Produto Pelicula(int estoque = 10) => new(1, "Película de vidro", 40m, estoque);

    [Fact]
    public void Subtotal_soma_servicos_e_produtos()
    {
        var carrinho = new Carrinho();
        carrinho.Adicionar(new ItemServico(1, "Troca de tela", 1, 350m));
        carrinho.Adicionar(new ItemProduto(Pelicula(), 2));

        Assert.Equal(430m, carrinho.Subtotal);
        Assert.Equal(430m, carrinho.Total);
    }

    [Theory]
    [InlineData("reais", 30, 400)]
    [InlineData("percentual", 10, 387)]
    [InlineData("progressivo", 0, 408.5)]
    [InlineData("nenhum", 0, 430)]
    public void Total_aplica_a_estrategia_de_desconto(string tipo, decimal valor, decimal totalEsperado)
    {
        var carrinho = new Carrinho();
        carrinho.Adicionar(new ItemServico(1, "Troca de tela", 1, 350m));
        carrinho.Adicionar(new ItemProduto(Pelicula(), 2));

        carrinho.AplicarDesconto(DescontoFactory.Criar(tipo, valor));

        Assert.Equal(totalEsperado, carrinho.Total);
    }

    [Fact]
    public void Desconto_maior_que_o_subtotal_e_recusado()
    {
        var carrinho = new Carrinho();
        carrinho.Adicionar(new ItemServico(1, "Limpeza", 1, 90m));
        carrinho.AplicarDesconto(new DescontoEmReais(100m));

        Assert.Throws<RegraDeNegocioException>(() => carrinho.Total);
    }

    [Fact]
    public void Somente_produtos_movimentam_estoque()
    {
        ItemCarrinho servico = new ItemServico(1, "Limpeza", 1, 90m);
        ItemCarrinho produto = new ItemProduto(Pelicula(), 1);

        Assert.False(servico.MovimentaEstoque);
        Assert.True(produto.MovimentaEstoque);
        Assert.StartsWith("Serviço:", servico.Rotulo);
        Assert.StartsWith("Produto:", produto.Rotulo);
    }

    [Fact]
    public void Produto_sem_estoque_suficiente_nao_entra_no_carrinho()
    {
        Assert.Throws<RegraDeNegocioException>(() => new ItemProduto(Pelicula(estoque: 1), 2));
    }

    [Fact]
    public void Fabrica_recusa_tipo_desconhecido()
    {
        Assert.Throws<ArgumentException>(() => DescontoFactory.Criar("cupom-magico", 5));
    }
}
