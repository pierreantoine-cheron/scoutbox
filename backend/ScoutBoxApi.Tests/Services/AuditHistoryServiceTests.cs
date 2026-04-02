using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Services;
using Xunit;

namespace ScoutBoxApi.Tests.Services;

public class AuditHistoryServiceTests : IDisposable
{
    private readonly ScoutBoxDbContext _db;
    private readonly AuditHistoryService _service;
    private readonly Mock<ILogger<AuditHistoryService>> _loggerMock;

    public AuditHistoryServiceTests()
    {
        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _db = new ScoutBoxDbContext(options);
        _loggerMock = new Mock<ILogger<AuditHistoryService>>();
        _service = new AuditHistoryService(_db, _loggerMock.Object);
    }

    public void Dispose()
    {
        _db.Dispose();
    }

    [Fact]
    public async Task ResolveActorDisplayName_WithActiveUser_ReturnsUsername()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "activeuser",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow,
            IsDeleted = false
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        var displayName = await _service.ResolveActorDisplayNameAsync(user.Id);

        Assert.Equal("activeuser", displayName);
    }

    [Fact]
    public async Task ResolveActorDisplayName_WithSoftDeletedUser_ReturnsUtilisateurSupprime()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "deleteduser",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow,
            IsDeleted = true,
            DeletedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        var displayName = await _service.ResolveActorDisplayNameAsync(user.Id);

        Assert.Equal("Utilisateur supprimé", displayName);
    }

    [Fact]
    public async Task ResolveActorDisplayName_WithMissingUser_ReturnsUtilisateurSupprime()
    {
        var nonExistentUserId = Guid.NewGuid();

        var displayName = await _service.ResolveActorDisplayNameAsync(nonExistentUserId);

        Assert.Equal("Utilisateur supprimé", displayName);
    }

    [Fact]
    public async Task ResolveActorDisplayName_WithNullUserId_ReturnsUtilisateurSupprime()
    {
        var displayName = await _service.ResolveActorDisplayNameAsync(null);

        Assert.Equal("Utilisateur supprimé", displayName);
    }

    [Fact]
    public async Task GetAuditHistory_ReturnsEventsWithResolvedDisplayNames()
    {
        var activeUser = new User
        {
            Id = Guid.NewGuid(),
            Username = "activeuser",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow,
            IsDeleted = false
        };

        var deletedUser = new User
        {
            Id = Guid.NewGuid(),
            Username = "deleteduser",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow,
            IsDeleted = true,
            DeletedAt = DateTime.UtcNow
        };

        _db.Users.AddRange(activeUser, deletedUser);

        var auditEvents = new List<AuditEvent>
        {
            new()
            {
                Id = Guid.NewGuid(),
                Action = AuditActions.UserLoginSucceeded,
                ActorUserId = activeUser.Id,
                OccurredAt = DateTime.UtcNow.AddMinutes(-5),
                TargetEntityType = nameof(User),
                TargetEntityId = activeUser.Id
            },
            new()
            {
                Id = Guid.NewGuid(),
                Action = AuditActions.InviteCreated,
                ActorUserId = deletedUser.Id,
                OccurredAt = DateTime.UtcNow.AddMinutes(-3),
                TargetEntityType = nameof(Invite),
                TargetEntityId = Guid.NewGuid()
            },
            new()
            {
                Id = Guid.NewGuid(),
                Action = AuditActions.UserRegisteredFromInvite,
                ActorUserId = null, // System/null actor
                OccurredAt = DateTime.UtcNow.AddMinutes(-1),
                TargetEntityType = nameof(User),
                TargetEntityId = Guid.NewGuid()
            }
        };

        _db.AuditEvents.AddRange(auditEvents);
        await _db.SaveChangesAsync();

        var history = await _service.GetAuditHistoryAsync();

        Assert.Equal(3, history.Count);

        // Active user should show username
        var activeUserEvent = history.First(h => h.ActorUserId == activeUser.Id);
        Assert.Equal("activeuser", activeUserEvent.ActorDisplayName);

        // Deleted user should show fallback
        var deletedUserEvent = history.First(h => h.ActorUserId == deletedUser.Id);
        Assert.Equal("Utilisateur supprimé", deletedUserEvent.ActorDisplayName);

        // Null actor should show fallback
        var nullActorEvent = history.First(h => h.ActorUserId == null);
        Assert.Equal("Utilisateur supprimé", nullActorEvent.ActorDisplayName);
    }

    [Fact]
    public async Task GetAuditHistory_FiltersByDateRange()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "testuser",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);

        var oldEvent = new AuditEvent
        {
            Id = Guid.NewGuid(),
            Action = AuditActions.UserLoginSucceeded,
            ActorUserId = user.Id,
            OccurredAt = DateTime.UtcNow.AddDays(-2),
            TargetEntityType = nameof(User),
            TargetEntityId = user.Id
        };

        var recentEvent = new AuditEvent
        {
            Id = Guid.NewGuid(),
            Action = AuditActions.InviteCreated,
            ActorUserId = user.Id,
            OccurredAt = DateTime.UtcNow.AddHours(-1),
            TargetEntityType = nameof(Invite),
            TargetEntityId = Guid.NewGuid()
        };

        _db.AuditEvents.AddRange(oldEvent, recentEvent);
        await _db.SaveChangesAsync();

        var history = await _service.GetAuditHistoryAsync(
            startDate: DateTime.UtcNow.AddDays(-1),
            endDate: DateTime.UtcNow);

        Assert.Single(history);
        Assert.Equal(AuditActions.InviteCreated, history[0].Action);
    }

    [Fact]
    public async Task GetAuditHistory_FiltersByActor()
    {
        var user1 = new User
        {
            Id = Guid.NewGuid(),
            Username = "user1",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow
        };

        var user2 = new User
        {
            Id = Guid.NewGuid(),
            Username = "user2",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow
        };

        _db.Users.AddRange(user1, user2);

        _db.AuditEvents.AddRange(
            new AuditEvent
            {
                Id = Guid.NewGuid(),
                Action = AuditActions.UserLoginSucceeded,
                ActorUserId = user1.Id,
                OccurredAt = DateTime.UtcNow.AddMinutes(-5),
                TargetEntityType = nameof(User),
                TargetEntityId = user1.Id
            },
            new AuditEvent
            {
                Id = Guid.NewGuid(),
                Action = AuditActions.UserLoginSucceeded,
                ActorUserId = user2.Id,
                OccurredAt = DateTime.UtcNow.AddMinutes(-3),
                TargetEntityType = nameof(User),
                TargetEntityId = user2.Id
            }
        );

        await _db.SaveChangesAsync();

        var history = await _service.GetAuditHistoryAsync(actorUserId: user1.Id);

        Assert.Single(history);
        Assert.Equal(user1.Id, history[0].ActorUserId);
    }

    [Fact]
    public async Task GetAuditHistory_FiltersByAction()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "testuser",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);

        _db.AuditEvents.AddRange(
            new AuditEvent
            {
                Id = Guid.NewGuid(),
                Action = AuditActions.UserLoginSucceeded,
                ActorUserId = user.Id,
                OccurredAt = DateTime.UtcNow.AddMinutes(-5),
                TargetEntityType = nameof(User),
                TargetEntityId = user.Id
            },
            new AuditEvent
            {
                Id = Guid.NewGuid(),
                Action = AuditActions.InviteCreated,
                ActorUserId = user.Id,
                OccurredAt = DateTime.UtcNow.AddMinutes(-3),
                TargetEntityType = nameof(Invite),
                TargetEntityId = Guid.NewGuid()
            }
        );

        await _db.SaveChangesAsync();

        var history = await _service.GetAuditHistoryAsync(action: AuditActions.UserLoginSucceeded);

        Assert.Single(history);
        Assert.Equal(AuditActions.UserLoginSucceeded, history[0].Action);
    }

    [Fact]
    public async Task GetEntityHistory_ReturnsEventsForSpecificEntity()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "testuser",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);

        var targetId = Guid.NewGuid();

        _db.AuditEvents.AddRange(
            new AuditEvent
            {
                Id = Guid.NewGuid(),
                Action = AuditActions.TentCreated,
                ActorUserId = user.Id,
                OccurredAt = DateTime.UtcNow.AddMinutes(-5),
                TargetEntityType = "Tent",
                TargetEntityId = targetId
            },
            new AuditEvent
            {
                Id = Guid.NewGuid(),
                Action = AuditActions.TentUpdated,
                ActorUserId = user.Id,
                OccurredAt = DateTime.UtcNow.AddMinutes(-3),
                TargetEntityType = "Tent",
                TargetEntityId = targetId
            },
            new AuditEvent
            {
                Id = Guid.NewGuid(),
                Action = AuditActions.InviteCreated,
                ActorUserId = user.Id,
                OccurredAt = DateTime.UtcNow.AddMinutes(-1),
                TargetEntityType = nameof(Invite),
                TargetEntityId = Guid.NewGuid()
            }
        );

        await _db.SaveChangesAsync();

        var history = await _service.GetEntityHistoryAsync("Tent", targetId);

        Assert.Equal(2, history.Count);
        Assert.All(history, h => Assert.Equal("Tent", h.TargetEntityType));
        Assert.All(history, h => Assert.Equal(targetId, h.TargetEntityId));
    }

    [Fact]
    public async Task GetAuditHistory_OrdersByMostRecentFirst()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "testuser",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);

        _db.AuditEvents.AddRange(
            new AuditEvent
            {
                Id = Guid.NewGuid(),
                Action = "action_old",
                ActorUserId = user.Id,
                OccurredAt = DateTime.UtcNow.AddDays(-1)
            },
            new AuditEvent
            {
                Id = Guid.NewGuid(),
                Action = "action_recent",
                ActorUserId = user.Id,
                OccurredAt = DateTime.UtcNow
            }
        );

        await _db.SaveChangesAsync();

        var history = await _service.GetAuditHistoryAsync();

        Assert.Equal(2, history.Count);
        Assert.Equal("action_recent", history[0].Action);
        Assert.Equal("action_old", history[1].Action);
    }
}
