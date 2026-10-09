using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;

namespace TechCarePro.Services
{
    public static class AuditoriaService
    {
        /// <summary>Adiciona o registro ao contexto; quem chama dá o SaveChanges junto com a alteração.</summary>
        public static void Registrar(AppDbContext db, ICurrentTenant ator, string acao, string alvo,
            int? lojaId = null, string? detalhe = null)
        {
            db.Auditorias.Add(new Auditoria
            {
                AtorId = ator.UsuarioId == 0 ? null : ator.UsuarioId,
                AtorNome = string.IsNullOrWhiteSpace(ator.UsuarioNome) ? "Sistema" : ator.UsuarioNome,
                LojaId = lojaId ?? (ator.LojaId == 0 ? null : ator.LojaId),
                Acao = acao,
                Alvo = alvo,
                Detalhe = detalhe
            });
        }
    }
}
