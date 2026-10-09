using Microsoft.EntityFrameworkCore;
using TechCarePro.Models;
using TechCarePro.Security;

namespace TechCarePro.Api.Data
{
    /// <summary>
    /// Cria o banco (primeira execução) e atualiza bancos de versões anteriores sem perder dados:
    /// adiciona as tabelas/colunas novas (lojas, sessões, auditoria, etnia) e leva os dados antigos
    /// para a "Loja Principal".
    /// </summary>
    public static class SchemaUpdater
    {
        public static void Executar(AppDbContext db, IConfiguration config)
        {
            db.Database.EnsureCreated();

            // Tabelas novas (no-op se o banco acabou de ser criado pelo EnsureCreated).
            Sql(db, @"CREATE TABLE IF NOT EXISTS ""Lojas"" (
                ""Id"" INTEGER NOT NULL CONSTRAINT ""PK_Lojas"" PRIMARY KEY AUTOINCREMENT,
                ""Nome"" TEXT NOT NULL, ""Status"" TEXT NOT NULL, ""VencimentoEm"" TEXT NULL,
                ""MotivoSuspensao"" TEXT NULL, ""CriadaEm"" TEXT NOT NULL);");

            Sql(db, @"CREATE TABLE IF NOT EXISTS ""Sessoes"" (
                ""Id"" TEXT NOT NULL CONSTRAINT ""PK_Sessoes"" PRIMARY KEY,
                ""UsuarioId"" INTEGER NOT NULL, ""LojaId"" INTEGER NULL, ""CriadaEm"" TEXT NOT NULL,
                ""UltimaAtividade"" TEXT NOT NULL, ""ExpiraEm"" TEXT NOT NULL, ""Ip"" TEXT NULL,
                ""Agente"" TEXT NULL, ""Revogada"" INTEGER NOT NULL, ""MotivoRevogacao"" TEXT NULL,
                ""RevogadaEm"" TEXT NULL);");
            Sql(db, @"CREATE INDEX IF NOT EXISTS ""IX_Sessoes_UsuarioId"" ON ""Sessoes"" (""UsuarioId"");");

            Sql(db, @"CREATE TABLE IF NOT EXISTS ""Auditorias"" (
                ""Id"" INTEGER NOT NULL CONSTRAINT ""PK_Auditorias"" PRIMARY KEY AUTOINCREMENT,
                ""Data"" TEXT NOT NULL, ""AtorId"" INTEGER NULL, ""AtorNome"" TEXT NOT NULL,
                ""LojaId"" INTEGER NULL, ""Acao"" TEXT NOT NULL, ""Alvo"" TEXT NOT NULL, ""Detalhe"" TEXT NULL);");

            Sql(db, @"CREATE TABLE IF NOT EXISTS ""Produtos"" (
                ""Id"" INTEGER NOT NULL CONSTRAINT ""PK_Produtos"" PRIMARY KEY AUTOINCREMENT,
                ""LojaId"" INTEGER NOT NULL, ""Nome"" TEXT NOT NULL, ""Preco"" TEXT NOT NULL,
                ""Estoque"" INTEGER NOT NULL, ""Ativo"" INTEGER NOT NULL);");

            Sql(db, @"CREATE TABLE IF NOT EXISTS ""OrdemServicoProdutos"" (
                ""Id"" INTEGER NOT NULL CONSTRAINT ""PK_OrdemServicoProdutos"" PRIMARY KEY AUTOINCREMENT,
                ""OrdemServicoId"" INTEGER NOT NULL, ""ProdutoId"" INTEGER NOT NULL, ""Nome"" TEXT NOT NULL,
                ""Quantidade"" INTEGER NOT NULL, ""ValorUnitario"" TEXT NOT NULL,
                CONSTRAINT ""FK_OrdemServicoProdutos_OrdensServico_OrdemServicoId"" FOREIGN KEY (""OrdemServicoId"")
                    REFERENCES ""OrdensServico"" (""Id"") ON DELETE CASCADE);");
            Sql(db, @"CREATE INDEX IF NOT EXISTS ""IX_OrdemServicoProdutos_OrdemServicoId"" ON ""OrdemServicoProdutos"" (""OrdemServicoId"");");

            // Colunas novas em tabelas antigas.
            AddColumn(db, "Usuarios", "Perfil", "TEXT NOT NULL DEFAULT 'Atendente'");
            AddColumn(db, "Usuarios", "LojaId", "INTEGER NULL");
            AddColumn(db, "Usuarios", "Ativo", "INTEGER NOT NULL DEFAULT 1");
            AddColumn(db, "Usuarios", "DeveTrocarSenha", "INTEGER NOT NULL DEFAULT 0");
            AddColumn(db, "Usuarios", "UltimoAcessoEm", "TEXT NULL");
            AddColumn(db, "UsuarioPerfis", "Etnia", "TEXT NULL");
            AddColumn(db, "Pacientes", "Etnia", "TEXT NULL");
            AddColumn(db, "OrdensServico", "Garantia", "TEXT NULL");
            AddColumn(db, "OrdensServico", "Desconto", "TEXT NOT NULL DEFAULT '0'");
            AddColumn(db, "OrdensServico", "FormaPagamento", "TEXT NULL");
            AddColumn(db, "OrdensServico", "VendedorId", "INTEGER NULL");
            AddColumn(db, "OrdensServico", "VendedorNome", "TEXT NULL");
            foreach (var t in new[] { "Pacientes", "Agendamentos", "Servicos", "OrdensServico" })
                AddColumn(db, t, "LojaId", "INTEGER NOT NULL DEFAULT 1");

            MigrarDadosAntigos(db);
            Semear(db, config);
        }

        private static void MigrarDadosAntigos(AppDbContext db)
        {
            // Usuários de versões anteriores (sem loja) passam a ser da "Loja Principal" (Id 1).
            var orfaos = db.Usuarios.Any(u => u.LojaId == null && u.Perfil != Perfis.Dono);
            var temDados =
                db.Pacientes.IgnoreQueryFilters().Any() || db.Servicos.IgnoreQueryFilters().Any() ||
                db.OrdemServicos.IgnoreQueryFilters().Any() ||
                db.Agendamentos.IgnoreQueryFilters().Any();

            if ((orfaos || temDados) && !db.Lojas.Any())
            {
                db.Lojas.Add(new Loja { Id = 1, Nome = "Loja Principal" });
                db.SaveChanges();
            }

            if (orfaos)
            {
                Sql(db, "UPDATE Usuarios SET LojaId = 1 WHERE LojaId IS NULL AND Perfil <> 'Dono';");
                // Se ninguém era Admin, o usuário mais antigo da loja assume.
                Sql(db, "UPDATE Usuarios SET Perfil = 'Admin' WHERE Id = (SELECT MIN(Id) FROM Usuarios WHERE LojaId = 1) " +
                        "AND NOT EXISTS (SELECT 1 FROM Usuarios WHERE LojaId = 1 AND Perfil = 'Admin');");
            }
        }

        private static void Semear(AppDbContext db, IConfiguration config)
        {
            if (db.Usuarios.Any()) return;

            // Dono do sistema (somente se configurado; em produção o 1º cadastro vira Dono).
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

            // Loja de demonstração com um Admin (somente se configurado).
            var adminUser = config["Seed:AdminUser"];
            var adminPass = config["Seed:AdminPassword"];
            if (!string.IsNullOrWhiteSpace(adminUser) && !string.IsNullOrWhiteSpace(adminPass))
            {
                var loja = new Loja { Nome = config["Seed:LojaNome"] ?? "Loja Demo" };
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

        private static void Sql(AppDbContext db, string sql) => db.Database.ExecuteSqlRaw(sql);

        private static void AddColumn(AppDbContext db, string tabela, string coluna, string definicao)
        {
            var conn = db.Database.GetDbConnection();
            var abriu = conn.State != System.Data.ConnectionState.Open;
            if (abriu) conn.Open();

            try
            {
                var existe = false;
                using (var cmd = conn.CreateCommand())
                {
                    cmd.CommandText = $"PRAGMA table_info('{tabela}');";
                    using var reader = cmd.ExecuteReader();
                    while (reader.Read())
                        if (string.Equals(reader.GetString(1), coluna, StringComparison.OrdinalIgnoreCase))
                            existe = true;
                }

                if (!existe)
                    db.Database.ExecuteSqlRaw($"ALTER TABLE \"{tabela}\" ADD COLUMN \"{coluna}\" {definicao};");
            }
            finally
            {
                if (abriu) conn.Close();
            }
        }
    }
}
