using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Admin.Models;
using TechCare.Admin.Services;

namespace TechCare.Admin.Controllers
{
    [Authorize(Roles = "Dono")]
    public class HomeController : Controller
    {
        private readonly ApiClient _api;
        public HomeController(ApiClient api) => _api = api;

        public async Task<IActionResult> Index()
        {
            var r = await _api.GetAsync<List<LojaVm>>("lojas");
            if (!r.Ok) TempData["Erro"] = r.Error;
            return View(r.Data ?? new List<LojaVm>());
        }

        [AllowAnonymous]
        public IActionResult Error() => View();
    }
}
