using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Services;
using Xunit;

namespace ScoutBoxApi.Tests.Controllers;

public class ActivityControllerIntegrationTests : IClassFixture<CustomApiFactory>
{
    private static readonly Guid SystemUserId = Guid.Parse("00000000-0000-0000-0000-000000000001");

    private readonly CustomApiFactory _factory;

    public ActivityControllerIntegrationTests(CustomApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task GetActivity_DefaultsToLastThirtyDaysAndExcludesAccountEvents()
    {
        await EnsureTestUserExistsAsync();
        var recentTent = await CreateTentAsync("Récente");
        await ResetAuditEventsAsync();
        await InsertAuditEventsAsync(
            Event(AuditActions.TentUpdated, DateTime.UtcNow.AddDays(-5),
                "Tent", recentTent, """{"oldName":"Ancienne","newName":"Récente"}"""),
            Event(AuditActions.UserLoginSucceeded, DateTime.UtcNow.AddDays(-2), "User", Guid.NewGuid()),
            Event(AuditActions.TentCreated, DateTime.UtcNow.AddDays(-40), "Tent", Guid.NewGuid()));

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/activity");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var page = await response.Content.ReadFromJsonAsync<ActivityPageApi>();
        Assert.NotNull(page);
        var item = Assert.Single(page.Items);
        Assert.Equal(AuditActions.TentUpdated, item.Action);
        Assert.Equal("tents", item.Category);
        Assert.Equal(recentTent, item.TentId);
        Assert.Equal("Récente", item.TentName);
        Assert.Equal("integration_test_user", item.ActorDisplayName);
        Assert.Null(page.NextCursor);
    }

    [Theory]
    [InlineData("tents", AuditActions.TentArchived)]
    [InlineData("parts", AuditActions.PartStateChanged)]
    [InlineData("tags", AuditActions.TagAssigned)]
    [InlineData("models", AuditActions.TentModelCreated)]
    [InlineData("accounts", AuditActions.InviteCreated)]
    public async Task GetActivity_FiltersByCategory(string category, string expectedAction)
    {
        await EnsureTestUserExistsAsync();
        var tentId = await CreateTentAsync($"Catégorie {category}");
        var partKindId = await GetFirstPartKindIdAsync();
        await ResetAuditEventsAsync();
        await InsertAuditEventsAsync(
            Event(AuditActions.TentArchived, DateTime.UtcNow.AddDays(-1), "Tent", tentId),
            Event(AuditActions.PartStateChanged, DateTime.UtcNow.AddDays(-1), "Part", Guid.NewGuid(),
                $$"""{"tentId":"{{tentId}}","partKindId":"{{partKindId}}","oldState":"Good","newState":"Good"}"""),
            Event(AuditActions.TagAssigned, DateTime.UtcNow.AddDays(-1), "TentTag", tentId,
                """{"tagName":"Groupe A"}"""),
            Event(AuditActions.TentModelCreated, DateTime.UtcNow.AddDays(-1), "TentModel", Guid.NewGuid(),
                """{"name":"Canadienne"}"""),
            Event(AuditActions.InviteCreated, DateTime.UtcNow.AddDays(-1), "Invite", Guid.NewGuid(),
                """{"code":"ABC123"}"""));

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync($"/api/activity?category={category}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var page = await response.Content.ReadFromJsonAsync<ActivityPageApi>();
        Assert.NotNull(page);
        var item = Assert.Single(page.Items);
        Assert.Equal(expectedAction, item.Action);
        Assert.Equal(category, item.Category);
    }

    [Theory]
    [InlineData("tents")]
    [InlineData("accounts")]
    public async Task GetActivity_AccountSignInEventsNeverAppear(string category)
    {
        await EnsureTestUserExistsAsync();
        await ResetAuditEventsAsync();
        await InsertAuditEventsAsync(
            Event(AuditActions.UserLoginSucceeded, DateTime.UtcNow.AddHours(-1), "User", Guid.NewGuid()),
            Event(AuditActions.UserRefreshTokenRotated, DateTime.UtcNow.AddHours(-1), "RefreshToken", Guid.NewGuid()),
            Event(AuditActions.UserLogoutSucceeded, DateTime.UtcNow.AddHours(-1), "User", Guid.NewGuid()),
            Event(AuditActions.InviteCreated, DateTime.UtcNow.AddHours(-1), "Invite", Guid.NewGuid(),
                """{"code":"ABC123"}"""));

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync($"/api/activity?category={category}&window=all");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var page = await response.Content.ReadFromJsonAsync<ActivityPageApi>();
        Assert.NotNull(page);
        Assert.DoesNotContain(page.Items, i => i.Action == AuditActions.UserLoginSucceeded);
        Assert.DoesNotContain(page.Items, i => i.Action == AuditActions.UserRefreshTokenRotated);
        Assert.DoesNotContain(page.Items, i => i.Action == AuditActions.UserLogoutSucceeded);
    }

    [Fact]
    public async Task GetActivity_ReturnsNewestFirst()
    {
        await EnsureTestUserExistsAsync();
        await ResetAuditEventsAsync();
        var now = DateTime.UtcNow;
        await InsertAuditEventsAsync(
            Event(AuditActions.TentCreated, now.AddHours(-3), "Tent", Guid.NewGuid()),
            Event(AuditActions.TentArchived, now.AddHours(-1), "Tent", Guid.NewGuid()),
            Event(AuditActions.TentUnarchived, now.AddHours(-2), "Tent", Guid.NewGuid()));

        using var client = CreateAuthenticatedClient();
        var page = await client.GetFromJsonAsync<ActivityPageApi>("/api/activity?window=all");

        Assert.NotNull(page);
        Assert.Equal(
            new[]
            {
                AuditActions.TentArchived,
                AuditActions.TentUnarchived,
                AuditActions.TentCreated
            },
            page.Items.Select(i => i.Action).ToArray());
    }

    [Fact]
    public async Task GetActivity_PagesWithCursorWithoutRepeatsOrGaps()
    {
        await EnsureTestUserExistsAsync();
        await ResetAuditEventsAsync();
        var occurredAt = DateTime.UtcNow.AddHours(-2);
        var events = Enumerable.Range(0, 5)
            .Select(_ => Event(AuditActions.TentCreated, occurredAt, "Tent", Guid.NewGuid()))
            .ToList();
        await InsertAuditEventsAsync(events.ToArray());

        using var client = CreateAuthenticatedClient();
        var seenIds = new List<Guid>();
        string? cursor = null;

        for (var pageNumber = 0; pageNumber < 10; pageNumber++)
        {
            var url = $"/api/activity?window=all&limit=2";
            if (cursor != null) url += $"&cursor={Uri.EscapeDataString(cursor)}";

            var page = await client.GetFromJsonAsync<ActivityPageApi>(url);
            Assert.NotNull(page);
            seenIds.AddRange(page.Items.Select(i => i.Id));
            cursor = page.NextCursor;
            if (cursor == null) break;
        }

        Assert.Null(cursor);
        Assert.Equal(5, seenIds.Count);
        Assert.Equal(5, seenIds.Distinct().Count());
        Assert.Equal(
            events.Select(e => e.Id).OrderBy(id => id.ToString()).ToList(),
            seenIds.OrderBy(id => id.ToString()).ToList());
    }

    [Theory]
    [InlineData("limit=0")]
    [InlineData("limit=51")]
    [InlineData("category=invalid")]
    [InlineData("window=12")]
    [InlineData("cursor=not-a-cursor")]
    public async Task GetActivity_InvalidParameters_ReturnInvalidRequest(string query)
    {
        await EnsureTestUserExistsAsync();
        using var client = CreateAuthenticatedClient();

        var response = await client.GetAsync($"/api/activity?{query}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("INVALID_REQUEST", payload.Code);
    }

    [Fact]
    public async Task GetActivity_WithoutAuthentication_Returns401()
    {
        using var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });

        var response = await client.GetAsync("/api/activity");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetActivity_ResolvesTentNameFromTentsThenMetadataThenDeletedFallback()
    {
        await EnsureTestUserExistsAsync();
        var tentId = await CreateTentAsync("Tente résolue");
        await ResetAuditEventsAsync();
        var withTent = Event(AuditActions.TentArchived, DateTime.UtcNow.AddHours(-3), "Tent", tentId);
        var withMetadata = Event(AuditActions.TentArchived, DateTime.UtcNow.AddHours(-2), "Tent", Guid.NewGuid(),
            """{"tentName":"Tente disparue"}""");
        var withoutMetadata = Event(AuditActions.TentArchived, DateTime.UtcNow.AddHours(-1), "Tent", Guid.NewGuid());
        await InsertAuditEventsAsync(withTent, withMetadata, withoutMetadata);

        using var client = CreateAuthenticatedClient();
        var page = await client.GetFromJsonAsync<ActivityPageApi>("/api/activity?window=all");

        Assert.NotNull(page);
        Assert.Equal(3, page.Items.Count);
        Assert.Equal("Tente résolue", page.Items.Single(i => i.Id == withTent.Id).TentName);
        Assert.Equal("Tente disparue", page.Items.Single(i => i.Id == withMetadata.Id).TentName);
        Assert.Equal("Tente supprimée", page.Items.Single(i => i.Id == withoutMetadata.Id).TentName);
    }

    [Fact]
    public async Task GetActivity_ResolvesPartEventsToTheirTentAndSubject()
    {
        await EnsureTestUserExistsAsync();
        var tentId = await CreateTentAsync("Tente pièce");
        var partKindId = await GetFirstPartKindIdAsync();
        await ResetAuditEventsAsync();
        var auditEvent = Event(AuditActions.PartStateChanged, DateTime.UtcNow.AddHours(-1), "Part", Guid.NewGuid(),
            $$"""{"tentId":"{{tentId}}","partKindId":"{{partKindId}}","oldState":"Good","newState":"NeedsRepair","partName":"Toile"}""");
        await InsertAuditEventsAsync(auditEvent);
        string partKindName;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            partKindName = await db.PartKinds.Where(pk => pk.Id == partKindId).Select(pk => pk.Name).FirstAsync();
        }

        using var client = CreateAuthenticatedClient();
        var page = await client.GetFromJsonAsync<ActivityPageApi>("/api/activity?window=all");

        Assert.NotNull(page);
        var item = Assert.Single(page.Items);
        Assert.Equal(tentId, item.TentId);
        Assert.Equal("Tente pièce", item.TentName);
        Assert.Equal(partKindName, item.SubjectName);
        var detail = Assert.Single(item.Details);
        Assert.Equal("État", detail.Label);
        Assert.Equal("Good", detail.OldValue);
        Assert.Equal("NeedsRepair", detail.NewValue);
        Assert.Equal("state", detail.ValueType);
    }

    [Fact]
    public async Task GetActivity_ResolvesTagAssignmentsToTheirTent()
    {
        await EnsureTestUserExistsAsync();
        var tentId = await CreateTentAsync("Tente étiquette");
        await ResetAuditEventsAsync();
        await InsertAuditEventsAsync(
            Event(AuditActions.TagAssigned, DateTime.UtcNow.AddHours(-1), "TentTag", tentId,
                """{"tagId":"11111111-1111-1111-1111-111111111111","tagName":"Groupe A"}"""));

        using var client = CreateAuthenticatedClient();
        var page = await client.GetFromJsonAsync<ActivityPageApi>("/api/activity?window=all");

        Assert.NotNull(page);
        var item = Assert.Single(page.Items);
        Assert.Equal(tentId, item.TentId);
        Assert.Equal("Tente étiquette", item.TentName);
        Assert.Equal("Groupe A", item.SubjectName);
        var detail = Assert.Single(item.Details);
        Assert.Equal("Étiquette", detail.Label);
        Assert.Equal("Groupe A", detail.Value);
    }

    [Fact]
    public async Task GetActivity_RendersSystemActorAsSysteme()
    {
        await EnsureTestUserExistsAsync();
        await ResetAuditEventsAsync();
        await InsertAuditEventsAsync(
            Event(AuditActions.TentCreated, DateTime.UtcNow.AddHours(-1), "Tent", Guid.NewGuid(),
                actorUserId: SystemUserId));

        using var client = CreateAuthenticatedClient();
        var page = await client.GetFromJsonAsync<ActivityPageApi>("/api/activity?window=all");

        Assert.NotNull(page);
        var item = Assert.Single(page.Items);
        Assert.Equal(SystemUserId, item.ActorUserId);
        Assert.Equal("Système", item.ActorDisplayName);
    }

    [Fact]
    public async Task GetActivity_WindowAll_IncludesEventsOlderThanThirtyDays()
    {
        await EnsureTestUserExistsAsync();
        await ResetAuditEventsAsync();
        var oldEvent = Event(AuditActions.TentCreated, DateTime.UtcNow.AddDays(-200), "Tent", Guid.NewGuid(),
            """{"tentName":"Ancienne tente"}""");
        await InsertAuditEventsAsync(oldEvent);

        using var client = CreateAuthenticatedClient();
        var defaultPage = await client.GetFromJsonAsync<ActivityPageApi>("/api/activity");
        var allPage = await client.GetFromJsonAsync<ActivityPageApi>("/api/activity?window=all");

        Assert.NotNull(defaultPage);
        Assert.Empty(defaultPage.Items);
        Assert.NotNull(allPage);
        Assert.Single(allPage.Items);
    }

    private static AuditEvent Event(
        string action,
        DateTime occurredAt,
        string? targetEntityType,
        Guid? targetEntityId,
        string? metadataJson = null,
        Guid? actorUserId = null)
    {
        return new AuditEvent
        {
            Id = Guid.NewGuid(),
            Action = action,
            ActorUserId = actorUserId ?? CustomApiFactory.TestUserId,
            OccurredAt = occurredAt,
            TargetEntityType = targetEntityType,
            TargetEntityId = targetEntityId,
            MetadataJson = metadataJson
        };
    }

    private async Task ResetAuditEventsAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        db.AuditEvents.RemoveRange(db.AuditEvents);
        await db.SaveChangesAsync();
    }

    private async Task InsertAuditEventsAsync(params AuditEvent[] events)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        db.AuditEvents.AddRange(events);
        await db.SaveChangesAsync();
    }

    private async Task<Guid> CreateTentAsync(string name)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var modelId = await db.TentModels.OrderBy(m => m.DisplayOrder).Select(m => m.Id).FirstAsync();
        var tent = new Tent
        {
            Id = Guid.NewGuid(),
            Name = name,
            Size = 4,
            TentModelId = modelId,
            OverallState = TentOverallState.Good,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        };
        db.Tents.Add(tent);
        await db.SaveChangesAsync();
        return tent.Id;
    }

    private async Task<Guid> GetFirstPartKindIdAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        return await db.PartKinds.Select(pk => pk.Id).FirstAsync();
    }

    private HttpClient CreateAuthenticatedClient()
    {
        var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });

        client.DefaultRequestHeaders.Authorization =
            new AuthenticationHeaderValue(TestAuthHandler.SchemeName, "integration");
        return client;
    }

    private async Task EnsureTestUserExistsAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();

        if (await db.Users.IgnoreQueryFilters().AnyAsync(u => u.Id == CustomApiFactory.TestUserId))
        {
            return;
        }

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

    private sealed class ActivityPageApi
    {
        public List<ActivityItemApi> Items { get; set; } = [];
        public string? NextCursor { get; set; }
    }

    private sealed class ActivityItemApi
    {
        public Guid Id { get; set; }
        public string Action { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;
        public DateTime OccurredAt { get; set; }
        public Guid ActorUserId { get; set; }
        public string ActorDisplayName { get; set; } = string.Empty;
        public Guid? TentId { get; set; }
        public string? TentName { get; set; }
        public string? SubjectName { get; set; }
        public List<ActivityDetailApi> Details { get; set; } = [];
    }

    private sealed class ActivityDetailApi
    {
        public string Label { get; set; } = string.Empty;
        public string? OldValue { get; set; }
        public string? NewValue { get; set; }
        public string? Value { get; set; }
        public string? ValueType { get; set; }
    }

    private sealed class ErrorPayload
    {
        public string Error { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
    }
}
