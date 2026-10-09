using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Models;

namespace TechCarePro.Services
{
    /// <summary>Regras de assinatura: suspensão manual e vencimento automático.</summary>
    public static class LojaRegras
    {
        /// <summary>Dias de tolerância depois do vencimento antes de suspender sozinho.</summary>
        public const int DiasCarencia = 3;

        public const string MensagemSuspensa =
            "Acesso suspenso por pendência de pagamento. Entre em contato com o suporte para regularizar.";

        public static bool Vencida(Loja loja) =>
            loja.VencimentoEm.HasValue &&
            loja.VencimentoEm.Value.Date.AddDays(DiasCarencia) < DateTime.UtcNow.Date;

        /// <summary>
        /// Garante que uma loja vencida fique suspensa (e que as sessões dela caiam).
        /// Retorna a mensagem de bloqueio, ou null se a loja pode operar.
        /// </summary>
        public static async Task<string?> VerificarAsync(AppDbContext db, Loja? loja)
        {
            if (loja is null) return "Loja não encontrada. Entre em contato com o suporte.";

            if (loja.Status == Loja.Ativa && Vencida(loja))
            {
                loja.Status = Loja.Suspensa;
                loja.MotivoSuspensao = $"Vencimento em {loja.VencimentoEm:dd/MM/yyyy} sem pagamento.";
                await RevogarSessoesDaLojaAsync(db, loja.Id, "Loja suspensa por vencimento.");
                db.Auditorias.Add(new Auditoria
                {
                    AtorNome = "Sistema",
                    LojaId = loja.Id,
                    Acao = "Loja suspensa (vencimento)",
                    Alvo = loja.Nome,
                    Detalhe = loja.MotivoSuspensao
                });
                await db.SaveChangesAsync();
            }

            return loja.Status == Loja.Ativa ? null : MensagemSuspensa;
        }

        public static async Task<int> RevogarSessoesDaLojaAsync(AppDbContext db, int lojaId, string motivo)
        {
            var sessoes = await db.Sessoes.Where(s => s.LojaId == lojaId && !s.Revogada).ToListAsync();
            foreach (var s in sessoes) Revogar(s, motivo);
            return sessoes.Count;
        }

        public static async Task<int> RevogarSessoesDoUsuarioAsync(AppDbContext db, int usuarioId, string motivo, string? exceto = null)
        {
            var sessoes = await db.Sessoes
                .Where(s => s.UsuarioId == usuarioId && !s.Revogada && s.Id != exceto)
                .ToListAsync();
            foreach (var s in sessoes) Revogar(s, motivo);
            return sessoes.Count;
        }

        public static void Revogar(Sessao s, string motivo)
        {
            s.Revogada = true;
            s.MotivoRevogacao = motivo;
            s.RevogadaEm = DateTime.UtcNow;
        }
    }
}
