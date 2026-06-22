using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ScoutBoxApi.Filters;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Controllers;

[Route("api/tent-models")]
[ApiController]
[Authorize]
public class TentModelsController : ControllerBase
{
    private readonly TentService _tentService;
    private readonly ICurrentUserAccessor _currentUserAccessor;

    public TentModelsController(TentService tentService, ICurrentUserAccessor currentUserAccessor)
    {
        _tentService = tentService;
        _currentUserAccessor = currentUserAccessor;
    }

    [HttpGet]
    public async Task<IActionResult> GetActiveModels()
    {
        var models = await _tentService.GetActiveModelsAsync();
        return Ok(new { data = models });
    }

    [HttpPost]
    [ValidateUser]
    public async Task<IActionResult> CreateModel([FromBody] CreateTentModelRequest request)
    {
        var userId = _currentUserAccessor.GetValidatedUserId();
        var (response, error, notFound) = await _tentService.CreateModelAsync(userId, request);
        if (error != null) return BadRequest(error);
        return Ok(new { data = response });
    }

    [HttpPut("{id:guid}")]
    [ValidateUser]
    public async Task<IActionResult> UpdateModel(Guid id, [FromBody] UpdateTentModelRequest request)
    {
        var userId = _currentUserAccessor.GetValidatedUserId();
        var (response, error, notFound) = await _tentService.UpdateModelAsync(userId, id, request);
        if (notFound) return NotFound(new ErrorResponse("Tent model not found", "TENT_MODEL_NOT_FOUND"));
        if (error != null) return BadRequest(error);
        return Ok(new { data = response });
    }

    [HttpDelete("{id:guid}")]
    [ValidateUser]
    public async Task<IActionResult> DeleteModel(Guid id)
    {
        var userId = _currentUserAccessor.GetValidatedUserId();
        var (success, error, notFound) = await _tentService.DeleteModelAsync(userId, id);
        if (notFound) return NotFound(new ErrorResponse("Tent model not found", "TENT_MODEL_NOT_FOUND"));
        if (error != null) return BadRequest(error);
        return NoContent();
    }
}
