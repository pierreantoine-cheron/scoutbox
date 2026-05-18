using Microsoft.EntityFrameworkCore;
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

    public TentService(ITentRepository repo, IAuditService auditService, ILogger<TentService> logger)
    {
        _repo = repo;
        _auditService = auditService;
        _logger = logger;
    }

    public async Task<IReadOnlyList<TentShapeDto>> GetActiveShapesAsync()
    {
        return await _repo.GetActiveShapesAsync();
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

        var shape = await _repo.GetActiveTentShapeByIdAsync(request.TentShapeId);
        if (shape == null)
            return (null, new ErrorResponse("Tent shape does not exist", "INVALID_TENT_SHAPE"));

        if (await _repo.HasDuplicateTentNameAsync(validated.Name))
            return (null, new ErrorResponse("Tent name already exists", "TENT_NAME_EXISTS"));

        await _repo.BeginTransactionAsync();

        try
        {
            var now = DateTime.UtcNow;
            var tent = new Tent
            {
                Id = Guid.NewGuid(),
                Name = validated.Name,
                Size = validated.Size,
                TentShapeId = request.TentShapeId,
                OverallState = validated.OverallState,
                Comments = validated.Comments,
                CreatedAt = now,
                UpdatedAt = now,
                CreatedByUserId = userId,
                UpdatedByUserId = userId
            };

            _repo.AddTent(tent);

            var orderedShapeParts = shape.TentShapeParts
                .OrderBy(sp => sp.PartKind.DisplayOrder)
                .ThenBy(sp => sp.PartKindId)
                .ToList();

            var createdParts = new List<Part>(orderedShapeParts.Count);
            foreach (var shapePart in orderedShapeParts)
            {
                var part = new Part
                {
                    Id = Guid.NewGuid(),
                    TentId = tent.Id,
                    PartKindId = shapePart.PartKindId,
                    PartKind = shapePart.PartKind,
                    State = PartState.Good,
                    Comments = null,
                    CreatedAt = now,
                    UpdatedAt = now,
                    CreatedByUserId = userId,
                    UpdatedByUserId = userId
                };
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
                    ["tentShapeId"] = tent.TentShapeId,
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
            return (ToTentDto(tent, ToPartDtos(createdParts), shape.Name), null);
        }
        catch (Exception ex)
        {
            await _repo.RollbackTransactionAsync();
            _logger.LogError(ex, "Failed to create tent {TentName} with shape {TentShapeId} for user {UserId}", validated.Name, request.TentShapeId, userId);
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

        // Need tracking entity for update
        var tent = await _repo.GetTentByIdForUpdateAsync(id);
        if (tent == null) return (null, null, true);

        if (await _repo.HasDuplicateTentNameAsync(validated.Name, id))
            return (null, new ErrorResponse("Tent name already exists", "TENT_NAME_EXISTS"), false);

        var oldName = tent.Name;
        var oldSize = tent.Size;
        var oldOverallState = tent.OverallState;
        var oldComments = tent.Comments;

        var changedFields = new List<string>();
        if (oldName != validated.Name) changedFields.Add("name");
        if (oldSize != validated.Size) changedFields.Add("size");
        if (oldOverallState != validated.OverallState) changedFields.Add("overallState");
        var commentsChanged = oldComments != validated.Comments;
        if (commentsChanged) changedFields.Add("comments");

        if (changedFields.Count > 0)
        {
            var now = DateTime.UtcNow;
            tent.Name = validated.Name;
            tent.Size = validated.Size;
            tent.OverallState = validated.OverallState;
            tent.Comments = validated.Comments;
            tent.UpdatedAt = now;
            tent.UpdatedByUserId = userId;

            _auditService.RecordEvent(
                AuditActions.TentUpdated,
                userId,
                targetEntityType: "Tent",
                targetEntityId: id,
                metadata: new Dictionary<string, object?>
                {
                    ["changedFields"] = changedFields,
                    ["oldName"] = oldName,
                    ["newName"] = tent.Name,
                    ["oldSize"] = oldSize,
                    ["newSize"] = tent.Size,
                    ["oldOverallState"] = oldOverallState.ToString(),
                    ["newOverallState"] = tent.OverallState.ToString(),
                    ["commentsChanged"] = commentsChanged
                });
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

        return (ToTentDto(tent, ToPartDtos(tent.Parts)), null, false);
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
            .Select(p => new PartDto(
                p.Id,
                p.PartKindId,
                p.PartKind.Name,
                p.PartKind.DisplayOrder,
                p.State.ToString(),
                p.Comments,
                p.CreatedAt,
                p.UpdatedAt
            ))
            .ToList();
    }

    private static TentDto ToTentDto(Tent tent, IReadOnlyList<PartDto> parts, string? shapeName = null)
    {
        return new TentDto(
            tent.Id,
            tent.Name,
            tent.Size,
            tent.TentShapeId,
            shapeName ?? tent.TentShape?.Name,
            tent.OverallState.ToString(),
            tent.IsArchived,
            tent.Comments,
            tent.CreatedAt,
            tent.UpdatedAt,
            parts
        );
    }

    private static bool IsDuplicateTentNameViolation(DbUpdateException exception)
    {
        var message = exception.InnerException?.Message ?? exception.Message;
        return message.Contains("UNIQUE constraint failed", StringComparison.OrdinalIgnoreCase)
            && message.Contains("Tents.Name", StringComparison.OrdinalIgnoreCase);
    }

    private sealed record ValidatedTentRequest(
        string Name,
        int Size,
        TentOverallState OverallState,
        string? Comments);
}
