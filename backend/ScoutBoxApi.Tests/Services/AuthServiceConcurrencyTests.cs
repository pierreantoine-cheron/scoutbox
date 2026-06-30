using System;
using System.Collections.Generic;
using System.Linq;
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

public class AuthServiceConcurrencyTests
{
    [Fact]
    public async Task Register_WithSameInviteConcurrently_AllowsOnlyOneSuccess()
    {
        var connectionString = "Data Source=:memory:;Cache=Shared";

        using var connection = new SqliteConnection(connectionString);
        await connection.OpenAsync();

        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseSqlite(connection)
            .Options;

        await using (var setupContext = new ScoutBoxDbContext(options))
        {
            await setupContext.Database.EnsureCreatedAsync();

            var systemUser = new User
            {
                Id = Guid.NewGuid(),
                Username = "concurrency-test-user",
                PasswordHash = "skip",
                CreatedAt = DateTime.UtcNow
            };
            setupContext.Users.Add(systemUser);

            setupContext.Invites.Add(new Invite
            {
                Id = Guid.NewGuid(),
                Code = "RACE-INVITE-001",
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = DateTime.UtcNow.AddMinutes(10),
                IsUsed = false,
                CreatedByUserId = systemUser.Id
            });

            await setupContext.SaveChangesAsync();
        }

        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new[]
            {
                new KeyValuePair<string, string?>("Jwt:Key", "concurrency-tests-jwt-key-with-minimum-32-characters"),
                new KeyValuePair<string, string?>("Jwt:Issuer", "TestIssuer"),
                new KeyValuePair<string, string?>("Jwt:Audience", "TestAudience")
            })
            .Build();

        var tokenService = new TokenService(config);
        var logger1 = new Mock<ILogger<AuthService>>();
        var logger2 = new Mock<ILogger<AuthService>>();
        var auditLogger1 = new Mock<ILogger<AuditService>>();
        var auditLogger2 = new Mock<ILogger<AuditService>>();

        await using var context1 = new ScoutBoxDbContext(options);
        await using var context2 = new ScoutBoxDbContext(options);

        var auditService1 = new AuditService(context1, auditLogger1.Object);
        var auditService2 = new AuditService(context2, auditLogger2.Object);
        var inviteLogger1 = new Mock<ILogger<InviteService>>();
        var inviteLogger2 = new Mock<ILogger<InviteService>>();
        var inviteService1 = new InviteService(context1, auditService1, inviteLogger1.Object);
        var inviteService2 = new InviteService(context2, auditService2, inviteLogger2.Object);

        var service1 = new AuthService(context1, tokenService, inviteService1, auditService1, logger1.Object);
        var service2 = new AuthService(context2, tokenService, inviteService2, auditService2, logger2.Object);

        var t1 = service1.RegisterAsync(new RegisterRequest("RACE-INVITE-001", $"race_user_{Guid.NewGuid():N}", "password123"));
        var t2 = service2.RegisterAsync(new RegisterRequest("RACE-INVITE-001", $"race_user_{Guid.NewGuid():N}", "password123"));

        var results = await Task.WhenAll(t1, t2);

        Assert.Equal(1, results.Count(r => r.Response != null));
        Assert.Equal(1, results.Count(r => r.Error?.Code == "INVALID_INVITE"));

        await using var verifyContext = new ScoutBoxDbContext(options);
        var invite = await verifyContext.Invites.SingleAsync(i => i.Code == "RACE-INVITE-001");
        Assert.True(invite.IsUsed);
    }
}
