using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ScoutBoxApi.Filters;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Controllers;

[Route("api/parts")]
[ApiController]
[Authorize]
public class PartsController : ControllerBase
{
    private readonly PartService _partService;

    public PartsController(PartService partService)
    {
        _partService = partService;
    }

    [HttpPut("{id:guid}")]
    [ValidateUser]
    public async Task<IActionResult> UpdatePartState([FromRoute] Guid id, [FromBody] UpdatePartStateRequest request)
    {
        var userId = HttpContext.GetUserId();
        var (response, error, notFound) = await _partService.UpdatePartStateAsync(id, userId, request);

        if (notFound)
        {
            return NotFound(new ErrorResponse("Part not found", "PART_NOT_FOUND"));
        }

        if (error != null)
        {
            return BadRequest(error);
        }

        return Ok(new { data = response });
    }
}
