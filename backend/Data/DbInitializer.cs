using Microsoft.EntityFrameworkCore;
using Npgsql;
using TechCarePro.Models;
using TechCarePro.Security;

namespace TechCarePro.Api.Data
{
    /// <summary>
    /// Prepara o banco PostgreSQL na inicialização da API:
    /// 1) o EF Core cria as tabelas a partir dos modelos C# (se ainda não existirem);
    /// 2) os scripts da pasta Database/ criam functions, procedures, triggers, índices,
    ///    views e papéis de segurança (todos idempotentes, podem rodar a cada início);
    /// 3) as contas iniciais e, em desenvolvimento, os dados de demonstração são criados.
    /// </summary>
    public static class DbInitializer
    {
        public static void Executar(AppDbContext db, IConfiguration config, ILogger logger, bool desenvolvimento)
        {
            // Em contêiner o banco pode demorar alguns segundos para aceitar conexões.
            for (var tentativa = 1; ; tentativa++)
            {
                try
                {
                    db.Database.EnsureCreated();
                    break;
                }
                catch (NpgsqlException ex) when (tentativa < 10)
                {
                    logger.LogWarning("Banco indisponível ({Mensagem}). Nova tentativa em 3 s ({N}/10)...", ex.Message, tentativa);
                    Thread.Sleep(TimeSpan.FromSeconds(3));
                }
            }

            ExecutarScripts(db, logger);
            Semear(db, config);

            if (desenvolvimento && config.GetValue("Seed:DadosDemo", true))
                PopularDemo(db, logger);
        }

        /// <summary>Executa, em ordem alfabética, os arquivos .sql da pasta Database.</summary>
        private static void ExecutarScripts(AppDbContext db, ILogger logger)
        {
            var pasta = Path.Combine(AppContext.BaseDirectory, "Database");
            if (!Directory.Exists(pasta))
            {
                logger.LogWarning("Pasta de scripts SQL não encontrada: {Pasta}", pasta);
                return;
            }

            var conexao = (NpgsqlConnection)db.Database.GetDbConnection();
            var abriu = conexao.State != System.Data.ConnectionState.Open;
            if (abriu) conexao.Open();
            try
            {
                foreach (var arquivo in Directory.GetFiles(pasta, "*.sql").OrderBy(f => f, StringComparer.Ordinal))
                {
                    try
                    {
                        using var cmd = new NpgsqlCommand(File.ReadAllText(arquivo), conexao);
                        cmd.ExecuteNonQuery();
                        logger.LogInformation("Script de banco aplicado: {Arquivo}", Path.GetFileName(arquivo));
                    }
                    catch (PostgresException ex)
                    {
                        // Um script com problema não derruba a API: o erro fica no log para correção.
                        logger.LogError("Falha no script {Arquivo}: {Erro}", Path.GetFileName(arquivo), ex.MessageText);
                    }
                }
            }
            finally
            {
                if (abriu) conexao.Close();
            }
        }

        /// <summary>Contas iniciais (somente se configuradas em Seed:*).</summary>
        private static void Semear(AppDbContext db, IConfiguration config)
        {
            if (db.Usuarios.Any()) return;

            var donoUser = config["Seed:DonoUser"];
            var donoPass = config["Seed:DonoPassword"];
            if (!string.IsNullOrWhiteSpace(donoUser) && !string.IsNullOrWhiteSpace(donoPass))
            {
                db.Usuarios.Add(new Usuario
                {
                    UsuarioNome = donoUser,
                    SenhaHash = PasswordHasher.Hash(donoPass),
                    Perfil = Perfis.Dono,
                    LojaId = null
                });
                db.SaveChanges();
            }

            var adminUser = config["Seed:AdminUser"];
            var adminPass = config["Seed:AdminPassword"];
            if (!string.IsNullOrWhiteSpace(adminUser) && !string.IsNullOrWhiteSpace(adminPass))
            {
                var loja = new Loja { Nome = config["Seed:LojaNome"] ?? "Loja Demo", VencimentoEm = DateTime.UtcNow.Date.AddDays(30) };
                db.Lojas.Add(loja);
                db.SaveChanges();

                var admin = new Usuario
                {
                    UsuarioNome = adminUser,
                    SenhaHash = PasswordHasher.Hash(adminPass),
                    Perfil = Perfis.Admin,
                    LojaId = loja.Id
                };
                db.Usuarios.Add(admin);
                db.SaveChanges();

                db.UsuarioPerfis.Add(new UsuarioPerfil { UsuarioId = admin.Id, Nome = "Administrador", Cargo = "Gerente" });
                db.SaveChanges();
            }
        }

        /// <summary>Preenche a primeira loja com dados de exemplo (procedure sp_popular_demo).</summary>
        private static void PopularDemo(AppDbContext db, ILogger logger)
        {
            var lojaId = db.Lojas.OrderBy(l => l.Id).Select(l => (int?)l.Id).FirstOrDefault();
            if (lojaId is null) return;
            try
            {
                // CALL não aceita subconsultas como argumento: o id vai como parâmetro.
                db.Database.ExecuteSqlRaw("CALL sp_popular_demo(@p0, 40, 250)", new NpgsqlParameter("p0", lojaId.Value));
            }
            catch (PostgresException ex)
            {
                logger.LogWarning("Dados de demonstração não criados: {Erro}", ex.MessageText);
            }
        }
    }
}
