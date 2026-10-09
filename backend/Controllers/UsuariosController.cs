using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;
using TechCarePro.Services;

namespace TechCarePro.Controllers
{
    /// <summary>
    /// Gestão de usuários. O Admin gerencia a própria loja; o Dono gerencia todas.
    /// Senhas nunca são exibidas (ficam em hash): para "senha perdida" define-se uma senha temporária.
    /// </summary>
    [ApiController]
    [Authorize(Roles = Perfis.Gestores)]
    [Route("api/usuarios")]
    public class UsuariosController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentTenant _tenant;

        public UsuariosController(AppDbContext context, ICurrentTenant tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public class CriarUsuarioRequest
        {
            public string Usuario { get; set; } = string.Empty;
            public string? Senha { get; set; }
            public string? Nome { get; set; }
            public string? Cargo { get; set; }
            public string? Perfil { get; set; }
            public string? Etnia { get; set; }
            public int? LojaId { get; set; }
        }

        public class AtualizarUsuarioRequest
        {
            public string? Nome { get; set; }
            public string? Cargo { get; set; }
            public string? Perfil { get; set; }
            public string? Etnia { get; set; }   // "" apaga; nulo mantém
            public bool? Ativo { get; set; }
        }

        public class SenhaRequest
        {
            public string? Senha { get; set; }   // vazio = gerar automaticamente
        }

        private bool EhDono => _tenant.Perfil == Perfis.Dono;

        /// <summary>Usuários que o solicitante pode ver/alterar.</summary>
        private IQueryable<Usuario> Escopo(int? lojaId = null)
        {
            var q = _context.Usuarios.AsQueryable();
            if (EhDono)
                return lojaId.HasValue ? q.Where(u => u.LojaId == lojaId.Value) : q;

            return q.Where(u => u.LojaId == _tenant.LojaId && u.Perfil != Perfis.Dono);
        }

        private async Task<object> ProjetarAsync(List<Usuario> usuarios)
        {
            var ids = usuarios.Select(u => u.Id).ToList();
            var agora = DateTime.UtcNow;
            var limiteOnline = agora.AddSeconds(-90);

            var perfis = await _context.UsuarioPerfis.AsNoTracking()
                .Where(p => ids.Contains(p.UsuarioId))
                .Select(p => new { p.UsuarioId, p.Nome, p.Cargo, p.Etnia, p.FotoPerfilBase64 })
                .ToListAsync();

            var sessoes = await _context.Sessoes.AsNoTracking()
                .Where(s => ids.Contains(s.UsuarioId) && !s.Revogada && s.ExpiraEm > agora)
                .Select(s => new { s.UsuarioId, s.UltimaAtividade })
                .ToListAsync();

            var lojas = await _context.Lojas.AsNoTracking().ToDictionaryAsync(l => l.Id, l => l.Nome);

            return usuarios.Select(u =>
            {
                var p = perfis.FirstOrDefault(x => x.UsuarioId == u.Id);
                var minhas = sessoes.Where(s => s.UsuarioId == u.Id).ToList();
                return new
                {
                    u.Id,
                    u.UsuarioNome,
                    Nome = string.IsNullOrWhiteSpace(p?.Nome) ? u.UsuarioNome : p!.Nome,
                    Cargo = p?.Cargo ?? "",
                    Etnia = p?.Etnia,
                    Foto = p?.FotoPerfilBase64,
                    u.Perfil,
                    u.Ativo,
                    u.DeveTrocarSenha,
                    u.LojaId,
                    LojaNome = u.LojaId.HasValue && lojas.TryGetValue(u.LojaId.Value, out var ln) ? ln : null,
                    u.CriadoEm,
                    u.UltimoAcessoEm,
                    SessoesAtivas = minhas.Count,
                    Online = minhas.Any(s => s.UltimaAtividade > limiteOnline)
                };
            }).ToList();
        }

        [HttpGet]
        public async Task<IActionResult> Listar([FromQuery] int? lojaId = null)
        {
            var lista = await Escopo(lojaId).AsNoTracking().OrderBy(u => u.UsuarioNome).ToListAsync();
            return Ok(await ProjetarAsync(lista));
        }

        [HttpPost]
        public async Task<IActionResult> Criar([FromBody] CriarUsuarioRequest request)
        {
            var login = request.Usuario?.Trim() ?? string.Empty;
            var perfil = string.IsNullOrWhiteSpace(request.Perfil) ? Perfis.Atendente : request.Perfil.Trim();

            if (string.IsNullOrWhiteSpace(login) || login.Length > 60)
                return BadRequest("Informe o usuário (até 60 caracteres).");
            if (!Perfis.DaLoja.Contains(perfil))
                return BadRequest("Perfil inválido. Use Admin ou Atendente.");
            if (!Etnias.Valida(request.Etnia))
                return BadRequest("Etnia inválida.");
            if (await _context.Usuarios.AnyAsync(u => u.UsuarioNome == login))
                return Conflict("Usuário já cadastrado. Escolha outro nome de usuário.");

            int lojaId;
            if (EhDono)
            {
                if (request.LojaId is null) return BadRequest("Informe a loja do usuário.");
                if (!await _context.Lojas.AnyAsync(l => l.Id == request.LojaId.Value))
                    return BadRequest("Loja inválida.");
                lojaId = request.LojaId.Value;
            }
            else
            {
                lojaId = _tenant.LojaId;
            }

            var gerada = string.IsNullOrWhiteSpace(request.Senha);
            var senha = gerada ? SenhaTemporaria.Gerar() : request.Senha!;
            if (senha.Length < 6) return BadRequest("A senha deve conter no mínimo 6 caracteres.");

            var usuario = new Usuario
            {
                UsuarioNome = login,
                SenhaHash = PasswordHasher.Hash(senha),
                Perfil = perfil,
                LojaId = lojaId,
                DeveTrocarSenha = true   // a senha inicial é provisória: o próprio usuário define a dele
            };
            _context.Usuarios.Add(usuario);
            await _context.SaveChangesAsync();

            _context.UsuarioPerfis.Add(new UsuarioPerfil
            {
                UsuarioId = usuario.Id,
                Nome = string.IsNullOrWhiteSpace(request.Nome) ? login : request.Nome.Trim(),
                Cargo = request.Cargo?.Trim() ?? string.Empty,
                Etnia = Etnias.Normaliza(request.Etnia)
            });

            AuditoriaService.Registrar(_context, _tenant, "Usuário criado", login, lojaId, $"Perfil {perfil}");
            await _context.SaveChangesAsync();

            return Ok(new { usuario.Id, usuario.UsuarioNome, usuario.Perfil, SenhaTemporaria = senha });
        }

        [HttpPut("{id:int}")]
        public async Task<IActionResult> Atualizar(int id, [FromBody] AtualizarUsuarioRequest request)
        {
            var usuario = await Escopo().FirstOrDefaultAsync(u => u.Id == id);
            if (usuario is null) return NotFound();
            if (usuario.Perfil == Perfis.Dono) return BadRequest("O Dono não pode ser alterado por aqui.");

            var proprio = usuario.Id == _tenant.UsuarioId;
            var novoPerfil = string.IsNullOrWhiteSpace(request.Perfil) ? usuario.Perfil : request.Perfil.Trim();

            if (!Perfis.DaLoja.Contains(novoPerfil)) return BadRequest("Perfil inválido. Use Admin ou Atendente.");
            if (!Etnias.Valida(request.Etnia)) return BadRequest("Etnia inválida.");
            if (proprio && (novoPerfil != usuario.Perfil || request.Ativo == false))
                return BadRequest("Você não pode bloquear nem rebaixar o seu próprio usuário.");

            var perdeAdmin = usuario.Perfil == Perfis.Admin &&
                             (novoPerfil != Perfis.Admin || request.Ativo == false);
            if (perdeAdmin)
            {
                var outros = await _context.Usuarios.CountAsync(u =>
                    u.LojaId == usuario.LojaId && u.Perfil == Perfis.Admin && u.Ativo && u.Id != usuario.Id);
                if (outros == 0)
                    return BadRequest("A loja precisa de ao menos um administrador ativo.");
            }

            var perfilMudou = novoPerfil != usuario.Perfil;
            var bloqueou = usuario.Ativo && request.Ativo == false;

            usuario.Perfil = novoPerfil;
            if (request.Ativo.HasValue) usuario.Ativo = request.Ativo.Value;

            var dados = await _context.UsuarioPerfis.FirstOrDefaultAsync(p => p.UsuarioId == usuario.Id);
            if (dados is null)
            {
                dados = new UsuarioPerfil { UsuarioId = usuario.Id, Nome = usuario.UsuarioNome, Cargo = string.Empty };
                _context.UsuarioPerfis.Add(dados);
            }
            if (request.Nome is not null && !string.IsNullOrWhiteSpace(request.Nome)) dados.Nome = request.Nome.Trim();
            if (request.Cargo is not null) dados.Cargo = request.Cargo.Trim();
            if (request.Etnia is not null) dados.Etnia = Etnias.Normaliza(request.Etnia);

            if (bloqueou)
                await LojaRegras.RevogarSessoesDoUsuarioAsync(_context, usuario.Id, "Seu acesso foi bloqueado pelo administrador.");
            else if (perfilMudou)
                await LojaRegras.RevogarSessoesDoUsuarioAsync(_context, usuario.Id, "Seu perfil foi alterado. Entre novamente.");

            AuditoriaService.Registrar(_context, _tenant,
                bloqueou ? "Usuário bloqueado" : "Usuário alterado", usuario.UsuarioNome, usuario.LojaId);
            await _context.SaveChangesAsync();

            return NoContent();
        }

        /// <summary>
        /// "Senha perdida": define uma senha temporária (informada ou gerada), derruba as sessões do
        /// usuário e o obriga a trocá-la no próximo acesso. A senha só é mostrada nesta resposta.
        /// </summary>
        [HttpPost("{id:int}/senha-temporaria")]
        public async Task<IActionResult> SenhaTemporariaAsync(int id, [FromBody] SenhaRequest? request)
        {
            var usuario = await Escopo().FirstOrDefaultAsync(u => u.Id == id);
            if (usuario is null) return NotFound();
            if (usuario.Perfil == Perfis.Dono && !EhDono) return NotFound();

            var senha = string.IsNullOrWhiteSpace(request?.Senha) ? SenhaTemporaria.Gerar() : request!.Senha!;
            if (senha.Length < 6) return BadRequest("A senha deve conter no mínimo 6 caracteres.");

            usuario.SenhaHash = PasswordHasher.Hash(senha);
            usuario.DeveTrocarSenha = true;
            await LojaRegras.RevogarSessoesDoUsuarioAsync(_context, usuario.Id,
                "Sua senha foi redefinida pelo administrador. Entre com a senha temporária.");

            AuditoriaService.Registrar(_context, _tenant, "Senha redefinida", usuario.UsuarioNome, usuario.LojaId);
            await _context.SaveChangesAsync();

            return Ok(new { usuario.Id, usuario.UsuarioNome, SenhaTemporaria = senha });
        }

        /// <summary>Encerra todas as sessões abertas do usuário, na hora.</summary>
        [HttpPost("{id:int}/derrubar")]
        public async Task<IActionResult> Derrubar(int id)
        {
            var usuario = await Escopo().FirstOrDefaultAsync(u => u.Id == id);
            if (usuario is null) return NotFound();
            if (usuario.Id == _tenant.UsuarioId)
                return BadRequest("Para encerrar a sua própria sessão use o botão Sair.");

            var qtd = await LojaRegras.RevogarSessoesDoUsuarioAsync(_context, usuario.Id,
                "Sua sessão foi encerrada pelo administrador.");

            AuditoriaService.Registrar(_context, _tenant, "Sessão derrubada", usuario.UsuarioNome, usuario.LojaId,
                $"{qtd} sessão(ões)");
            await _context.SaveChangesAsync();

            return Ok(new { Encerradas = qtd });
        }

        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Excluir(int id)
        {
            var usuario = await Escopo().FirstOrDefaultAsync(u => u.Id == id);
            if (usuario is null) return NotFound();
            if (usuario.Perfil == Perfis.Dono) return BadRequest("O Dono não pode ser excluído.");
            if (usuario.Id == _tenant.UsuarioId)
                return BadRequest("Você não pode excluir o próprio usuário.");

            if (usuario.Perfil == Perfis.Admin)
            {
                var outros = await _context.Usuarios.CountAsync(u =>
                    u.LojaId == usuario.LojaId && u.Perfil == Perfis.Admin && u.Ativo && u.Id != usuario.Id);
                if (outros == 0) return BadRequest("A loja precisa de ao menos um administrador ativo.");
            }

            _context.Sessoes.RemoveRange(_context.Sessoes.Where(s => s.UsuarioId == id));
            _context.UsuarioPerfis.RemoveRange(_context.UsuarioPerfis.Where(p => p.UsuarioId == id));
            _context.UsuarioPreferencias.RemoveRange(_context.UsuarioPreferencias.Where(p => p.UsuarioId == id));
            _context.Usuarios.Remove(usuario);

            AuditoriaService.Registrar(_context, _tenant, "Usuário excluído", usuario.UsuarioNome, usuario.LojaId);
            await _context.SaveChangesAsync();

            return NoContent();
        }
    }
}
