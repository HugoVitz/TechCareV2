using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using TechCarePro.Models;

namespace TechCarePro.Controllers
{
    /// <summary>Listas usadas nos formulários (site, app e painel), mantidas num único lugar.</summary>
    [ApiController]
    [Authorize]
    [Route("api/opcoes")]
    public class OpcoesController : ControllerBase
    {
        [HttpGet]
        public IActionResult Get() => Ok(new
        {
            Etnias = Etnias.Todas,
            Cargos = Cargos.Sugeridos,
            Perfis = Perfis.DaLoja
        });
    }
}
