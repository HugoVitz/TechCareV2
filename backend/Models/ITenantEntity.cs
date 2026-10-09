namespace TechCarePro.Models
{
    /// <summary>Entidade que pertence a uma loja. O DbContext filtra e preenche o LojaId sozinho.</summary>
    public interface ITenantEntity
    {
        int LojaId { get; set; }
    }
}
