namespace TechCarePro.Models
{
    public static class Perfis
    {
        /// <summary>Dono do sistema (quem vende): gerencia lojas, pagamento e sessões. Não vê dados das lojas.</summary>
        public const string Dono = "Dono";

        /// <summary>Administrador da loja: tudo da loja, incluindo serviços e atendentes.</summary>
        public const string Admin = "Admin";

        /// <summary>Atendente: operação do dia a dia, sem cadastrar serviços nem usuários.</summary>
        public const string Atendente = "Atendente";

        /// <summary>Perfis que pertencem a uma loja (valor usado em [Authorize(Roles = ...)]).</summary>
        public const string Loja = "Admin,Atendente";

        /// <summary>Quem pode gerenciar usuários.</summary>
        public const string Gestores = "Dono,Admin";

        public static readonly string[] DaLoja = { Admin, Atendente };
    }

    public class Usuario
    {
        public int Id { get; set; }
        public string UsuarioNome { get; set; } = string.Empty;
        public string SenhaHash { get; set; } = string.Empty;

        public string Perfil { get; set; } = Perfis.Atendente;

        /// <summary>Loja a que o usuário pertence. Nulo apenas para o Dono do sistema.</summary>
        public int? LojaId { get; set; }

        /// <summary>false = bloqueado: não consegue entrar e as sessões abertas caem.</summary>
        public bool Ativo { get; set; } = true;

        /// <summary>true = senha temporária: o usuário é obrigado a trocar no próximo acesso.</summary>
        public bool DeveTrocarSenha { get; set; }

        public DateTime? UltimoAcessoEm { get; set; }

        public DateTime CriadoEm { get; set; } = DateTime.UtcNow;
    }
}
