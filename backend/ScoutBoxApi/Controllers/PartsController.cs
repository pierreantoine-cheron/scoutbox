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

    [HttpDelete("{id:guid}")]
    [ValidateUser]
    public async Task<IActionResult> DeletePart(Guid id)
    {
        var userId = HttpContext.GetUserId();
        var (error, notFound) = await _partService.RemovePartAsync(id, userId);

        if (notFound)
        {
            return NotFound(new ErrorResponse("Part not found", "PART_NOT_FOUND"));
        }

        if (error != null)
        {
            return BadRequest(error);
        }

        return NoContent();
    }
}

[Route("api/tents/{tentId:guid}/parts")]
[ApiController]
[Authorize]
public class TentPartsController : ControllerBase
{
    private readonly PartService _partService;

    public TentPartsController(PartService partService)
    {
        _partService = partService;
    }

    [HttpPost]
    [ValidateUser]
    public async Task<IActionResult> AddPartsToTent(Guid tentId, [FromBody] AddPartsRequest request)
    {
        if (request == null || request.PartKindIds == null || request.PartKindIds.Count == 0)
        {
            return BadRequest(new ErrorResponse("Request must contain at least one partKindId", "INVALID_REQUEST"));
        }

        var userId = HttpContext.GetUserId();
        var (response, error) = await _partService.AddPartsToTentAsync(tentId, request.PartKindIds, userId);

        if (error != null)
        {
            if (error.Code == "TENT_NOT_FOUND")
            {
                return NotFound(error);
            }

            return BadRequest(error);
        }

        return Ok(new { data = response });
    }
}
