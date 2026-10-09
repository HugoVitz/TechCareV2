using System.ComponentModel.DataAnnotations;

namespace TechCarePro.Models
{
    public class Servico : ITenantEntity
    {
        public int Id { get; set; }

        /// <summary>Loja dona do registro (preenchido pela API; o valor enviado pelo cliente é ignorado).</summary>
        public int LojaId { get; set; }

        [Required(ErrorMessage = "Título é obrigatório."), StringLength(150)]
        public string Titulo { get; set; } = string.Empty;

        [Required(ErrorMessage = "Descrição é obrigatória."), StringLength(1000)]
        public string Descricao { get; set; } = string.Empty;

        // opcional - pode ser nulo/zero se você não quiser preço por serviço
        [Range(0, 1_000_000)]
        public decimal Valor { get; set; }
    }
}
