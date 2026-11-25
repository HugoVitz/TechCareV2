namespace TechCare.Core.Dominio;

/// <summary>
/// Classe base ABSTRATA de todas as entidades: centraliza a identidade (Id) e a
/// comparação por identidade. Não pode ser instanciada sozinha.
/// </summary>
public abstract class Entidade
{
    public int Id { get; protected set; }

    protected Entidade(int id)
    {
        if (id < 0) throw new ArgumentOutOfRangeException(nameof(id), "Id não pode ser negativo.");
        Id = id;
    }

    public override bool Equals(object? obj) =>
        obj is Entidade outra && outra.GetType() == GetType() && Id != 0 && outra.Id == Id;

    public override int GetHashCode() => HashCode.Combine(GetType(), Id);
}
