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
    public void RecordEvent_SanitizesSensitiveTokenData()
    {
        var userId = Guid.NewGuid();

        var metadata = new Dictionary<string, object?>
        {
            ["username"] = "testuser",
            ["token"] = "secret-token-123",
            ["refreshToken"] = "refresh-secret",
            ["authorization"] = "Bearer abc123"
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
        Assert.DoesNotContain("secret-token-123", auditEvent.MetadataJson);
        Assert.DoesNotContain("refresh-secret", auditEvent.MetadataJson);
        Assert.DoesNotContain("Bearer abc123", auditEvent.MetadataJson);
    }

    [Fact]
    public void RecordEvent_SanitizesLongBase64Strings()
    {
        var userId = Guid.NewGuid();

        // Create a long base64 string (>100 chars)
        var longBase64 = Convert.ToBase64String(new byte[80]); // ~107 chars

        var metadata = new Dictionary<string, object?>
        {
            ["username"] = "testuser",
            ["suspiciousData"] = longBase64
        };

        var auditEvent = _auditService.RecordEvent(
            AuditActions.UserLoginSucceeded,
            userId,
            null,
            null,
            metadata);

        Assert.NotNull(auditEvent.MetadataJson);
        Assert.Contains("username", auditEvent.MetadataJson);
        Assert.DoesNotContain(longBase64, auditEvent.MetadataJson);
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
    public void ValidateCurrentUserIdentity_WithValidClaim_ReturnsNull()
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

        var result = accessor.ValidateCurrentUserIdentity();

        Assert.Null(result);
    }

    [Fact]
    public void ValidateCurrentUserIdentity_WithNoAuthentication_ReturnsError()
    {
        var httpContext = new DefaultHttpContext();
        var httpContextAccessor = new HttpContextAccessor { HttpContext = httpContext };
        var accessor = new CurrentUserAccessor(httpContextAccessor);

        var result = accessor.ValidateCurrentUserIdentity();

        Assert.NotNull(result);
        Assert.Equal("AUTH_INVALID_TOKEN", result.Code);
    }

    [Fact]
    public void ValidateCurrentUserIdentity_WithInvalidClaim_ReturnsIdentityError()
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

        var result = accessor.ValidateCurrentUserIdentity();

        Assert.NotNull(result);
        Assert.Equal("AUTH_INVALID_IDENTITY_CLAIM", result.Code);
    }
}
