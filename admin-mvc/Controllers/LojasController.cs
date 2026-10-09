using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Admin.Models;
using TechCare.Admin.Services;

namespace TechCare.Admin.Controllers
{
    /// <summary>Clientes do sistema: cadastro, vencimento e suspensão por falta de pagamento.</summary>
    [Authorize(Roles = "Dono")]
    public class LojasController : Controller
    {
        private readonly ApiClient _api;
        public LojasController(ApiClient api) => _api = api;

        public async Task<IActionResult> Index()
        {
            var r = await _api.GetAsync<List<LojaVm>>("lojas");
            if (!r.Ok) TempData["Erro"] = r.Error;
            return View(r.Data ?? new List<LojaVm>());
        }

        public IActionResult Nova() => View(new NovaLojaVm());

        [HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> Nova(NovaLojaVm model)
        {
            if (!ModelState.IsValid) return View(model);

            var r = await _api.PostAsync<Dictionary<string, object>>("lojas", new
            {
                nome = model.Nome,
                vencimentoEm = model.VencimentoEm,
                adminUsuario = model.AdminUsuario,
                adminNome = model.AdminNome,
                adminSenha = string.IsNullOrWhiteSpace(model.AdminSenha) ? null : model.AdminSenha
            });

            if (!r.Ok || r.Data is null)
            {
                ModelState.AddModelError(string.Empty, r.Error ?? "Erro ao criar a loja.");
                return View(model);
            }

            return View("SenhaGerada", new SenhaGeradaVm
            {
                Usuario = model.AdminUsuario,
                Senha = r.Data["senhaTemporaria"].ToString() ?? "",
                Contexto = $"Loja \"{model.Nome}\" criada. Entregue o acesso do administrador:"
            });
        }

        public async Task<IActionResult> Editar(int id)
        {
            var r = await _api.GetAsync<List<LojaVm>>("lojas");
            var l = r.Data?.FirstOrDefault(x => x.Id == id);
            if (l is null) { TempData["Erro"] = r.Error ?? "Loja não encontrada."; return RedirectToAction(nameof(Index)); }
            return View(new EditarLojaVm { Id = l.Id, Nome = l.Nome, VencimentoEm = l.VencimentoEm });
        }

        [HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> Editar(EditarLojaVm model)
        {
            if (!ModelState.IsValid) return View(model);
            var r = await _api.PutAsync<bool>($"lojas/{model.Id}", new
            {
                nome = model.Nome,
                vencimentoEm = model.VencimentoEm,
                limparVencimento = model.VencimentoEm is null
            });
            if (!r.Ok) { ModelState.AddModelError(string.Empty, r.Error ?? "Erro ao salvar."); return View(model); }
            TempData["Ok"] = "Loja atualizada.";
            return RedirectToAction(nameof(Index));
        }

        /// <summary>Tela de confirmação: para excluir é preciso digitar o nome da loja.</summary>
        public async Task<IActionResult> Excluir(int id)
        {
            var r = await _api.GetAsync<List<LojaVm>>("lojas");
            var l = r.Data?.FirstOrDefault(x => x.Id == id);
            if (l is null) { TempData["Erro"] = r.Error ?? "Loja não encontrada."; return RedirectToAction(nameof(Index)); }
            return View(l);
        }

        [HttpPost, ActionName("Excluir"), ValidateAntiForgeryToken]
        public async Task<IActionResult> ExcluirConfirmado(int id, string confirmacao)
        {
            var lista = await _api.GetAsync<List<LojaVm>>("lojas");
            var l = lista.Data?.FirstOrDefault(x => x.Id == id);
            if (l is null) { TempData["Erro"] = "Loja não encontrada."; return RedirectToAction(nameof(Index)); }
            if (!string.Equals(confirmacao?.Trim(), l.Nome, StringComparison.Ordinal))
            {
                TempData["Erro"] = "O nome digitado não confere. Nada foi excluído.";
                return RedirectToAction(nameof(Excluir), new { id });
            }
            var r = await _api.DeleteAsync($"lojas/{id}");
            if (r.Ok) TempData["Ok"] = $"Loja \"{l.Nome}\" excluída com todos os dados."; else TempData["Erro"] = r.Error;
            return RedirectToAction(nameof(Index));
        }

        [HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> Vencimento(int id, DateTime? vencimentoEm, bool limpar = false)
        {
            var r = await _api.PutAsync<bool>($"lojas/{id}", new { vencimentoEm, limparVencimento = limpar });
            if (r.Ok) TempData["Ok"] = "Vencimento atualizado."; else TempData["Erro"] = r.Error;
            return RedirectToAction(nameof(Index));
        }

        /// <summary>Suspende por falta de pagamento e derruba as sessões da loja inteira.</summary>
        [HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> Suspender(int id, string? motivo)
        {
            var r = await _api.PostAsync<Dictionary<string, object>>($"lojas/{id}/suspender", new { motivo });
            if (r.Ok) TempData["Ok"] = $"Loja suspensa. Sessões derrubadas: {r.Data?["sessoesDerrubadas"]}.";
            else TempData["Erro"] = r.Error;
            return RedirectToAction(nameof(Index));
        }

        [HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> Reativar(int id, DateTime? novoVencimentoEm)
        {
            var r = await _api.PostAsync<bool>($"lojas/{id}/reativar", new { novoVencimentoEm });
            if (r.Ok) TempData["Ok"] = "Loja reativada."; else TempData["Erro"] = r.Error;
            return RedirectToAction(nameof(Index));
        }

        /// <summary>Derruba só as sessões (sem suspender): o pessoal precisa entrar de novo.</summary>
        [HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> DerrubarSessoes(int id)
        {
            var lista = await _api.GetAsync<List<SessaoVm>>($"sessoes?lojaId={id}");
            if (!lista.Ok) { TempData["Erro"] = lista.Error; return RedirectToAction(nameof(Index)); }

            var qtd = 0;
            foreach (var s in lista.Data ?? new())
            {
                var d = await _api.DeleteAsync($"sessoes/{s.Id}");
                if (d.Ok) qtd++;
            }
            TempData["Ok"] = $"{qtd} sessão(ões) derrubada(s).";
            return RedirectToAction(nameof(Index));
        }
    }
}
