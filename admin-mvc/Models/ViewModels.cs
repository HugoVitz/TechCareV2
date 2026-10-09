using System.ComponentModel.DataAnnotations;

namespace TechCare.Admin.Models
{
    public class LoginVm
    {
        [Required(ErrorMessage = "Informe o usuário.")]
        public string Usuario { get; set; } = string.Empty;

        [Required(ErrorMessage = "Informe a senha.")]
        [DataType(DataType.Password)]
        public string Senha { get; set; } = string.Empty;
    }

    public class LoginResposta
    {
        public string Token { get; set; } = string.Empty;
        public string Usuario { get; set; } = string.Empty;
        public string Perfil { get; set; } = string.Empty;
    }

    public class LojaVm
    {
        public int Id { get; set; }
        public string Nome { get; set; } = string.Empty;
        public string Status { get; set; } = string.Empty;
        public DateTime? VencimentoEm { get; set; }
        public bool Vencida { get; set; }
        public string? MotivoSuspensao { get; set; }
        public DateTime CriadaEm { get; set; }
        public int Usuarios { get; set; }
        public int Admins { get; set; }
        public int SessoesAtivas { get; set; }
    }

    public class NovaLojaVm
    {
        [Required(ErrorMessage = "Informe o nome da loja.")]
        public string Nome { get; set; } = string.Empty;

        [DataType(DataType.Date)]
        public DateTime? VencimentoEm { get; set; }

        [Required(ErrorMessage = "Informe o usuário do administrador.")]
        public string AdminUsuario { get; set; } = string.Empty;

        public string? AdminNome { get; set; }

        [MinLength(6, ErrorMessage = "A senha deve ter no mínimo 6 caracteres.")]
        public string? AdminSenha { get; set; }
    }

    public class EditarLojaVm
    {
        public int Id { get; set; }

        [Required(ErrorMessage = "Informe o nome da loja.")]
        public string Nome { get; set; } = string.Empty;

        [DataType(DataType.Date)]
        public DateTime? VencimentoEm { get; set; }
    }

    public class EditarUsuarioVm
    {
        public int Id { get; set; }
        public int? LojaId { get; set; }
        public string UsuarioNome { get; set; } = string.Empty;

        [Required(ErrorMessage = "Informe o nome.")]
        public string Nome { get; set; } = string.Empty;

        public string? Cargo { get; set; }
        public string Perfil { get; set; } = "Atendente";
        public string? Etnia { get; set; }
    }

    public class SenhaGeradaVm
    {
        public string Usuario { get; set; } = string.Empty;
        public string Senha { get; set; } = string.Empty;
        public string Contexto { get; set; } = string.Empty;
    }

    public class UsuarioVm
    {
        public int Id { get; set; }
        public string UsuarioNome { get; set; } = string.Empty;
        public string Nome { get; set; } = string.Empty;
        public string Cargo { get; set; } = string.Empty;
        public string? Etnia { get; set; }
        public string Perfil { get; set; } = string.Empty;
        public bool Ativo { get; set; }
        public bool DeveTrocarSenha { get; set; }
        public int? LojaId { get; set; }
        public string? LojaNome { get; set; }
        public DateTime? UltimoAcessoEm { get; set; }
        public int SessoesAtivas { get; set; }
        public bool Online { get; set; }
    }

    public class SessaoVm
    {
        public string Id { get; set; } = string.Empty;
        public string UsuarioNome { get; set; } = string.Empty;
        public string? Nome { get; set; }
        public string? Cargo { get; set; }
        public string? Perfil { get; set; }
        public string? LojaNome { get; set; }
        public DateTime CriadaEm { get; set; }
        public DateTime UltimaAtividade { get; set; }
        public bool Online { get; set; }
        public string? Ip { get; set; }
        public bool Atual { get; set; }
    }

    public class AuditoriaVm
    {
        public DateTime Data { get; set; }
        public string AtorNome { get; set; } = string.Empty;
        public int? LojaId { get; set; }
        public string Acao { get; set; } = string.Empty;
        public string Alvo { get; set; } = string.Empty;
        public string? Detalhe { get; set; }
    }

    public class EtniaQtdVm
    {
        public string Etnia { get; set; } = string.Empty;
        public int Quantidade { get; set; }
    }

    public class GrupoDiversidadeVm
    {
        public int Total { get; set; }
        public List<EtniaQtdVm> PorEtnia { get; set; } = new();
    }

    public class DiversidadeVm
    {
        public GrupoDiversidadeVm Clientes { get; set; } = new();
        public GrupoDiversidadeVm Equipe { get; set; } = new();
        public string Observacao { get; set; } = string.Empty;
    }
}
