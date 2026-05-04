using System;
using System.Linq;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;
using Xunit;

namespace ScoutBoxApi.Tests.Controllers;

public class PartsControllerIntegrationTests : IClassFixture<CustomApiFactory>
{
    private readonly CustomApiFactory _factory;

    public PartsControllerIntegrationTests(CustomApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task UpdatePartState_WithValidState_UpdatesPartAndReturnsEnvelope()
    {
        var (partId, tentId, partKindId, oldUpdatedAt) = await SeedPartAsync(isArchived: false, state: PartState.Good, comments: "ok");

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/parts/{partId}", new { state = "NeedsRepair" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<PartApiDto>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.Equal(partId, payload.Data.Id);
        Assert.Equal("NeedsRepair", payload.Data.State);
        Assert.Equal("ok", payload.Data.Comments);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var part = await db.Parts.FirstAsync(p => p.Id == partId);
        Assert.Equal(PartState.NeedsRepair, part.State);
        Assert.Equal(CustomApiFactory.TestUserId, part.UpdatedByUserId);
        Assert.True(part.UpdatedAt > oldUpdatedAt);

        var audit = await db.AuditEvents
            .Where(a => a.Action == "part_state_changed" && a.TargetEntityId == partId)
            .OrderByDescending(a => a.OccurredAt)
            .FirstOrDefaultAsync();
        Assert.NotNull(audit);
        Assert.Equal(CustomApiFactory.TestUserId, audit.ActorUserId);
        Assert.Equal("Part", audit.TargetEntityType);
        Assert.Contains(tentId.ToString(), audit.MetadataJson);
        Assert.Contains(partKindId.ToString(), audit.MetadataJson);
        Assert.Contains("oldState", audit.MetadataJson);
        Assert.Contains("newState", audit.MetadataJson);
    }

    [Fact]
    public async Task UpdatePartState_WithSameState_DoesNotMutateTimestampOrCreateAudit()
    {
        var (partId, _, _, oldUpdatedAt) = await SeedPartAsync(isArchived: false, state: PartState.Missing, comments: null);

        using var preScope = _factory.Services.CreateScope();
        var preDb = preScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var beforeAuditCount = await preDb.AuditEvents.CountAsync(a => a.Action == "part_state_changed" && a.TargetEntityId == partId);

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/parts/{partId}", new { state = "Missing" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using var postScope = _factory.Services.CreateScope();
        var postDb = postScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var part = await postDb.Parts.FirstAsync(p => p.Id == partId);
        var afterAuditCount = await postDb.AuditEvents.CountAsync(a => a.Action == "part_state_changed" && a.TargetEntityId == partId);

        Assert.Equal(oldUpdatedAt, part.UpdatedAt);
        Assert.Equal(beforeAuditCount, afterAuditCount);
    }

    [Fact]
    public async Task UpdatePartState_WithInvalidState_ReturnsInvalidPartState()
    {
        var (partId, _, _, _) = await SeedPartAsync(isArchived: false, state: PartState.Good, comments: null);
        using var client = CreateAuthenticatedClient();

        var response = await client.PutAsJsonAsync($"/api/parts/{partId}", new { state = "good" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("INVALID_PART_STATE", payload.Code);
    }

    [Fact]
    public async Task UpdatePartState_WithoutAuthentication_ReturnsUnauthorized()
    {
        var (partId, _, _, _) = await SeedPartAsync(isArchived: false, state: PartState.Good, comments: null);
        using var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });

        var response = await client.PutAsJsonAsync($"/api/parts/{partId}", new { state = "Missing" });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [InlineData("{}")]
    [InlineData("{\"state\":null}")]
    [InlineData("{\"state\":\"\"}")]
    [InlineData("{\"state\":\"   \"}")]
    public async Task UpdatePartState_WithInvalidStateShape_ReturnsInvalidPartState(string body)
    {
        var (partId, _, _, _) = await SeedPartAsync(isArchived: false, state: PartState.Good, comments: null);
        using var client = CreateAuthenticatedClient();
        using var content = new StringContent(body, Encoding.UTF8, "application/json");

        var response = await client.PutAsync($"/api/parts/{partId}", content);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("INVALID_PART_STATE", payload.Code);
    }

    [Fact]
    public async Task UpdatePartState_WithUnknownPart_ReturnsPartNotFound()
    {
        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/parts/{Guid.NewGuid()}", new { state = "Good" });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("PART_NOT_FOUND", payload.Code);
    }

    [Fact]
    public async Task UpdatePartState_ForArchivedTent_ReturnsTentArchivedAndNoMutation()
    {
        var (partId, _, _, oldUpdatedAt) = await SeedPartAsync(isArchived: true, state: PartState.Good, comments: null);

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/parts/{partId}", new { state = "Unusable" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TENT_ARCHIVED", payload.Code);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var part = await db.Parts.FirstAsync(p => p.Id == partId);
        Assert.Equal(PartState.Good, part.State);
        Assert.Equal(oldUpdatedAt, part.UpdatedAt);
    }

    private HttpClient CreateAuthenticatedClient()
    {
        var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(TestAuthHandler.SchemeName, "test-token");
        return client;
    }

    private async Task<(Guid PartId, Guid TentId, Guid PartKindId, DateTime UpdatedAt)> SeedPartAsync(bool isArchived, PartState state, string? comments)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();

        var existingUser = await db.Users.IgnoreQueryFilters().FirstOrDefaultAsync(u => u.Id == CustomApiFactory.TestUserId);
        if (existingUser == null)
        {
            db.Users.Add(new User
            {
                Id = CustomApiFactory.TestUserId,
                Username = "parts_test_user",
                PasswordHash = "hash",
                CreatedAt = DateTime.UtcNow,
                IsDeleted = false
            });
            await db.SaveChangesAsync();
        }

        var shapeId = await db.TentShapes.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();
        var partKind = await db.PartKinds.OrderBy(x => x.DisplayOrder).FirstAsync();

        var tentId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        db.Tents.Add(new Tent
        {
            Id = tentId,
            Name = $"Tent-{Guid.NewGuid():N}",
            Size = 4,
            TentShapeId = shapeId,
            OverallState = TentOverallState.Good,
            IsArchived = isArchived,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        });

        var partId = Guid.NewGuid();
        db.Parts.Add(new Part
        {
            Id = partId,
            TentId = tentId,
            PartKindId = partKind.Id,
            State = state,
            Comments = comments,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        });

        await db.SaveChangesAsync();
        return (partId, tentId, partKind.Id, now);
    }

    private sealed class DataEnvelope<T>
    {
        public T Data { get; set; } = default!;
    }

    private sealed class PartApiDto
    {
        public Guid Id { get; set; }
        public string State { get; set; } = string.Empty;
        public string? Comments { get; set; }
    }

    private sealed class ErrorPayload
    {
        public string Code { get; set; } = string.Empty;
    }
}
