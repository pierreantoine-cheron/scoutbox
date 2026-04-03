using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Services;
using Xunit;

namespace ScoutBoxApi.Tests.Services;

public class AuditServiceTests : IDisposable
{
    private readonly ScoutBoxDbContext _db;
    private readonly AuditService _auditService;
    private readonly Mock<ILogger<AuditService>> _loggerMock;

    public AuditServiceTests()
    {
        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _db = new ScoutBoxDbContext(options);
        _loggerMock = new Mock<ILogger<AuditService>>();
        _auditService = new AuditService(_db, _loggerMock.Object);
    }

    public void Dispose()
    {
        _db.Dispose();
    }

    [Fact]
    public void RecordEvent_WithValidData_CreatesAuditEvent()
    {
        var userId = Guid.NewGuid();
        var targetId = Guid.NewGuid();

        var auditEvent = _auditService.RecordEvent(
            AuditActions.InviteCreated,
            userId,
            nameof(Invite),
            targetId,
            new Dictionary<string, object?> { ["code"] = "TEST-123" });

        Assert.NotNull(auditEvent);
        Assert.Equal(AuditActions.InviteCreated, auditEvent.Action);
        Assert.Equal(userId, auditEvent.ActorUserId);
        Assert.Equal(nameof(Invite), auditEvent.TargetEntityType);
        Assert.Equal(targetId, auditEvent.TargetEntityId);
        Assert.NotNull(auditEvent.MetadataJson);
        Assert.Contains("TEST-123", auditEvent.MetadataJson);
    }

    [Fact]
    public void RecordEvent_WithNullMetadata_CreatesAuditEventWithoutMetadata()
    {
        var userId = Guid.NewGuid();

        var auditEvent = _auditService.RecordEvent(
            AuditActions.UserLoginSucceeded,
            userId,
            nameof(User),
            userId);

        Assert.NotNull(auditEvent);
        Assert.Null(auditEvent.MetadataJson);
    }

    [Fact]
    public void RecordEvent_FiltersExcludedTopLevelKeys()
    {
        var userId = Guid.NewGuid();

        var metadata = new Dictionary<string, object?>
        {
            ["username"] = "testuser",
            ["token"] = "secret-token-123",
            ["password"] = "secret-password",
            ["action"] = "login"
        };

        var auditEvent = _auditService.RecordEvent(
            AuditActions.UserLoginSucceeded,
            userId,
            null,
            null,
            metadata);

        Assert.NotNull(auditEvent.MetadataJson);
        Assert.Contains("username", auditEvent.MetadataJson);
        Assert.Contains("testuser", auditEvent.MetadataJson);
        Assert.Contains("action", auditEvent.MetadataJson);
        // Excluded keys should not be present
        Assert.DoesNotContain("secret-token-123", auditEvent.MetadataJson);
        Assert.DoesNotContain("secret-password", auditEvent.MetadataJson);
    }

    [Fact]
    public void RecordEvent_KeepsNestedObjectsIntact()
    {
        var userId = Guid.NewGuid();

        // Nested objects are kept as-is - callers are responsible for safe metadata
        var metadata = new Dictionary<string, object?>
        {
            ["user"] = new Dictionary<string, object?>
            {
                ["id"] = userId.ToString(),
                ["name"] = "John Doe",
                ["settings"] = new Dictionary<string, object?>
                {
                    ["theme"] = "dark",
                    ["notifications"] = true
                }
            },
            ["timestamp"] = DateTime.UtcNow.ToString("O")
        };

        var auditEvent = _auditService.RecordEvent(
            AuditActions.UserLoginSucceeded,
            userId,
            null,
            null,
            metadata);

        Assert.NotNull(auditEvent.MetadataJson);
        Assert.Contains("John Doe", auditEvent.MetadataJson);
        Assert.Contains("dark", auditEvent.MetadataJson);
        Assert.Contains("notifications", auditEvent.MetadataJson);
    }

    [Fact]
    public void RecordEvent_DoesNotRecurseIntoNestedObjectsForFiltering()
    {
        var userId = Guid.NewGuid();

        // Nested keys named "token" are NOT filtered - only top-level
        var metadata = new Dictionary<string, object?>
        {
            ["user"] = new Dictionary<string, object?>
            {
                ["token"] = "nested-token-value",
                ["name"] = "testuser"
            },
            ["safeField"] = "safe-value"
        };

        var auditEvent = _auditService.RecordEvent(
            AuditActions.UserLoginSucceeded,
            userId,
            null,
            null,
            metadata);

        Assert.NotNull(auditEvent.MetadataJson);
        // Top-level safe field
        Assert.Contains("safe-value", auditEvent.MetadataJson);
        // User object preserved
        Assert.Contains("testuser", auditEvent.MetadataJson);
        // Nested token is NOT filtered - only top-level keys are checked
        Assert.Contains("nested-token-value", auditEvent.MetadataJson);
    }

    [Fact]
    public async Task RecordEventAsync_SavesToDatabase()
    {
        var userId = Guid.NewGuid();

        var auditEvent = await _auditService.RecordEventAsync(
            AuditActions.UserRegisteredFromInvite,
            userId,
            nameof(User),
            userId,
            new Dictionary<string, object?> { ["inviteCode"] = "INVITE-123" });

        var savedEvent = await _db.AuditEvents.FindAsync(auditEvent.Id);
        Assert.NotNull(savedEvent);
        Assert.Equal(AuditActions.UserRegisteredFromInvite, savedEvent.Action);
    }

    [Fact]
    public void RecordEvent_SetsUtcTimestamp()
    {
        var before = DateTime.UtcNow;

        var auditEvent = _auditService.RecordEvent(
            AuditActions.UserLoginSucceeded,
            Guid.NewGuid());

        var after = DateTime.UtcNow;

        Assert.True(auditEvent.OccurredAt >= before);
        Assert.True(auditEvent.OccurredAt <= after);
        Assert.Equal(DateTimeKind.Utc, auditEvent.OccurredAt.Kind);
    }

    [Fact]
    public async Task AuditEvent_WithActorUser_PreservesRelationship()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "testuser",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        _auditService.RecordEvent(
            AuditActions.InviteCreated,
            user.Id,
            nameof(Invite),
            Guid.NewGuid());

        await _db.SaveChangesAsync();

        var auditEvent = await _db.AuditEvents
            .Include(ae => ae.Actor)
            .FirstOrDefaultAsync(ae => ae.ActorUserId == user.Id);

        Assert.NotNull(auditEvent);
        Assert.NotNull(auditEvent.Actor);
        Assert.Equal("testuser", auditEvent.Actor.Username);
    }

    [Fact]
    public void RecordEvent_HandlesComplexMetadata()
    {
        var userId = Guid.NewGuid();

        var metadata = new Dictionary<string, object?>
        {
            ["count"] = 42,
            ["isValid"] = true,
            ["ratio"] = 3.14,
            ["nullable"] = (string?)null,
            ["guid"] = Guid.NewGuid(),
            ["date"] = DateTime.UtcNow
        };

        var auditEvent = _auditService.RecordEvent(
            AuditActions.TentCreated,
            userId,
            null,
            null,
            metadata);

        Assert.NotNull(auditEvent.MetadataJson);
        Assert.Contains("42", auditEvent.MetadataJson);
        Assert.Contains("true", auditEvent.MetadataJson);
        Assert.Contains("3.14", auditEvent.MetadataJson);
    }

    [Fact]
    public void RecordEvent_ReturnsNullMetadata_WhenAllContentFiltered()
    {
        var userId = Guid.NewGuid();

        var metadata = new Dictionary<string, object?>
        {
            ["password"] = "secret",
            ["token"] = "bearer-token"
        };

        var auditEvent = _auditService.RecordEvent(
            AuditActions.UserLoginSucceeded,
            userId,
            null,
            null,
            metadata);

        // When everything is filtered away, metadata should be null
        Assert.Null(auditEvent.MetadataJson);
    }

    [Fact]
    public void RecordEvent_HandlesEmptyMetadata()
    {
        var userId = Guid.NewGuid();

        var auditEvent = _auditService.RecordEvent(
            AuditActions.UserLoginSucceeded,
            userId,
            null,
            null,
            new Dictionary<string, object?>());

        Assert.NotNull(auditEvent);
        Assert.Null(auditEvent.MetadataJson);
    }

    [Fact]
    public void AllAuditActions_AreDefinedAndConsistent()
    {
        // Verify all expected actions are defined and use consistent format
        var expectedActions = new[]
        {
            AuditActions.InviteCreated,
            AuditActions.InviteRevoked,
            AuditActions.UserRegisteredFromInvite,
            AuditActions.UserLoginSucceeded,
            AuditActions.UserRefreshTokenRotated,
            AuditActions.TentCreated,
            AuditActions.TentUpdated,
            AuditActions.TentArchived,
            AuditActions.PartStateChanged,
            AuditActions.PartAdded,
            AuditActions.PartRemoved,
            AuditActions.PhotoUploaded,
            AuditActions.PhotoDeleted,
            AuditActions.TagCreated,
            AuditActions.TagAssigned,
            AuditActions.TagRemoved
        };

        foreach (var action in expectedActions)
        {
            Assert.False(string.IsNullOrEmpty(action));
            Assert.Contains("_", action); // Snake_case format
            Assert.All(action, c => Assert.True(char.IsLower(c) || c == '_' || char.IsDigit(c)));
        }
    }
}

public class CurrentUserAccessorTests
{
    [Fact]
    public void GetCurrentUserId_WithValidClaim_ReturnsUserId()
    {
        var userId = Guid.NewGuid();
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim(ClaimTypes.Name, "testuser")
        };
        var identity = new ClaimsIdentity(claims, "Test");
        var principal = new ClaimsPrincipal(identity);

        var httpContext = new DefaultHttpContext { User = principal };
        var httpContextAccessor = new HttpContextAccessor { HttpContext = httpContext };
        var accessor = new CurrentUserAccessor(httpContextAccessor);

        var result = accessor.GetCurrentUserId();

        Assert.Equal(userId, result);
    }

    [Fact]
    public void GetCurrentUserId_WithNoAuthentication_ReturnsNull()
    {
        var httpContext = new DefaultHttpContext();
        var httpContextAccessor = new HttpContextAccessor { HttpContext = httpContext };
        var accessor = new CurrentUserAccessor(httpContextAccessor);

        var result = accessor.GetCurrentUserId();

        Assert.Null(result);
    }

    [Fact]
    public void GetCurrentUserId_WithInvalidGuidClaim_ReturnsNull()
    {
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, "not-a-valid-guid")
        };
        var identity = new ClaimsIdentity(claims, "Test");
        var principal = new ClaimsPrincipal(identity);

        var httpContext = new DefaultHttpContext { User = principal };
        var httpContextAccessor = new HttpContextAccessor { HttpContext = httpContext };
        var accessor = new CurrentUserAccessor(httpContextAccessor);

        var result = accessor.GetCurrentUserId();

        Assert.Null(result);
    }

    [Fact]
    public void GetCurrentUserIdOrThrow_WithValidClaim_ReturnsUserId()
    {
        var userId = Guid.NewGuid();
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString())
        };
        var identity = new ClaimsIdentity(claims, "Test");
        var principal = new ClaimsPrincipal(identity);

        var httpContext = new DefaultHttpContext { User = principal };
        var httpContextAccessor = new HttpContextAccessor { HttpContext = httpContext };
        var accessor = new CurrentUserAccessor(httpContextAccessor);

        var result = accessor.GetCurrentUserIdOrThrow();

        Assert.Equal(userId, result);
    }

    [Fact]
    public void GetCurrentUserIdOrThrow_WithNoAuthentication_ThrowsException()
    {
        var httpContext = new DefaultHttpContext();
        var httpContextAccessor = new HttpContextAccessor { HttpContext = httpContext };
        var accessor = new CurrentUserAccessor(httpContextAccessor);

        Assert.Throws<UnauthorizedAccessException>(() => accessor.GetCurrentUserIdOrThrow());
    }

    [Fact]
    public void GetCurrentUsername_WithValidClaim_ReturnsUsername()
    {
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, Guid.NewGuid().ToString()),
            new Claim(ClaimTypes.Name, "testuser")
        };
        var identity = new ClaimsIdentity(claims, "Test");
        var principal = new ClaimsPrincipal(identity);

        var httpContext = new DefaultHttpContext { User = principal };
        var httpContextAccessor = new HttpContextAccessor { HttpContext = httpContext };
        var accessor = new CurrentUserAccessor(httpContextAccessor);

        var result = accessor.GetCurrentUsername();

        Assert.Equal("testuser", result);
    }

    [Fact]
    public void GetValidatedUserId_WithValidClaim_ReturnsUserId()
    {
        var userId = Guid.NewGuid();
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim(ClaimTypes.Name, "testuser")
        };
        var identity = new ClaimsIdentity(claims, "Test");
        var principal = new ClaimsPrincipal(identity);

        var httpContext = new DefaultHttpContext { User = principal };
        var httpContextAccessor = new HttpContextAccessor { HttpContext = httpContext };
        var accessor = new CurrentUserAccessor(httpContextAccessor);

        var result = accessor.GetValidatedUserId();

        Assert.Equal(userId, result);
    }

    [Fact]
    public void GetValidatedUserId_WithNoAuthentication_ThrowsUnauthorizedAccessException()
    {
        var httpContext = new DefaultHttpContext();
        var httpContextAccessor = new HttpContextAccessor { HttpContext = httpContext };
        var accessor = new CurrentUserAccessor(httpContextAccessor);

        var exception = Assert.Throws<UnauthorizedAccessException>(() => accessor.GetValidatedUserId());
        Assert.Equal("Authentication required", exception.Message);
    }

    [Fact]
    public void GetValidatedUserId_WithInvalidClaim_ThrowsUnauthorizedAccessException()
    {
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, "invalid-guid")
        };
        var identity = new ClaimsIdentity(claims, "Test");
        var principal = new ClaimsPrincipal(identity);

        var httpContext = new DefaultHttpContext { User = principal };
        var httpContextAccessor = new HttpContextAccessor { HttpContext = httpContext };
        var accessor = new CurrentUserAccessor(httpContextAccessor);

        var exception = Assert.Throws<UnauthorizedAccessException>(() => accessor.GetValidatedUserId());
        Assert.Equal("Invalid identity claim in token", exception.Message);
    }
}
