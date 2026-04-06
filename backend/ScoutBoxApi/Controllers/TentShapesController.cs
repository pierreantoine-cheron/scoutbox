using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Controllers;

[Route("api/tent-shapes")]
[ApiController]
[Authorize]
public class TentShapesController : ControllerBase
{
    private readonly TentService _tentService;

    public TentShapesController(TentService tentService)
    {
        _tentService = tentService;
    }

    [HttpGet]
    public async Task<IActionResult> GetActiveShapes()
    {
        var shapes = await _tentService.GetActiveShapesAsync();
        return Ok(new { data = shapes });
    }
}
