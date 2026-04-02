using System.Text.Json;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Services;

/// <summary>
/// Service for recording audit events with lightweight metadata handling.
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
    /// <param name="metadata">Additional context (optional, simple key-value pairs recommended)</param>
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
/// Implementation of IAuditService that writes audit records to the database.
/// Uses a lightweight approach to metadata: simple top-level denylist only.
/// </summary>
public class AuditService : IAuditService
{
    private readonly ScoutBoxDbContext _db;
    private readonly ILogger<AuditService> _logger;

    // Simple top-level denylist for obvious secret keys
    // This is a lightweight approach - we trust callers to pass safe metadata
    private static readonly HashSet<string> ExcludedTopLevelKeys = new(StringComparer.OrdinalIgnoreCase)
    {
        "token", "password", "authorization", "apikey", "secret", "refreshtoken"
    };

    // Maximum serialized metadata size (16KB) - operational limit, not security
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
        var filteredMetadata = FilterMetadata(metadata);
        var metadataJson = SerializeMetadata(filteredMetadata);

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
        var filteredMetadata = FilterMetadata(metadata);
        var metadataJson = SerializeMetadata(filteredMetadata);

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
    /// Applies simple top-level filtering to metadata.
    /// Only removes top-level keys matching the denylist.
    /// Nested objects are serialized as-is (callers should pass safe metadata).
    /// </summary>
    private Dictionary<string, object?>? FilterMetadata(Dictionary<string, object?>? metadata)
    {
        if (metadata == null || metadata.Count == 0)
        {
            return null;
        }

        var filtered = new Dictionary<string, object?>();

        foreach (var (key, value) in metadata)
        {
            // Skip excluded top-level keys only
            if (ExcludedTopLevelKeys.Contains(key))
            {
                _logger.LogDebug("Audit metadata: excluded key '{Key}'", key);
                continue;
            }

            // Simple value handling - convert primitives, let complex objects serialize via JSON
            filtered[key] = SimplifyValue(value);
        }

        return filtered.Count > 0 ? filtered : null;
    }

    /// <summary>
    /// Simplifies values for serialization.
    /// Primitives and strings pass through, Guids convert to string, DateTime ensures UTC.
    /// Complex objects rely on JSON serializer.
    /// </summary>
    private object? SimplifyValue(object? value)
    {
        if (value == null)
        {
            return null;
        }

        // Pass through primitives and strings
        if (value.GetType().IsPrimitive || value is string || value is decimal)
        {
            return value;
        }

        // Convert Guid to string
        if (value is Guid guid)
        {
            return guid.ToString();
        }

        // Ensure DateTime is UTC
        if (value is DateTime dateTime)
        {
            return dateTime.Kind == DateTimeKind.Utc
                ? dateTime
                : DateTime.SpecifyKind(dateTime, DateTimeKind.Utc);
        }

        // For collections, arrays, and complex objects, let JSON serializer handle them
        // Callers are responsible for not passing sensitive nested data
        return value;
    }

    /// <summary>
    /// Serializes metadata to JSON with size limit.
    /// Size limit is operational (performance), not a security control.
    /// </summary>
    private string? SerializeMetadata(Dictionary<string, object?>? metadata)
    {
        if (metadata == null || metadata.Count == 0)
        {
            return null;
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
                return truncated;
            }

            return json;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to serialize audit metadata");
            return null;
        }
    }
}
