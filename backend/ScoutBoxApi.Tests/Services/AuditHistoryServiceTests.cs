using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Services;
using ScoutBoxApi.Tests.Fixtures;
using Xunit;

namespace ScoutBoxApi.Tests.Services;

public class AuditHistoryServiceTests : TestBase
{
    private readonly AuditHistoryService _service;
    private readonly Mock<ILogger<AuditHistoryService>> _loggerMock;

    public AuditHistoryServiceTests()
    {
        _loggerMock = Fixtures.MockFactory.CreateLogger<AuditHistoryService>();
        _service = new AuditHistoryService(Db, _loggerMock.Object);
    }

    [Fact]
    public async Task ResolveActorDisplayName_WithActiveUser_ReturnsUsername()
    {
        var user = Builder.CreateUser("activeuser");
        await Builder.SaveChangesAsync();

        var displayName = await _service.ResolveActorDisplayNameAsync(user.Id);

        Assert.Equal("activeuser", displayName);
    }

    [Fact]
    public async Task ResolveActorDisplayName_WithSoftDeletedUser_ReturnsUtilisateurSupprime()
    {
        var user = Builder.CreateUser("deleteduser", isDeleted: true);
        await Builder.SaveChangesAsync();

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
        // Arrange
        var activeUser = Builder.CreateUser("activeuser");
        var deletedUser = Builder.CreateUser("deleteduser", isDeleted: true);

        Builder.CreateAuditEvent(
            AuditActions.UserLoginSucceeded,
            activeUser.Id,
            nameof(User),
            activeUser.Id,
            DateTime.UtcNow.AddMinutes(-5));

        Builder.CreateAuditEvent(
            AuditActions.InviteCreated,
            deletedUser.Id,
            nameof(Invite),
            Guid.NewGuid(),
            DateTime.UtcNow.AddMinutes(-3));

        Builder.CreateAuditEvent(
            AuditActions.UserRegisteredFromInvite,
            null, // System/null actor
            nameof(User),
            Guid.NewGuid(),
            DateTime.UtcNow.AddMinutes(-1));

        await Builder.SaveChangesAsync();

        // Act
        var history = await _service.GetAuditHistoryAsync();

        // Assert
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
        var user = Builder.CreateUser("testuser");

        Builder.CreateAuditEvent(
            AuditActions.UserLoginSucceeded,
            user.Id,
            nameof(User),
            user.Id,
            DateTime.UtcNow.AddDays(-2));

        Builder.CreateAuditEvent(
            AuditActions.InviteCreated,
            user.Id,
            nameof(Invite),
            Guid.NewGuid(),
            DateTime.UtcNow.AddHours(-1));

        await Builder.SaveChangesAsync();

        var history = await _service.GetAuditHistoryAsync(
            startDate: DateTime.UtcNow.AddDays(-1),
            endDate: DateTime.UtcNow);

        Assert.Single(history);
        Assert.Equal(AuditActions.InviteCreated, history[0].Action);
    }

    [Fact]
    public async Task GetAuditHistory_FiltersByActor()
    {
        var user1 = Builder.CreateUser("user1");
        var user2 = Builder.CreateUser("user2");

        Builder.CreateAuditEvent(
            AuditActions.UserLoginSucceeded,
            user1.Id,
            nameof(User),
            user1.Id,
            DateTime.UtcNow.AddMinutes(-5));

        Builder.CreateAuditEvent(
            AuditActions.UserLoginSucceeded,
            user2.Id,
            nameof(User),
            user2.Id,
            DateTime.UtcNow.AddMinutes(-3));

        await Builder.SaveChangesAsync();

        var history = await _service.GetAuditHistoryAsync(actorUserId: user1.Id);

        Assert.Single(history);
        Assert.Equal(user1.Id, history[0].ActorUserId);
    }

    [Fact]
    public async Task GetAuditHistory_FiltersByAction()
    {
        var user = Builder.CreateUser("testuser");

        Builder.CreateAuditEvent(
            AuditActions.UserLoginSucceeded,
            user.Id,
            nameof(User),
            user.Id,
            DateTime.UtcNow.AddMinutes(-5));

        Builder.CreateAuditEvent(
            AuditActions.InviteCreated,
            user.Id,
            nameof(Invite),
            Guid.NewGuid(),
            DateTime.UtcNow.AddMinutes(-3));

        await Builder.SaveChangesAsync();

        var history = await _service.GetAuditHistoryAsync(action: AuditActions.UserLoginSucceeded);

        Assert.Single(history);
        Assert.Equal(AuditActions.UserLoginSucceeded, history[0].Action);
    }

    [Fact]
    public async Task GetEntityHistory_ReturnsEventsForSpecificEntity()
    {
        var user = Builder.CreateUser("testuser");
        var targetId = Guid.NewGuid();

        Builder.CreateAuditEvent(
            AuditActions.TentCreated,
            user.Id,
            "Tent",
            targetId,
            DateTime.UtcNow.AddMinutes(-5));

        Builder.CreateAuditEvent(
            AuditActions.TentUpdated,
            user.Id,
            "Tent",
            targetId,
            DateTime.UtcNow.AddMinutes(-3));

        Builder.CreateAuditEvent(
            AuditActions.InviteCreated,
            user.Id,
            nameof(Invite),
            Guid.NewGuid(),
            DateTime.UtcNow.AddMinutes(-1));

        await Builder.SaveChangesAsync();

        var history = await _service.GetEntityHistoryAsync("Tent", targetId);

        Assert.Equal(2, history.Count);
        Assert.All(history, h => Assert.Equal("Tent", h.TargetEntityType));
        Assert.All(history, h => Assert.Equal(targetId, h.TargetEntityId));
    }

    [Fact]
    public async Task GetTentHistory_IncludesTagAssignmentEvents()
    {
        var user = Builder.CreateUser("taguser");
        var tentId = Guid.NewGuid();

        Builder.CreateAuditEvent(
            AuditActions.TagAssigned,
            user.Id,
            "TentTag",
            tentId,
            DateTime.UtcNow.AddMinutes(-2),
            new Dictionary<string, object?>
            {
                ["tagId"] = Guid.NewGuid(),
                ["tagName"] = "Patrouille"
            });

        await Builder.SaveChangesAsync();

        var history = await _service.GetTentHistoryAsync(tentId);

        var item = Assert.Single(history);
        Assert.Equal(AuditActions.TagAssigned, item.Action);
        Assert.Equal("tags", item.Category);
        Assert.Equal("Patrouille", item.SubjectName);
        Assert.Equal("Étiquette", Assert.Single(item.Details).Label);
        Assert.Equal("Patrouille", item.Details[0].Value);
    }

    [Fact]
    public async Task GetTentHistory_WithTagsCategory_ReturnsOnlyTagEvents()
    {
        var user = Builder.CreateUser("taguser");
        var tentId = Guid.NewGuid();

        Builder.CreateAuditEvent(
            AuditActions.TentUpdated,
            user.Id,
            "Tent",
            tentId,
            DateTime.UtcNow.AddMinutes(-3));

        Builder.CreateAuditEvent(
            AuditActions.TagRemoved,
            user.Id,
            "TentTag",
            tentId,
            DateTime.UtcNow.AddMinutes(-2),
            new Dictionary<string, object?>
            {
                ["tagId"] = Guid.NewGuid(),
                ["tagName"] = "Rouge"
            });

        await Builder.SaveChangesAsync();

        var history = await _service.GetTentHistoryAsync(tentId, TentHistoryCategory.Tags);

        var item = Assert.Single(history);
        Assert.Equal(AuditActions.TagRemoved, item.Action);
        Assert.Equal("tags", item.Category);
        Assert.Equal("Rouge", item.SubjectName);
    }

    [Fact]
    public async Task GetAuditHistory_OrdersByMostRecentFirst()
    {
        var user = Builder.CreateUser("testuser");

        Builder.CreateAuditEvent(
            "action_old",
            user.Id,
            null,
            null,
            DateTime.UtcNow.AddDays(-1));

        Builder.CreateAuditEvent(
            "action_recent",
            user.Id,
            null,
            null,
            DateTime.UtcNow);

        await Builder.SaveChangesAsync();

        var history = await _service.GetAuditHistoryAsync();

        Assert.Equal(2, history.Count);
        Assert.Equal("action_recent", history[0].Action);
        Assert.Equal("action_old", history[1].Action);
    }
}
