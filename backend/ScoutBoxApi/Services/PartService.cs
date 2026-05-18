using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Repositories;

namespace ScoutBoxApi.Services;

public class PartService
{
    private const int MaxPartCommentsLength = 500;

    private static readonly IReadOnlyDictionary<string, PartState> SupportedStates =
        new Dictionary<string, PartState>(StringComparer.Ordinal)
        {
            ["Good"] = PartState.Good,
            ["NeedsRepair"] = PartState.NeedsRepair,
            ["Missing"] = PartState.Missing,
            ["Unusable"] = PartState.Unusable
        };

    private readonly ITentRepository _repo;
    private readonly IAuditService _auditService;

    public PartService(ITentRepository repo, IAuditService auditService)
    {
        _repo = repo;
        _auditService = auditService;
    }

    public async Task<(PartDto? Response, ErrorResponse? Error, bool NotFound)> UpdatePartStateAsync(
        Guid id,
        Guid userId,
        UpdatePartStateRequest request)
    {
        if (!TryParseState(request.State, out var newState))
        {
            return (null, new ErrorResponse("Part state is invalid", "INVALID_PART_STATE"), false);
        }

        var requestedComments = NormalizeComments(request.Comments);
        if (request.HasComments && requestedComments != null && requestedComments.Length > MaxPartCommentsLength)
        {
            return (null, new ErrorResponse("Part comments are too long", "PART_COMMENTS_TOO_LONG"), false);
        }

        var part = await _repo.GetPartByIdForUpdateAsync(id);
        if (part == null)
        {
            return (null, null, true);
        }

        if (part.Tent.IsArchived)
        {
            return (null, new ErrorResponse("Cannot update part state for archived tent", "TENT_ARCHIVED"), false);
        }

        var normalizedComments = request.HasComments ? requestedComments : part.Comments;

        if (part.State == newState && part.Comments == normalizedComments)
        {
            return (ToPartDto(part), null, false);
        }

        var oldState = part.State;
        var oldComments = part.Comments;
        part.State = newState;
        part.Comments = normalizedComments;
        part.UpdatedAt = DateTime.UtcNow;
        part.UpdatedByUserId = userId;

        if (oldState != part.State)
        {
            _auditService.RecordEvent(
                AuditActions.PartStateChanged,
                userId,
                targetEntityType: "Part",
                targetEntityId: part.Id,
                metadata: new Dictionary<string, object?>
                {
                    ["tentId"] = part.TentId,
                    ["partKindId"] = part.PartKindId,
                    ["oldState"] = oldState.ToString(),
                    ["newState"] = part.State.ToString()
                });
        }

        if (oldComments != part.Comments)
        {
            _auditService.RecordEvent(
                AuditActions.PartCommentsChanged,
                userId,
                targetEntityType: "Part",
                targetEntityId: part.Id,
                metadata: new Dictionary<string, object?>
                {
                    ["tentId"] = part.TentId,
                    ["partKindId"] = part.PartKindId
                });
        }

        await _repo.SaveChangesAsync();
        return (ToPartDto(part), null, false);
    }

    private static bool TryParseState(string? value, out PartState state)
    {
        if (value == null)
        {
            state = default;
            return false;
        }

        var normalized = value.Trim();
        if (normalized.Length == 0)
        {
            state = default;
            return false;
        }

        return SupportedStates.TryGetValue(normalized, out state);
    }

    private static string? NormalizeComments(string? comments)
    {
        var normalized = comments?.Trim();
        return string.IsNullOrEmpty(normalized) ? null : normalized;
    }

    public async Task<(List<PartDto>? Response, ErrorResponse? Error)> AddPartsToTentAsync(
        Guid tentId,
        List<Guid> partKindIds,
        Guid userId)
    {
        if (partKindIds == null || partKindIds.Count == 0)
        {
            return (null, new ErrorResponse("Request must contain at least one partKindId", "INVALID_REQUEST"));
        }

        if (partKindIds.Count != partKindIds.Distinct().Count())
        {
            return (null, new ErrorResponse("Request contains duplicate PartKindIds", "DUPLICATE_PART"));
        }

        var tent = await _repo.GetTentByIdForUpdateAsync(tentId);
        if (tent == null)
        {
            return (null, new ErrorResponse("Tent not found", "TENT_NOT_FOUND"));
        }

        if (tent.IsArchived)
        {
            return (null, new ErrorResponse("Cannot add parts to archived tent", "TENT_ARCHIVED"));
        }

        var allPartKinds = await _repo.GetAllPartKindsAsync();
        var existingPartKindIds = tent.Parts.Select(p => p.PartKindId).ToHashSet();
        var allPartKindIds = allPartKinds.Select(pk => pk.Id).ToHashSet();

        var invalidIds = partKindIds.Where(id => !allPartKindIds.Contains(id)).ToList();
        if (invalidIds.Count > 0)
        {
            return (null, new ErrorResponse("One or more PartKindIds are invalid", "INVALID_PART_KIND"));
        }

        var duplicateIds = partKindIds.Where(id => existingPartKindIds.Contains(id)).ToList();
        if (duplicateIds.Count > 0)
        {
            return (null, new ErrorResponse("One or more parts already exist on this tent", "DUPLICATE_PART"));
        }

        var now = DateTime.UtcNow;
        var newParts = new List<Part>();

        foreach (var partKindId in partKindIds)
        {
            var part = new Part
            {
                Id = Guid.NewGuid(),
                TentId = tentId,
                PartKindId = partKindId,
                State = PartState.Good,
                Comments = null,
                CreatedAt = now,
                UpdatedAt = now,
                CreatedByUserId = userId,
                UpdatedByUserId = userId
            };

            newParts.Add(part);

            _auditService.RecordEvent(
                AuditActions.PartAdded,
                userId,
                targetEntityType: "Part",
                targetEntityId: part.Id,
                metadata: new Dictionary<string, object?>
                {
                    ["tentId"] = tentId,
                    ["partKindId"] = partKindId
                });
        }

        _repo.AddParts(newParts);
        await _repo.SaveChangesAsync();

        var partIds = newParts.Select(p => p.Id).ToList();
        var savedParts = await _repo.GetPartsByIdsAsync(partIds);
        var dtos = savedParts.Select(ToPartDto).ToList();
        return (dtos, null);
    }

    public async Task<(ErrorResponse? Error, bool NotFound)> RemovePartAsync(Guid partId, Guid userId)
    {
        var part = await _repo.GetPartByIdIncludingTentAsync(partId);
        if (part == null)
        {
            return (null, true);
        }

        if (part.Tent.IsArchived)
        {
            return (new ErrorResponse("Cannot remove part from archived tent", "TENT_ARCHIVED"), false);
        }

        var tentId = part.TentId;
        var partKindId = part.PartKindId;

        _auditService.RecordEvent(
            AuditActions.PartDeleted,
            userId,
            targetEntityType: "Part",
            targetEntityId: partId,
            metadata: new Dictionary<string, object?>
            {
                ["tentId"] = tentId,
                ["partKindId"] = partKindId
            });

        _repo.RemovePart(part);
        await _repo.SaveChangesAsync();

        return (null, false);
    }

    private static PartDto ToPartDto(Part part)
    {
        return new PartDto(
            part.Id,
            part.PartKindId,
            part.PartKind.Name,
            part.PartKind.DisplayOrder,
            part.State.ToString(),
            part.Comments,
            part.CreatedAt,
            part.UpdatedAt);
    }
}
