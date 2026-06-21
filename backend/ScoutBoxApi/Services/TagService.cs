using System.Text.RegularExpressions;
using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Repositories;

namespace ScoutBoxApi.Services;

public class TagService
{
    private const int MinTagNameLength = 2;
    private const int MaxTagNameLength = 30;
    private static readonly Regex ColorRegex = new("^#[0-9A-Fa-f]{6}$", RegexOptions.Compiled);

    private readonly ITagRepository _repo;
    private readonly IAuditService _auditService;
    private readonly ILogger<TagService> _logger;

    public TagService(ITagRepository repo, IAuditService auditService, ILogger<TagService> logger)
    {
        _repo = repo;
        _auditService = auditService;
        _logger = logger;
    }

    public async Task<IReadOnlyList<TagDto>> GetTagsAsync()
    {
        return await _repo.GetTagsAsync();
    }

    public async Task<(TagDto? Response, ErrorResponse? Error)> CreateTagAsync(Guid userId, CreateTagRequest request)
    {
        var validationError = ValidateRequest(request?.Name, request?.Color, out var name, out var color);
        if (validationError != null) return (null, validationError);

        if (await _repo.HasDuplicateNameAsync(name))
        {
            return (null, new ErrorResponse("Tag name already exists", "TAG_NAME_EXISTS"));
        }

        var tag = new Tag
        {
            Name = name,
            Color = color,
        };
        EntityFactory.SetCreationAudit(tag, userId);

        _repo.AddTag(tag);
        _auditService.RecordEvent(
            AuditActions.TagCreated,
            userId,
            targetEntityType: "Tag",
            targetEntityId: tag.Id,
            metadata: new Dictionary<string, object?>
            {
                ["name"] = tag.Name,
                ["color"] = tag.Color
            });

        try
        {
            await _repo.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (DbExceptionHelper.IsConstraintViolation(ex, "Tags", "Name"))
        {
            _logger.LogWarning(ex, "Duplicate tag name blocked by DB constraint: {TagName}", name);
            return (null, new ErrorResponse("Tag name already exists", "TAG_NAME_EXISTS"));
        }

        return (TagDto.FromTag(tag), null);
    }

    public async Task<(TagDto? Response, ErrorResponse? Error, bool NotFound)> UpdateTagAsync(
        Guid userId, Guid id, UpdateTagRequest? request)
    {
        var tag = await _repo.GetTagByIdAsync(id);
        if (tag == null) return (null, null, true);

        var validationError = ValidateRequest(request?.Name, request?.Color, out var name, out var color);
        if (validationError != null) return (null, validationError, false);

        if (await _repo.HasDuplicateNameAsync(name, id))
        {
            return (null, new ErrorResponse("Tag name already exists", "TAG_NAME_EXISTS"), false);
        }

        tag.Name = name;
        tag.Color = color;
        tag.UpdatedAt = DateTime.UtcNow;
        tag.UpdatedByUserId = userId;

        _auditService.RecordEvent(
            AuditActions.TagRenamed,
            userId,
            targetEntityType: "Tag",
            targetEntityId: tag.Id,
            metadata: new Dictionary<string, object?>
            {
                ["name"] = name,
                ["color"] = color
            });

        try
        {
            await _repo.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (DbExceptionHelper.IsConstraintViolation(ex, "Tags", "Name"))
        {
            _logger.LogWarning(ex, "Duplicate tag name blocked by DB constraint on rename: {TagName}", name);
            return (null, new ErrorResponse("Tag name already exists", "TAG_NAME_EXISTS"), false);
        }

        return (TagDto.FromTag(tag), null, false);
    }

    public async Task<(bool Success, ErrorResponse? Error, bool NotFound)> DeleteTagAsync(Guid userId, Guid id)
    {
        var tag = await _repo.GetTagByIdAsync(id);
        if (tag == null) return (false, null, true);

        var tentCount = tag.TentTags.Count;

        _auditService.RecordEvent(
            AuditActions.TagDeleted,
            userId,
            targetEntityType: "Tag",
            targetEntityId: tag.Id,
            metadata: new Dictionary<string, object?>
            {
                ["name"] = tag.Name,
                ["tentCount"] = tentCount
            });

        _repo.RemoveTag(tag);
        await _repo.SaveChangesAsync();

        return (true, null, false);
    }

    private static ErrorResponse? ValidateRequest(string? requestName, string? requestColor, out string name, out string color)
    {
        name = requestName?.Trim() ?? string.Empty;
        color = requestColor?.Trim() ?? string.Empty;

        if (name.Length == 0)
        {
            return new ErrorResponse("Tag name is required", "TAG_NAME_REQUIRED");
        }

        if (name.Length < MinTagNameLength)
        {
            return new ErrorResponse("Tag name is too short", "TAG_NAME_TOO_SHORT");
        }
        if (name.Length > MaxTagNameLength)
        {
            return new ErrorResponse("Tag name is too long", "TAG_NAME_TOO_LONG");
        }
        if (!ColorRegex.IsMatch(color))
        {
            return new ErrorResponse("Tag color must be a #RRGGBB hex value", "INVALID_TAG_COLOR");
        }

        return null;
    }
}
