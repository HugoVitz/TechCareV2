using TechCare.Core.Dominio;
using TechCare.Core.Estoque;
using Xunit;

namespace TechCare.Tests;

/// <summary>Encapsulamento do estoque e padrão Observer do monitor.</summary>
public class ProdutoEstoqueTests
{
    [Fact]
    public void Ajuste_positivo_e_negativo_atualiza_o_saldo()
    {
        var produto = new Produto(1, "Cabo USB-C", 30m, 10);
        produto.AjustarEstoque(5);
        produto.AjustarEstoque(-12);
        Assert.Equal(3, produto.Estoque);
    }

    [Fact]
    public void Ajuste_que_deixaria_estoque_negativo_e_recusado_e_nada_muda()
    {
        var produto = new Produto(1, "Cabo USB-C", 30m, 2);
        Assert.Throws<RegraDeNegocioException>(() => produto.AjustarEstoque(-3));
        Assert.Equal(2, produto.Estoque);
    }

    [Theory]
    [InlineData("", 10, 1)]
    [InlineData("Capinha", -1, 1)]
    [InlineData("Capinha", 10, -1)]
    public void Construtor_valida_os_dados(string nome, decimal preco, int estoque)
    {
        Assert.Throws<RegraDeNegocioException>(() => new Produto(1, nome, preco, estoque));
    }

    [Fact]
    public void Monitor_avisa_somente_produtos_ativos_abaixo_do_limite()
    {
        var monitor = new MonitorEstoque(limite: 5);
        var avisados = new List<string>();
        monitor.EstoqueBaixo += (_, e) => avisados.Add(e.Produto.Nome);

        var total = monitor.Verificar(new[]
        {
            new Produto(1, "Fone", 130m, 3),
            new Produto(2, "Película", 40m, 80),
            new Produto(3, "Carregador antigo", 50m, 0, ativo: false),
            new Produto(4, "Cabo", 30m, 5)
        });

        Assert.Equal(2, total);
        Assert.Equal(new[] { "Fone", "Cabo" }, avisados);
    }

    [Fact]
    public void Entidades_sao_iguais_pelo_id_e_tipo()
    {
        Assert.Equal(new Produto(7, "A", 1m, 1), new Produto(7, "B", 2m, 2));
        Assert.NotEqual(new Produto(7, "A", 1m, 1), new Produto(8, "A", 1m, 1));
    }
}
