using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Controllers;

[Route("api/activity")]
[ApiController]
[Authorize]
public class ActivityController : ControllerBase
{
    private const int DefaultLimit = 50;
    private const int MaxLimit = 50;

    private readonly IActivityService _activityService;

    public ActivityController(IActivityService activityService)
    {
        _activityService = activityService;
    }

    [HttpGet]
    public async Task<IActionResult> GetActivity(
        [FromQuery] string? category = null,
        [FromQuery] string? window = null,
        [FromQuery] string? cursor = null,
        [FromQuery] int limit = DefaultLimit,
        CancellationToken cancellationToken = default)
    {
        if (limit < 1 || limit > MaxLimit)
        {
            return BadRequest(new ErrorResponse(
                "Limit must be between 1 and 50", "INVALID_REQUEST"));
        }

        if (!ActivityCategoryMapper.TryParse(category, out var parsedCategory))
        {
            return BadRequest(new ErrorResponse(
                "Invalid activity category", "INVALID_REQUEST"));
        }

        if (!ActivityWindow.TryParse(window, out var windowDays))
        {
            return BadRequest(new ErrorResponse(
                "Invalid activity window", "INVALID_REQUEST"));
        }

        ActivityCursor? parsedCursor = null;
        if (!string.IsNullOrEmpty(cursor))
        {
            if (!ActivityCursor.TryParse(cursor, out parsedCursor))
            {
                return BadRequest(new ErrorResponse(
                    "Invalid activity cursor", "INVALID_REQUEST"));
            }
        }

        var page = await _activityService.GetActivityAsync(
            parsedCategory,
            windowDays,
            parsedCursor,
            limit,
            cancellationToken);

        return Ok(page);
    }
}
