using System.Globalization;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Authentication.Cookies;
using Microsoft.AspNetCore.Localization;
using TechCare.Admin.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllersWithViews();
builder.Services.AddHttpContextAccessor();

// Cliente tipado que conversa com a API REST (ASP.NET Core) usando o JWT do usuário logado.
builder.Services.AddHttpClient<ApiClient>(client =>
{
    var baseUrl = builder.Configuration["Api:BaseUrl"] ?? "http://localhost:5000/api/";
    client.BaseAddress = new Uri(baseUrl.EndsWith('/') ? baseUrl : baseUrl + "/");
    client.Timeout = TimeSpan.FromSeconds(20);
});

// Autenticação por cookie; o JWT da API fica guardado (criptografado) dentro do cookie.
builder.Services
    .AddAuthentication(CookieAuthenticationDefaults.AuthenticationScheme)
    .AddCookie(options =>
    {
        options.LoginPath = "/Account/Login";
        options.AccessDeniedPath = "/Account/AcessoNegado";
        options.ExpireTimeSpan = TimeSpan.FromHours(8);
        options.SlidingExpiration = false;
        options.Cookie.HttpOnly = true;
        options.Cookie.SameSite = SameSiteMode.Lax;
        options.Cookie.Name = "techcare.admin";
    });

builder.Services.AddAuthorization();

var app = builder.Build();

var pt = new CultureInfo("pt-BR");
app.UseRequestLocalization(new RequestLocalizationOptions
{
    DefaultRequestCulture = new RequestCulture(pt),
    SupportedCultures = new List<CultureInfo> { pt },
    SupportedUICultures = new List<CultureInfo> { pt }
});

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Home/Error");
    app.UseHsts();
}

// Se a API devolver 401 (token expirado), encerra a sessão e volta ao login.
app.Use(async (context, next) =>
{
    try
    {
        await next();
    }
    catch (UnauthorizedApiException)
    {
        await context.SignOutAsync(CookieAuthenticationDefaults.AuthenticationScheme);
        context.Response.Redirect("/Account/Login");
    }
});

app.UseStaticFiles();
app.UseRouting();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllerRoute("default", "{controller=Home}/{action=Index}/{id?}");

app.Run();
