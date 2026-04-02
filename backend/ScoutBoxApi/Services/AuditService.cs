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

    // Sensitive field patterns that should be excluded from metadata
    private static readonly HashSet<string> SensitiveFieldPatterns = new(StringComparer.OrdinalIgnoreCase)
    {
        "token", "refreshtoken", "password", "authorization", "apikey", "secret",
        "credential", "authheader", "bearer", "accesstoken", "idtoken"
    };

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
        var metadataJson = sanitizedMetadata != null
            ? JsonSerializer.Serialize(sanitizedMetadata)
            : null;

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
        var metadataJson = sanitizedMetadata != null
            ? JsonSerializer.Serialize(sanitizedMetadata)
            : null;

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
    /// Sanitizes metadata to remove sensitive data before persistence.
    /// </summary>
    private Dictionary<string, object?>? SanitizeMetadata(Dictionary<string, object?>? metadata)
    {
        if (metadata == null || metadata.Count == 0)
        {
            return null;
        }

        var sanitized = new Dictionary<string, object?>();

        foreach (var (key, value) in metadata)
        {
            // Skip any keys that match sensitive patterns
            if (IsSensitiveField(key))
            {
                _logger.LogDebug("Sanitizing audit metadata: excluded sensitive field '{Key}'", key);
                continue;
            }

            // Also check string values for potential tokens/secrets
            if (value is string stringValue && ContainsSensitivePattern(stringValue))
            {
                _logger.LogDebug("Sanitizing audit metadata: excluded sensitive value in '{Key}'", key);
                continue;
            }

            sanitized[key] = value;
        }

        return sanitized.Count > 0 ? sanitized : null;
    }

    private bool IsSensitiveField(string fieldName)
    {
        var normalized = fieldName.Replace("_", "").Replace("-", "").ToLowerInvariant();
        return SensitiveFieldPatterns.Any(pattern =>
            normalized.Contains(pattern, StringComparison.OrdinalIgnoreCase));
    }

    private bool ContainsSensitivePattern(string value)
    {
        // Check for patterns that look like tokens (long base64 strings, bearer tokens, etc.)
        if (value.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase) ||
            value.StartsWith("Basic ", StringComparison.OrdinalIgnoreCase))
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
}
