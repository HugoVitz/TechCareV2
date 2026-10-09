using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;
using TechCarePro.Services;

namespace TechCarePro.Controllers
{
    /// <summary>Clientes do sistema (lojas): cadastro, vencimento e suspensão por falta de pagamento. Só o Dono.</summary>
    [ApiController]
    [Authorize(Roles = Perfis.Dono)]
    [Route("api/lojas")]
    public class LojasController : ControllerBase
    {
        private readonly AppDbContext _context;
        private readonly ICurrentTenant _tenant;

        public LojasController(AppDbContext context, ICurrentTenant tenant)
        {
            _context = context;
            _tenant = tenant;
        }

        public class CriarLojaRequest
        {
            public string Nome { get; set; } = string.Empty;
            public DateTime? VencimentoEm { get; set; }
            public string AdminUsuario { get; set; } = string.Empty;
            public string? AdminNome { get; set; }
            public string? AdminSenha { get; set; }
        }

        public class AtualizarLojaRequest
        {
            public string? Nome { get; set; }
            public DateTime? VencimentoEm { get; set; }
            public bool LimparVencimento { get; set; }
        }

        public class SuspenderRequest
        {
            public string? Motivo { get; set; }
        }

        public class ReativarRequest
        {
            public DateTime? NovoVencimentoEm { get; set; }
        }

        [HttpGet]
        public async Task<IActionResult> Listar()
        {
            var lojas = await _context.Lojas.AsNoTracking().OrderBy(l => l.Nome).ToListAsync();
            var usuarios = await _context.Usuarios.AsNoTracking()
                .Where(u => u.LojaId != null)
                .Select(u => new { u.Id, u.LojaId, u.Perfil, u.Ativo })
                .ToListAsync();
            var agora = DateTime.UtcNow;
            var ativas = await _context.Sessoes.AsNoTracking()
                .Where(s => !s.Revogada && s.ExpiraEm > agora && s.LojaId != null)
                .Select(s => s.LojaId)
                .ToListAsync();

            return Ok(lojas.Select(l => new
            {
                l.Id,
                l.Nome,
                l.Status,
                l.VencimentoEm,
                Vencida = l.Status == Loja.Ativa && LojaRegras.Vencida(l),
                l.MotivoSuspensao,
                l.CriadaEm,
                Usuarios = usuarios.Count(u => u.LojaId == l.Id),
                Admins = usuarios.Count(u => u.LojaId == l.Id && u.Perfil == Perfis.Admin && u.Ativo),
                SessoesAtivas = ativas.Count(x => x == l.Id)
            }));
        }

        [HttpPost]
        public async Task<IActionResult> Criar([FromBody] CriarLojaRequest request)
        {
            var nome = request.Nome?.Trim() ?? string.Empty;
            var login = request.AdminUsuario?.Trim() ?? string.Empty;

            if (string.IsNullOrWhiteSpace(nome)) return BadRequest("Informe o nome da loja.");
            if (string.IsNullOrWhiteSpace(login)) return BadRequest("Informe o usuário do administrador da loja.");
            if (await _context.Usuarios.AnyAsync(u => u.UsuarioNome == login))
                return Conflict("Usuário já cadastrado. Escolha outro nome de usuário.");

            var gerada = string.IsNullOrWhiteSpace(request.AdminSenha);
            var senha = gerada ? SenhaTemporaria.Gerar() : request.AdminSenha!;
            if (senha.Length < 6) return BadRequest("A senha deve conter no mínimo 6 caracteres.");

            var loja = new Loja { Nome = nome, VencimentoEm = request.VencimentoEm?.Date };
            _context.Lojas.Add(loja);
            await _context.SaveChangesAsync();

            var admin = new Usuario
            {
                UsuarioNome = login,
                SenhaHash = PasswordHasher.Hash(senha),
                Perfil = Perfis.Admin,
                LojaId = loja.Id,
                DeveTrocarSenha = true
            };
            _context.Usuarios.Add(admin);
            await _context.SaveChangesAsync();

            _context.UsuarioPerfis.Add(new UsuarioPerfil
            {
                UsuarioId = admin.Id,
                Nome = string.IsNullOrWhiteSpace(request.AdminNome) ? login : request.AdminNome.Trim(),
                Cargo = "Administrador"
            });

            AuditoriaService.Registrar(_context, _tenant, "Loja criada", nome, loja.Id);
            await _context.SaveChangesAsync();

            return Ok(new { loja.Id, loja.Nome, AdminUsuario = login, SenhaTemporaria = senha });
        }

        [HttpPut("{id:int}")]
        public async Task<IActionResult> Atualizar(int id, [FromBody] AtualizarLojaRequest request)
        {
            var loja = await _context.Lojas.FirstOrDefaultAsync(l => l.Id == id);
            if (loja is null) return NotFound();

            if (!string.IsNullOrWhiteSpace(request.Nome)) loja.Nome = request.Nome.Trim();
            if (request.LimparVencimento) loja.VencimentoEm = null;
            else if (request.VencimentoEm.HasValue) loja.VencimentoEm = request.VencimentoEm.Value.Date;

            AuditoriaService.Registrar(_context, _tenant, "Loja alterada", loja.Nome, loja.Id,
                loja.VencimentoEm is null ? "Sem vencimento" : $"Vencimento {loja.VencimentoEm:dd/MM/yyyy}");
            await _context.SaveChangesAsync();
            return NoContent();
        }

        /// <summary>Exclui a loja e TODOS os dados dela (usuários, clientes, serviços, produtos, ordens, agendamentos). Não tem volta.</summary>
        [HttpDelete("{id:int}")]
        public async Task<IActionResult> Excluir(int id)
        {
            var loja = await _context.Lojas.FirstOrDefaultAsync(l => l.Id == id);
            if (loja is null) return NotFound();

            var usuarios = await _context.Usuarios.IgnoreQueryFilters().Where(u => u.LojaId == id).ToListAsync();
            if (usuarios.Any(u => u.Perfil == Perfis.Dono)) return BadRequest("Esta loja contém o Dono e não pode ser excluída.");
            var uids = usuarios.Select(u => u.Id).ToList();

            var ordens = await _context.OrdemServicos.IgnoreQueryFilters()
                .Include(o => o.Itens).Include(o => o.Produtos).Include(o => o.Imagens)
                .Where(o => o.LojaId == id).ToListAsync();
            _context.OrdemServicos.RemoveRange(ordens);
            _context.Agendamentos.RemoveRange(await _context.Agendamentos.IgnoreQueryFilters().Where(x => x.LojaId == id).ToListAsync());
            _context.Pacientes.RemoveRange(await _context.Pacientes.IgnoreQueryFilters().Where(x => x.LojaId == id).ToListAsync());
            _context.Servicos.RemoveRange(await _context.Servicos.IgnoreQueryFilters().Where(x => x.LojaId == id).ToListAsync());
            _context.Produtos.RemoveRange(await _context.Produtos.IgnoreQueryFilters().Where(x => x.LojaId == id).ToListAsync());

            _context.Sessoes.RemoveRange(await _context.Sessoes.Where(s => s.LojaId == id || uids.Contains(s.UsuarioId)).ToListAsync());
            _context.UsuarioPerfis.RemoveRange(await _context.UsuarioPerfis.Where(p => uids.Contains(p.UsuarioId)).ToListAsync());
            _context.UsuarioPreferencias.RemoveRange(await _context.UsuarioPreferencias.Where(p => uids.Contains(p.UsuarioId)).ToListAsync());
            _context.Usuarios.RemoveRange(usuarios);
            _context.Lojas.Remove(loja);

            AuditoriaService.Registrar(_context, _tenant, "Loja excluída", loja.Nome, null,
                $"{usuarios.Count} usuário(s) e {ordens.Count} ordem(ns) removidos");
            await _context.SaveChangesAsync();
            return NoContent();
        }

        /// <summary>Suspende a loja por falta de pagamento e derruba as sessões de todos os usuários dela.</summary>
        [HttpPost("{id:int}/suspender")]
        public async Task<IActionResult> Suspender(int id, [FromBody] SuspenderRequest? request)
        {
            var loja = await _context.Lojas.FirstOrDefaultAsync(l => l.Id == id);
            if (loja is null) return NotFound();

            var motivo = string.IsNullOrWhiteSpace(request?.Motivo) ? "Falta de pagamento." : request!.Motivo!.Trim();
            loja.Status = Loja.Suspensa;
            loja.MotivoSuspensao = motivo;

            var derrubadas = await LojaRegras.RevogarSessoesDaLojaAsync(_context, loja.Id, LojaRegras.MensagemSuspensa);

            AuditoriaService.Registrar(_context, _tenant, "Loja suspensa", loja.Nome, loja.Id,
                $"{motivo} ({derrubadas} sessão(ões) derrubada(s))");
            await _context.SaveChangesAsync();

            return Ok(new { loja.Id, loja.Status, SessoesDerrubadas = derrubadas });
        }

        [HttpPost("{id:int}/reativar")]
        public async Task<IActionResult> Reativar(int id, [FromBody] ReativarRequest? request)
        {
            var loja = await _context.Lojas.FirstOrDefaultAsync(l => l.Id == id);
            if (loja is null) return NotFound();

            if (request?.NovoVencimentoEm is not null) loja.VencimentoEm = request.NovoVencimentoEm.Value.Date;
            if (LojaRegras.Vencida(loja))
                return BadRequest("O vencimento já passou. Informe uma nova data de vencimento para reativar.");

            loja.Status = Loja.Ativa;
            loja.MotivoSuspensao = null;

            AuditoriaService.Registrar(_context, _tenant, "Loja reativada", loja.Nome, loja.Id,
                loja.VencimentoEm is null ? null : $"Vencimento {loja.VencimentoEm:dd/MM/yyyy}");
            await _context.SaveChangesAsync();

            return Ok(new { loja.Id, loja.Status });
        }
    }
}
