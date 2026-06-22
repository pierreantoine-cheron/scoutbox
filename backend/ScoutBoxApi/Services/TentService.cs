using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Repositories;

namespace ScoutBoxApi.Services;

public class TentService
{
    private const int MaxTentNameLength = 100;
    private const int MaxTentCommentsLength = 500;
    private const int MaxTentSize = 100;

    private readonly ITentRepository _repo;
    private readonly IAuditService _auditService;
    private readonly ILogger<TentService> _logger;
    private readonly ScoutBoxDbContext _db;

    public TentService(ITentRepository repo, IAuditService auditService, ILogger<TentService> logger, ScoutBoxDbContext db)
    {
        _repo = repo;
        _auditService = auditService;
        _logger = logger;
        _db = db;
    }

    public async Task<IReadOnlyList<TentModelDto>> GetActiveModelsAsync()
    {
        return await _repo.GetActiveModelsAsync();
    }

    public async Task<IReadOnlyList<TentDto>> GetTentsAsync()
    {
        return await _repo.GetTentsAsync();
    }

    public async Task<TentDto?> GetTentByIdAsync(Guid id)
    {
        var tent = await _repo.GetTentByIdAsync(id);
        if (tent == null) return null;
        return ToTentDto(tent, ToPartDtos(tent.Parts));
    }

    public async Task<(TentDto? Response, ErrorResponse? Error)> CreateTentAsync(Guid userId, CreateTentRequest request)
    {
        var validationError = ValidateTentRequest(
            request.Name,
            request.Size,
            request.OverallState,
            request.Comments,
            failureCode: "TENT_CREATE_FAILED",
            out var validated);
        if (validationError != null) return (null, validationError);

        var model = await _repo.GetActiveTentModelByIdAsync(request.TentModelId);
        if (model == null)
            return (null, new ErrorResponse("Tent model does not exist", "INVALID_TENT_MODEL"));

        if (await _repo.HasDuplicateTentNameAsync(validated.Name))
            return (null, new ErrorResponse("Tent name already exists", "TENT_NAME_EXISTS"));

        await _repo.BeginTransactionAsync();

        try
        {
            var tent = new Tent
            {
                Name = validated.Name,
                Size = validated.Size,
                TentModelId = request.TentModelId,
                OverallState = validated.OverallState,
                Comments = validated.Comments,
            };
            EntityFactory.SetCreationAudit(tent, userId);

            _repo.AddTent(tent);

            var orderedModelComponents = model.TentModelComponents
                .OrderBy(mc => mc.PartKind.DisplayOrder)
                .ThenBy(mc => mc.PartKindId)
                .ToList();

            var createdParts = new List<Part>(orderedModelComponents.Count);
            foreach (var component in orderedModelComponents)
            {
                var part = new Part
                {
                    TentId = tent.Id,
                    PartKindId = component.PartKindId,
                    PartKind = component.PartKind,
                    State = PartState.Good,
                    Comments = null,
                };
                EntityFactory.SetCreationAudit(part, userId);
                _repo.AddPart(part);
                createdParts.Add(part);
            }

            _auditService.RecordEvent(
                AuditActions.TentCreated,
                userId,
                targetEntityType: "Tent",
                targetEntityId: tent.Id,
                metadata: new Dictionary<string, object?>
                {
                    ["name"] = tent.Name,
                    ["size"] = tent.Size,
                    ["overallState"] = tent.OverallState.ToString(),
                    ["tentModelId"] = tent.TentModelId,
                    ["partCount"] = createdParts.Count
                });

            try
            {
                await _repo.SaveChangesAsync();
            }
            catch (DbUpdateException ex) when (IsDuplicateTentNameViolation(ex))
            {
                await _repo.RollbackTransactionAsync();
                _logger.LogWarning(ex, "Duplicate tent name blocked by DB constraint: {TentName}", validated.Name);
                return (null, new ErrorResponse("Tent name already exists", "TENT_NAME_EXISTS"));
            }

            await _repo.CommitTransactionAsync();
            return (ToTentDto(tent, ToPartDtos(createdParts), model.Name), null);
        }
        catch (Exception ex)
        {
            await _repo.RollbackTransactionAsync();
            _logger.LogError(ex, "Failed to create tent {TentName} with model {TentModelId} for user {UserId}", validated.Name, request.TentModelId, userId);
            throw;
        }
    }

    public async Task<(TentDto? Response, ErrorResponse? Error, bool NotFound)> UpdateTentAsync(Guid id, Guid userId, UpdateTentRequest request)
    {
        var validationError = ValidateTentRequest(
            request.Name,
            request.Size,
            request.OverallState,
            request.Comments,
            failureCode: "TENT_UPDATE_FAILED",
            out var validated);
        if (validationError != null) return (null, validationError, false);

        var tent = await _repo.GetTentByIdForUpdateAsync(id);
        if (tent == null) return (null, null, true);

        if (await _repo.HasDuplicateTentNameAsync(validated.Name, id))
            return (null, new ErrorResponse("Tent name already exists", "TENT_NAME_EXISTS"), false);

        var oldName = tent.Name;
        var oldSize = tent.Size;
        var oldOverallState = tent.OverallState;
        var oldComments = tent.Comments;
        var oldModelId = tent.TentModelId;

        var changedFields = new List<string>();
        if (oldName != validated.Name) changedFields.Add("name");
        if (oldSize != validated.Size) changedFields.Add("size");
        if (oldOverallState != validated.OverallState) changedFields.Add("overallState");
        var commentsChanged = oldComments != validated.Comments;
        if (commentsChanged) changedFields.Add("comments");

        var modelName = tent.TentModel?.Name;
        var oldModelName = modelName;

        if (request.TentModelId.HasValue && request.TentModelId.Value != oldModelId)
        {
            var model = await _repo.GetActiveTentModelByIdAsync(request.TentModelId.Value);
            if (model == null)
                return (null, new ErrorResponse("Tent model does not exist", "INVALID_TENT_MODEL"), false);

            tent.TentModelId = request.TentModelId.Value;
            tent.TentModel = model;
            modelName = model.Name;
            changedFields.Add("tentModelId");
        }

        if (changedFields.Count > 0)
        {
            var now = DateTime.UtcNow;
            tent.Name = validated.Name;
            tent.Size = validated.Size;
            tent.OverallState = validated.OverallState;
            tent.Comments = validated.Comments;
            tent.UpdatedAt = now;
            tent.UpdatedByUserId = userId;

            var metadata = new Dictionary<string, object?>
            {
                ["changedFields"] = changedFields,
                ["oldName"] = oldName,
                ["newName"] = tent.Name,
                ["oldSize"] = oldSize,
                ["newSize"] = tent.Size,
                ["oldOverallState"] = oldOverallState.ToString(),
                ["newOverallState"] = tent.OverallState.ToString(),
                ["commentsChanged"] = commentsChanged
            };

            if (request.TentModelId.HasValue && request.TentModelId.Value != oldModelId)
            {
                metadata["oldTentModelId"] = oldModelId;
                metadata["newTentModelId"] = request.TentModelId.Value;
                metadata["oldTentModelName"] = oldModelName;
                metadata["newTentModelName"] = modelName;
            }

            _auditService.RecordEvent(
                AuditActions.TentUpdated,
                userId,
                targetEntityType: "Tent",
                targetEntityId: id,
                metadata: metadata);
        }

        try
        {
            await _repo.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (IsDuplicateTentNameViolation(ex))
        {
            _logger.LogWarning(ex, "Duplicate tent name blocked by DB constraint on update: {TentName}", validated.Name);
            return (null, new ErrorResponse("Tent name already exists", "TENT_NAME_EXISTS"), false);
        }

        return (ToTentDto(tent, ToPartDtos(tent.Parts), modelName), null, false);
    }

    public async Task<(TentDto? Response, ErrorResponse? Error, bool NotFound)> SetTentTagsAsync(Guid tentId, IReadOnlyList<Guid> tagIds, Guid userId)
    {
        tagIds ??= Array.Empty<Guid>();
        var requestedTagIdSet = tagIds.Distinct().ToHashSet();
        var tent = await _repo.GetTentByIdForUpdateAsync(tentId);
        if (tent == null) return (null, null, true);

        await _repo.BeginTransactionAsync();

        try
        {
            var tags = await _repo.GetTagsByIdsAsync(requestedTagIdSet);
            if (tags.Count != requestedTagIdSet.Count)
            {
                await _repo.RollbackTransactionAsync();
                return (null, new ErrorResponse("One or more tags not found", "TAG_NOT_FOUND"), false);
            }

            var tagsById = tags.ToDictionary(tag => tag.Id);
            var currentTagIds = tent.TentTags.Select(tt => tt.TagId).ToHashSet();
            var toAdd = requestedTagIdSet.Where(tagId => !currentTagIds.Contains(tagId)).ToList();
            var toRemove = tent.TentTags.Where(tt => !requestedTagIdSet.Contains(tt.TagId)).ToList();

            var now = DateTime.UtcNow;
            foreach (var tentTag in toRemove)
            {
                _repo.RemoveTentTag(tentTag);
                _auditService.RecordEvent(
                    AuditActions.TagRemoved,
                    userId,
                    targetEntityType: "TentTag",
                    targetEntityId: tentId,
                    metadata: new Dictionary<string, object?>
                    {
                        ["tagId"] = tentTag.TagId,
                        ["tagName"] = tentTag.Tag.Name
                    });
            }

            foreach (var tagId in toAdd)
            {
                var tag = tagsById[tagId];
                _repo.AddTentTag(new TentTag
                {
                    TentId = tentId,
                    TagId = tagId,
                    CreatedAt = now,
                    CreatedByUserId = userId
                });
                _auditService.RecordEvent(
                    AuditActions.TagAssigned,
                    userId,
                    targetEntityType: "TentTag",
                    targetEntityId: tentId,
                    metadata: new Dictionary<string, object?>
                    {
                        ["tagId"] = tagId,
                        ["tagName"] = tag.Name
                    });
            }

            tent.UpdatedAt = now;
            tent.UpdatedByUserId = userId;

            await _repo.SaveChangesAsync();
            var updatedTent = await _repo.GetTentByIdAsync(tentId);
            if (updatedTent == null)
            {
                await _repo.RollbackTransactionAsync();
                return (null, null, true);
            }

            await _repo.CommitTransactionAsync();

            return (ToTentDto(updatedTent, ToPartDtos(updatedTent.Parts)), null, false);
        }
        catch (DbUpdateException ex) when (DbExceptionHelper.IsAnyConstraintViolation(ex, "FOREIGN KEY", "constraint"))
        {
            await _repo.RollbackTransactionAsync();
            _logger.LogWarning(ex, "Tag assignment constraint violation for tent {TentId}", tentId);
            return (null, new ErrorResponse("One or more tags not found", "TAG_NOT_FOUND"), false);
        }
        catch (Exception ex)
        {
            await _repo.RollbackTransactionAsync();
            _logger.LogError(ex, "Failed to set tags for tent {TentId} by user {UserId}", tentId, userId);
            throw;
        }
    }

    public async Task<(TentDto? Response, bool NotFound)> UnarchiveTentAsync(Guid id, Guid userId)
    {
        var tent = await _repo.GetTentByIdForUpdateAsync(id);
        if (tent == null) return (null, true);

        if (tent.IsArchived)
        {
            tent.IsArchived = false;
            tent.UpdatedAt = DateTime.UtcNow;
            tent.UpdatedByUserId = userId;

            _auditService.RecordEvent(
                AuditActions.TentUnarchived,
                userId,
                targetEntityType: "Tent",
                targetEntityId: id,
                metadata: new Dictionary<string, object?>
                {
                    ["archived"] = false,
                    ["previousIsArchived"] = true,
                    ["tentName"] = tent.Name
                });

            await _repo.SaveChangesAsync();
        }

        return (ToTentDto(tent, ToPartDtos(tent.Parts)), false);
    }

    public async Task<(TentDto? Response, bool NotFound)> ArchiveTentAsync(Guid id, Guid userId)
    {
        var tent = await _repo.GetTentByIdForUpdateAsync(id);
        if (tent == null) return (null, true);

        if (!tent.IsArchived)
        {
            tent.IsArchived = true;
            tent.UpdatedAt = DateTime.UtcNow;
            tent.UpdatedByUserId = userId;

            _auditService.RecordEvent(
                AuditActions.TentArchived,
                userId,
                targetEntityType: "Tent",
                targetEntityId: id,
                metadata: new Dictionary<string, object?>
                {
                    ["archived"] = true,
                    ["previousIsArchived"] = false,
                    ["tentName"] = tent.Name
                });

            await _repo.SaveChangesAsync();
        }

        return (ToTentDto(tent, ToPartDtos(tent.Parts)), false);
    }

    public async Task<(TentModelDto? Response, ErrorResponse? Error, bool NotFound)> CreateModelAsync(
        Guid userId, CreateTentModelRequest request)
    {
        var name = request.Name?.Trim() ?? string.Empty;
        if (name.Length < 2)
            return (null, new ErrorResponse("Model name is required (min 2 characters)", "MODEL_NAME_REQUIRED"), false);
        if (name.Length > 100)
            return (null, new ErrorResponse("Model name is too long (max 100 characters)", "MODEL_NAME_TOO_LONG"), false);

        if (await _repo.HasDuplicateModelNameAsync(name))
            return (null, new ErrorResponse("Model name already exists", "MODEL_NAME_EXISTS"), false);

        var componentIds = request.ComponentIds ?? [];

        if (componentIds.Count > 0)
        {
            var existingPartKindIds = await _db.PartKinds
                .Where(pk => componentIds.Contains(pk.Id))
                .Select(pk => pk.Id)
                .ToListAsync();
            if (existingPartKindIds.Count != componentIds.Count)
                return (null, new ErrorResponse("One or more component IDs are invalid", "INVALID_COMPONENT_IDS"), false);
        }

        var displayOrder = await _repo.GetNextDisplayOrderAsync();

        var model = new TentModel
        {
            Id = Guid.NewGuid(),
            Name = name,
            DisplayOrder = displayOrder,
            IsActive = true,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };

        foreach (var pkId in componentIds)
        {
            model.TentModelComponents.Add(new TentModelComponent
            {
                Id = Guid.NewGuid(),
                TentModelId = model.Id,
                PartKindId = pkId,
                IsStandard = true
            });
        }

        _auditService.RecordEvent(
            AuditActions.TentModelCreated,
            userId,
            targetEntityType: "TentModel",
            targetEntityId: model.Id,
            metadata: new Dictionary<string, object?>
            {
                ["name"] = name,
                ["componentCount"] = componentIds.Count
            });

        _repo.AddTentModel(model);
        await _repo.SaveChangesAsync();

        var created = await _repo.GetTentModelByIdWithComponentsAsync(model.Id);
        return (TentModelDto.FromTentModel(created!), null, false);
    }

    public async Task<(TentModelDto? Response, ErrorResponse? Error, bool NotFound)> UpdateModelAsync(
        Guid userId, Guid id, UpdateTentModelRequest request)
    {
        var model = await _repo.GetTentModelByIdWithComponentsAsync(id);
        if (model == null)
            return (null, null, true);

        var nameChanged = request.Name != null;
        var componentsChanged = request.ComponentIds != null;

        if (!nameChanged && !componentsChanged)
            return (null, new ErrorResponse("At least one of Name or ComponentIds must be provided", "MODEL_UPDATE_NO_CHANGES"), false);

        if (nameChanged)
        {
            var name = request.Name!.Trim();
            if (name.Length < 2)
                return (null, new ErrorResponse("Model name is required (min 2 characters)", "MODEL_NAME_REQUIRED"), false);
            if (name.Length > 100)
                return (null, new ErrorResponse("Model name is too long (max 100 characters)", "MODEL_NAME_TOO_LONG"), false);

            if (await _repo.HasDuplicateModelNameAsync(name, id))
                return (null, new ErrorResponse("Model name already exists", "MODEL_NAME_EXISTS"), false);

            model.Name = name;
        }

        if (componentsChanged)
        {
            var componentIds = request.ComponentIds!;

            if (componentIds.Count > 0)
            {
                var existingPartKindIds = await _db.PartKinds
                    .Where(pk => componentIds.Contains(pk.Id))
                    .Select(pk => pk.Id)
                    .ToListAsync();
                if (existingPartKindIds.Count != componentIds.Count)
                    return (null, new ErrorResponse("One or more component IDs are invalid", "INVALID_COMPONENT_IDS"), false);
            }

            _db.TentModelComponents.RemoveRange(
                _db.TentModelComponents.Where(mc => mc.TentModelId == id));
        }

        model.UpdatedAt = DateTime.UtcNow;

        if (componentsChanged)
        {
            foreach (var pkId in request.ComponentIds!)
            {
                _db.TentModelComponents.Add(new TentModelComponent
                {
                    Id = Guid.NewGuid(),
                    TentModelId = id,
                    PartKindId = pkId,
                    IsStandard = true
                });
            }
        }

        if (nameChanged)
        {
            _auditService.RecordEvent(
                AuditActions.TentModelRenamed,
                userId,
                targetEntityType: "TentModel",
                targetEntityId: id,
                metadata: new Dictionary<string, object?>
                {
                    ["name"] = model.Name,
                    ["componentCount"] = request.ComponentIds?.Count ?? model.TentModelComponents.Count
                });
        }

        await _repo.SaveChangesAsync();

        var updated = await _repo.GetTentModelByIdWithComponentsAsync(id);
        return (TentModelDto.FromTentModel(updated!), null, false);
    }

    public async Task<(bool Success, ErrorResponse? Error, bool NotFound)> DeleteModelAsync(Guid userId, Guid id)
    {
        var model = await _repo.GetTentModelByIdAsync(id);
        if (model == null)
            return (false, null, true);

        if (await _repo.HasTentsForModelAsync(id))
            return (false, new ErrorResponse("Cannot delete model that is in use by tents", "MODEL_IN_USE"), false);

        var name = model.Name;
        var componentCount = model.TentModelComponents.Count;

        _auditService.RecordEvent(
            AuditActions.TentModelDeleted,
            userId,
            targetEntityType: "TentModel",
            targetEntityId: id,
            metadata: new Dictionary<string, object?>
            {
                ["name"] = name,
                ["componentCount"] = componentCount
            });

        _repo.RemoveTentModel(model);
        await _repo.SaveChangesAsync();

        return (true, null, false);
    }

    private static ErrorResponse? ValidateTentRequest(
        string? name,
        int size,
        string? overallStateValue,
        string? comments,
        string failureCode,
        out ValidatedTentRequest validated)
    {
        var normalizedName = (name ?? string.Empty).Trim();
        var normalizedComments = string.IsNullOrWhiteSpace(comments) ? null : comments.Trim();

        if (string.IsNullOrWhiteSpace(normalizedName))
        {
            validated = new ValidatedTentRequest(normalizedName, size, default, normalizedComments);
            return new ErrorResponse("Tent name is required", "TENT_NAME_REQUIRED");
        }

        if (normalizedName.Length > MaxTentNameLength)
        {
            validated = new ValidatedTentRequest(normalizedName, size, default, normalizedComments);
            return new ErrorResponse("Tent name exceeds maximum length", failureCode);
        }

        if (size <= 0 || size > MaxTentSize)
        {
            validated = new ValidatedTentRequest(normalizedName, size, default, normalizedComments);
            return new ErrorResponse("Tent size must be between 1 and 100", "INVALID_TENT_SIZE");
        }

        if (!Enum.TryParse<TentOverallState>(overallStateValue, true, out var overallState)
            || !Enum.IsDefined(overallState))
        {
            validated = new ValidatedTentRequest(normalizedName, size, default, normalizedComments);
            return new ErrorResponse("Tent overall state is invalid", "INVALID_TENT_STATE");
        }

        if (normalizedComments != null && normalizedComments.Length > MaxTentCommentsLength)
        {
            validated = new ValidatedTentRequest(normalizedName, size, default, normalizedComments);
            return new ErrorResponse("Tent comments exceed maximum length", failureCode);
        }

        validated = new ValidatedTentRequest(normalizedName, size, overallState, normalizedComments);
        return null;
    }

    private static List<PartDto> ToPartDtos(IEnumerable<Part> parts)
    {
        return parts
            .OrderBy(p => p.PartKind.DisplayOrder)
            .ThenBy(p => p.PartKindId)
            .Select(PartDto.FromPart)
            .ToList();
    }

    private static TentDto ToTentDto(Tent tent, IReadOnlyList<PartDto> parts, string? modelName = null)
    {
        return new TentDto(
            tent.Id,
            tent.Name,
            tent.Size,
            tent.TentModelId,
            modelName ?? tent.TentModel?.Name,
            tent.OverallState.ToString(),
            tent.IsArchived,
            tent.Comments,
            tent.CreatedAt,
            tent.UpdatedAt,
            parts,
            TentRepository.ToTagDtos(tent.TentTags)
        );
    }

    private static bool IsDuplicateTentNameViolation(DbUpdateException exception)
    {
        return DbExceptionHelper.IsConstraintViolation(exception, "UNIQUE", "Tents.Name");
    }

    private sealed record ValidatedTentRequest(
        string Name,
        int Size,
        TentOverallState OverallState,
        string? Comments);
}
