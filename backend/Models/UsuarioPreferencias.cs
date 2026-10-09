namespace TechCarePro.Models
{
    public class UsuarioPreferencias
    {
        
        public int UsuarioId { get; set; }


        public string Tema { get; set; } = "light"; 
        public string CorPrincipal { get; set; } = "#2563eb";
        public bool CompactarTabelas { get; set; } = false;
        public double FatorFonte { get; set; } = 1.0; 

        public bool Libras { get; set; } = false;
        public bool AltoContraste { get; set; } = false;

        public Usuario Usuario { get; set; } = null!;
    }
}

