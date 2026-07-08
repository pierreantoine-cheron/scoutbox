using System;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Services;
using Xunit;

namespace ScoutBoxApi.Tests.Services;

public class AuthServiceSoftDeleteTests
{
    [Fact]
    public async Task RefreshToken_WithSoftDeletedUser_ReturnsInvalidRefreshTokenError()
    {
        var connectionString = "Data Source=:memory:;Cache=Shared";

        using var connection = new SqliteConnection(connectionString);
        await connection.OpenAsync();

        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseSqlite(connection)
            .Options;

        await using var setupContext = new ScoutBoxDbContext(options);
        await setupContext.Database.EnsureCreatedAsync();

        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "deleteduser",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow,
            IsDeleted = true,
            DeletedAt = DateTime.UtcNow
        };
        setupContext.Users.Add(user);

        var refreshToken = new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = TokenService.HashRefreshToken("valid-refresh-token"),
            UserId = user.Id,
            ExpiresAt = DateTime.UtcNow.AddDays(180),
            CreatedAt = DateTime.UtcNow,
            IsRevoked = false
        };
        setupContext.RefreshTokens.Add(refreshToken);
        await setupContext.SaveChangesAsync();

        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new[]
            {
                new KeyValuePair<string, string?>("Jwt:Key", "test-jwt-key-with-minimum-32-characters"),
                new KeyValuePair<string, string?>("Jwt:Issuer", "TestIssuer"),
                new KeyValuePair<string, string?>("Jwt:Audience", "TestAudience")
            })
            .Build();

        var tokenService = new TokenService(config);
        var loggerMock = new Mock<ILogger<AuthService>>();
        var auditLoggerMock = new Mock<ILogger<AuditService>>();
        var inviteLoggerMock = new Mock<ILogger<InviteService>>();

        await using var context = new ScoutBoxDbContext(options);
        var auditService = new AuditService(context, auditLoggerMock.Object);
        var inviteService = new InviteService(context, auditService, inviteLoggerMock.Object);
        var authService = new AuthService(context, tokenService, inviteService, auditService, loggerMock.Object, config);

        // Attempt to refresh token for deleted user
        var (response, error) = await authService.RefreshTokenAsync("valid-refresh-token");

        // Should return error, not crash
        Assert.Null(response);
        Assert.NotNull(error);
        Assert.Equal("INVALID_REFRESH_TOKEN", error.Code);

        // Verify no audit event was written (check that rejection happened before audit write)
        var auditCount = await context.AuditEvents.CountAsync();
        Assert.Equal(0, auditCount);
    }

    [Fact]
    public async Task RefreshToken_WithMissingUser_ReturnsInvalidRefreshTokenError()
    {
        var connectionString = "Data Source=:memory:;Cache=Shared";

        using var connection = new SqliteConnection(connectionString);
        await connection.OpenAsync();

        // Disable FK constraints to simulate orphan token scenario (defensive test)
        using (var command = connection.CreateCommand())
        {
            command.CommandText = "PRAGMA foreign_keys = OFF;";
            await command.ExecuteNonQueryAsync();
        }

        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseSqlite(connection)
            .Options;

        await using var setupContext = new ScoutBoxDbContext(options);
        await setupContext.Database.EnsureCreatedAsync();

        // Orphan refresh token (user doesn't exist at all)
        var nonExistentUserId = Guid.NewGuid();
        var refreshToken = new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = TokenService.HashRefreshToken("orphan-refresh-token"),
            UserId = nonExistentUserId,
            ExpiresAt = DateTime.UtcNow.AddDays(180),
            CreatedAt = DateTime.UtcNow,
            IsRevoked = false
        };
        setupContext.RefreshTokens.Add(refreshToken);
        await setupContext.SaveChangesAsync();

        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new[]
            {
                new KeyValuePair<string, string?>("Jwt:Key", "test-jwt-key-with-minimum-32-characters"),
                new KeyValuePair<string, string?>("Jwt:Issuer", "TestIssuer"),
                new KeyValuePair<string, string?>("Jwt:Audience", "TestAudience")
            })
            .Build();

        var tokenService = new TokenService(config);
        var loggerMock = new Mock<ILogger<AuthService>>();
        var auditLoggerMock = new Mock<ILogger<AuditService>>();
        var inviteLoggerMock = new Mock<ILogger<InviteService>>();

        await using var context = new ScoutBoxDbContext(options);
        var auditService = new AuditService(context, auditLoggerMock.Object);
        var inviteService = new InviteService(context, auditService, inviteLoggerMock.Object);
        var authService = new AuthService(context, tokenService, inviteService, auditService, loggerMock.Object, config);

        // Attempt to refresh token for non-existent user
        var (response, error) = await authService.RefreshTokenAsync("orphan-refresh-token");

        // Should return error, not crash
        Assert.Null(response);
        Assert.NotNull(error);
        Assert.Equal("INVALID_REFRESH_TOKEN", error.Code);

        // Verify no audit event was written
        var auditCount = await context.AuditEvents.CountAsync();
        Assert.Equal(0, auditCount);
    }

    [Fact]
    public async Task RefreshToken_WithActiveUser_SucceedsAndWritesAudit()
    {
        var connectionString = "Data Source=:memory:;Cache=Shared";

        using var connection = new SqliteConnection(connectionString);
        await connection.OpenAsync();

        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseSqlite(connection)
            .Options;

        await using var setupContext = new ScoutBoxDbContext(options);
        await setupContext.Database.EnsureCreatedAsync();

        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "activeuser",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow,
            IsDeleted = false
        };
        setupContext.Users.Add(user);

        var refreshToken = new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = TokenService.HashRefreshToken("active-refresh-token"),
            UserId = user.Id,
            ExpiresAt = DateTime.UtcNow.AddDays(180),
            CreatedAt = DateTime.UtcNow,
            IsRevoked = false
        };
        setupContext.RefreshTokens.Add(refreshToken);
        await setupContext.SaveChangesAsync();

        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new[]
            {
                new KeyValuePair<string, string?>("Jwt:Key", "test-jwt-key-with-minimum-32-characters"),
                new KeyValuePair<string, string?>("Jwt:Issuer", "TestIssuer"),
                new KeyValuePair<string, string?>("Jwt:Audience", "TestAudience")
            })
            .Build();

        var tokenService = new TokenService(config);
        var loggerMock = new Mock<ILogger<AuthService>>();
        var auditLoggerMock = new Mock<ILogger<AuditService>>();
        var inviteLoggerMock = new Mock<ILogger<InviteService>>();

        await using var context = new ScoutBoxDbContext(options);
        var auditService = new AuditService(context, auditLoggerMock.Object);
        var inviteService = new InviteService(context, auditService, inviteLoggerMock.Object);
        var authService = new AuthService(context, tokenService, inviteService, auditService, loggerMock.Object, config);

        // Refresh token for active user should succeed
        var (response, error) = await authService.RefreshTokenAsync("active-refresh-token");

        Assert.NotNull(response);
        Assert.Null(error);
        Assert.NotNull(response.AccessToken);
        Assert.NotNull(response.RefreshToken);

        // Verify audit event was written
        var auditEvents = await context.AuditEvents.ToListAsync();
        Assert.Single(auditEvents);
        Assert.Equal(AuditActions.UserRefreshTokenRotated, auditEvents[0].Action);
        Assert.Equal(user.Id, auditEvents[0].ActorUserId);
    }
}
