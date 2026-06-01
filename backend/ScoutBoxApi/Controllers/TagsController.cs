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
}
