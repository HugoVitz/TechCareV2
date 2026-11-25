using TechCarePro.Security;
using Xunit;

namespace TechCare.Tests;

/// <summary>Testes da segurança da API (hash de senha PBKDF2 e senha provisória).</summary>
public class SegurancaTests
{
    [Fact]
    public void Hash_da_senha_confere_e_nao_guarda_o_texto()
    {
        var hash = PasswordHasher.Hash("Senha@123");

        Assert.DoesNotContain("Senha@123", hash);
        Assert.True(PasswordHasher.Verify("Senha@123", hash));
        Assert.False(PasswordHasher.Verify("senha@123", hash));
    }

    [Fact]
    public void Mesma_senha_gera_hashes_diferentes_por_causa_do_salt()
    {
        Assert.NotEqual(PasswordHasher.Hash("igual"), PasswordHasher.Hash("igual"));
    }

    [Fact]
    public void Senha_provisoria_tem_o_tamanho_pedido_e_varia()
    {
        var a = SenhaTemporaria.Gerar(12);
        var b = SenhaTemporaria.Gerar(12);

        Assert.Equal(12, a.Length);
        Assert.NotEqual(a, b);
    }
}

/// <summary>Compatibilidade: contas criadas no PIM VII (100 mil iterações) continuam entrando.</summary>
public class SenhaLegadoTests
{
    [Fact]
    public void Hash_no_formato_antigo_continua_valido_e_e_marcado_para_atualizar()
    {
        var salt = System.Security.Cryptography.RandomNumberGenerator.GetBytes(16);
        var hash = System.Security.Cryptography.Rfc2898DeriveBytes.Pbkdf2(
            "admin123", salt, 100_000, System.Security.Cryptography.HashAlgorithmName.SHA256, 32);
        var legado = $"{Convert.ToBase64String(salt)}:{Convert.ToBase64String(hash)}";

        Assert.True(PasswordHasher.Verify("admin123", legado));
        Assert.True(PasswordHasher.PrecisaAtualizar(legado));
        Assert.False(PasswordHasher.PrecisaAtualizar(PasswordHasher.Hash("admin123")));
    }

    [Fact]
    public void Hash_corrompido_nao_gera_excecao()
    {
        Assert.False(PasswordHasher.Verify("x", "v2:600000:@@@:###"));
        Assert.False(PasswordHasher.Verify("x", "qualquer-coisa"));
    }
}
