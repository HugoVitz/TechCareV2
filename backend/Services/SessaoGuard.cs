using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Models;

namespace TechCarePro.Services
{
    /// <summary>
    /// Chamado a cada requisição autenticada: o JWT sozinho não basta, a sessão precisa estar viva,
    /// o usuário ativo e a loja em dia. É isto que faz "derrubar a sessão" funcionar na hora.
    /// </summary>
    public static class SessaoGuard
    {
        /// <summary>Devolve null se a sessão é válida; senão, o motivo para mostrar ao usuário.</summary>
        public static async Task<string?> ValidarAsync(AppDbContext db, string? sessaoId)
        {
            if (string.IsNullOrWhiteSpace(sessaoId))
                return "Sessão inválida. Entre novamente.";

            var sessao = await db.Sessoes.FirstOrDefaultAsync(s => s.Id == sessaoId);
            if (sessao is null)
                return "Sessão inválida. Entre novamente.";

            if (sessao.Revogada)
                return string.IsNullOrWhiteSpace(sessao.MotivoRevogacao)
                    ? "Sua sessão foi encerrada. Entre novamente."
                    : sessao.MotivoRevogacao;

            var agora = DateTime.UtcNow;
            if (sessao.ExpiraEm < agora)
                return "Sessão expirada. Entre novamente.";

            var usuario = await db.Usuarios.FirstOrDefaultAsync(u => u.Id == sessao.UsuarioId);
            if (usuario is null || !usuario.Ativo)
            {
                LojaRegras.Revogar(sessao, "Usuário bloqueado.");
                await db.SaveChangesAsync();
                return "Seu acesso foi bloqueado pelo administrador.";
            }

            if (usuario.LojaId.HasValue)
            {
                var loja = await db.Lojas.FirstOrDefaultAsync(l => l.Id == usuario.LojaId.Value);
                var bloqueio = await LojaRegras.VerificarAsync(db, loja);
                if (bloqueio is not null)
                {
                    // VerificarAsync já derruba as sessões quando suspende por vencimento;
                    // na suspensão manual elas foram derrubadas no ato. Garante este caso:
                    if (!sessao.Revogada) LojaRegras.Revogar(sessao, bloqueio);
                    await db.SaveChangesAsync();
                    return bloqueio;
                }
            }

            // Marca a atividade no máximo a cada minuto (evita gravar a cada clique).
            if ((agora - sessao.UltimaAtividade).TotalSeconds > 60)
            {
                sessao.UltimaAtividade = agora;
                usuario.UltimoAcessoEm = agora;
                await db.SaveChangesAsync();
            }

            return null;
        }
    }
}
