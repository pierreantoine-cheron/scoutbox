using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ScoutBoxApi.Filters;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Controllers;

[Route("api/part-kinds")]
[ApiController]
[Authorize]
public class PartKindsController : ControllerBase
{
    private readonly PartKindService _partKindService;
    private readonly ICurrentUserAccessor _currentUserAccessor;

    public PartKindsController(
        PartKindService partKindService,
        ICurrentUserAccessor currentUserAccessor)
    {
        _partKindService = partKindService;
        _currentUserAccessor = currentUserAccessor;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var partKinds = await _partKindService.GetAllAsync();
        return Ok(partKinds);
    }

    [HttpPost]
    [ValidateUser]
    public async Task<IActionResult> Create([FromBody] CreatePartKindRequest? request)
    {
        var userId = _currentUserAccessor.GetValidatedUserId();
        var (response, error) = await _partKindService.CreateAsync(userId, request);
        if (error != null) return BadRequest(error);
        return Ok(response);
    }

    [HttpPut("{id:guid}")]
    [ValidateUser]
    public async Task<IActionResult> Rename(Guid id, [FromBody] UpdatePartKindRequest? request)
    {
        var userId = _currentUserAccessor.GetValidatedUserId();
        var (response, error, notFound) = await _partKindService.RenameAsync(userId, id, request);
        if (notFound) return NotFound(new ErrorResponse("Part kind not found", "PART_KIND_NOT_FOUND"));
        if (error != null) return BadRequest(error);
        return Ok(response);
    }

    [HttpDelete("{id:guid}")]
    [ValidateUser]
    public async Task<IActionResult> Delete(Guid id)
    {
        var (_, error, notFound) = await _partKindService.DeleteAsync(id);
        if (notFound) return NotFound(new ErrorResponse("Part kind not found", "PART_KIND_NOT_FOUND"));
        if (error != null) return BadRequest(error);
        return NoContent();
    }
}
