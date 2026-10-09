using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Admin.Models;
using TechCare.Admin.Services;

namespace TechCare.Admin.Controllers
{
    [Authorize(Roles = "Dono")]
    public class SessoesController : Controller
    {
        private readonly ApiClient _api;
        public SessoesController(ApiClient api) => _api = api;

        public async Task<IActionResult> Index()
        {
            var r = await _api.GetAsync<List<SessaoVm>>("sessoes");
            if (!r.Ok) TempData["Erro"] = r.Error;
            return View(r.Data ?? new List<SessaoVm>());
        }

        [HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> Derrubar(string id)
        {
            var r = await _api.DeleteAsync($"sessoes/{id}");
            if (r.Ok) TempData["Ok"] = "Sessão derrubada."; else TempData["Erro"] = r.Error;
            return RedirectToAction(nameof(Index));
        }
    }
}
