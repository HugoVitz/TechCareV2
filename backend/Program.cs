using System.Text;
using System.Text.Json.Serialization;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi.Models;
using TechCarePro.Api.Data;
using TechCarePro.Models;
using TechCarePro.Security;
using TechCarePro.Services;

var builder = WebApplication.CreateBuilder(args);

// ---------- Configuração do JWT (a chave NÃO fica versionada) ----------
// Ordem de busca: variável de ambiente Jwt__Key > appsettings.{Ambiente}.json > appsettings.json.
// Se nada estiver configurado, gera uma chave aleatória só para esta execução (seguro, mas os
// logins são invalidados quando a API reinicia). Em produção, defina Jwt__Key.
var jwtIssuer = builder.Configuration["Jwt:Issuer"] ?? "TechCarePro";
var jwtAudience = builder.Configuration["Jwt:Audience"] ?? "TechCarePro";
var jwtKey = builder.Configuration["Jwt:Key"];

if (string.IsNullOrWhiteSpace(jwtKey) || jwtKey.Length < 32)
{
    jwtKey = Convert.ToBase64String(System.Security.Cryptography.RandomNumberGenerator.GetBytes(48));
    builder.Configuration["Jwt:Key"] = jwtKey; // o AuthController lê daqui
    Console.WriteLine("[AVISO] Jwt:Key não configurada - usando chave temporária desta execução.");
}

// ---------- Serviços ----------
builder.Services.AddControllers()
    .AddJsonOptions(o => o.JsonSerializerOptions.ReferenceHandler = ReferenceHandler.IgnoreCycles);

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(c =>
{
    c.SwaggerDoc("v1", new OpenApiInfo { Title = "TechCare Pro API", Version = "v1" });
    c.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Informe apenas o token JWT retornado em /api/auth/login."
    });
    c.AddSecurityRequirement(new OpenApiSecurityRequirement
    {
        {
            new OpenApiSecurityScheme { Reference = new OpenApiReference { Type = ReferenceType.SecurityScheme, Id = "Bearer" } },
            Array.Empty<string>()
        }
    });
});

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentTenant, CurrentTenant>();

// O banco fica SEMPRE na pasta do projeto (backend/techcare.db), não importa de onde o programa foi aberto.
// Assim o login e os dados continuam os mesmos entre uma execução e outra.
var sqliteCs = new Microsoft.Data.Sqlite.SqliteConnectionStringBuilder(
    builder.Configuration.GetConnectionString("DefaultConnection") ?? "Data Source=techcare.db");
if (!Path.IsPathRooted(sqliteCs.DataSource))
    sqliteCs.DataSource = Path.Combine(builder.Environment.ContentRootPath, sqliteCs.DataSource);

builder.Services.AddDbContext<AppDbContext>(options => options.UseSqlite(sqliteCs.ToString()));

// CORS configurável (Cors:Origins). O app Flutter não depende de CORS.
var origins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>()
              ?? new[] { "http://127.0.0.1:5500", "http://localhost:5500" };

builder.Services.AddCors(options =>
{
    options.AddPolicy("Frontend", policy =>
        policy
            .SetIsOriginAllowed(origin =>
            {
                if (origins.Contains(origin)) return true;
                // Qualquer porta em localhost/127.0.0.1 (front HTML, flutter run -d chrome...).
                return Uri.TryCreate(origin, UriKind.Absolute, out var u)
                       && (u.Host == "localhost" || u.Host == "127.0.0.1");
            })
            .AllowAnyHeader()
            .AllowAnyMethod());
});

builder.Services
    .AddAuthentication("Bearer")
    .AddJwtBearer("Bearer", options =>
    {
        options.TokenValidationParameters = new TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = jwtIssuer,
            ValidAudience = jwtAudience,
            IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey)),
            ClockSkew = TimeSpan.FromMinutes(1)
        };

        options.Events = new JwtBearerEvents
        {
            // A cada requisição: a sessão precisa estar viva, o usuário ativo e a loja em dia.
            // É isto que permite "derrubar a sessão" (ex.: falta de pagamento) na hora.
            OnTokenValidated = async ctx =>
            {
                var db = ctx.HttpContext.RequestServices.GetRequiredService<AppDbContext>();
                var sid = ctx.Principal?.FindFirst("tc_sid")?.Value;
                var motivo = await SessaoGuard.ValidarAsync(db, sid);
                if (motivo is not null)
                {
                    ctx.HttpContext.Items["tc_motivo"] = motivo;
                    ctx.Fail(motivo);
                }
            },
            OnChallenge = async ctx =>
            {
                ctx.HandleResponse();
                var motivo = ctx.HttpContext.Items["tc_motivo"] as string
                             ?? "Sessão expirada ou inválida. Entre novamente.";
                ctx.Response.StatusCode = StatusCodes.Status401Unauthorized;
                ctx.Response.ContentType = "application/json; charset=utf-8";
                await ctx.Response.WriteAsJsonAsync(new { mensagem = motivo, sessaoEncerrada = true });
            }
        };
    });

builder.Services.AddAuthorization();

// Limita tentativas de login/cadastro por IP (mitiga força bruta).
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("auth", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "anon",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0
            }));
});

var app = builder.Build();

app.UseSwagger();
app.UseSwaggerUI();

app.UseDefaultFiles();   // /app/ -> /app/index.html
app.UseStaticFiles();    // serve backend/wwwroot (app web publicado com publicar-web.bat)

// Painel web (HTML): a própria API entrega o site em /painel/, então clientes na rede local
// abrem http://IP-DO-PC:5000 no navegador do computador ou do celular, sem instalar nada.
// Usa a pasta ../frontend (desenvolvimento) ou wwwroot/painel (publicado).
var pastaPainel = Path.GetFullPath(Path.Combine(app.Environment.ContentRootPath, "..", "frontend"));
if (!Directory.Exists(pastaPainel))
    pastaPainel = Path.Combine(app.Environment.WebRootPath ?? app.Environment.ContentRootPath, "painel");
var painelExiste = Directory.Exists(pastaPainel);
if (painelExiste)
{
    var painelFiles = new Microsoft.Extensions.FileProviders.PhysicalFileProvider(pastaPainel);
    app.UseDefaultFiles(new DefaultFilesOptions { FileProvider = painelFiles, RequestPath = "/painel", DefaultFileNames = new List<string> { "login.html" } });
    app.UseStaticFiles(new StaticFileOptions { FileProvider = painelFiles, RequestPath = "/painel" });
}

app.UseCors("Frontend");
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();

// Quem entrou com senha temporária só pode trocá-la (ou sair) até definir a própria.
app.Use(async (ctx, next) =>
{
    var path = ctx.Request.Path.Value?.ToLowerInvariant() ?? string.Empty;
    var liberado = path.StartsWith("/api/auth/") || path.StartsWith("/api/health") || path == "/api/conta/me";
    if (path.StartsWith("/api/") && !liberado && ctx.User.Identity?.IsAuthenticated == true
        && ctx.User.FindFirst("must_change")?.Value == "1")
    {
        ctx.Response.StatusCode = StatusCodes.Status403Forbidden;
        await ctx.Response.WriteAsJsonAsync(new { mensagem = "Defina uma nova senha para continuar.", trocarSenha = true });
        return;
    }
    await next();
});

app.MapControllers();

// Atalhos: "/" abre o painel web (ou o app web, ou o Swagger); "/app" vira "/app/".
var appPublicado = File.Exists(Path.Combine(app.Environment.WebRootPath ?? string.Empty, "app", "index.html"));
app.MapGet("/", () => Results.Redirect(painelExiste ? "/painel/" : appPublicado ? "/app/" : "/swagger"));
app.MapGet("/app", () => Results.Redirect("/app/"));

// ---------- Banco: criação, ajuste de esquema, migração para multi-loja e contas iniciais ----------
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<AppDbContext>();
    SchemaUpdater.Executar(db, app.Configuration);
}

app.Run();
