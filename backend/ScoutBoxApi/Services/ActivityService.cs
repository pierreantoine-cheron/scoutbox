using System.Text;
using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Services;

public enum ActivityCategory
{
    All,
    Tents,
    Parts,
    Tags,
    Models,
    Accounts
}

public static class ActivityCategoryMapper
{
    private static readonly string[] TentActions =
    [
        AuditActions.TentCreated,
        AuditActions.TentUpdated,
        AuditActions.TentArchived,
        AuditActions.TentUnarchived
    ];

    private static readonly string[] PartActions =
    [
        AuditActions.PartStateChanged,
        AuditActions.PartCommentsChanged,
        AuditActions.PartAdded,
        AuditActions.PartDeleted
    ];

    private static readonly string[] TagActions =
    [
        AuditActions.TagCreated,
        AuditActions.TagRenamed,
        AuditActions.TagColorChanged,
        AuditActions.TagDeleted,
        AuditActions.TagAssigned,
        AuditActions.TagRemoved
    ];

    private static readonly string[] ModelActions =
    [
        AuditActions.TentModelCreated,
        AuditActions.TentModelRenamed,
        AuditActions.TentModelDeleted
    ];

    private static readonly string[] AccountActions =
    [
        AuditActions.UserRegisteredFromInvite,
        AuditActions.InviteCreated
    ];

    /// <summary>
    /// Actions that are never part of the activity journal, whatever the filter.
    /// </summary>
    public static readonly string[] ExcludedActions =
    [
        AuditActions.UserLoginSucceeded,
        AuditActions.UserRefreshTokenRotated,
        AuditActions.UserLogoutSucceeded
    ];

    public static bool TryParse(string? value, out ActivityCategory category)
    {
        category = value switch
        {
            null or "" or "all" => ActivityCategory.All,
            "tents" => ActivityCategory.Tents,
            "parts" => ActivityCategory.Parts,
            "tags" => ActivityCategory.Tags,
            "models" => ActivityCategory.Models,
            "accounts" => ActivityCategory.Accounts,
            _ => (ActivityCategory)(-1)
        };

        return category != (ActivityCategory)(-1);
    }

    public static string ToApiValue(ActivityCategory category)
    {
        return category switch
        {
            ActivityCategory.Tents => "tents",
            ActivityCategory.Parts => "parts",
            ActivityCategory.Tags => "tags",
            ActivityCategory.Models => "models",
            ActivityCategory.Accounts => "accounts",
            _ => "all"
        };
    }

    public static string[]? ActionsFor(ActivityCategory category)
    {
        return category switch
        {
            ActivityCategory.Tents => TentActions,
            ActivityCategory.Parts => PartActions,
            ActivityCategory.Tags => TagActions,
            ActivityCategory.Models => ModelActions,
            ActivityCategory.Accounts => AccountActions,
            _ => null
        };
    }

    public static string ToApiValueForAction(string action)
    {
        if (TentActions.Contains(action)) return "tents";
        if (PartActions.Contains(action)) return "parts";
        if (TagActions.Contains(action)) return "tags";
        if (ModelActions.Contains(action)) return "models";
        if (AccountActions.Contains(action)) return "accounts";
        return "other";
    }
}

public static class ActivityWindow
{
    public static bool TryParse(string? value, out int? days)
    {
        switch (value)
        {
            case null:
            case "":
            case "30":
                days = 30;
                return true;
            case "7":
                days = 7;
                return true;
            case "90":
                days = 90;
                return true;
            case "all":
                days = null;
                return true;
            default:
                days = null;
                return false;
        }
    }
}

public readonly record struct ActivityCursor(DateTime OccurredAt, Guid Id)
{
    public string Encode() =>
        Convert.ToBase64String(Encoding.UTF8.GetBytes($"{OccurredAt.Ticks}:{Id:N}"));

    public static bool TryParse(string? value, out ActivityCursor? cursor)
    {
        cursor = null;
        if (string.IsNullOrWhiteSpace(value)) return false;

        string decoded;
        try
        {
            decoded = Encoding.UTF8.GetString(Convert.FromBase64String(value));
        }
        catch
        {
            return false;
        }

        var parts = decoded.Split(':');
        if (parts.Length != 2) return false;
        if (!long.TryParse(parts[0], out var ticks)) return false;
        if (!Guid.TryParseExact(parts[1], "N", out var id)) return false;

        try
        {
            cursor = new ActivityCursor(
                DateTime.SpecifyKind(new DateTime(ticks, DateTimeKind.Utc), DateTimeKind.Utc),
                id);
            return true;
        }
        catch (ArgumentOutOfRangeException)
        {
            return false;
        }
    }
}

/// <summary>
/// Read-only projection of audit events across all tents for the activity journal.
/// Detail construction is deliberately separate from the per-tent history pipeline.
/// </summary>
public interface IActivityService
{
    Task<ActivityPageDto> GetActivityAsync(
        ActivityCategory category,
        int? windowDays,
        ActivityCursor? cursor,
        int limit,
        CancellationToken cancellationToken = default);
}

public class ActivityService : IActivityService
{
    private const string SystemDisplayName = "Système";
    private const string DeletedTentName = "Tente supprimée";
    private const string UnknownPartName = "Pièce inconnue";
    private const string UnknownTagName = "Étiquette inconnue";
    private const string UnknownModelName = "Modèle inconnu";
    private const string UnknownActorName = "Utilisateur inconnu";

    private static readonly Guid SystemUserId = Guid.Parse("00000000-0000-0000-0000-000000000001");

    private readonly ScoutBoxDbContext _db;

    public ActivityService(ScoutBoxDbContext db)
    {
        _db = db;
    }

    public async Task<ActivityPageDto> GetActivityAsync(
        ActivityCategory category,
        int? windowDays,
        ActivityCursor? cursor,
        int limit,
        CancellationToken cancellationToken = default)
    {
        var query = _db.AuditEvents
            .AsNoTracking()
            .Where(ae => !ActivityCategoryMapper.ExcludedActions.Contains(ae.Action));

        var actions = ActivityCategoryMapper.ActionsFor(category);
        if (actions != null)
        {
            query = query.Where(ae => actions.Contains(ae.Action));
        }

        if (windowDays.HasValue)
        {
            var since = DateTime.UtcNow.AddDays(-windowDays.Value);
            query = query.Where(ae => ae.OccurredAt >= since);
        }

        if (cursor.HasValue)
        {
            var after = cursor.Value;
            query = query.Where(ae =>
                ae.OccurredAt < after.OccurredAt ||
                (ae.OccurredAt == after.OccurredAt && ae.Id < after.Id));
        }

        var events = await query
            .OrderByDescending(ae => ae.OccurredAt)
            .ThenByDescending(ae => ae.Id)
            .Take(limit + 1)
            .ToListAsync(cancellationToken);

        var hasMore = events.Count > limit;
        var pageEvents = hasMore ? events.Take(limit).ToList() : events;

        var items = await MapToItemsAsync(pageEvents, cancellationToken);
        var nextCursor = hasMore && pageEvents.Count > 0
            ? new ActivityCursor(pageEvents[^1].OccurredAt, pageEvents[^1].Id).Encode()
            : null;

        return new ActivityPageDto(items, nextCursor);
    }

    private async Task<List<ActivityItemDto>> MapToItemsAsync(
        List<AuditEvent> events,
        CancellationToken cancellationToken)
    {
        if (events.Count == 0) return [];

        var actorNames = await ResolveActorDisplayNamesAsync(
            events.Select(e => e.ActorUserId).Distinct().ToList(),
            cancellationToken);

        var partKindIds = events
            .Select(e => TryGetMetadataGuid(e.MetadataJson, "partKindId"))
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .Distinct()
            .ToList();

        var partKindNames = partKindIds.Count == 0
            ? new Dictionary<Guid, string>()
            : await _db.PartKinds
                .AsNoTracking()
                .Where(pk => partKindIds.Contains(pk.Id))
                .ToDictionaryAsync(pk => pk.Id, pk => pk.Name, cancellationToken);

        var tentIds = events
            .Select(TryGetTentId)
            .Where(id => id.HasValue)
            .Select(id => id!.Value)
            .Distinct()
            .ToList();

        var tentNames = tentIds.Count == 0
            ? new Dictionary<Guid, string>()
            : await _db.Tents
                .AsNoTracking()
                .Where(t => tentIds.Contains(t.Id))
                .ToDictionaryAsync(t => t.Id, t => t.Name, cancellationToken);

        return events
            .Select(e => BuildItem(e, actorNames, partKindNames, tentNames))
            .ToList();
    }

    private static ActivityItemDto BuildItem(
        AuditEvent ae,
        Dictionary<Guid, string> actorNames,
        Dictionary<Guid, string> partKindNames,
        Dictionary<Guid, string> tentNames)
    {
        var actorName = actorNames.TryGetValue(ae.ActorUserId, out var name)
            ? name
            : UnknownActorName;

        var tentId = TryGetTentId(ae);
        var tentName = ResolveTentName(ae, tentId, tentNames);
        var subjectName = ResolveSubjectName(ae, partKindNames);
        var details = BuildDetails(ae, partKindNames);

        return new ActivityItemDto(
            ae.Id,
            ae.Action,
            ActivityCategoryMapper.ToApiValueForAction(ae.Action),
            ae.OccurredAt,
            ae.ActorUserId,
            actorName,
            tentId,
            tentName,
            subjectName,
            details);
    }

    private static Guid? TryGetTentId(AuditEvent ae)
    {
        return ae.TargetEntityType switch
        {
            "Tent" => ae.TargetEntityId,
            "TentTag" => ae.TargetEntityId,
            "Part" => TryGetMetadataGuid(ae.MetadataJson, "tentId"),
            _ => null
        };
    }

    private static string? ResolveTentName(
        AuditEvent ae,
        Guid? tentId,
        Dictionary<Guid, string> tentNames)
    {
        if (!tentId.HasValue) return null;

        if (tentNames.TryGetValue(tentId.Value, out var name))
        {
            return name;
        }

        return TryGetMetadataString(ae.MetadataJson, "tentName")
            ?? TryGetMetadataString(ae.MetadataJson, "newName")
            ?? TryGetMetadataString(ae.MetadataJson, "name")
            ?? DeletedTentName;
    }

    private static string? ResolveSubjectName(
        AuditEvent ae,
        Dictionary<Guid, string> partKindNames)
    {
        return ae.Action switch
        {
            AuditActions.PartStateChanged or
            AuditActions.PartCommentsChanged or
            AuditActions.PartAdded or
            AuditActions.PartDeleted => ResolvePartName(ae, partKindNames),
            AuditActions.TagAssigned or AuditActions.TagRemoved =>
                TryGetMetadataString(ae.MetadataJson, "tagName") ?? UnknownTagName,
            AuditActions.TagCreated or AuditActions.TagRenamed or AuditActions.TagDeleted =>
                TryGetMetadataString(ae.MetadataJson, "name") ?? UnknownTagName,
            AuditActions.TagColorChanged =>
                TryGetMetadataString(ae.MetadataJson, "name") ?? UnknownTagName,
            AuditActions.TentModelCreated or
            AuditActions.TentModelRenamed or
            AuditActions.TentModelDeleted =>
                TryGetMetadataString(ae.MetadataJson, "name") ?? UnknownModelName,
            AuditActions.InviteCreated =>
                TryGetMetadataString(ae.MetadataJson, "code") ?? "Invitation",
            AuditActions.UserRegisteredFromInvite =>
                TryGetMetadataString(ae.MetadataJson, "username") ?? "Compte",
            _ => null
        };
    }

    private static string ResolvePartName(
        AuditEvent ae,
        Dictionary<Guid, string> partKindNames)
    {
        var partKindId = TryGetMetadataGuid(ae.MetadataJson, "partKindId");
        return partKindId.HasValue && partKindNames.TryGetValue(partKindId.Value, out var name)
            ? name
            : UnknownPartName;
    }

    private static List<TentHistoryDetailDto> BuildDetails(
        AuditEvent ae,
        Dictionary<Guid, string> partKindNames)
    {
        return ae.Action switch
        {
            AuditActions.TentUpdated => BuildTentUpdatedDetails(ae),
            AuditActions.PartStateChanged => BuildPartStateChangedDetails(ae),
            AuditActions.PartAdded => [new TentHistoryDetailDto("État", null, null, "Bon état", "initial_state")],
            AuditActions.TagAssigned or AuditActions.TagRemoved => BuildTagDetails(ae),
            AuditActions.TagCreated or AuditActions.TagRenamed or AuditActions.TagDeleted =>
                BuildCatalogueDetails(ae, "Étiquette", "tag"),
            AuditActions.TagColorChanged => BuildTagColorDetails(ae),
            AuditActions.TentModelCreated or
            AuditActions.TentModelRenamed or
            AuditActions.TentModelDeleted =>
                BuildCatalogueDetails(ae, "Modèle", "model"),
            _ => []
        };
    }

    private static List<TentHistoryDetailDto> BuildTentUpdatedDetails(AuditEvent ae)
    {
        var details = new List<TentHistoryDetailDto>();

        var oldName = TryGetMetadataString(ae.MetadataJson, "oldName");
        var newName = TryGetMetadataString(ae.MetadataJson, "newName");
        if (!string.IsNullOrEmpty(oldName) && !string.IsNullOrEmpty(newName) && oldName != newName)
        {
            details.Add(new TentHistoryDetailDto("Nom", oldName, newName, null, "old_new"));
        }

        var oldSize = TryGetMetadataInt(ae.MetadataJson, "oldSize");
        var newSize = TryGetMetadataInt(ae.MetadataJson, "newSize");
        if (oldSize.HasValue && newSize.HasValue && oldSize != newSize)
        {
            details.Add(new TentHistoryDetailDto("Taille", oldSize.ToString(), newSize.ToString(), null, "old_new"));
        }

        var oldState = TryGetMetadataString(ae.MetadataJson, "oldOverallState");
        var newState = TryGetMetadataString(ae.MetadataJson, "newOverallState");
        if (!string.IsNullOrEmpty(oldState) && !string.IsNullOrEmpty(newState) && oldState != newState)
        {
            details.Add(new TentHistoryDetailDto("État", oldState, newState, null, "state"));
        }

        if (TryGetMetadataBool(ae.MetadataJson, "commentsChanged") == true)
        {
            details.Add(new TentHistoryDetailDto("Commentaire", null, null, "Commentaire modifié", "flag"));
        }

        var oldModelName = TryGetMetadataString(ae.MetadataJson, "oldTentModelName");
        var newModelName = TryGetMetadataString(ae.MetadataJson, "newTentModelName");
        if (!string.IsNullOrEmpty(oldModelName) && !string.IsNullOrEmpty(newModelName) && oldModelName != newModelName)
        {
            details.Add(new TentHistoryDetailDto("Modèle", oldModelName, newModelName, null, "old_new"));
        }

        return details;
    }

    private static List<TentHistoryDetailDto> BuildPartStateChangedDetails(AuditEvent ae)
    {
        var oldState = TryGetMetadataString(ae.MetadataJson, "oldState");
        var newState = TryGetMetadataString(ae.MetadataJson, "newState");

        return string.IsNullOrEmpty(oldState) && string.IsNullOrEmpty(newState)
            ? []
            : [new TentHistoryDetailDto("État", oldState, newState, null, "state")];
    }

    private static List<TentHistoryDetailDto> BuildTagDetails(AuditEvent ae)
    {
        var tagName = TryGetMetadataString(ae.MetadataJson, "tagName") ?? UnknownTagName;
        return [new TentHistoryDetailDto("Étiquette", null, null, tagName, "tag")];
    }

    private static List<TentHistoryDetailDto> BuildCatalogueDetails(
        AuditEvent ae,
        string label,
        string valueType)
    {
        var oldName = TryGetMetadataString(ae.MetadataJson, "oldName");
        var newName = TryGetMetadataString(ae.MetadataJson, "newName");
        if (!string.IsNullOrEmpty(oldName) && !string.IsNullOrEmpty(newName) && oldName != newName)
        {
            return [new TentHistoryDetailDto(label, oldName, newName, null, "old_new")];
        }

        var name = TryGetMetadataString(ae.MetadataJson, "name");
        return name == null
            ? []
            : [new TentHistoryDetailDto(label, null, null, name, valueType)];
    }

    private static List<TentHistoryDetailDto> BuildTagColorDetails(AuditEvent ae)
    {
        var oldColor = TryGetMetadataString(ae.MetadataJson, "oldColor");
        var newColor = TryGetMetadataString(ae.MetadataJson, "newColor");

        return oldColor == null && newColor == null
            ? []
            : [new TentHistoryDetailDto("Couleur", oldColor, newColor, null, "color")];
    }

    private async Task<Dictionary<Guid, string>> ResolveActorDisplayNamesAsync(
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

        return users.ToDictionary(
            u => u.Id,
            u => u.Id == SystemUserId ? SystemDisplayName : u.Username);
    }

    private static Guid? TryGetMetadataGuid(string? metadataJson, string propertyName)
    {
        if (string.IsNullOrWhiteSpace(metadataJson)) return null;

        try
        {
            using var doc = JsonDocument.Parse(metadataJson);
            return doc.RootElement.TryGetProperty(propertyName, out var property) &&
                   property.ValueKind == JsonValueKind.String &&
                   Guid.TryParse(property.GetString(), out var value)
                ? value
                : null;
        }
        catch
        {
            return null;
        }
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

    private static int? TryGetMetadataInt(string? metadataJson, string propertyName)
    {
        if (string.IsNullOrWhiteSpace(metadataJson)) return null;

        try
        {
            using var doc = JsonDocument.Parse(metadataJson);
            return doc.RootElement.TryGetProperty(propertyName, out var property) &&
                   property.ValueKind == JsonValueKind.Number &&
                   property.TryGetInt32(out var value)
                ? value
                : null;
        }
        catch
        {
            return null;
        }
    }

    private static bool? TryGetMetadataBool(string? metadataJson, string propertyName)
    {
        if (string.IsNullOrWhiteSpace(metadataJson)) return null;

        try
        {
            using var doc = JsonDocument.Parse(metadataJson);
            return doc.RootElement.TryGetProperty(propertyName, out var property) &&
                   (property.ValueKind == JsonValueKind.True || property.ValueKind == JsonValueKind.False)
                ? property.GetBoolean()
                : null;
        }
        catch
        {
            return null;
        }
    }
}
