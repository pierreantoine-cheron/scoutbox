using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Controllers;

[Route("api/tent-models")]
[ApiController]
[Authorize]
public class TentModelsController : ControllerBase
{
    private readonly TentService _tentService;

    public TentModelsController(TentService tentService)
    {
        _tentService = tentService;
    }

    [HttpGet]
    public async Task<IActionResult> GetActiveModels()
    {
        var models = await _tentService.GetActiveModelsAsync();
        return Ok(new { data = models });
    }
}
