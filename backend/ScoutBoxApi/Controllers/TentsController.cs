using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Controllers;

[Route("api/tents")]
[ApiController]
[Authorize]
public class TentsController : ControllerBase
{
    private readonly TentService _tentService;
    private readonly ICurrentUserAccessor _currentUserAccessor;

    public TentsController(TentService tentService, ICurrentUserAccessor currentUserAccessor)
    {
        _tentService = tentService;
        _currentUserAccessor = currentUserAccessor;
    }

    [HttpGet]
    public async Task<IActionResult> GetTents()
    {
        var tents = await _tentService.GetTentsAsync();
        return Ok(new { data = tents });
    }

    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetTentById([FromRoute] Guid id)
    {
        var tent = await _tentService.GetTentByIdAsync(id);
        if (tent == null)
        {
            return NotFound(new ErrorResponse("Tent not found", "TENT_NOT_FOUND"));
        }

        return Ok(new { data = tent });
    }

    [HttpPost]
    public async Task<IActionResult> CreateTent([FromBody] CreateTentRequest request)
    {
        var userId = _currentUserAccessor.GetValidatedUserId();
        var (response, error) = await _tentService.CreateTentAsync(userId, request);

        if (error != null)
        {
            return BadRequest(error);
        }

        return Ok(new { data = response });
    }
}
