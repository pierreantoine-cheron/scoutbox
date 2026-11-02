using System.Text.Json;
using ScoutBoxApi.Models.DTOs;

namespace ScoutBoxApi.Services;

/// <summary>
/// Builds the audit details shared by the activity journal and the per-tent history.
/// Label, value type and fallbacks live here so every caller speaks the same language.
/// </summary>
public static class AuditDetailFactory
{
    public const string UnknownPartName = "Pièce inconnue";

    public static TentHistoryDetailDto? Reason(string? reason)
    {
        return string.IsNullOrEmpty(reason)
            ? null
            : new TentHistoryDetailDto("Raison", null, null, reason, "reason");
    }

    /// <summary>
    /// Resolves a part's kind name, preferring the name frozen on the event and
    /// falling back to the live lookup, then to the unknown-part label.
    /// </summary>
    public static string ResolvePartName(
        string? metadataJson,
        IReadOnlyDictionary<Guid, string> partKindNames)
    {
        var frozenName = TryGetMetadataString(metadataJson, "partKindName");
        if (!string.IsNullOrEmpty(frozenName)) return frozenName;

        var partKindId = TryGetMetadataGuid(metadataJson, "partKindId");
        return partKindId.HasValue && partKindNames.TryGetValue(partKindId.Value, out var name)
            ? name
            : UnknownPartName;
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
}
