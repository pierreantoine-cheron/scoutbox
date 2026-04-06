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
