using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace TechCarePro.Models
{
    /// <summary>Produto vendido no carrinho da Ordem de Serviço (peças, acessórios...). Tem controle de estoque.</summary>
    public class Produto : ITenantEntity
    {
        public int Id { get; set; }

        /// <summary>Loja dona do registro (preenchido pela API; o valor enviado pelo cliente é ignorado).</summary>
        public int LojaId { get; set; }

        [Required(ErrorMessage = "Nome é obrigatório."), StringLength(150)]
        public string Nome { get; set; } = string.Empty;

        [Range(0, 1_000_000, ErrorMessage = "Preço inválido.")]
        public decimal Preco { get; set; }

        [Range(0, 1_000_000, ErrorMessage = "Estoque inválido.")]
        public int Estoque { get; set; }

        /// <summary>Produto inativo não aparece no carrinho dos atendentes.</summary>
        public bool Ativo { get; set; } = true;

        /// <summary>
        /// Controle de concorrência OTIMISTA: mapeado para a coluna de sistema xmin do PostgreSQL.
        /// Se dois atendentes alterarem o mesmo produto ao mesmo tempo, o segundo recebe um conflito
        /// em vez de sobrescrever o estoque. Não é enviado no JSON.
        /// </summary>
        [Timestamp]
        [JsonIgnore]
        public uint Versao { get; set; }
    }
}
