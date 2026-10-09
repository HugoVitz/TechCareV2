using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Admin.Models;
using TechCare.Admin.Services;

namespace TechCare.Admin.Controllers
{
    [Authorize(Roles = "Dono")]
    public class RelatoriosController : Controller
    {
        private readonly ApiClient _api;
        public RelatoriosController(ApiClient api) => _api = api;

        public async Task<IActionResult> Diversidade()
        {
            var r = await _api.GetAsync<DiversidadeVm>("relatorios/diversidade");
            if (!r.Ok) TempData["Erro"] = r.Error;
            return View(r.Data ?? new DiversidadeVm());
        }

        public async Task<IActionResult> Auditoria()
        {
            var r = await _api.GetAsync<List<AuditoriaVm>>("auditoria?limite=200");
            if (!r.Ok) TempData["Erro"] = r.Error;
            return View(r.Data ?? new List<AuditoriaVm>());
        }
    }
}
