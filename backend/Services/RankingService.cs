using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Models;

namespace TechCarePro.Services
{
    public class RankingItem
    {
        public int Posicao { get; set; }
        public int UsuarioId { get; set; }
        public string Nome { get; set; } = string.Empty;
        public string Cargo { get; set; } = string.Empty;
        public string? Foto { get; set; }
        public decimal TotalVendido { get; set; }
        public int Ordens { get; set; }
    }

    /// <summary>Ranking de vendas do mês, por loja. Vale OS concluída (serviços + produtos - desconto).</summary>
    public static class RankingService
    {
        public static decimal Total(OrdemServico o) =>
            Math.Max(0, o.Itens.Sum(i => i.Quantidade * i.ValorUnitario)
                        + o.Produtos.Sum(p => p.Quantidade * p.ValorUnitario) - o.Desconto);

        public static async Task<List<RankingItem>> CalcularAsync(AppDbContext db, int lojaId, int ano, int mes, bool comFoto)
        {
            var ini = new DateTime(ano, mes, 1);
            var fim = ini.AddMonths(1);

            // O filtro por loja já vem do HasQueryFilter nas OS; usuários são filtrados à mão.
            var os = await db.OrdemServicos.AsNoTracking()
                .Include(o => o.Itens).Include(o => o.Produtos)
                .Where(o => o.Status.StartsWith("Conclu") && o.VendedorId != null
                            && (o.DataConclusao ?? o.DataAbertura) >= ini && (o.DataConclusao ?? o.DataAbertura) < fim)
                .ToListAsync();

            var usuarios = await db.Usuarios.AsNoTracking()
                .Where(u => u.LojaId == lojaId && u.Ativo && u.Perfil != Perfis.Dono)
                .ToListAsync();
            var ids = usuarios.Select(u => u.Id).ToList();
            var perfis = await db.UsuarioPerfis.AsNoTracking().Where(p => ids.Contains(p.UsuarioId)).ToListAsync();

            var lista = usuarios.Select(u =>
            {
                var p = perfis.FirstOrDefault(x => x.UsuarioId == u.Id);
                var minhas = os.Where(o => o.VendedorId == u.Id).ToList();
                return new RankingItem
                {
                    UsuarioId = u.Id,
                    Nome = string.IsNullOrWhiteSpace(p?.Nome) ? u.UsuarioNome : p!.Nome,
                    Cargo = p?.Cargo ?? u.Perfil,
                    Foto = comFoto ? p?.FotoPerfilBase64 : null,
                    TotalVendido = minhas.Sum(x => Total(x)),
                    Ordens = minhas.Count
                };
            })
            .OrderByDescending(r => r.TotalVendido).ThenByDescending(r => r.Ordens).ThenBy(r => r.Nome)
            .ToList();

            for (var i = 0; i < lista.Count; i++) lista[i].Posicao = i + 1;
            return lista;
        }

        /// <summary>Id do 1º colocado do mês atual (precisa ter vendido algo), ou null.</summary>
        public static async Task<int?> LiderDoMesAsync(AppDbContext db, int lojaId)
        {
            var agora = DateTime.Now;
            var r = await CalcularAsync(db, lojaId, agora.Year, agora.Month, false);
            var primeiro = r.FirstOrDefault();
            return primeiro is { TotalVendido: > 0 } ? primeiro.UsuarioId : null;
        }
    }
}
