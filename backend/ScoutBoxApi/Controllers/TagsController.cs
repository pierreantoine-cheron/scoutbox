using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using ScoutBoxApi.Filters;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Controllers;

[Route("api/tags")]
[ApiController]
[Authorize]
public class TagsController : ControllerBase
{
    private readonly TagService _tagService;
    private readonly ICurrentUserAccessor _currentUserAccessor;

    public TagsController(TagService tagService, ICurrentUserAccessor currentUserAccessor)
    {
        _tagService = tagService;
        _currentUserAccessor = currentUserAccessor;
    }

    [HttpGet]
    public async Task<IActionResult> GetTags()
    {
        var tags = await _tagService.GetTagsAsync();
        return Ok(new { data = tags });
    }

    [HttpPost]
    [ValidateUser]
    public async Task<IActionResult> CreateTag([FromBody] CreateTagRequest request)
    {
        var userId = _currentUserAccessor.GetValidatedUserId();
        return this.OkDataOrBadRequest(await _tagService.CreateTagAsync(userId, request));
    }

    [HttpPut("{id:guid}")]
    [ValidateUser]
    public async Task<IActionResult> UpdateTag(Guid id, [FromBody] UpdateTagRequest? request)
    {
        var userId = _currentUserAccessor.GetValidatedUserId();
        var (response, error, notFound) = await _tagService.UpdateTagAsync(userId, id, request);
        if (notFound) return NotFound(new ErrorResponse("Tag not found", "TAG_NOT_FOUND"));
        if (error != null) return BadRequest(error);
        return Ok(new { data = response });
    }

    [HttpDelete("{id:guid}")]
    [ValidateUser]
    public async Task<IActionResult> DeleteTag(Guid id)
    {
        var userId = _currentUserAccessor.GetValidatedUserId();
        var (success, error, notFound) = await _tagService.DeleteTagAsync(userId, id);
        if (notFound) return NotFound(new ErrorResponse("Tag not found", "TAG_NOT_FOUND"));
        if (error != null) return BadRequest(error);
        return NoContent();
    }
}
