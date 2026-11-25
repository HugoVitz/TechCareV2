using Microsoft.EntityFrameworkCore;
using Npgsql;
using TechCarePro.Api.Data;

namespace TechCarePro.Services
{
    /// <summary>
    /// Tarefa em segundo plano que chama as rotinas de manutenção do banco a cada hora:
    /// suspende lojas vencidas (procedure), limpa sessões antigas (procedure) e atualiza
    /// a visão materializada de faturamento. Com várias réplicas no Kubernetes, o
    /// FOR UPDATE SKIP LOCKED da procedure evita que duas réplicas tratem a mesma loja.
    /// </summary>
    public class ManutencaoBancoService : BackgroundService
    {
        private static readonly TimeSpan Intervalo = TimeSpan.FromHours(1);
        private readonly IServiceScopeFactory _scopes;
        private readonly ILogger<ManutencaoBancoService> _logger;

        public ManutencaoBancoService(IServiceScopeFactory scopes, ILogger<ManutencaoBancoService> logger)
        {
            _scopes = scopes;
            _logger = logger;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            // Espera a API terminar de subir antes da primeira execução.
            await Task.Delay(TimeSpan.FromMinutes(1), stoppingToken);

            using var timer = new PeriodicTimer(Intervalo);
            do
            {
                await ExecutarRotinasAsync(stoppingToken);
            }
            while (await timer.WaitForNextTickAsync(stoppingToken));
        }

        private async Task ExecutarRotinasAsync(CancellationToken ct)
        {
            try
            {
                using var scope = _scopes.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
                var conexao = (NpgsqlConnection)db.Database.GetDbConnection();
                await conexao.OpenAsync(ct);
                try
                {
                    var suspensas = await ChamarAsync(conexao, $"CALL sp_suspender_lojas_vencidas({LojaRegras.DiasCarencia}, NULL)", ct);
                    var sessoes = await ChamarAsync(conexao, "CALL sp_limpar_sessoes(30, NULL)", ct);

                    await using (var refresh = new NpgsqlCommand("REFRESH MATERIALIZED VIEW CONCURRENTLY mv_faturamento_mensal", conexao))
                        await refresh.ExecuteNonQueryAsync(ct);

                    _logger.LogInformation("Manutenção do banco: {Lojas} loja(s) suspensa(s), {Sessoes} sessão(ões) removida(s).", suspensas, sessoes);
                }
                finally
                {
                    await conexao.CloseAsync();
                }
            }
            catch (OperationCanceledException)
            {
                // API sendo encerrada.
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Falha na manutenção periódica do banco.");
            }
        }

        /// <summary>Executa um CALL e devolve o valor do parâmetro INOUT (contador).</summary>
        private static async Task<int> ChamarAsync(NpgsqlConnection conexao, string sql, CancellationToken ct)
        {
            await using var cmd = new NpgsqlCommand(sql, conexao);
            var resultado = await cmd.ExecuteScalarAsync(ct);
            return resultado is int n ? n : Convert.ToInt32(resultado ?? 0);
        }
    }
}
