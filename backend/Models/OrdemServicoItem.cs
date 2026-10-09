namespace TechCarePro.Models
{
    public class OrdemServicoItem
    {
        public int Id { get; set; }

        public int OrdemServicoId { get; set; }
        public OrdemServico? OrdemServico { get; set; }

        public int ServicoId { get; set; }
        public Servico? Servico { get; set; }

        public int Quantidade { get; set; } = 1;
        public decimal ValorUnitario { get; set; }

        public decimal ValorTotal => Quantidade * ValorUnitario;
    }
}

