using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Services;

/// <summary>
/// Data transfer object for audit history items with resolved actor display names.
/// </summary>
public record AuditEventHistoryItemDto(
    Guid Id,
    string Action,
    DateTime OccurredAt,
    string? TargetEntityType,
    Guid? TargetEntityId,
    string? MetadataJson,
    Guid? ActorUserId,
    string ActorDisplayName);

/// <summary>
/// Service for querying audit history with resolved user display names.
/// Handles soft-deleted users by showing "Utilisateur supprimé" as fallback.
/// </summary>
public interface IAuditHistoryService
{
    /// <summary>
    /// Gets audit history with resolved actor display names.
    /// Deleted or missing users display as "Utilisateur supprimé".
    /// </summary>
    /// <param name="startDate">Optional start date filter (UTC)</param>
    /// <param name="endDate">Optional end date filter (UTC)</param>
    /// <param name="actorUserId">Optional filter by specific actor</param>
    /// <param name="action">Optional filter by action type</param>
    /// <param name="limit">Maximum number of results (default 100)</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>List of audit history items with resolved display names</returns>
    Task<List<AuditEventHistoryItemDto>> GetAuditHistoryAsync(
        DateTime? startDate = null,
        DateTime? endDate = null,
        Guid? actorUserId = null,
        string? action = null,
        int limit = 100,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Gets audit history for a specific target entity.
    /// </summary>
    /// <param name="targetEntityType">Entity type (e.g., "Tent", "User")</param>
    /// <param name="targetEntityId">Entity ID</param>
    /// <param name="limit">Maximum number of results</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>List of audit history items for the entity</returns>
    Task<List<AuditEventHistoryItemDto>> GetEntityHistoryAsync(
        string targetEntityType,
        Guid targetEntityId,
        int limit = 50,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Gets tent-specific history including direct tent events and part events for this tent.
    /// </summary>
    Task<List<TentHistoryItemDto>> GetTentHistoryAsync(
        Guid tentId,
        string? category = null,
        int limit = 50,
        CancellationToken cancellationToken = default);

    /// <summary>
    /// Resolves the display name for a user, handling deleted/missing users.
    /// </summary>
    /// <param name="userId">User ID to resolve</param>
    /// <param name="cancellationToken">Cancellation token</param>
    /// <returns>Display name or "Utilisateur supprimé" if user is deleted/missing</returns>
    Task<string> ResolveActorDisplayNameAsync(Guid? userId, CancellationToken cancellationToken = default);
}

/// <summary>
/// Implementation of IAuditHistoryService that queries audit events with user display name resolution.
/// </summary>
public class AuditHistoryService : IAuditHistoryService
{
    private readonly ScoutBoxDbContext _db;
    private readonly ILogger<AuditHistoryService> _logger;

    // French display text for deleted users per specification
    private const string DeletedUserDisplayName = "Utilisateur supprimé";

    public AuditHistoryService(ScoutBoxDbContext db, ILogger<AuditHistoryService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<AuditEventHistoryItemDto>> GetAuditHistoryAsync(
        DateTime? startDate = null,
        DateTime? endDate = null,
        Guid? actorUserId = null,
        string? action = null,
        int limit = 100,
        CancellationToken cancellationToken = default)
    {
        var query = _db.AuditEvents
            .AsNoTracking()
            .AsQueryable();

        // Apply filters
        if (startDate.HasValue)
        {
            query = query.Where(ae => ae.OccurredAt >= startDate.Value);
        }

        if (endDate.HasValue)
        {
            query = query.Where(ae => ae.OccurredAt <= endDate.Value);
        }

        if (actorUserId.HasValue)
        {
            query = query.Where(ae => ae.ActorUserId == actorUserId.Value);
        }

        if (!string.IsNullOrEmpty(action))
        {
            query = query.Where(ae => ae.Action == action);
        }

        // Order by most recent first
        query = query.OrderByDescending(ae => ae.OccurredAt);

        // Get the events
        var events = await query
            .Take(limit)
            .ToListAsync(cancellationToken);

        // Map to DTOs with resolved display names
        return await MapToHistoryDtosAsync(events, cancellationToken);
    }

    public async Task<List<AuditEventHistoryItemDto>> GetEntityHistoryAsync(
        string targetEntityType,
        Guid targetEntityId,
        int limit = 50,
        CancellationToken cancellationToken = default)
    {
        var events = await _db.AuditEvents
            .AsNoTracking()
            .Where(ae => ae.TargetEntityType == targetEntityType && ae.TargetEntityId == targetEntityId)
            .OrderByDescending(ae => ae.OccurredAt)
            .Take(limit)
            .ToListAsync(cancellationToken);

        // Map to DTOs with resolved display names
        return await MapToHistoryDtosAsync(events, cancellationToken);
    }

    /// <summary>
    /// Maps audit events to DTOs with resolved actor display names.
    /// </summary>
    private async Task<List<AuditEventHistoryItemDto>> MapToHistoryDtosAsync(
        List<AuditEvent> events,
        CancellationToken cancellationToken)
    {
        // Resolve display names for all unique actor IDs
        var actorIds = events
            .Where(e => e.ActorUserId.HasValue)
            .Select(e => e.ActorUserId!.Value)
            .Distinct()
            .ToList();

        var displayNameMap = new Dictionary<Guid, string>();
        foreach (var id in actorIds)
        {
            displayNameMap[id] = await ResolveActorDisplayNameAsync(id, cancellationToken);
        }

        return events.Select(ae => new AuditEventHistoryItemDto(
            ae.Id,
            ae.Action,
            ae.OccurredAt,
            ae.TargetEntityType,
            ae.TargetEntityId,
            ae.MetadataJson,
            ae.ActorUserId,
            ae.ActorUserId.HasValue && displayNameMap.ContainsKey(ae.ActorUserId.Value)
                ? displayNameMap[ae.ActorUserId.Value]
                : DeletedUserDisplayName
        )).ToList();
    }

    private static class TentHistoryCategories
    {
        public const string TentInfo = "tent_info";
        public const string Archive = "archive";
        public const string PartState = "part_state";
        public const string PartManagement = "part_management";
        public const string Other = "other";
    }

    public async Task<List<TentHistoryItemDto>> GetTentHistoryAsync(
        Guid tentId,
        string? category = null,
        int limit = 50,
        CancellationToken cancellationToken = default)
    {
        var candidateCount = Math.Min(Math.Max(limit * 5, 200), 500);

        var tentEvents = await _db.AuditEvents
            .AsNoTracking()
            .Where(ae => ae.TargetEntityType == "Tent" && ae.TargetEntityId == tentId)
            .OrderByDescending(ae => ae.OccurredAt)
            .Take(candidateCount)
            .ToListAsync(cancellationToken);

        var partActions = new[] { AuditActions.PartStateChanged, AuditActions.PartCommentsChanged, AuditActions.PartAdded, AuditActions.PartDeleted };
        var partEventCandidates = await _db.AuditEvents
            .AsNoTracking()
            .Where(ae => ae.TargetEntityType == "Part" && partActions.Contains(ae.Action))
            .OrderByDescending(ae => ae.OccurredAt)
            .Take(candidateCount)
            .ToListAsync(cancellationToken);

        var matchingPartEvents = partEventCandidates
            .Where(pe => TryGetMetadataTentId(pe.MetadataJson) == tentId)
            .ToList();

        var allEvents = tentEvents.Concat(matchingPartEvents)
            .OrderByDescending(ae => ae.OccurredAt)
            .Take(limit)
            .ToList();

        var allPartKindIds = allEvents
            .Select(ae => TryGetMetadataPartKindId(ae.MetadataJson))
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .Distinct()
            .ToList();

        var partKindNames = await _db.PartKinds
            .AsNoTracking()
            .Where(pk => allPartKindIds.Contains(pk.Id))
            .ToDictionaryAsync(pk => pk.Id, pk => pk.Name, cancellationToken);

        return await MapToTentHistoryDtosAsync(allEvents, partKindNames, category, cancellationToken);
    }

    private static Guid? TryGetMetadataTentId(string? metadataJson)
    {
        if (string.IsNullOrWhiteSpace(metadataJson)) return null;
        try
        {
            using var doc = JsonDocument.Parse(metadataJson);
            if (doc.RootElement.TryGetProperty("tentId", out var tentIdProp) &&
                tentIdProp.ValueKind == JsonValueKind.String &&
                Guid.TryParse(tentIdProp.GetString(), out var tentId))
            {
                return tentId;
            }
            return null;
        }
        catch
        {
            return null;
        }
    }

    private static Guid? TryGetMetadataPartKindId(string? metadataJson)
    {
        if (string.IsNullOrWhiteSpace(metadataJson)) return null;
        try
        {
            using var doc = JsonDocument.Parse(metadataJson);
            if (doc.RootElement.TryGetProperty("partKindId", out var pkIdProp) &&
                pkIdProp.ValueKind == JsonValueKind.String &&
                Guid.TryParse(pkIdProp.GetString(), out var pkId))
            {
                return pkId;
            }
            return null;
        }
        catch
        {
            return null;
        }
    }

    private async Task<List<TentHistoryItemDto>> MapToTentHistoryDtosAsync(
        List<AuditEvent> events,
        Dictionary<Guid, string> partKindNames,
        string? categoryFilter,
        CancellationToken cancellationToken)
    {
        var actorIds = events
            .Where(e => e.ActorUserId.HasValue)
            .Select(e => e.ActorUserId!.Value)
            .Distinct()
            .ToList();

        var displayNameMap = new Dictionary<Guid, string>();
        foreach (var id in actorIds)
        {
            displayNameMap[id] = await ResolveActorDisplayNameAsync(id, cancellationToken);
        }

        var results = new List<TentHistoryItemDto>();

        foreach (var ae in events)
        {
            string? metadataJson = null;

            var item = BuildTentHistoryItem(ae, partKindNames, displayNameMap, out metadataJson);

            if (categoryFilter == null || item.Category == categoryFilter)
            {
                results.Add(item);
            }
        }

        return results;
    }

    private TentHistoryItemDto BuildTentHistoryItem(
        AuditEvent ae,
        Dictionary<Guid, string> partKindNames,
        Dictionary<Guid, string> displayNameMap,
        out string? metadataJson)
    {
        metadataJson = ae.MetadataJson;
        var actorName = ae.ActorUserId.HasValue && displayNameMap.ContainsKey(ae.ActorUserId.Value)
            ? displayNameMap[ae.ActorUserId.Value]
            : DeletedUserDisplayName;

        return ae.Action switch
        {
            AuditActions.TentCreated => BuildTentCreatedItem(ae, actorName),
            AuditActions.TentUpdated => BuildTentUpdatedItem(ae, actorName),
            AuditActions.TentArchived => BuildTentArchivedItem(ae, actorName),
            AuditActions.PartStateChanged => BuildPartStateChangedItem(ae, actorName, partKindNames),
            AuditActions.PartCommentsChanged => BuildPartCommentsChangedItem(ae, actorName, partKindNames),
            AuditActions.PartAdded => BuildPartAddedItem(ae, actorName, partKindNames),
            AuditActions.PartDeleted => BuildPartDeletedItem(ae, actorName, partKindNames),
            _ => BuildUnknownItem(ae, actorName)
        };
    }

    private static TentHistoryItemDto BuildTentCreatedItem(AuditEvent ae, string actorName)
    {
        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategories.TentInfo,
            ae.OccurredAt, ae.ActorUserId, actorName,
            $"Tente créée le {ae.OccurredAt.ToLocalTime():g} par {actorName}",
            new List<TentHistoryDetailDto>(),
            ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private TentHistoryItemDto BuildTentUpdatedItem(AuditEvent ae, string actorName)
    {
        var details = new List<TentHistoryDetailDto>();
        TryParseMetadata(ae.MetadataJson, out var changedFields, out var oldName, out var newName,
            out var oldSize, out var newSize, out var oldOverallState, out var newOverallState,
            out var commentsChanged);

        if (!string.IsNullOrEmpty(oldName) && !string.IsNullOrEmpty(newName) && oldName != newName)
        {
            details.Add(new TentHistoryDetailDto("Nom", oldName, newName, null, "old_new"));
        }
        if (oldSize.HasValue && newSize.HasValue && oldSize != newSize)
        {
            details.Add(new TentHistoryDetailDto("Taille", oldSize.ToString(), newSize.ToString(), null, "old_new"));
        }
        if (!string.IsNullOrEmpty(oldOverallState) && !string.IsNullOrEmpty(newOverallState) && oldOverallState != newOverallState)
        {
            details.Add(new TentHistoryDetailDto("État", oldOverallState, newOverallState, null, "state"));
        }
        if (commentsChanged == true)
        {
            details.Add(new TentHistoryDetailDto("Commentaire", null, null, "Commentaire modifié", "flag"));
        }

        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategories.TentInfo,
            ae.OccurredAt, ae.ActorUserId, actorName,
            $"Informations mises à jour le {ae.OccurredAt.ToLocalTime():g} par {actorName}",
            details, ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private static TentHistoryItemDto BuildTentArchivedItem(AuditEvent ae, string actorName)
    {
        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategories.Archive,
            ae.OccurredAt, ae.ActorUserId, actorName,
            $"Tente archivée le {ae.OccurredAt.ToLocalTime():g} par {actorName}",
            new List<TentHistoryDetailDto>(),
            ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private TentHistoryItemDto BuildPartStateChangedItem(
        AuditEvent ae, string actorName, Dictionary<Guid, string> partKindNames)
    {
        var partKindId = TryGetMetadataPartKindId(ae.MetadataJson);
        var partName = partKindId.HasValue && partKindNames.TryGetValue(partKindId.Value, out var name)
            ? name
            : "Pièce inconnue";

        var details = new List<TentHistoryDetailDto>();
        TryParsePartStateMetadata(ae.MetadataJson, out var oldState, out var newState);

        if (!string.IsNullOrEmpty(oldState) || !string.IsNullOrEmpty(newState))
        {
            details.Add(new TentHistoryDetailDto("État", oldState, newState, null, "state"));
        }

        var oldStateLabel = !string.IsNullOrEmpty(oldState) ? oldState : "?";
        var newStateLabel = !string.IsNullOrEmpty(newState) ? newState : "?";

        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategories.PartState,
            ae.OccurredAt, ae.ActorUserId, actorName,
            $"État de {partName} changé de {oldStateLabel} à {newStateLabel} le {ae.OccurredAt.ToLocalTime():g} par {actorName}",
            details, ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private TentHistoryItemDto BuildPartCommentsChangedItem(
        AuditEvent ae, string actorName, Dictionary<Guid, string> partKindNames)
    {
        var partKindId = TryGetMetadataPartKindId(ae.MetadataJson);
        var partName = partKindId.HasValue && partKindNames.TryGetValue(partKindId.Value, out var name)
            ? name
            : "Pièce inconnue";

        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategories.PartState,
            ae.OccurredAt, ae.ActorUserId, actorName,
            $"Commentaire de {partName} modifié le {ae.OccurredAt.ToLocalTime():g} par {actorName}",
            new List<TentHistoryDetailDto>(),
            ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private TentHistoryItemDto BuildPartAddedItem(
        AuditEvent ae, string actorName, Dictionary<Guid, string> partKindNames)
    {
        var partKindId = TryGetMetadataPartKindId(ae.MetadataJson);
        var partName = partKindId.HasValue && partKindNames.TryGetValue(partKindId.Value, out var name)
            ? name
            : "Pièce inconnue";

        var details = new List<TentHistoryDetailDto>
        {
            new TentHistoryDetailDto("État", null, null, "Bon état", "initial_state")
        };

        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategories.PartManagement,
            ae.OccurredAt, ae.ActorUserId, actorName,
            $"Pièce ajoutée : {partName} le {ae.OccurredAt.ToLocalTime():g} par {actorName}",
            details, ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private TentHistoryItemDto BuildPartDeletedItem(
        AuditEvent ae, string actorName, Dictionary<Guid, string> partKindNames)
    {
        var partKindId = TryGetMetadataPartKindId(ae.MetadataJson);
        var partName = partKindId.HasValue && partKindNames.TryGetValue(partKindId.Value, out var name)
            ? name
            : "Pièce inconnue";

        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategories.PartManagement,
            ae.OccurredAt, ae.ActorUserId, actorName,
            $"Pièce supprimée : {partName} le {ae.OccurredAt.ToLocalTime():g} par {actorName}",
            new List<TentHistoryDetailDto>(),
            ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private static TentHistoryItemDto BuildUnknownItem(AuditEvent ae, string actorName)
    {
        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategories.Other,
            ae.OccurredAt, ae.ActorUserId, actorName,
            $"Action {ae.Action} le {ae.OccurredAt.ToLocalTime():g} par {actorName}",
            new List<TentHistoryDetailDto>(),
            ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private static void TryParseMetadata(
        string? metadataJson,
        out List<string>? changedFields,
        out string? oldName, out string? newName,
        out int? oldSize, out int? newSize,
        out string? oldOverallState, out string? newOverallState,
        out bool? commentsChanged)
    {
        changedFields = null;
        oldName = null; newName = null;
        oldSize = null; newSize = null;
        oldOverallState = null; newOverallState = null;
        commentsChanged = null;

        if (string.IsNullOrWhiteSpace(metadataJson)) return;

        try
        {
            using var doc = JsonDocument.Parse(metadataJson);
            var root = doc.RootElement;

            if (root.TryGetProperty("changedFields", out var fieldsProp) && fieldsProp.ValueKind == JsonValueKind.Array)
            {
                changedFields = fieldsProp.EnumerateArray().Select(f => f.GetString() ?? "").Where(s => !string.IsNullOrEmpty(s)).ToList()!;
            }

            if (root.TryGetProperty("oldName", out var p)) oldName = p.GetString();
            if (root.TryGetProperty("newName", out var p2)) newName = p2.GetString();
            if (root.TryGetProperty("oldSize", out var p3) && p3.ValueKind == JsonValueKind.Number) oldSize = p3.GetInt32();
            if (root.TryGetProperty("newSize", out var p4) && p4.ValueKind == JsonValueKind.Number) newSize = p4.GetInt32();
            if (root.TryGetProperty("oldOverallState", out var p5)) oldOverallState = p5.GetString();
            if (root.TryGetProperty("newOverallState", out var p6)) newOverallState = p6.GetString();
            if (root.TryGetProperty("commentsChanged", out var p7) && p7.ValueKind == JsonValueKind.True) commentsChanged = true;
        }
        catch
        {
        }
    }

    private static void TryParsePartStateMetadata(
        string? metadataJson,
        out string? oldState, out string? newState)
    {
        oldState = null; newState = null;
        if (string.IsNullOrWhiteSpace(metadataJson)) return;

        try
        {
            using var doc = JsonDocument.Parse(metadataJson);
            var root = doc.RootElement;
            if (root.TryGetProperty("oldState", out var p)) oldState = p.GetString();
            if (root.TryGetProperty("newState", out var p2)) newState = p2.GetString();
        }
        catch
        {
        }
    }

    public async Task<string> ResolveActorDisplayNameAsync(Guid? userId, CancellationToken cancellationToken = default)
    {
        if (!userId.HasValue)
        {
            return DeletedUserDisplayName;
        }

        try
        {
            // Query user with IgnoreQueryFilters to check soft-delete status
            var user = await _db.Users
                .AsNoTracking()
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(u => u.Id == userId.Value, cancellationToken);

            if (user == null)
            {
                _logger.LogDebug("Actor user {UserId} not found in database", userId.Value);
                return DeletedUserDisplayName;
            }

            if (user.IsDeleted)
            {
                _logger.LogDebug("Actor user {UserId} is soft-deleted", userId.Value);
                return DeletedUserDisplayName;
            }

            return user.Username;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error resolving actor display name for user {UserId}", userId.Value);
            return DeletedUserDisplayName;
        }
    }
}
