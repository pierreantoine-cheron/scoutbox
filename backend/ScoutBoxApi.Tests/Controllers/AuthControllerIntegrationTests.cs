using System;
using System.Collections.Generic;
using System.IO;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Encodings.Web;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.TestHost;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;
using Xunit;

namespace ScoutBoxApi.Tests.Controllers;

public class AuthControllerIntegrationTests : IClassFixture<CustomApiFactory>
{
    private readonly CustomApiFactory _factory;

    public AuthControllerIntegrationTests(CustomApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task CreateInvite_WithInvalidExpiresInDays_ReturnsApiValidationError()
    {
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            if (!await db.Users.AnyAsync(u => u.Id == CustomApiFactory.TestUserId))
            {
                db.Users.Add(new User
                {
                    Id = CustomApiFactory.TestUserId,
                    Username = "integration_test_user",
                    PasswordHash = BCrypt.Net.BCrypt.HashPassword("password123"),
                    CreatedAt = DateTime.UtcNow
                });
                await db.SaveChangesAsync();
            }
        }

        using var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(TestAuthHandler.SchemeName, "integration");

        var inviteResponse = await client.PostAsJsonAsync("/api/auth/invites", new { code = "TEST-VALIDATION", expiresInDays = 0 });

        Assert.Equal(HttpStatusCode.BadRequest, inviteResponse.StatusCode);

        var payload = await inviteResponse.Content.ReadFromJsonAsync<ValidationProblemDetails>();
        Assert.NotNull(payload);
        Assert.True(payload.Errors.ContainsKey("ExpiresInDays"));
    }
}

public sealed class CustomApiFactory : WebApplicationFactory<Program>
{
    public static readonly Guid TestUserId = Guid.Parse("00000000-0000-0000-0000-000000000123");
    private readonly string _dbPath = Path.Combine(Path.GetTempPath(), $"scoutbox_it_{Guid.NewGuid():N}.db");

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((_, configBuilder) =>
        {
            var settings = new Dictionary<string, string?>
            {
                ["ConnectionStrings:DefaultConnection"] = $"Data Source={_dbPath}",
                ["Jwt:Key"] = "integration-tests-jwt-key-with-minimum-32-characters"
            };

            configBuilder.AddInMemoryCollection(settings);
        });

        builder.ConfigureTestServices(services =>
        {
            services.AddAuthentication(options =>
                {
                    options.DefaultAuthenticateScheme = TestAuthHandler.SchemeName;
                    options.DefaultChallengeScheme = TestAuthHandler.SchemeName;
                })
                .AddScheme<AuthenticationSchemeOptions, TestAuthHandler>(TestAuthHandler.SchemeName, _ => { });
        });
    }

    protected override void Dispose(bool disposing)
    {
        base.Dispose(disposing);

        if (disposing && File.Exists(_dbPath))
        {
            File.Delete(_dbPath);
        }
    }
}

public sealed class TestAuthHandler : AuthenticationHandler<AuthenticationSchemeOptions>
{
    public const string SchemeName = "TestAuth";

    public TestAuthHandler(
        IOptionsMonitor<AuthenticationSchemeOptions> options,
        ILoggerFactory logger,
        UrlEncoder encoder)
        : base(options, logger, encoder)
    {
    }

    protected override Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        if (!Request.Headers.TryGetValue("Authorization", out var headerValue))
        {
            return Task.FromResult(AuthenticateResult.NoResult());
        }

        if (!headerValue.ToString().StartsWith($"{SchemeName} ", StringComparison.OrdinalIgnoreCase))
        {
            return Task.FromResult(AuthenticateResult.NoResult());
        }

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, CustomApiFactory.TestUserId.ToString()),
            new Claim(ClaimTypes.Name, "integration_test_user")
        };

        var identity = new ClaimsIdentity(claims, SchemeName);
        var principal = new ClaimsPrincipal(identity);
        var ticket = new AuthenticationTicket(principal, SchemeName);
        return Task.FromResult(AuthenticateResult.Success(ticket));
    }
}
