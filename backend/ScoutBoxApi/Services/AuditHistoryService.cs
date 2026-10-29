using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Services;

public enum TentHistoryCategory
{
    TentInfo,
    Archive,
    PartState,
    PartManagement,
    Tags,
    Other
}

public static class TentHistoryCategoryMapper
{
    public static bool TryParse(string? value, out TentHistoryCategory? category)
    {
        category = value switch
        {
            null or "" => null,
            "tent_info" => TentHistoryCategory.TentInfo,
            "archive" => TentHistoryCategory.Archive,
            "part_state" => TentHistoryCategory.PartState,
            "part_management" => TentHistoryCategory.PartManagement,
            "tags" => TentHistoryCategory.Tags,
            "other" => TentHistoryCategory.Other,
            _ => null
        };

        return string.IsNullOrEmpty(value) || category.HasValue;
    }

    public static string ToApiValue(TentHistoryCategory category)
    {
        return category switch
        {
            TentHistoryCategory.TentInfo => "tent_info",
            TentHistoryCategory.Archive => "archive",
            TentHistoryCategory.PartState => "part_state",
            TentHistoryCategory.PartManagement => "part_management",
            TentHistoryCategory.Tags => "tags",
            TentHistoryCategory.Other => "other",
            _ => "other"
        };
    }
}

/// <summary>
/// Service for querying audit history with resolved user display names.
/// The seeded system account is displayed as "Système".
/// </summary>
public interface IAuditHistoryService
{
    /// <summary>
    /// Gets tent-specific history including direct tent events and part events for this tent.
    /// </summary>
    Task<List<TentHistoryItemDto>> GetTentHistoryAsync(
        Guid tentId,
        TentHistoryCategory? category = null,
        int limit = 50,
        CancellationToken cancellationToken = default);
}

/// <summary>
/// Implementation of IAuditHistoryService that queries audit events with user display name resolution.
/// </summary>
public class AuditHistoryService : IAuditHistoryService
{
    private readonly ScoutBoxDbContext _db;
    private readonly ILogger<AuditHistoryService> _logger;

    private static readonly Guid SystemUserId = Guid.Parse("00000000-0000-0000-0000-000000000001");
    private const string SystemDisplayName = "Système";

    public AuditHistoryService(ScoutBoxDbContext db, ILogger<AuditHistoryService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<List<TentHistoryItemDto>> GetTentHistoryAsync(
        Guid tentId,
        TentHistoryCategory? category = null,
        int limit = 50,
        CancellationToken cancellationToken = default)
    {
        var candidateCount = Math.Min(Math.Max(limit * 5, 200), 500);
        var tentActions = GetTentHistoryTentActions(category);
        var partActions = GetTentHistoryPartActions(category);
        var tagActions = GetTentHistoryTagActions(category);

        var tentQuery = _db.AuditEvents
            .AsNoTracking()
            .Where(ae => ae.TargetEntityType == "Tent" && ae.TargetEntityId == tentId);

        if (tentActions != null)
        {
            tentQuery = tentQuery.Where(ae => tentActions.Contains(ae.Action));
        }

        var tentEvents = await tentQuery
            .OrderByDescending(ae => ae.OccurredAt)
            .Take(candidateCount)
            .ToListAsync(cancellationToken);

        var tentIdPattern = $"%{tentId}%";
        var partQuery = _db.AuditEvents
            .AsNoTracking()
            .Where(ae => ae.TargetEntityType == "Part" &&
                         ae.MetadataJson != null &&
                         EF.Functions.Like(ae.MetadataJson, tentIdPattern));

        if (partActions != null)
        {
            partQuery = partQuery.Where(ae => partActions.Contains(ae.Action));
        }

        var partEventCandidates = await partQuery
            .OrderByDescending(ae => ae.OccurredAt)
            .Take(candidateCount)
            .ToListAsync(cancellationToken);

        var matchingPartEvents = partEventCandidates
            .Where(pe => TryGetMetadataTentId(pe.MetadataJson) == tentId)
            .ToList();

        var tagQuery = _db.AuditEvents
            .AsNoTracking()
            .Where(ae => ae.TargetEntityType == "TentTag" && ae.TargetEntityId == tentId);

        if (tagActions != null)
        {
            tagQuery = tagQuery.Where(ae => tagActions.Contains(ae.Action));
        }

        var tagEvents = await tagQuery
            .OrderByDescending(ae => ae.OccurredAt)
            .Take(candidateCount)
            .ToListAsync(cancellationToken);

        var allCandidateEvents = tentEvents.Concat(matchingPartEvents).Concat(tagEvents)
            .OrderByDescending(ae => ae.OccurredAt)
            .ToList();

        var allPartKindIds = allCandidateEvents
            .Select(ae => TryGetMetadataPartKindId(ae.MetadataJson))
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .Distinct()
            .ToList();

        var partKindNames = await _db.PartKinds
            .AsNoTracking()
            .Where(pk => allPartKindIds.Contains(pk.Id))
            .ToDictionaryAsync(pk => pk.Id, pk => pk.Name, cancellationToken);

        return await MapToTentHistoryDtosAsync(allCandidateEvents, partKindNames, category, limit, cancellationToken);
    }

    private static string[]? GetTentHistoryTentActions(TentHistoryCategory? category)
    {
        return category switch
        {
            TentHistoryCategory.TentInfo => new[] { AuditActions.TentCreated, AuditActions.TentUpdated },
            TentHistoryCategory.Archive => new[] { AuditActions.TentArchived, AuditActions.TentUnarchived },
            TentHistoryCategory.PartState => Array.Empty<string>(),
            TentHistoryCategory.PartManagement => Array.Empty<string>(),
            TentHistoryCategory.Tags => Array.Empty<string>(),
            _ => null
        };
    }

    private static string[]? GetTentHistoryPartActions(TentHistoryCategory? category)
    {
        return category switch
        {
            TentHistoryCategory.TentInfo => Array.Empty<string>(),
            TentHistoryCategory.Archive => Array.Empty<string>(),
            TentHistoryCategory.PartState => new[] { AuditActions.PartStateChanged, AuditActions.PartCommentsChanged },
            TentHistoryCategory.PartManagement => new[] { AuditActions.PartAdded, AuditActions.PartDeleted },
            TentHistoryCategory.Tags => Array.Empty<string>(),
            _ => new[] { AuditActions.PartStateChanged, AuditActions.PartCommentsChanged, AuditActions.PartAdded, AuditActions.PartDeleted }
        };
    }

    private static string[]? GetTentHistoryTagActions(TentHistoryCategory? category)
    {
        return category switch
        {
            TentHistoryCategory.TentInfo => Array.Empty<string>(),
            TentHistoryCategory.Archive => Array.Empty<string>(),
            TentHistoryCategory.PartState => Array.Empty<string>(),
            TentHistoryCategory.PartManagement => Array.Empty<string>(),
            TentHistoryCategory.Tags => new[] { AuditActions.TagAssigned, AuditActions.TagRemoved },
            _ => new[] { AuditActions.TagAssigned, AuditActions.TagRemoved }
        };
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
        TentHistoryCategory? categoryFilter,
        int limit,
        CancellationToken cancellationToken)
    {
        var actorIds = events
            .Select(e => e.ActorUserId)
            .Distinct()
            .ToList();

        var displayNameMap = await ResolveActorDisplayNamesBatchAsync(actorIds, cancellationToken);

        var results = new List<TentHistoryItemDto>();

        foreach (var ae in events)
        {
            string? metadataJson = null;

            var item = BuildTentHistoryItem(ae, partKindNames, displayNameMap, out metadataJson);

            if (categoryFilter == null || item.Category == TentHistoryCategoryMapper.ToApiValue(categoryFilter.Value))
            {
                results.Add(item);
            }
        }

        return results.Take(limit).ToList();
    }

    private TentHistoryItemDto BuildTentHistoryItem(
        AuditEvent ae,
        Dictionary<Guid, string> partKindNames,
        Dictionary<Guid, string> displayNameMap,
        out string? metadataJson)
    {
        metadataJson = ae.MetadataJson;
        var actorName = displayNameMap[ae.ActorUserId];

        return ae.Action switch
        {
            AuditActions.TentCreated => BuildTentCreatedItem(ae, actorName),
            AuditActions.TentUpdated => BuildTentUpdatedItem(ae, actorName),
            AuditActions.TentArchived => BuildTentArchivedItem(ae, actorName),
            AuditActions.TentUnarchived => BuildTentUnarchivedItem(ae, actorName),
            AuditActions.PartStateChanged => BuildPartStateChangedItem(ae, actorName, partKindNames),
            AuditActions.PartCommentsChanged => BuildPartCommentsChangedItem(ae, actorName, partKindNames),
            AuditActions.PartAdded => BuildPartAddedItem(ae, actorName, partKindNames),
            AuditActions.PartDeleted => BuildPartDeletedItem(ae, actorName, partKindNames),
            AuditActions.TagAssigned => BuildTagItem(ae, actorName),
            AuditActions.TagRemoved => BuildTagItem(ae, actorName),
            _ => BuildUnknownItem(ae, actorName)
        };
    }

    private static TentHistoryItemDto BuildTentCreatedItem(AuditEvent ae, string actorName)
    {
        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategoryMapper.ToApiValue(TentHistoryCategory.TentInfo),
            ae.OccurredAt, ae.ActorUserId, actorName,
            null, new List<TentHistoryDetailDto>(),
            ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private TentHistoryItemDto BuildTentUpdatedItem(AuditEvent ae, string actorName)
    {
        var details = new List<TentHistoryDetailDto>();
        TryParseMetadata(ae.MetadataJson, out var changedFields, out var oldName, out var newName,
            out var oldSize, out var newSize, out var oldOverallState, out var newOverallState,
            out var commentsChanged, out var oldTentModelName, out var newTentModelName);

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

        if (!string.IsNullOrEmpty(oldTentModelName) && !string.IsNullOrEmpty(newTentModelName) && oldTentModelName != newTentModelName)
        {
            details.Add(new TentHistoryDetailDto("Modèle", oldTentModelName, newTentModelName, null, "old_new"));
        }

        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategoryMapper.ToApiValue(TentHistoryCategory.TentInfo),
            ae.OccurredAt, ae.ActorUserId, actorName,
            null, details, ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private static TentHistoryItemDto BuildTentArchivedItem(AuditEvent ae, string actorName)
    {
        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategoryMapper.ToApiValue(TentHistoryCategory.Archive),
            ae.OccurredAt, ae.ActorUserId, actorName,
            null, new List<TentHistoryDetailDto>(),
            ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private static TentHistoryItemDto BuildTentUnarchivedItem(AuditEvent ae, string actorName)
    {
        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategoryMapper.ToApiValue(TentHistoryCategory.Archive),
            ae.OccurredAt, ae.ActorUserId, actorName,
            null, new List<TentHistoryDetailDto>(),
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

        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategoryMapper.ToApiValue(TentHistoryCategory.PartState),
            ae.OccurredAt, ae.ActorUserId, actorName,
            partName, details, ae.TargetEntityType, ae.TargetEntityId
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
            ae.Id, ae.Action, TentHistoryCategoryMapper.ToApiValue(TentHistoryCategory.PartState),
            ae.OccurredAt, ae.ActorUserId, actorName,
            partName, new List<TentHistoryDetailDto>(),
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
            ae.Id, ae.Action, TentHistoryCategoryMapper.ToApiValue(TentHistoryCategory.PartManagement),
            ae.OccurredAt, ae.ActorUserId, actorName,
            partName, details, ae.TargetEntityType, ae.TargetEntityId
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
            ae.Id, ae.Action, TentHistoryCategoryMapper.ToApiValue(TentHistoryCategory.PartManagement),
            ae.OccurredAt, ae.ActorUserId, actorName,
            partName, new List<TentHistoryDetailDto>(),
            ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private static TentHistoryItemDto BuildUnknownItem(AuditEvent ae, string actorName)
    {
        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategoryMapper.ToApiValue(TentHistoryCategory.Other),
            ae.OccurredAt, ae.ActorUserId, actorName,
            null, new List<TentHistoryDetailDto>(),
            ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private static TentHistoryItemDto BuildTagItem(AuditEvent ae, string actorName)
    {
        var tagName = TryGetMetadataString(ae.MetadataJson, "tagName") ?? "Étiquette inconnue";
        var details = new List<TentHistoryDetailDto>
        {
            new TentHistoryDetailDto("Étiquette", null, null, tagName, "tag")
        };

        return new TentHistoryItemDto(
            ae.Id, ae.Action, TentHistoryCategoryMapper.ToApiValue(TentHistoryCategory.Tags),
            ae.OccurredAt, ae.ActorUserId, actorName,
            tagName, details, ae.TargetEntityType, ae.TargetEntityId
        );
    }

    private static string? TryGetMetadataString(string? metadataJson, string propertyName)
    {
        if (string.IsNullOrWhiteSpace(metadataJson)) return null;

        try
        {
            using var doc = JsonDocument.Parse(metadataJson);
            return doc.RootElement.TryGetProperty(propertyName, out var property) &&
                   property.ValueKind == JsonValueKind.String
                ? property.GetString()
                : null;
        }
        catch
        {
            return null;
        }
    }

    private static void TryParseMetadata(
        string? metadataJson,
        out List<string>? changedFields,
        out string? oldName, out string? newName,
        out int? oldSize, out int? newSize,
        out string? oldOverallState, out string? newOverallState,
        out bool? commentsChanged,
        out string? oldTentModelName, out string? newTentModelName)
    {
        changedFields = null;
        oldName = null; newName = null;
        oldSize = null; newSize = null;
        oldOverallState = null; newOverallState = null;
        commentsChanged = null;
        oldTentModelName = null; newTentModelName = null;

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
            if (root.TryGetProperty("oldTentModelName", out var p8)) oldTentModelName = p8.GetString();
            if (root.TryGetProperty("newTentModelName", out var p9)) newTentModelName = p9.GetString();
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

    private async Task<Dictionary<Guid, string>> ResolveActorDisplayNamesBatchAsync(
        List<Guid> actorIds,
        CancellationToken cancellationToken)
    {
        if (actorIds.Count == 0) return [];

        var users = await _db.Users
            .AsNoTracking()
            .IgnoreQueryFilters()
            .Where(u => actorIds.Contains(u.Id))
            .Select(u => new { u.Id, u.Username })
            .ToListAsync(cancellationToken);

        return users.ToDictionary(u => u.Id, u => ToDisplayName(u.Id, u.Username));
    }

    private static string ToDisplayName(Guid userId, string username) =>
        userId == SystemUserId ? SystemDisplayName : username;
}
