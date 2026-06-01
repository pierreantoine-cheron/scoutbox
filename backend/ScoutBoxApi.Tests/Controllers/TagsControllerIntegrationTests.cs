using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;
using Xunit;

namespace ScoutBoxApi.Tests.Controllers;

public class TagsControllerIntegrationTests : IClassFixture<CustomApiFactory>
{
    private readonly CustomApiFactory _factory;

    public TagsControllerIntegrationTests(CustomApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task GetTags_Authenticated_ReturnsTagsAlphabeticallyWithTentCount()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var tent = await CreateTentAsync(db, $"Tag Count Tent {prefix}");
            var alpha = CreateTag($"Alpha {prefix}", "#F44336");
            var beta = CreateTag($"Beta {prefix}", "#2196F3");
            db.Tags.AddRange(beta, alpha);
            db.TentTags.Add(new TentTag
            {
                TentId = tent.Id,
                TagId = alpha.Id,
                CreatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/tags");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TagApiDto>>>();
        Assert.NotNull(payload?.Data);

        var tags = payload.Data.Where(tag => tag.Name.EndsWith(prefix, StringComparison.Ordinal)).ToList();
        Assert.Equal(new[] { $"Alpha {prefix}", $"Beta {prefix}" }, tags.Select(tag => tag.Name));
        Assert.Equal(1, tags[0].TentCount);
        Assert.Equal(0, tags[1].TentCount);
    }

    [Fact]
    public async Task GetTags_WhenEmpty_ReturnsEmptyList()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/tags");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TagApiDto>>>();
        Assert.NotNull(payload?.Data);
    }

    [Fact]
    public async Task GetTags_Unauthorized_ReturnsUnauthorized()
    {
        using var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/tags");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task CreateTag_WithValidPayload_ReturnsCreatedTagAndAuditEvent()
    {
        await EnsureTestUserExistsAsync();
        var name = $"À réparer {Guid.NewGuid():N}"[..30];

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/tags", new { name, color = "#F44336" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TagApiDto>>();
        Assert.NotNull(payload?.Data);
        Assert.Equal(name, payload.Data.Name);
        Assert.Equal("#F44336", payload.Data.Color);
        Assert.Equal(0, payload.Data.TentCount);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var audit = await db.AuditEvents.FirstOrDefaultAsync(a =>
            a.TargetEntityId == payload.Data.Id && a.Action == "tag_created");
        Assert.NotNull(audit);
        Assert.Equal(CustomApiFactory.TestUserId, audit.ActorUserId);
        Assert.Equal("Tag", audit.TargetEntityType);
        Assert.NotNull(audit.MetadataJson);
        using var metadata = JsonDocument.Parse(audit.MetadataJson);
        Assert.Equal(name, metadata.RootElement.GetProperty("name").GetString());
        Assert.Equal("#F44336", metadata.RootElement.GetProperty("color").GetString());
    }

    [Fact]
    public async Task CreateTag_TrimsNameAndDefaultsBlankColor()
    {
        await EnsureTestUserExistsAsync();
        var name = $"Hangar {Guid.NewGuid():N}"[..24];

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/tags", new { name = $"  {name}  ", color = " " });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TagApiDto>>();
        Assert.NotNull(payload?.Data);
        Assert.Equal(name, payload.Data.Name);
        Assert.Equal("#2196F3", payload.Data.Color);
    }

    [Theory]
    [InlineData("", "#2196F3", "TAG_NAME_REQUIRED")]
    [InlineData("A", "#2196F3", "TAG_NAME_TOO_SHORT")]
    [InlineData("1234567890123456789012345678901", "#2196F3", "TAG_NAME_TOO_LONG")]
    [InlineData("Valid Name", "blue", "INVALID_TAG_COLOR")]
    public async Task CreateTag_WithInvalidPayload_ReturnsStableErrorCode(string name, string color, string expectedCode)
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/tags", new { name, color });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal(expectedCode, payload.Code);
    }

    [Fact]
    public async Task CreateTag_DuplicateExactCase_ReturnsStableErrorCode()
    {
        await EnsureTestUserExistsAsync();
        var name = $"Groupe {Guid.NewGuid():N}"[..24];

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            db.Tags.Add(CreateTag(name, "#2196F3"));
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/tags", new { name, color = "#4CAF50" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TAG_NAME_EXISTS", payload.Code);
    }

    [Fact]
    public async Task CreateTag_DifferentCaseName_IsAllowed()
    {
        await EnsureTestUserExistsAsync();
        var suffix = Guid.NewGuid().ToString("N")[..8];

        using var client = CreateAuthenticatedClient();
        var first = await client.PostAsJsonAsync("/api/tags", new { name = $"Case {suffix}", color = "#2196F3" });
        var second = await client.PostAsJsonAsync("/api/tags", new { name = $"case {suffix}", color = "#4CAF50" });

        Assert.Equal(HttpStatusCode.OK, first.StatusCode);
        Assert.Equal(HttpStatusCode.OK, second.StatusCode);
    }

    private HttpClient CreateAuthenticatedClient()
    {
        var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });

        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(TestAuthHandler.SchemeName, "integration");
        return client;
    }

    private async Task EnsureTestUserExistsAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();

        if (!await db.Users.IgnoreQueryFilters().AnyAsync(u => u.Id == CustomApiFactory.TestUserId))
        {
            db.Users.Add(new User
            {
                Id = CustomApiFactory.TestUserId,
                Username = "integration_test_user",
                PasswordHash = BCrypt.Net.BCrypt.HashPassword("password123"),
                CreatedAt = DateTime.UtcNow,
                IsDeleted = false
            });
            await db.SaveChangesAsync();
        }
    }

    private static Tag CreateTag(string name, string color)
    {
        return new Tag
        {
            Id = Guid.NewGuid(),
            Name = name,
            Color = color,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        };
    }

    private static async Task<Tent> CreateTentAsync(ScoutBoxDbContext db, string name)
    {
        var modelId = await db.TentModels
            .Where(model => model.IsActive)
            .OrderBy(model => model.DisplayOrder)
            .Select(model => model.Id)
            .FirstAsync();

        var tent = new Tent
        {
            Id = Guid.NewGuid(),
            Name = name,
            Size = 6,
            TentModelId = modelId,
            OverallState = TentOverallState.Good,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        };
        db.Tents.Add(tent);
        return tent;
    }

    private sealed class DataEnvelope<T>
    {
        public T Data { get; set; } = default!;
    }

    private sealed class TagApiDto
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Color { get; set; } = string.Empty;
        public DateTime CreatedAt { get; set; }
        public int TentCount { get; set; }
    }

    private sealed class ErrorPayload
    {
        public string Error { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
    }
}
