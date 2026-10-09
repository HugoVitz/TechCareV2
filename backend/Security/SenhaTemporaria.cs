using System.Security.Cryptography;

namespace TechCarePro.Security
{
    public static class SenhaTemporaria
    {
        // Sem caracteres ambíguos (0/O, 1/l/I) para ser fácil de ditar por telefone.
        private const string Alfabeto = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnpqrstuvwxyz23456789";

        public static string Gerar(int tamanho = 10)
        {
            var chars = new char[tamanho];
            for (var i = 0; i < tamanho; i++)
                chars[i] = Alfabeto[RandomNumberGenerator.GetInt32(Alfabeto.Length)];
            return new string(chars);
        }
    }
}
