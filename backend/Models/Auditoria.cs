namespace TechCarePro.Models
{
    /// <summary>Registro de ações administrativas (quem suspendeu, quem redefiniu senha...).</summary>
    public class Auditoria
    {
        public int Id { get; set; }
        public DateTime Data { get; set; } = DateTime.UtcNow;
        public int? AtorId { get; set; }
        public string AtorNome { get; set; } = string.Empty;
        public int? LojaId { get; set; }
        public string Acao { get; set; } = string.Empty;
        public string Alvo { get; set; } = string.Empty;
        public string? Detalhe { get; set; }
    }
}
