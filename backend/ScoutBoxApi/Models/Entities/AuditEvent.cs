namespace ScoutBoxApi.Models.Entities;

/// <summary>
/// Audit event record capturing user actions for accountability and history.
/// All timestamps are stored in UTC.
/// </summary>
public class AuditEvent
{
    public Guid Id { get; set; }

    /// <summary>
    /// Machine-readable action type (e.g., "invite_created", "user_login_succeeded").
    /// Use AuditActions constants for consistency.
    /// </summary>
    public string Action { get; set; } = string.Empty;

    /// <summary>
    /// The user who performed the action. Null for system-generated events or if user was deleted.
    /// FK to Users table with SetNull behavior to preserve history.
    /// </summary>
    public Guid? ActorUserId { get; set; }

    /// <summary>
    /// UTC timestamp when the action occurred.
    /// </summary>
    public DateTime OccurredAt { get; set; }

    /// <summary>
    /// Type of the target entity affected (e.g., "Invite", "User", "Tent", "Part").
    /// </summary>
    public string? TargetEntityType { get; set; }

    /// <summary>
    /// ID of the target entity affected, if applicable.
    /// </summary>
    public Guid? TargetEntityId { get; set; }

    /// <summary>
    /// JSON-encoded metadata about the action.
    /// Optional context for troubleshooting and reporting.
    /// Callers should avoid passing sensitive values (tokens, passwords) in metadata.
    /// </summary>
    public string? MetadataJson { get; set; }

    // Navigation property
    public User? Actor { get; set; }
}
