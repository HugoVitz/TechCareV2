using Microsoft.Extensions.Diagnostics.HealthChecks;
using TechCarePro.Api.Data;

namespace TechCarePro.Services
{
    /// <summary>
    /// Sonda de prontidão (readiness) usada pelo Kubernetes: a réplica só recebe tráfego
    /// quando consegue falar com o PostgreSQL.
    /// </summary>
    public class BancoHealthCheck : IHealthCheck
    {
        private readonly AppDbContext _db;

        public BancoHealthCheck(AppDbContext db) => _db = db;

        public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
        {
            try
            {
                return await _db.Database.CanConnectAsync(cancellationToken)
                    ? HealthCheckResult.Healthy("PostgreSQL acessível.")
                    : HealthCheckResult.Unhealthy("PostgreSQL não respondeu.");
            }
            catch (Exception ex)
            {
                return HealthCheckResult.Unhealthy("Falha ao conectar no PostgreSQL.", ex);
            }
        }
    }
}
