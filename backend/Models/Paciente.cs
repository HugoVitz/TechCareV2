using System.ComponentModel.DataAnnotations;

namespace TechCarePro.Models
{
    public class Paciente : ITenantEntity
    {
        public int Id { get; set; }

        /// <summary>Loja dona do registro (preenchido pela API; o valor enviado pelo cliente é ignorado).</summary>
        public int LojaId { get; set; }

        /// <summary>Autodeclaração opcional (IBGE). Usada só em relatórios agregados de diversidade.</summary>
        [StringLength(30)]
        public string? Etnia { get; set; }

        [Required(ErrorMessage = "Nome é obrigatório."), StringLength(150)]
        public string Nome { get; set; } = string.Empty;

        [Required(ErrorMessage = "E-mail é obrigatório."), EmailAddress(ErrorMessage = "E-mail inválido."), StringLength(150)]
        public string Email { get; set; } = string.Empty;

        [Required(ErrorMessage = "Telefone é obrigatório."), StringLength(30)]
        public string Telefone { get; set; } = string.Empty;

        [Required(ErrorMessage = "CPF é obrigatório."), StringLength(20)]
        public string CPF { get; set; } = string.Empty;
    }
}
