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
    public async Task UpdatePartState_WithComments_UpdatesCommentsAndReturnsEnvelope()
    {
        var (partId, _, _, oldUpdatedAt) = await SeedPartAsync(isArchived: false, state: PartState.Good, comments: "old");

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/parts/{partId}", new { state = "Good", comments = "  nouveau commentaire  " });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<PartApiDto>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.Equal("Good", payload.Data.State);
        Assert.Equal("nouveau commentaire", payload.Data.Comments);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var part = await db.Parts.FirstAsync(p => p.Id == partId);
        Assert.Equal("nouveau commentaire", part.Comments);
        Assert.True(part.UpdatedAt > oldUpdatedAt);
    }

    [Fact]
    public async Task UpdatePartState_WithTooLongComments_ReturnsPartCommentsTooLong()
    {
        var (partId, _, _, _) = await SeedPartAsync(isArchived: false, state: PartState.Good, comments: null);

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/parts/{partId}", new { state = "Good", comments = new string('x', 501) });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("PART_COMMENTS_TOO_LONG", payload.Code);
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

    [Fact]
    public async Task AddPartsToTent_WithValidPartKinds_AddsPartsAndReturnsEnvelope()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();

        var userExists = await db.Users.IgnoreQueryFilters().AnyAsync(u => u.Id == CustomApiFactory.TestUserId);
        if (!userExists)
        {
            db.Users.Add(new User
            {
                Id = CustomApiFactory.TestUserId,
                Username = "add_parts_test_user",
                PasswordHash = "hash",
                CreatedAt = DateTime.UtcNow,
                IsDeleted = false
            });
            await db.SaveChangesAsync();
        }

        var shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();
        var partKinds = await db.PartKinds.OrderBy(x => x.DisplayOrder).ToListAsync();

        var tentId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        db.Tents.Add(new Tent
        {
            Id = tentId,
            Name = $"AddPartsTest-{Guid.NewGuid():N}",
            Size = 4,
            TentModelId = shapeId,
            OverallState = TentOverallState.Good,
            IsArchived = false,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        });
        await db.SaveChangesAsync();

        var newPartKindIds = partKinds.Skip(2).Take(2).Select(pk => pk.Id).ToList();

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync($"/api/tents/{tentId}/parts", new { partKindIds = newPartKindIds });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<PartApiDto>>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.Equal(2, payload.Data.Count);

        foreach (var dto in payload.Data)
        {
            Assert.NotEqual(Guid.Empty, dto.Id);
            Assert.Equal("Good", dto.State);
        }

        var audit = await db.AuditEvents
            .Where(a => a.Action == "part_added"
                && a.MetadataJson != null
                && a.MetadataJson.Contains(tentId.ToString()))
            .ToListAsync();
        Assert.Equal(2, audit.Count);
        Assert.All(audit, a => Assert.Contains("partKindId", a.MetadataJson));
    }

    [Fact]
    public async Task AddPartsToTent_WithDuplicatePartKind_ReturnsDuplicatePart()
    {
        var (partId, tentId, partKindId, _) = await SeedPartAsync(isArchived: false, state: PartState.Good, comments: null);

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync($"/api/tents/{tentId}/parts", new { partKindIds = new[] { partKindId } });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("DUPLICATE_PART", payload.Code);
    }

    [Fact]
    public async Task AddPartsToTent_WithDuplicatePartKindIdsInRequest_ReturnsDuplicatePart()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();
        var partKindId = await db.PartKinds.Select(x => x.Id).FirstAsync();

        var tentId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        db.Tents.Add(new Tent
        {
            Id = tentId,
            Name = $"DuplicateRequest-{Guid.NewGuid():N}",
            Size = 4,
            TentModelId = shapeId,
            OverallState = TentOverallState.Good,
            IsArchived = false,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        });
        await db.SaveChangesAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync($"/api/tents/{tentId}/parts", new { partKindIds = new[] { partKindId, partKindId } });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("DUPLICATE_PART", payload.Code);
        Assert.False(await db.Parts.AnyAsync(p => p.TentId == tentId));
    }

    [Fact]
    public async Task AddPartsToTent_WithInvalidPartKindId_ReturnsInvalidPartKind()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();

        var tentId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        db.Tents.Add(new Tent
        {
            Id = tentId,
            Name = $"InvalidPK-{Guid.NewGuid():N}",
            Size = 4,
            TentModelId = shapeId,
            OverallState = TentOverallState.Good,
            IsArchived = false,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        });
        await db.SaveChangesAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync($"/api/tents/{tentId}/parts", new { partKindIds = new[] { Guid.NewGuid() } });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("INVALID_PART_KIND", payload.Code);
    }

    [Fact]
    public async Task AddPartsToTent_ForArchivedTent_ReturnsTentArchived()
    {
        var (partId, tentId, partKindId, _) = await SeedPartAsync(isArchived: true, state: PartState.Good, comments: null);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var otherPartKind = await db.PartKinds.Where(pk => pk.Id != partKindId).Select(pk => pk.Id).FirstAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync($"/api/tents/{tentId}/parts", new { partKindIds = new[] { otherPartKind } });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TENT_ARCHIVED", payload.Code);
    }

    [Fact]
    public async Task AddPartsToTent_ForUnknownTent_ReturnsTentNotFound()
    {
        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync($"/api/tents/{Guid.NewGuid()}/parts", new { partKindIds = new[] { Guid.NewGuid() } });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TENT_NOT_FOUND", payload.Code);
    }

    [Fact]
    public async Task AddPartsToTent_WithEmptyRequest_ReturnsInvalidRequest()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();

        var tentId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        db.Tents.Add(new Tent
        {
            Id = tentId,
            Name = $"EmptyReq-{Guid.NewGuid():N}",
            Size = 4,
            TentModelId = shapeId,
            OverallState = TentOverallState.Good,
            IsArchived = false,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        });
        await db.SaveChangesAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync($"/api/tents/{tentId}/parts", new { partKindIds = new List<Guid>() });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("INVALID_REQUEST", payload.Code);
    }

    [Fact]
    public async Task DeletePart_WithValidId_RemovesPartAndReturnsNoContent()
    {
        var (partId, tentId, partKindId, _) = await SeedPartAsync(isArchived: false, state: PartState.Good, comments: null);

        using var preScope = _factory.Services.CreateScope();
        var preDb = preScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        Assert.True(await preDb.Parts.AnyAsync(p => p.Id == partId));

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/parts/{partId}");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        using var postScope = _factory.Services.CreateScope();
        var postDb = postScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        Assert.False(await postDb.Parts.AnyAsync(p => p.Id == partId));

        var audit = await postDb.AuditEvents
            .Where(a => a.Action == "part_deleted" && a.TargetEntityId == partId)
            .FirstOrDefaultAsync();
        Assert.NotNull(audit);
        Assert.Equal(CustomApiFactory.TestUserId, audit.ActorUserId);
        Assert.Contains("tentId", audit.MetadataJson);
        Assert.Contains("partKindId", audit.MetadataJson);
    }

    [Fact]
    public async Task DeletePart_WithUnknownId_ReturnsPartNotFound()
    {
        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/parts/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("PART_NOT_FOUND", payload.Code);
    }

    [Fact]
    public async Task DeletePart_ForArchivedTent_ReturnsTentArchived()
    {
        var (partId, _, _, _) = await SeedPartAsync(isArchived: true, state: PartState.Good, comments: null);

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/parts/{partId}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TENT_ARCHIVED", payload.Code);
    }

    [Fact]
    public async Task DeletePart_WithoutAuthentication_ReturnsUnauthorized()
    {
        var (partId, _, _, _) = await SeedPartAsync(isArchived: false, state: PartState.Good, comments: null);
        using var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });

        var response = await client.DeleteAsync($"/api/parts/{partId}");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task AddPartsToTent_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });

        var response = await client.PostAsJsonAsync($"/api/tents/{Guid.NewGuid()}/parts", new { partKindIds = new[] { Guid.NewGuid() } });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task AddPartsToTent_ReturnsPartKindDisplayOrder()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();

        var userExists = await db.Users.IgnoreQueryFilters().AnyAsync(u => u.Id == CustomApiFactory.TestUserId);
        if (!userExists)
        {
            db.Users.Add(new User
            {
                Id = CustomApiFactory.TestUserId,
                Username = "display_order_test_user",
                PasswordHash = "hash",
                CreatedAt = DateTime.UtcNow,
                IsDeleted = false
            });
            await db.SaveChangesAsync();
        }

        var shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();
        var partKinds = await db.PartKinds.OrderBy(x => x.DisplayOrder).ToListAsync();

        var tentId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        db.Tents.Add(new Tent
        {
            Id = tentId,
            Name = $"DisplayOrderTest-{Guid.NewGuid():N}",
            Size = 4,
            TentModelId = shapeId,
            OverallState = TentOverallState.Good,
            IsArchived = false,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        });
        await db.SaveChangesAsync();

        var firstKind = partKinds[0];
        var lastKind = partKinds[^1];

        using var client = CreateAuthenticatedClient();
        var firstResponse = await client.PostAsJsonAsync($"/api/tents/{tentId}/parts", new { partKindIds = new[] { firstKind.Id } });
        Assert.Equal(HttpStatusCode.OK, firstResponse.StatusCode);
        var firstPayload = await firstResponse.Content.ReadFromJsonAsync<DataEnvelope<List<PartApiDto>>>();
        Assert.NotNull(firstPayload);
        Assert.NotNull(firstPayload.Data);
        Assert.Single(firstPayload.Data);
        Assert.Equal(firstKind.DisplayOrder, firstPayload.Data[0].DisplayOrder);

        var secondResponse = await client.PostAsJsonAsync($"/api/tents/{tentId}/parts", new { partKindIds = new[] { lastKind.Id } });
        Assert.Equal(HttpStatusCode.OK, secondResponse.StatusCode);
        var secondPayload = await secondResponse.Content.ReadFromJsonAsync<DataEnvelope<List<PartApiDto>>>();
        Assert.NotNull(secondPayload);
        Assert.NotNull(secondPayload.Data);
        Assert.Single(secondPayload.Data);
        Assert.Equal(lastKind.DisplayOrder, secondPayload.Data[0].DisplayOrder);
    }

    [Fact]
    public async Task DeletePart_RemovingAllParts_IsValid()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();

        var userExists = await db.Users.IgnoreQueryFilters().AnyAsync(u => u.Id == CustomApiFactory.TestUserId);
        if (!userExists)
        {
            db.Users.Add(new User
            {
                Id = CustomApiFactory.TestUserId,
                Username = "all_parts_test_user",
                PasswordHash = "hash",
                CreatedAt = DateTime.UtcNow,
                IsDeleted = false
            });
            await db.SaveChangesAsync();
        }

        var shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();
        var partKinds = await db.PartKinds.OrderBy(x => x.DisplayOrder).ToListAsync();

        var tentId = Guid.NewGuid();
        var now = DateTime.UtcNow;

        db.Tents.Add(new Tent
        {
            Id = tentId,
            Name = $"AllPartsTest-{Guid.NewGuid():N}",
            Size = 4,
            TentModelId = shapeId,
            OverallState = TentOverallState.Good,
            IsArchived = false,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        });

        var partIds = new List<Guid>();
        foreach (var pk in partKinds)
        {
            var pid = Guid.NewGuid();
            partIds.Add(pid);
            db.Parts.Add(new Part
            {
                Id = pid,
                TentId = tentId,
                PartKindId = pk.Id,
                State = PartState.Good,
                Comments = null,
                CreatedAt = now,
                UpdatedAt = now,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
        }
        await db.SaveChangesAsync();

        using var client = CreateAuthenticatedClient();
        foreach (var pid in partIds)
        {
            var deleteResponse = await client.DeleteAsync($"/api/parts/{pid}");
            Assert.Equal(HttpStatusCode.NoContent, deleteResponse.StatusCode);
        }

        using var postScope = _factory.Services.CreateScope();
        var postDb = postScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var remainingParts = await postDb.Parts.Where(p => p.TentId == tentId).CountAsync();
        Assert.Equal(0, remainingParts);
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

        var shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();
        var partKind = await db.PartKinds.OrderBy(x => x.DisplayOrder).FirstAsync();

        var tentId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        db.Tents.Add(new Tent
        {
            Id = tentId,
            Name = $"Tent-{Guid.NewGuid():N}",
            Size = 4,
            TentModelId = shapeId,
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
        public Guid PartKindId { get; set; }
        public string PartKindName { get; set; } = string.Empty;
        public int DisplayOrder { get; set; }
        public string State { get; set; } = string.Empty;
        public string? Comments { get; set; }
    }

    private sealed class ErrorPayload
    {
        public string Code { get; set; } = string.Empty;
    }
}
