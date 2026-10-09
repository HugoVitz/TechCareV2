using System.Security.Claims;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCare.Admin.Models;
using TechCare.Admin.Services;

namespace TechCare.Admin.Controllers
{
    public class AccountController : Controller
    {
        private readonly ApiClient _api;
        public AccountController(ApiClient api) => _api = api;

        [AllowAnonymous]
        public IActionResult Login(string? returnUrl = null)
        {
            if (User.Identity?.IsAuthenticated == true) return RedirectToAction("Index", "Home");
            ViewData["ReturnUrl"] = returnUrl;
            return View(new LoginVm());
        }

        [AllowAnonymous, HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> Login(LoginVm model, string? returnUrl = null)
        {
            if (!ModelState.IsValid) return View(model);

            var r = await _api.PostAnonymousAsync<LoginResposta>("auth/login",
                new { usuario = model.Usuario, senha = model.Senha });

            if (!r.Ok || r.Data is null)
            {
                ModelState.AddModelError(string.Empty, r.Error ?? "Falha no login.");
                return View(model);
            }

            // Este console é só do Dono. Admins e atendentes usam o painel web / app.
            if (r.Data.Perfil != "Dono")
            {
                ModelState.AddModelError(string.Empty,
                    "Este console é exclusivo do Dono do sistema. Use o painel web ou o aplicativo da sua loja.");
                return View(model);
            }

            var identity = new ClaimsIdentity(new List<Claim>
            {
                new(ClaimTypes.Name, r.Data.Usuario),
                new(ClaimTypes.Role, r.Data.Perfil)
            }, CookieAuthenticationDefaults.AuthenticationScheme);

            var props = new AuthenticationProperties { IsPersistent = false };
            props.StoreTokens(new[] { new AuthenticationToken { Name = "access_token", Value = r.Data.Token } });

            await HttpContext.SignInAsync(CookieAuthenticationDefaults.AuthenticationScheme,
                new ClaimsPrincipal(identity), props);

            if (!string.IsNullOrEmpty(returnUrl) && Url.IsLocalUrl(returnUrl))
                return Redirect(returnUrl);

            return RedirectToAction("Index", "Home");
        }

        [Authorize, HttpPost, ValidateAntiForgeryToken]
        public async Task<IActionResult> Logout()
        {
            await _api.PostAsync<bool>("auth/logout", new { });
            await HttpContext.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
            return RedirectToAction(nameof(Login));
        }

        [AllowAnonymous]
        public IActionResult AcessoNegado() => View();
    }
}
