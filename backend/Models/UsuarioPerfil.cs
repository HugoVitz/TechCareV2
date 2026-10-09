using System.ComponentModel.DataAnnotations;

namespace TechCarePro.Models
{
    public class UsuarioPerfil
    {
        // PK para o EF Core
        public int UsuarioId { get; set; }



        [MaxLength(200)]
        public string Nome { get; set; } = string.Empty;

        [MaxLength(200)]
        public string Cargo { get; set; } = string.Empty;

        /// <summary>Autodeclaração opcional (IBGE).</summary>
        [MaxLength(30)]
        public string? Etnia { get; set; }

        // Armazena uma imagem em base64 (data URL ou raw base64)
        public string? FotoPerfilBase64 { get; set; }

        public Usuario Usuario { get; set; } = null!;
    }
}


