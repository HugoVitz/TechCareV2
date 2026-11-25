namespace TechCare.Core.Dominio;

/// <summary>Erro de regra de negócio (mensagem pronta para mostrar ao usuário).</summary>
public class RegraDeNegocioException : Exception
{
    public RegraDeNegocioException(string mensagem) : base(mensagem) { }
}
