using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
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
