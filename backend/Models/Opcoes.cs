namespace TechCarePro.Models
{
    /// <summary>Etnia/cor conforme as categorias do IBGE. Declaração opcional (dado sensível pela LGPD).</summary>
    public static class Etnias
    {
        public const string NaoInformar = "Prefiro não informar";

        public static readonly string[] Todas =
            { "Branca", "Preta", "Parda", "Amarela", "Indígena", NaoInformar };

        /// <summary>Nulo/vazio é válido (campo opcional).</summary>
        public static bool Valida(string? valor) =>
            string.IsNullOrWhiteSpace(valor) || Todas.Contains(valor.Trim());

        public static string? Normaliza(string? valor) =>
            string.IsNullOrWhiteSpace(valor) ? null : valor.Trim();
    }

    public static class Cargos
    {
        public static readonly string[] Sugeridos = { "Gerente", "Técnico", "Atendente", "Recepcionista", "Financeiro" };
    }
}
