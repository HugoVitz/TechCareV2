using System.Security.Cryptography;

namespace TechCarePro.Security
{
    /// <summary>
    /// Hash de senha PBKDF2 (HMAC-SHA-256) com salt aleatório.
    /// PIM VIII (manutenção): as senhas novas usam 600.000 iterações, valor recomendado pela OWASP.
    /// Formato novo:  v2:iteracoes:salt:hash  (Base64)
    /// Formato antigo: salt:hash (100.000 iterações) continua aceito, para não invalidar contas existentes.
    /// </summary>
    public static class PasswordHasher
    {
        public const int Iteracoes = 600_000;
        private const int IteracoesLegado = 100_000;

        public static string Hash(string password)
        {
            var salt = RandomNumberGenerator.GetBytes(16);
            var hash = Rfc2898DeriveBytes.Pbkdf2(password, salt, Iteracoes, HashAlgorithmName.SHA256, 32);
            return $"v2:{Iteracoes}:{Convert.ToBase64String(salt)}:{Convert.ToBase64String(hash)}";
        }

        public static bool Verify(string password, string stored)
        {
            try
            {
                var parts = stored.Split(':');
                int iteracoes;
                byte[] salt, expected;

                if (parts.Length == 4 && parts[0] == "v2" && int.TryParse(parts[1], out iteracoes))
                {
                    salt = Convert.FromBase64String(parts[2]);
                    expected = Convert.FromBase64String(parts[3]);
                }
                else if (parts.Length == 2)
                {
                    iteracoes = IteracoesLegado;
                    salt = Convert.FromBase64String(parts[0]);
                    expected = Convert.FromBase64String(parts[1]);
                }
                else
                {
                    return false;
                }

                var computed = Rfc2898DeriveBytes.Pbkdf2(password, salt, iteracoes, HashAlgorithmName.SHA256, expected.Length);
                return CryptographicOperations.FixedTimeEquals(expected, computed);
            }
            catch (FormatException)
            {
                return false;
            }
        }

        /// <summary>Indica se o hash foi gerado com parâmetros antigos (pode ser regravado no próximo login).</summary>
        public static bool PrecisaAtualizar(string stored) => !stored.StartsWith($"v2:{Iteracoes}:", StringComparison.Ordinal);
    }
}
