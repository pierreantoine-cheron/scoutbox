using System.ComponentModel.DataAnnotations;
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
    private readonly ICurrentUserAccessor _currentUserAccessor;

    public PartsController(PartService partService, ICurrentUserAccessor currentUserAccessor)
    {
        _partService = partService;
        _currentUserAccessor = currentUserAccessor;
    }

    [HttpPut("{id:guid}")]
    [ValidateUser]
    public async Task<IActionResult> UpdatePartState([FromRoute] Guid id, [FromBody, Required] UpdatePartStateRequest request)
    {
        var userId = _currentUserAccessor.GetValidatedUserId();
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
        var userId = _currentUserAccessor.GetValidatedUserId();
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
    private readonly ICurrentUserAccessor _currentUserAccessor;

    public TentPartsController(PartService partService, ICurrentUserAccessor currentUserAccessor)
    {
        _partService = partService;
        _currentUserAccessor = currentUserAccessor;
    }

    [HttpPost]
    [ValidateUser]
    public async Task<IActionResult> AddPartsToTent(Guid tentId, [FromBody, Required] AddPartsRequest request)
    {
        if (request.PartKindIds == null || request.PartKindIds.Count == 0)
        {
            return BadRequest(new ErrorResponse("Request must contain at least one partKindId", "INVALID_REQUEST"));
        }

        var userId = _currentUserAccessor.GetValidatedUserId();
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
