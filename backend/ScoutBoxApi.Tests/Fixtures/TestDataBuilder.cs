using System;
using System.Collections.Generic;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Tests.Fixtures;

/// <summary>
/// Builder for creating test data entities with sensible defaults.
/// Reduces repetitive setup in test methods.
/// </summary>
public class TestDataBuilder
{
    private readonly ScoutBoxDbContext _db;

    public TestDataBuilder(ScoutBoxDbContext db)
    {
        _db = db;
    }

    /// <summary>
    /// Creates a user with sensible defaults. Does not save changes.
    /// </summary>
    public User CreateUser(
        string? username = null,
        bool isDeleted = false,
        Guid? id = null,
        string password = "password123")
    {
        var user = new User
        {
            Id = id ?? Guid.NewGuid(),
            Username = username ?? $"user_{Guid.NewGuid():N}[8]",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(password),
            CreatedAt = DateTime.UtcNow,
            IsDeleted = isDeleted,
            DeletedAt = isDeleted ? DateTime.UtcNow : null
        };
        _db.Users.Add(user);
        return user;
    }

    /// <summary>
    /// Creates an invite with sensible defaults. Does not save changes.
    /// </summary>
    public Invite CreateInvite(
        string? code = null,
        bool isUsed = false,
        Guid? usedByUserId = null,
        int expiresInDays = 30,
        Guid? createdByUserId = null)
    {
        var invite = new Invite
        {
            Id = Guid.NewGuid(),
            Code = code ?? $"INVITE-{Guid.NewGuid():N}[6]",
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(expiresInDays),
            IsUsed = isUsed,
            UsedByUserId = usedByUserId,
            UsedAt = isUsed ? DateTime.UtcNow : null,
            CreatedByUserId = createdByUserId
        };
        _db.Invites.Add(invite);
        return invite;
    }

    /// <summary>
    /// Creates an audit event. Does not save changes.
    /// </summary>
    public AuditEvent CreateAuditEvent(
        string action,
        Guid? actorUserId = null,
        string? targetEntityType = null,
        Guid? targetEntityId = null,
        DateTime? occurredAt = null,
        Dictionary<string, object?>? metadata = null)
    {
        var auditEvent = new AuditEvent
        {
            Id = Guid.NewGuid(),
            Action = action,
            ActorUserId = actorUserId,
            TargetEntityType = targetEntityType,
            TargetEntityId = targetEntityId ?? Guid.NewGuid(),
            OccurredAt = occurredAt ?? DateTime.UtcNow,
            MetadataJson = metadata != null ? System.Text.Json.JsonSerializer.Serialize(metadata) : null
        };
        _db.AuditEvents.Add(auditEvent);
        return auditEvent;
    }

    /// <summary>
    /// Saves all pending changes to the database.
    /// </summary>
    public async Task SaveChangesAsync()
    {
        await _db.SaveChangesAsync();
    }
}

/// <summary>
/// Factory for creating commonly used mock objects in tests.
/// </summary>
public static class MockFactory
{
    /// <summary>
    /// Creates an ILogger mock that accepts any log level and message.
    /// </summary>
    public static Mock<ILogger<T>> CreateLogger<T>()
    {
        var mock = new Mock<ILogger<T>>();
        // Use Returns<bool>() extension for void-like behavior
        mock.Setup(x => x.Log(
            It.IsAny<LogLevel>(),
            It.IsAny<EventId>(),
            It.IsAny<It.IsAnyType>(),
            It.IsAny<Exception?>(),
            It.IsAny<Func<It.IsAnyType, Exception?, string>>()));
        return mock;
    }
}

/// <summary>
/// Helper for setting up HTTP context with authentication for controller tests.
/// </summary>
public static class HttpContextFixture
{
    /// <summary>
    /// Creates a ClaimsPrincipal for test authentication.
    /// </summary>
    public static ClaimsPrincipal CreatePrincipal(Guid userId, string username, string authScheme = "TestAuth")
    {
        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim(ClaimTypes.Name, username)
        };
        var identity = new ClaimsIdentity(claims, authScheme);
        return new ClaimsPrincipal(identity);
    }

    /// <summary>
    /// Sets up an HttpContextAccessor with the specified user for service tests.
    /// </summary>
    public static HttpContextAccessor CreateAccessor(Guid userId, string username, string authScheme = "TestAuth")
    {
        var principal = CreatePrincipal(userId, username, authScheme);
        var httpContext = new DefaultHttpContext { User = principal };
        return new HttpContextAccessor { HttpContext = httpContext };
    }
}

/// <summary>
/// Base test class that provides common test infrastructure.
/// </summary>
public abstract class TestBase : IDisposable
{
    protected readonly ScoutBoxDbContext Db;
    protected readonly TestDataBuilder Builder;

    protected TestBase()
    {
        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        Db = new ScoutBoxDbContext(options);
        Builder = new TestDataBuilder(Db);
    }

    public void Dispose()
    {
        Db.Dispose();
        GC.SuppressFinalize(this);
    }
}
