namespace TechCarePro.Models
{
    /// <summary>
    /// Sessão de login. O JWT carrega o Id desta sessão (claim "sid") e a API confere a cada
    /// requisição se ela ainda vale. É isso que permite "derrubar" alguém na hora.
    /// </summary>
    public class Sessao
    {
        public string Id { get; set; } = Guid.NewGuid().ToString("N");
        public int UsuarioId { get; set; }
        public int? LojaId { get; set; }
        public DateTime CriadaEm { get; set; } = DateTime.UtcNow;
        public DateTime UltimaAtividade { get; set; } = DateTime.UtcNow;
        public DateTime ExpiraEm { get; set; }
        public string? Ip { get; set; }
        public string? Agente { get; set; }
        public bool Revogada { get; set; }
        public string? MotivoRevogacao { get; set; }
        public DateTime? RevogadaEm { get; set; }
    }
}
