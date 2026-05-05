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
