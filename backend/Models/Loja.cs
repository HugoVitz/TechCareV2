namespace TechCarePro.Models
{
    /// <summary>Cliente do sistema (uma loja). Todos os dados operacionais pertencem a uma loja.</summary>
    public class Loja
    {
        public const string Ativa = "Ativa";
        public const string Suspensa = "Suspensa";

        public int Id { get; set; }
        public string Nome { get; set; } = string.Empty;
        public string Status { get; set; } = Ativa;

        /// <summary>Data até a qual a mensalidade está paga. Passou (mais a carência), a loja é suspensa.</summary>
        public DateTime? VencimentoEm { get; set; }

        public string? MotivoSuspensao { get; set; }
        public DateTime CriadaEm { get; set; } = DateTime.UtcNow;
    }
}
