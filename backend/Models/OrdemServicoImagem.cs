namespace TechCarePro.Models
{
    public class OrdemServicoImagem
    {
        public int Id { get; set; }

        public int OrdemServicoId { get; set; }
        public OrdemServico? OrdemServico { get; set; }

        // armazenaremos como base64 no SQLite/EF (string) para simplificar
        public string NomeArquivo { get; set; } = string.Empty;
        public string ConteudoBase64 { get; set; } = string.Empty;
    }
}

