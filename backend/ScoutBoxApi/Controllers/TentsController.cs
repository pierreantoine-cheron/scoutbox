using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ScoutBoxApi.Filters;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Controllers;

[Route("api/tents")]
[ApiController]
[Authorize]
public class TentsController : ControllerBase
{
    private readonly TentService _tentService;
    private readonly IAuditHistoryService _auditHistoryService;

    public TentsController(TentService tentService, IAuditHistoryService auditHistoryService)
    {
        _tentService = tentService;
        _auditHistoryService = auditHistoryService;
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
    [ValidateUser]
    public async Task<IActionResult> CreateTent([FromBody] CreateTentRequest request)
    {
        var userId = HttpContext.GetUserId();
        return this.OkDataOrBadRequest(await _tentService.CreateTentAsync(userId, request));
    }

    [HttpPut("{id:guid}")]
    [ValidateUser]
    public async Task<IActionResult> UpdateTent([FromRoute] Guid id, [FromBody] UpdateTentRequest request)
    {
        var userId = HttpContext.GetUserId();
        var (response, error, notFound) = await _tentService.UpdateTentAsync(id, userId, request);

        if (notFound)
        {
            return NotFound(new ErrorResponse("Tent not found", "TENT_NOT_FOUND"));
        }

        if (error != null)
        {
            return BadRequest(error);
        }

        return Ok(new { data = response });
    }

    [HttpPut("{id:guid}/archive")]
    [ValidateUser]
    public async Task<IActionResult> ArchiveTent([FromRoute] Guid id)
    {
        var userId = HttpContext.GetUserId();
        var (response, notFound) = await _tentService.ArchiveTentAsync(id, userId);

        if (notFound)
        {
            return NotFound(new ErrorResponse("Tent not found", "TENT_NOT_FOUND"));
        }

        return Ok(new { data = response });
    }

    [HttpGet("{id:guid}/history")]
    public async Task<IActionResult> GetTentHistory(
        [FromRoute] Guid id,
        [FromQuery] string? category = null,
        [FromQuery] int limit = 50,
        CancellationToken cancellationToken = default)
    {
        if (limit < 1 || limit > 100)
        {
            return BadRequest(new ErrorResponse("Limit must be between 1 and 100", "INVALID_REQUEST"));
        }

        if (!TentHistoryCategoryMapper.TryParse(category, out var parsedCategory))
        {
            return BadRequest(new ErrorResponse("Invalid history category", "INVALID_REQUEST"));
        }

        var tent = await _tentService.GetTentByIdAsync(id);
        if (tent == null)
        {
            return NotFound(new ErrorResponse("Tent not found", "TENT_NOT_FOUND"));
        }

        var history = await _auditHistoryService.GetTentHistoryAsync(id, parsedCategory, limit, cancellationToken);

        return Ok(new { data = history });
    }
}
