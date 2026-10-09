using Microsoft.EntityFrameworkCore;
using TechCarePro.Models;
using TechCarePro.Security;

namespace TechCarePro.Api.Data
{
    public class AppDbContext : DbContext
    {
        private readonly ICurrentTenant _tenant;

        public AppDbContext(DbContextOptions<AppDbContext> options, ICurrentTenant tenant) : base(options)
        {
            _tenant = tenant;
        }

        /// <summary>Usado pelos filtros de consulta: cada loja só enxerga os próprios registros.</summary>
        public int CurrentLojaId => _tenant.LojaId;

        public DbSet<Loja> Lojas => Set<Loja>();
        public DbSet<Sessao> Sessoes => Set<Sessao>();
        public DbSet<Auditoria> Auditorias => Set<Auditoria>();

        public DbSet<Paciente> Pacientes => Set<Paciente>();
        public DbSet<Agendamento> Agendamentos => Set<Agendamento>();
        public DbSet<Usuario> Usuarios => Set<Usuario>();
        public DbSet<UsuarioPerfil> UsuarioPerfis => Set<UsuarioPerfil>();
        public DbSet<UsuarioPreferencias> UsuarioPreferencias => Set<UsuarioPreferencias>();
        public DbSet<Servico> Servicos => Set<Servico>();
        public DbSet<OrdemServico> OrdemServicos => Set<OrdemServico>();
        public DbSet<OrdemServicoItem> OrdemServicoItens => Set<OrdemServicoItem>();
        public DbSet<OrdemServicoImagem> OrdemServicoImagens => Set<OrdemServicoImagem>();
        public DbSet<Produto> Produtos => Set<Produto>();
        public DbSet<OrdemServicoProduto> OrdemServicoProdutos => Set<OrdemServicoProduto>();

        protected override void OnModelCreating(ModelBuilder modelBuilder)
        {
            modelBuilder.Entity<Loja>().ToTable("Lojas");
            modelBuilder.Entity<Loja>().Property(x => x.Nome).IsRequired().HasMaxLength(150);
            modelBuilder.Entity<Loja>().Property(x => x.Status).IsRequired().HasMaxLength(20);

            modelBuilder.Entity<Sessao>().ToTable("Sessoes");
            modelBuilder.Entity<Sessao>().HasKey(x => x.Id);
            modelBuilder.Entity<Sessao>().Property(x => x.Id).HasMaxLength(40);
            modelBuilder.Entity<Sessao>().HasIndex(x => x.UsuarioId);

            modelBuilder.Entity<Auditoria>().ToTable("Auditorias");
            modelBuilder.Entity<Auditoria>().Property(x => x.AtorNome).HasMaxLength(150);
            modelBuilder.Entity<Auditoria>().Property(x => x.Acao).HasMaxLength(80);
            modelBuilder.Entity<Auditoria>().Property(x => x.Alvo).HasMaxLength(200);

            modelBuilder.Entity<Usuario>().Property(x => x.Perfil).IsRequired().HasMaxLength(20);

            modelBuilder.Entity<Paciente>().ToTable("Pacientes");
            modelBuilder.Entity<Agendamento>().ToTable("Agendamentos");
            modelBuilder.Entity<Servico>().ToTable("Servicos");
            modelBuilder.Entity<OrdemServico>().ToTable("OrdensServico");
            modelBuilder.Entity<OrdemServicoItem>().ToTable("OrdemServicoItens");
            modelBuilder.Entity<OrdemServicoImagem>().ToTable("OrdemServicoImagens");
            modelBuilder.Entity<Produto>().ToTable("Produtos");
            modelBuilder.Entity<OrdemServicoProduto>().ToTable("OrdemServicoProdutos");

            // Isolamento entre lojas: toda consulta a estas tabelas já sai filtrada pela loja do usuário.
            modelBuilder.Entity<Paciente>().HasQueryFilter(e => e.LojaId == CurrentLojaId);
            modelBuilder.Entity<Agendamento>().HasQueryFilter(e => e.LojaId == CurrentLojaId);
            modelBuilder.Entity<Servico>().HasQueryFilter(e => e.LojaId == CurrentLojaId);
            modelBuilder.Entity<Produto>().HasQueryFilter(e => e.LojaId == CurrentLojaId);
            modelBuilder.Entity<OrdemServico>().HasQueryFilter(e => e.LojaId == CurrentLojaId);

            // Itens e imagens só existem ligados a uma OS; o filtro da OS vale para eles também.
            modelBuilder.Entity<OrdemServicoItem>().HasQueryFilter(e => e.OrdemServico!.LojaId == CurrentLojaId);
            modelBuilder.Entity<OrdemServicoImagem>().HasQueryFilter(e => e.OrdemServico!.LojaId == CurrentLojaId);
            modelBuilder.Entity<OrdemServicoProduto>().HasQueryFilter(e => e.OrdemServico!.LojaId == CurrentLojaId);

            modelBuilder.Entity<Produto>().Property(x => x.Nome).IsRequired().HasMaxLength(150);
            modelBuilder.Entity<OrdemServicoProduto>().Property(x => x.Nome).IsRequired().HasMaxLength(150);
            modelBuilder.Entity<OrdemServico>().Property(x => x.FormaPagamento).HasMaxLength(20);

            modelBuilder.Entity<Paciente>().Property(x => x.Nome).IsRequired().HasMaxLength(150);
            modelBuilder.Entity<Paciente>().Property(x => x.Email).IsRequired().HasMaxLength(150);
            modelBuilder.Entity<Paciente>().Property(x => x.Telefone).IsRequired().HasMaxLength(30);
            modelBuilder.Entity<Paciente>().Property(x => x.CPF).IsRequired().HasMaxLength(20);
            modelBuilder.Entity<Paciente>().Property(x => x.Etnia).HasMaxLength(30);


            modelBuilder.Entity<Agendamento>().Property(x => x.PacienteNome).IsRequired().HasMaxLength(150);
            modelBuilder.Entity<Agendamento>().Property(x => x.ProfissionalNome).IsRequired().HasMaxLength(150);
            modelBuilder.Entity<Agendamento>().Property(x => x.Status).IsRequired().HasMaxLength(50);

            modelBuilder.Entity<Servico>().Property(x => x.Titulo).IsRequired().HasMaxLength(150);
            modelBuilder.Entity<Servico>().Property(x => x.Descricao).IsRequired().HasMaxLength(1000);

            modelBuilder.Entity<OrdemServico>().Property(x => x.ClienteNome).IsRequired().HasMaxLength(150);
            modelBuilder.Entity<OrdemServico>().Property(x => x.ClienteTelefone).IsRequired().HasMaxLength(30);
            modelBuilder.Entity<OrdemServico>().Property(x => x.ClienteCPF).IsRequired().HasMaxLength(20);
            modelBuilder.Entity<OrdemServico>().Property(x => x.ClienteEmail).IsRequired().HasMaxLength(150);
            modelBuilder.Entity<OrdemServico>().Property(x => x.Titulo).IsRequired().HasMaxLength(200);
            modelBuilder.Entity<OrdemServico>().Property(x => x.Descricao).IsRequired().HasMaxLength(2000);
            modelBuilder.Entity<OrdemServico>().Property(x => x.Status).IsRequired().HasMaxLength(50);
            modelBuilder.Entity<OrdemServico>().Property(x => x.ProfissionalNome).IsRequired().HasMaxLength(150);

            modelBuilder.Entity<OrdemServicoImagem>().Property(x => x.NomeArquivo).IsRequired().HasMaxLength(255);
            modelBuilder.Entity<OrdemServicoImagem>().Property(x => x.ConteudoBase64).IsRequired();

            modelBuilder.Entity<UsuarioPerfil>().ToTable("UsuarioPerfis");
            modelBuilder.Entity<UsuarioPerfil>().HasKey(x => x.UsuarioId);

            modelBuilder.Entity<UsuarioPreferencias>().HasKey(x => x.UsuarioId);
            modelBuilder.Entity<UsuarioPerfil>().HasOne(x => x.Usuario).WithOne().HasForeignKey<UsuarioPerfil>(x => x.UsuarioId).OnDelete(DeleteBehavior.Cascade);
            modelBuilder.Entity<UsuarioPreferencias>().HasOne(x => x.Usuario).WithOne().HasForeignKey<UsuarioPreferencias>(x => x.UsuarioId).OnDelete(DeleteBehavior.Cascade);

            modelBuilder.Entity<UsuarioPerfil>().Property(x => x.Nome).HasMaxLength(200);
            modelBuilder.Entity<UsuarioPerfil>().Property(x => x.Cargo).HasMaxLength(200);
            modelBuilder.Entity<UsuarioPerfil>().Property(x => x.FotoPerfilBase64).IsRequired(false);

            modelBuilder.Entity<UsuarioPreferencias>().ToTable("UsuarioPreferencias");
            modelBuilder.Entity<UsuarioPreferencias>().Property(x => x.Tema).HasMaxLength(20);
            modelBuilder.Entity<UsuarioPreferencias>().Property(x => x.CorPrincipal).HasMaxLength(20);
        }

        // ---------- Loja sempre definida pelo servidor, nunca pelo cliente ----------

        private void AplicarLoja()
        {
            var lojaAtual = _tenant.LojaId;

            foreach (var entry in ChangeTracker.Entries<ITenantEntity>())
            {
                if (entry.State == EntityState.Added && lojaAtual > 0)
                {
                    entry.Entity.LojaId = lojaAtual; // ignora qualquer LojaId enviado no corpo
                }
                else if (entry.State == EntityState.Modified)
                {
                    entry.Property(x => x.LojaId).IsModified = false; // registro nunca muda de loja
                }
            }
        }

        public override int SaveChanges(bool acceptAllChangesOnSuccess)
        {
            AplicarLoja();
            return base.SaveChanges(acceptAllChangesOnSuccess);
        }

        public override Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
        {
            AplicarLoja();
            return base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
        }
    }
}
