using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Admin.Models;
using TechCare.Admin.Services;

namespace TechCare.Admin.Controllers
{
    /// <summary>Todos os usuários de todas as lojas: senha perdida, bloqueio e sessão.</summary>
    [Authorize(Roles = "Dono")]
    public class UsuariosController : Controller
    {
        private readonly ApiClient _api;
        public UsuariosController(ApiClient api) => _api = api;

        public async Task<IActionResult> Index(int? lojaId)
        {
            var r = await _api.GetAsync<List<UsuarioVm>>(lojaId.HasValue ? $"usuarios?lojaId={lojaId}" : "usuarios");
            if (!r.Ok) TempData["Erro"] = r.Error;
            ViewData["LojaId"] = lojaId;
            return View(r.Data ?? new List<UsuarioVm>());
        }

        private static readonly string[] EtniasOpcoes = { "Branca", "Preta", "Parda", "Amarela", "Indígena", "Prefiro não informar" };

        public async Task<IActionResult> Editar(int id, int? lojaId)
        {
            var r = await _api.GetAsync<List<UsuarioVm>>("usuarios");
            var u = r.Data?.FirstOrDefault(x => x.Id == id);
            if (u is null) { TempData["Erro"] = r.Error ?? "Usuário não encontrado."; return RedirectToAction(nameof(Index), new { lojaId }); }
            ViewData["Etnias"] = EtniasOpcoes;
            return View(new EditarUsuarioVm { Id = u.Id, LojaId = u.LojaId, UsuarioNome = u.UsuarioNome, Nome = u.Nome, Cargo = u.Cargo, Perfil = u.Perfil, Etnia = u.Etnia });
        }

        [HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> Editar(EditarUsuarioVm model)
        {
            ViewData["Etnias"] = EtniasOpcoes;
            if (!ModelState.IsValid) return View(model);
            var r = await _api.PutAsync<bool>($"usuarios/{model.Id}", new
            {
                nome = model.Nome,
                cargo = model.Cargo ?? "",
                perfil = model.Perfil,
                etnia = model.Etnia ?? ""
            });
            if (!r.Ok) { ModelState.AddModelError(string.Empty, r.Error ?? "Erro ao salvar."); return View(model); }
            TempData["Ok"] = "Usuário atualizado.";
            return RedirectToAction(nameof(Index), new { lojaId = model.LojaId });
        }

        [HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> Excluir(int id, int? lojaId)
        {
            var r = await _api.DeleteAsync($"usuarios/{id}");
            if (r.Ok) TempData["Ok"] = "Usuário excluído."; else TempData["Erro"] = r.Error;
            return RedirectToAction(nameof(Index), new { lojaId });
        }

        [HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> SenhaTemporaria(int id, string usuario)
        {
            var r = await _api.PostAsync<Dictionary<string, object>>($"usuarios/{id}/senha-temporaria", new { });
            if (!r.Ok || r.Data is null)
            {
                TempData["Erro"] = r.Error;
                return RedirectToAction(nameof(Index));
            }
            return View("~/Views/Lojas/SenhaGerada.cshtml", new SenhaGeradaVm
            {
                Usuario = usuario,
                Senha = r.Data["senhaTemporaria"].ToString() ?? "",
                Contexto = "Senha provisória gerada. As sessões do usuário foram encerradas:"
            });
        }

        [HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> Ativo(int id, bool ativo, int? lojaId)
        {
            var r = await _api.PutAsync<bool>($"usuarios/{id}", new { ativo });
            if (r.Ok) TempData["Ok"] = ativo ? "Usuário reativado." : "Usuário bloqueado e desconectado.";
            else TempData["Erro"] = r.Error;
            return RedirectToAction(nameof(Index), new { lojaId });
        }

        [HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> Derrubar(int id, int? lojaId)
        {
            var r = await _api.PostAsync<bool>($"usuarios/{id}/derrubar", new { });
            if (r.Ok) TempData["Ok"] = "Sessões do usuário encerradas."; else TempData["Erro"] = r.Error;
            return RedirectToAction(nameof(Index), new { lojaId });
        }
    }
}
