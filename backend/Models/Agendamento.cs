namespace TechCarePro.Models
{
    public class Agendamento : ITenantEntity
    {
        public int Id { get; set; }

        /// <summary>Loja dona do registro (preenchido pela API; o valor enviado pelo cliente é ignorado).</summary>
        public int LojaId { get; set; }

        public string PacienteNome { get; set; } = string.Empty;
        public string ProfissionalNome { get; set; } = string.Empty;
        public DateTime DataHora { get; set; }
        public string Status { get; set; } = string.Empty;
    }
}

