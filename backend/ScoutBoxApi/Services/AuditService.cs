using System.Collections;
using System.Text.Json;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Services;

/// <summary>
/// Service for recording immutable audit events with sanitized metadata.
/// </summary>
public interface IAuditService
{
    /// <summary>
    /// Records an audit event synchronously (for use within transactions).
    /// </summary>
    /// <param name="action">The action type from AuditActions constants</param>
    /// <param name="actorUserId">The user who performed the action (null for system)</param>
    /// <param name="targetEntityType">Type of affected entity (e.g., "Invite", "User")</param>
    /// <param name="targetEntityId">ID of affected entity</param>
    /// <param name="metadata">Additional context (will be sanitized to remove secrets)</param>
    /// <returns>The created audit event</returns>
    AuditEvent RecordEvent(
        string action,
        Guid? actorUserId,
        string? targetEntityType = null,
        Guid? targetEntityId = null,
        Dictionary<string, object?>? metadata = null);

    /// <summary>
    /// Records an audit event asynchronously (for standalone operations outside transactions).
    /// </summary>
    Task<AuditEvent> RecordEventAsync(
        string action,
        Guid? actorUserId,
        string? targetEntityType = null,
        Guid? targetEntityId = null,
        Dictionary<string, object?>? metadata = null,
        CancellationToken cancellationToken = default);
}

/// <summary>
/// Implementation of IAuditService that writes sanitized audit records to the database.
/// </summary>
public class AuditService : IAuditService
{
    private readonly ScoutBoxDbContext _db;
    private readonly ILogger<AuditService> _logger;

    // Sensitive field patterns that should be excluded from metadata at any nesting level
    private static readonly HashSet<string> SensitiveFieldPatterns = new(StringComparer.OrdinalIgnoreCase)
    {
        "token", "refreshtoken", "password", "authorization", "apikey", "secret",
        "credential", "authheader", "bearer", "accesstoken", "idtoken",
        "jwt", "cookie", "session", "sessionid", "auth", "authentication",
        "privatekey", "api_secret", "clientsecret", "client_secret"
    };

    // Maximum recursion depth to prevent stack overflow attacks
    private const int MaxSanitizationDepth = 8;

    // Maximum serialized metadata size (16KB) to prevent oversized payloads
    private const int MaxMetadataSizeBytes = 16 * 1024;

    public AuditService(ScoutBoxDbContext db, ILogger<AuditService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public AuditEvent RecordEvent(
        string action,
        Guid? actorUserId,
        string? targetEntityType = null,
        Guid? targetEntityId = null,
        Dictionary<string, object?>? metadata = null)
    {
        var sanitizedMetadata = SanitizeMetadata(metadata);
        var (metadataJson, wasTruncated) = SerializeMetadataWithSizeLimit(sanitizedMetadata);

        if (wasTruncated)
        {
            _logger.LogWarning(
                "Audit event metadata truncated due to size limit: {Action} by user {ActorUserId}",
                action, actorUserId);
        }

        var auditEvent = new AuditEvent
        {
            Id = Guid.NewGuid(),
            Action = action,
            ActorUserId = actorUserId,
            OccurredAt = DateTime.UtcNow,
            TargetEntityType = targetEntityType,
            TargetEntityId = targetEntityId,
            MetadataJson = metadataJson
        };

        _db.AuditEvents.Add(auditEvent);

        _logger.LogDebug(
            "Audit event recorded: {Action} by user {ActorUserId} on {TargetEntityType}:{TargetEntityId}",
            action, actorUserId, targetEntityType, targetEntityId);

        return auditEvent;
    }

    public async Task<AuditEvent> RecordEventAsync(
        string action,
        Guid? actorUserId,
        string? targetEntityType = null,
        Guid? targetEntityId = null,
        Dictionary<string, object?>? metadata = null,
        CancellationToken cancellationToken = default)
    {
        var sanitizedMetadata = SanitizeMetadata(metadata);
        var (metadataJson, wasTruncated) = SerializeMetadataWithSizeLimit(sanitizedMetadata);

        if (wasTruncated)
        {
            _logger.LogWarning(
                "Audit event metadata truncated due to size limit: {Action} by user {ActorUserId}",
                action, actorUserId);
        }

        var auditEvent = new AuditEvent
        {
            Id = Guid.NewGuid(),
            Action = action,
            ActorUserId = actorUserId,
            OccurredAt = DateTime.UtcNow,
            TargetEntityType = targetEntityType,
            TargetEntityId = targetEntityId,
            MetadataJson = metadataJson
        };

        _db.AuditEvents.Add(auditEvent);
        await _db.SaveChangesAsync(cancellationToken);

        _logger.LogDebug(
            "Audit event recorded asynchronously: {Action} by user {ActorUserId} on {TargetEntityType}:{TargetEntityId}",
            action, actorUserId, targetEntityType, targetEntityId);

        return auditEvent;
    }

    /// <summary>
    /// Sanitizes metadata recursively to remove sensitive data at any nesting level.
    /// </summary>
    private Dictionary<string, object?>? SanitizeMetadata(Dictionary<string, object?>? metadata)
    {
        if (metadata == null || metadata.Count == 0)
        {
            return null;
        }

        var sanitized = SanitizeObject(metadata, 0) as Dictionary<string, object?>;
        return sanitized?.Count > 0 ? sanitized : null;
    }

    /// <summary>
    /// Recursively sanitizes an object, handling dictionaries, lists, and primitive values.
    /// </summary>
    private object? SanitizeObject(object? value, int depth)
    {
        // Guard against excessive recursion depth
        if (depth >= MaxSanitizationDepth)
        {
            _logger.LogDebug("Audit metadata sanitization: max depth {Depth} reached, truncating", MaxSanitizationDepth);
            return "[MAX_DEPTH_REACHED]";
        }

        if (value == null)
        {
            return null;
        }

        // Handle dictionaries (including our metadata type)
        if (value is Dictionary<string, object?> dict)
        {
            return SanitizeDictionary(dict, depth);
        }

        // Handle IDictionary (non-generic dictionary interface)
        if (value is IDictionary nonGenericDict)
        {
            return SanitizeNonGenericDictionary(nonGenericDict, depth);
        }

        // Handle lists and arrays
        if (value is IEnumerable enumerable && value is not string)
        {
            return SanitizeEnumerable(enumerable, depth);
        }

        // Handle strings - check for sensitive patterns
        if (value is string stringValue)
        {
            return SanitizeString(stringValue);
        }

        // Handle Guid - convert to string for serialization compatibility
        if (value is Guid guid)
        {
            return guid.ToString();
        }

        // Handle DateTime - ensure UTC
        if (value is DateTime dateTime)
        {
            return dateTime.Kind == DateTimeKind.Utc
                ? dateTime
                : DateTime.SpecifyKind(dateTime, DateTimeKind.Utc);
        }

        // For other primitive types (numbers, booleans), return as-is
        if (value.GetType().IsPrimitive || value is decimal)
        {
            return value;
        }

        // For complex objects, attempt to convert to dictionary via reflection
        // This handles anonymous types and simple POCOs
        try
        {
            var properties = value.GetType().GetProperties()
                .Where(p => p.CanRead)
                .ToDictionary(
                    p => p.Name,
                    p => p.GetValue(value));

            return SanitizeDictionary(properties, depth);
        }
        catch
        {
            // If we can't process the object, return its string representation
            // but sanitize it first
            return SanitizeString(value.ToString() ?? "");
        }
    }

    private Dictionary<string, object?> SanitizeDictionary(Dictionary<string, object?> dict, int depth)
    {
        var sanitized = new Dictionary<string, object?>();

        foreach (var (key, val) in dict)
        {
            // Check if key contains sensitive patterns
            if (IsSensitiveField(key))
            {
                _logger.LogDebug("Sanitizing audit metadata: excluded sensitive field '{Key}' at depth {Depth}", key, depth);
                continue;
            }

            // Recursively sanitize the value
            var sanitizedValue = SanitizeObject(val, depth + 1);
            sanitized[key] = sanitizedValue;
        }

        return sanitized;
    }

    private Dictionary<string, object?> SanitizeNonGenericDictionary(IDictionary dict, int depth)
    {
        var sanitized = new Dictionary<string, object?>();

        foreach (var key in dict.Keys)
        {
            var keyString = key?.ToString() ?? "";

            // Check if key contains sensitive patterns
            if (IsSensitiveField(keyString))
            {
                _logger.LogDebug("Sanitizing audit metadata: excluded sensitive field '{Key}' at depth {Depth}", keyString, depth);
                continue;
            }

            // Recursively sanitize the value
            var value = key != null ? dict[key] : null;
            var sanitizedValue = SanitizeObject(value, depth + 1);
            sanitized[keyString] = sanitizedValue;
        }

        return sanitized;
    }

    private List<object?> SanitizeEnumerable(IEnumerable enumerable, int depth)
    {
        var sanitized = new List<object?>();

        foreach (var item in enumerable)
        {
            sanitized.Add(SanitizeObject(item, depth + 1));
        }

        return sanitized;
    }

    private string? SanitizeString(string value)
    {
        if (string.IsNullOrEmpty(value))
        {
            return value;
        }

        // Check for patterns that look like tokens (long base64 strings, bearer tokens, etc.)
        if (ContainsSensitivePattern(value))
        {
            _logger.LogDebug("Sanitizing audit metadata: excluded sensitive value pattern");
            return null; // Remove entirely
        }

        return value;
    }

    private bool IsSensitiveField(string fieldName)
    {
        var normalized = fieldName.Replace("_", "").Replace("-", "").ToLowerInvariant();
        return SensitiveFieldPatterns.Any(pattern =>
            normalized.Contains(pattern, StringComparison.OrdinalIgnoreCase));
    }

    private bool ContainsSensitivePattern(string value)
    {
        // Check for patterns that look like tokens
        if (value.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) ||
            value.StartsWith("Basic ", StringComparison.OrdinalIgnoreCase) ||
            value.StartsWith("Token ", StringComparison.OrdinalIgnoreCase))
        {
            return true;
        }

        // Check for long base64 strings that could be tokens (typical JWT length is >100 chars)
        if (value.Length > 100 && IsBase64String(value))
        {
            return true;
        }

        return false;
    }

    private bool IsBase64String(string value)
    {
        // Quick check for base64 characteristics
        if (string.IsNullOrEmpty(value) || value.Length % 4 != 0)
        {
            return false;
        }

        // Check for valid base64 characters
        foreach (var c in value)
        {
            if (!char.IsLetterOrDigit(c) && c != '+' && c != '/' && c != '=')
            {
                return false;
            }
        }

        return true;
    }

    /// <summary>
    /// Serializes metadata with size limit enforcement.
    /// Returns the JSON string and a flag indicating if truncation occurred.
    /// </summary>
    private (string? Json, bool WasTruncated) SerializeMetadataWithSizeLimit(Dictionary<string, object?>? metadata)
    {
        if (metadata == null || metadata.Count == 0)
        {
            return (null, false);
        }

        try
        {
            var json = JsonSerializer.Serialize(metadata);

            if (json.Length > MaxMetadataSizeBytes)
            {
                _logger.LogWarning(
                    "Audit metadata exceeds size limit ({Size} > {Limit} bytes), truncating",
                    json.Length, MaxMetadataSizeBytes);

                // Truncate and add marker
                var truncated = json.Substring(0, MaxMetadataSizeBytes - 50) + "...[TRUNCATED]";
                return (truncated, true);
            }

            return (json, false);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to serialize audit metadata");
            return (null, false);
        }
    }
}
