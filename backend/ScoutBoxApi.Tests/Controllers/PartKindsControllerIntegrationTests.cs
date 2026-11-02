using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Services;
using Xunit;

namespace ScoutBoxApi.Tests.Controllers;

public class PartKindsControllerIntegrationTests : IClassFixture<CustomApiFactory>
{
    private readonly CustomApiFactory _factory;

    public PartKindsControllerIntegrationTests(CustomApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task GetPartKinds_Authenticated_ReturnsPartKindsWithTentCount()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            db.PartKinds.AddRange(
                new PartKind { Id = Guid.NewGuid(), Name = $"Arceaux {prefix}", DisplayOrder = 2, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow },
                new PartKind { Id = Guid.NewGuid(), Name = $"Sardines {prefix}", DisplayOrder = 1, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow }
            );
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/part-kinds");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<List<PartKindApiDto>>();
        Assert.NotNull(payload);

        var filtered = payload.Where(pk => pk.Name.EndsWith(prefix, StringComparison.Ordinal)).ToList();
        Assert.Equal(2, filtered.Count);
        Assert.Equal($"Sardines {prefix}", filtered[0].Name);
        Assert.Equal($"Arceaux {prefix}", filtered[1].Name);
    }

    [Fact]
    public async Task GetPartKinds_ReturnsTentCount()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        Guid createdPartKindId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var partKindEntity = new PartKind { Id = Guid.NewGuid(), Name = $"TentCount Test {prefix}", DisplayOrder = 1, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
            db.PartKinds.Add(partKindEntity);
            await db.SaveChangesAsync();
            createdPartKindId = partKindEntity.Id;

            var modelId = await db.TentModels.Where(m => m.IsActive).OrderBy(m => m.DisplayOrder).Select(m => m.Id).FirstAsync();
            var tent = new Tent
            {
                Id = Guid.NewGuid(),
                Name = $"PartKind Tent Count {prefix}",
                Size = 6,
                TentModelId = modelId,
                OverallState = TentOverallState.Good,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            };
            db.Tents.Add(tent);
            db.Parts.Add(new Part
            {
                Id = Guid.NewGuid(),
                TentId = tent.Id,
                PartKindId = createdPartKindId,
                State = PartState.Good,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/part-kinds");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<List<PartKindApiDto>>();
        Assert.NotNull(payload);

        var result = payload.FirstOrDefault(pk => pk.Id == createdPartKindId);
        Assert.NotNull(result);
        Assert.Equal(1, result.TentCount);
    }

    [Fact]
    public async Task GetPartKinds_WhenEmpty_ReturnsEmptyList()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/part-kinds");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<List<PartKindApiDto>>();
        Assert.NotNull(payload);
    }

    [Fact]
    public async Task GetPartKinds_Unauthorized_ReturnsUnauthorized()
    {
        using var client = _factory.CreateClient();
        var response = await client.GetAsync("/api/part-kinds");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task CreatePartKind_WithValidName_ReturnsCreatedPartKind()
    {
        await EnsureTestUserExistsAsync();
        var name = "Arceaux " + Guid.NewGuid().ToString("N");
        if (name.Length > 60) name = name[..60];

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/part-kinds", new { name });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<PartKindApiDto>();
        Assert.NotNull(payload);
        Assert.Equal(name, payload.Name);
        Assert.Equal(0, payload.TentCount);
    }

    [Fact]
    public async Task CreatePartKind_DuplicateName_ReturnsBadRequest()
    {
        await EnsureTestUserExistsAsync();
        var name = "Arceaux " + Guid.NewGuid().ToString("N");
        if (name.Length > 60) name = name[..60];

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            db.PartKinds.Add(new PartKind
            {
                Id = Guid.NewGuid(),
                Name = name,
                DisplayOrder = 1,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/part-kinds", new { name });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("PART_KIND_NAME_EXISTS", payload.Code);
    }

    [Fact]
    public async Task CreatePartKind_DuplicateNameDifferentCase_ReturnsBadRequest()
    {
        await EnsureTestUserExistsAsync();
        var suffix = Guid.NewGuid().ToString("N")[..8];
        var existingName = $"Arceaux {suffix}";

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            db.PartKinds.Add(new PartKind
            {
                Id = Guid.NewGuid(),
                Name = existingName,
                DisplayOrder = 1,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/part-kinds", new { name = existingName.ToLowerInvariant() });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("PART_KIND_NAME_EXISTS", payload.Code);
    }

    [Fact]
    public async Task CreatePartKind_NullBody_ReturnsNameRequired()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync<object?>("/api/part-kinds", null);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("PART_KIND_NAME_REQUIRED", payload.Code);
    }

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    public async Task CreatePartKind_EmptyName_ReturnsBadRequest(string name)
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/part-kinds", new { name });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("PART_KIND_NAME_REQUIRED", payload.Code);
    }

    [Fact]
    public async Task RenamePartKind_WithValidName_ReturnsUpdated()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        Guid pkId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var pk = new PartKind
            {
                Id = Guid.NewGuid(),
                Name = $"Old Name {prefix}",
                DisplayOrder = 1,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.PartKinds.Add(pk);
            await db.SaveChangesAsync();
            pkId = pk.Id;
        }

        var newName = $"New Name {prefix}";
        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/part-kinds/{pkId}", new { name = newName });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<PartKindApiDto>();
        Assert.NotNull(payload);
        Assert.Equal(newName, payload.Name);
    }

    [Fact]
    public async Task RenamePartKind_DuplicateName_ReturnsBadRequest()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        Guid renameId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            db.PartKinds.Add(new PartKind { Id = Guid.NewGuid(), Name = $"Existing {prefix}", DisplayOrder = 1, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow });
            var pk = new PartKind { Id = Guid.NewGuid(), Name = $"To Rename {prefix}", DisplayOrder = 2, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
            db.PartKinds.Add(pk);
            await db.SaveChangesAsync();
            renameId = pk.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/part-kinds/{renameId}", new { name = $"Existing {prefix}" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("PART_KIND_NAME_EXISTS", payload.Code);
    }

    [Fact]
    public async Task RenamePartKind_DuplicateNameDifferentCase_ReturnsBadRequest()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        Guid renameId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            db.PartKinds.Add(new PartKind { Id = Guid.NewGuid(), Name = $"Existing {prefix}", DisplayOrder = 1, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow });
            var pk = new PartKind { Id = Guid.NewGuid(), Name = $"To Rename {prefix}", DisplayOrder = 2, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
            db.PartKinds.Add(pk);
            await db.SaveChangesAsync();
            renameId = pk.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/part-kinds/{renameId}", new { name = $"existing {prefix}" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("PART_KIND_NAME_EXISTS", payload.Code);
    }

    [Fact]
    public async Task RenamePartKind_NullBody_ReturnsNameRequired()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        Guid pkId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var pk = new PartKind { Id = Guid.NewGuid(), Name = $"Null Rename {prefix}", DisplayOrder = 1, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
            db.PartKinds.Add(pk);
            await db.SaveChangesAsync();
            pkId = pk.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync<object?>($"/api/part-kinds/{pkId}", null);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("PART_KIND_NAME_REQUIRED", payload.Code);
    }

    [Fact]
    public async Task RenamePartKind_NonExistent_ReturnsNotFound()
    {
        await EnsureTestUserExistsAsync();
        var id = Guid.NewGuid();

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/part-kinds/{id}", new { name = "New Name" });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task DeletePartKind_WithNoUsages_ReturnsNoContent()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        Guid pkId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var pk = new PartKind
            {
                Id = Guid.NewGuid(),
                Name = $"To Delete {prefix}",
                DisplayOrder = 1,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.PartKinds.Add(pk);
            await db.SaveChangesAsync();
            pkId = pk.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/part-kinds/{pkId}");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task DeletePartKind_WithPartsOnTents_ReturnsNoContentAndDeletesParts()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        Guid pkId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var pk = new PartKind { Id = Guid.NewGuid(), Name = $"With Parts {prefix}", DisplayOrder = 1, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
            db.PartKinds.Add(pk);
            await db.SaveChangesAsync();
            pkId = pk.Id;

            var modelId = await db.TentModels.Where(m => m.IsActive).OrderBy(m => m.DisplayOrder).Select(m => m.Id).FirstAsync();
            var tent = new Tent
            {
                Id = Guid.NewGuid(),
                Name = $"Parts Cascade {prefix}",
                Size = 6,
                TentModelId = modelId,
                OverallState = TentOverallState.Good,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            };
            db.Tents.Add(tent);
            db.Parts.Add(new Part
            {
                Id = Guid.NewGuid(),
                TentId = tent.Id,
                PartKindId = pkId,
                State = PartState.Good,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/part-kinds/{pkId}");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var parts = await db.Parts.Where(p => p.PartKindId == pkId).ToListAsync();
            Assert.Empty(parts);
            var deleted = await db.PartKinds.FindAsync(pkId);
            Assert.Null(deleted);
        }
    }

    [Fact]
    public async Task DeletePartKind_WithTentModelComponents_ReturnsNoContentAndDeletesComponents()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        Guid pkId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var pk = new PartKind { Id = Guid.NewGuid(), Name = $"With Components {prefix}", DisplayOrder = 1, CreatedAt = DateTime.UtcNow, UpdatedAt = DateTime.UtcNow };
            db.PartKinds.Add(pk);
            await db.SaveChangesAsync();
            pkId = pk.Id;

            var modelId = await db.TentModels.Where(m => m.IsActive).OrderBy(m => m.DisplayOrder).Select(m => m.Id).FirstAsync();
            db.TentModelComponents.Add(new TentModelComponent
            {
                Id = Guid.NewGuid(),
                TentModelId = modelId,
                PartKindId = pkId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/part-kinds/{pkId}");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var components = await db.TentModelComponents.Where(c => c.PartKindId == pkId).ToListAsync();
            Assert.Empty(components);
            var deleted = await db.PartKinds.FindAsync(pkId);
            Assert.Null(deleted);
        }
    }

    [Fact]
    public async Task DeletePartKind_UsedBySeveralTentsAndModels_RecordsSummaryAboveItsConsequences()
    {
        await EnsureTestUserExistsAsync();
        await ResetAuditEventsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];
        var kindName = $"Kind {prefix}";

        var (pkId, tentIds, modelIds) = await SeedUsedPartKindAsync(kindName);

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/part-kinds/{pkId}");
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        var page = await client.GetFromJsonAsync<ActivityPageApi>("/api/activity?window=all");
        Assert.NotNull(page);

        var summary = page.Items[0];
        Assert.Equal(AuditActions.PartKindDeleted, summary.Action);
        Assert.Equal("parts", summary.Category);
        Assert.Equal(kindName, summary.SubjectName);
        Assert.Null(summary.TentId);
        Assert.Equal(2, CountDetail(summary, "Tentes"));
        Assert.Equal(2, CountDetail(summary, "Pièces"));
        Assert.Equal(2, CountDetail(summary, "Modèles de tente"));

        var modelNames = modelIds.Select(id => id.Name).ToList();
        var partItems = page.Items.Where(i => i.Action == AuditActions.PartDeleted).ToList();
        Assert.Equal(2, partItems.Count);
        Assert.All(partItems, item =>
        {
            Assert.Equal(kindName, item.SubjectName);
            Assert.Contains(item.TentId!.Value, tentIds);
            Assert.Equal("part_kind_deleted", Detail(item, "Raison").Value);
        });

        var modelItems = page.Items.Where(i => i.Action == AuditActions.TentModelComponentsChanged).ToList();
        Assert.Equal(2, modelItems.Count);
        Assert.All(modelItems, item =>
        {
            Assert.Contains(item.SubjectName!, modelNames);
            Assert.Equal(kindName, Detail(item, "Modèle de pièce retiré").Value);
            Assert.Equal("part_kind_deleted", Detail(item, "Raison").Value);
        });

        Assert.All(partItems, item => Assert.True(page.Items.IndexOf(summary) < page.Items.IndexOf(item)));
        Assert.All(modelItems, item => Assert.True(page.Items.IndexOf(summary) < page.Items.IndexOf(item)));
    }

    [Fact]
    public async Task DeletePartKind_RecordsOnePieceDeletionInEachAffectedTentHistory()
    {
        await EnsureTestUserExistsAsync();
        await ResetAuditEventsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];
        var kindName = $"Kind {prefix}";

        var (pkId, tentIds, _) = await SeedUsedPartKindAsync(kindName);

        using (var client = CreateAuthenticatedClient())
        {
            var response = await client.DeleteAsync($"/api/part-kinds/{pkId}");
            Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        }

        using var historyClient = CreateAuthenticatedClient();
        foreach (var tentId in tentIds)
        {
            var history = await historyClient.GetFromJsonAsync<List<HistoryItemApi>>($"/api/tents/{tentId}/history");
            Assert.NotNull(history);
            var deletion = Assert.Single(history, h => h.Action == AuditActions.PartDeleted);
            Assert.Equal(kindName, deletion.SubjectName);
            Assert.Equal("part_management", deletion.Category);
            Assert.Equal("part_kind_deleted", Detail(deletion, "Raison").Value);
        }
    }

    [Fact]
    public async Task DeletePartKind_UsedNowhere_RecordsOnlyTheDeletion()
    {
        await EnsureTestUserExistsAsync();
        await ResetAuditEventsAsync();
        var kindName = $"Unused {Guid.NewGuid().ToString("N")[..8]}";

        Guid pkId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var pk = new PartKind
            {
                Id = Guid.NewGuid(),
                Name = kindName,
                DisplayOrder = 100,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.PartKinds.Add(pk);
            await db.SaveChangesAsync();
            pkId = pk.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/part-kinds/{pkId}");
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        var page = await client.GetFromJsonAsync<ActivityPageApi>("/api/activity?window=all");
        Assert.NotNull(page);

        var summary = Assert.Single(page.Items);
        Assert.Equal(AuditActions.PartKindDeleted, summary.Action);
        Assert.Equal(kindName, summary.SubjectName);
        Assert.Equal(0, CountDetail(summary, "Tentes"));
        Assert.Equal(0, CountDetail(summary, "Pièces"));
        Assert.Equal(0, CountDetail(summary, "Modèles de tente"));
    }

    [Fact]
    public async Task DeletePartKind_WhenRecordingTheActFails_RollsBackTheCatalogue()
    {
        using var factory = new CustomApiFactory();
        var client = factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue(TestAuthHandler.SchemeName, "integration");

        Guid pkId;
        Guid partId;
        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var pk = new PartKind
            {
                Id = Guid.NewGuid(),
                Name = $"Rollback {Guid.NewGuid().ToString("N")[..8]}",
                DisplayOrder = 100,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.PartKinds.Add(pk);
            await db.SaveChangesAsync();
            pkId = pk.Id;

            var modelId = await db.TentModels.Select(m => m.Id).FirstAsync();
            var systemUserId = Guid.Parse("00000000-0000-0000-0000-000000000001");
            var tent = new Tent
            {
                Id = Guid.NewGuid(),
                Name = $"Rollback tent {Guid.NewGuid().ToString("N")[..8]}",
                Size = 4,
                TentModelId = modelId,
                OverallState = TentOverallState.Good,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = systemUserId,
                UpdatedByUserId = systemUserId
            };
            db.Tents.Add(tent);

            var part = new Part
            {
                Id = Guid.NewGuid(),
                TentId = tent.Id,
                PartKindId = pkId,
                State = PartState.Good,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = systemUserId,
                UpdatedByUserId = systemUserId
            };
            db.Parts.Add(part);
            await db.SaveChangesAsync();
            partId = part.Id;
        }

        // The test actor is not a stored user, so writing the audit row violates its FK
        // after the bulk deletes have run. The transaction must roll those deletes back.
        var response = await client.DeleteAsync($"/api/part-kinds/{pkId}");
        Assert.Equal(HttpStatusCode.InternalServerError, response.StatusCode);

        using (var scope = factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            Assert.NotNull(await db.PartKinds.FindAsync(pkId));
            Assert.NotNull(await db.Parts.FindAsync(partId));
            Assert.False(await db.AuditEvents.AnyAsync(ae => ae.TargetEntityId == pkId));
        }
    }

    [Fact]
    public async Task DeletePartKind_NonExistent_ReturnsNotFound()
    {
        await EnsureTestUserExistsAsync();
        var id = Guid.NewGuid();

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/part-kinds/{id}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task CreatePartKind_RecordsCreatedEventInJournal()
    {
        await EnsureTestUserExistsAsync();
        await ResetAuditEventsAsync();
        var name = $"Modèle {Guid.NewGuid().ToString("N")[..8]}";

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/part-kinds", new { name });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var page = await client.GetFromJsonAsync<ActivityPageApi>("/api/activity?category=parts&window=all");

        Assert.NotNull(page);
        var item = Assert.Single(page.Items);
        Assert.Equal("part_kind_created", item.Action);
        Assert.Equal("parts", item.Category);
        Assert.Equal(name, item.SubjectName);
        Assert.Equal("integration_test_user", item.ActorDisplayName);
        Assert.Null(item.TentId);
        var detail = Assert.Single(item.Details);
        Assert.Equal("Modèle de pièce", detail.Label);
        Assert.Equal(name, detail.Value);
    }

    [Fact]
    public async Task RenamePartKind_RecordsRenameEventWithOldAndNewName()
    {
        await EnsureTestUserExistsAsync();
        await ResetAuditEventsAsync();
        var suffix = Guid.NewGuid().ToString("N")[..8];
        var oldName = $"Ancien {suffix}";
        var newName = $"Nouveau {suffix}";

        Guid pkId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var pk = new PartKind
            {
                Id = Guid.NewGuid(),
                Name = oldName,
                DisplayOrder = 1,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.PartKinds.Add(pk);
            await db.SaveChangesAsync();
            pkId = pk.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/part-kinds/{pkId}", new { name = newName });
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var page = await client.GetFromJsonAsync<ActivityPageApi>("/api/activity?category=parts&window=all");

        Assert.NotNull(page);
        var item = Assert.Single(page.Items);
        Assert.Equal("part_kind_renamed", item.Action);
        Assert.Equal("parts", item.Category);
        Assert.Equal(newName, item.SubjectName);
        Assert.Equal("integration_test_user", item.ActorDisplayName);
        Assert.Null(item.TentId);
        Assert.Null(item.TentName);
        var detail = Assert.Single(item.Details);
        Assert.Equal("Modèle de pièce", detail.Label);
        Assert.Equal(oldName, detail.OldValue);
        Assert.Equal(newName, detail.NewValue);
        Assert.Equal("old_new", detail.ValueType);
    }

    [Fact]
    public async Task RenamePartKind_WithUnchangedName_RecordsNothingAndKeepsTimestamp()
    {
        await EnsureTestUserExistsAsync();
        await ResetAuditEventsAsync();
        var name = $"Inchangé {Guid.NewGuid().ToString("N")[..8]}";
        var originalUpdatedAt = new DateTime(2026, 1, 15, 8, 30, 0, DateTimeKind.Utc);

        Guid pkId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var pk = new PartKind
            {
                Id = Guid.NewGuid(),
                Name = name,
                DisplayOrder = 1,
                CreatedAt = originalUpdatedAt,
                UpdatedAt = originalUpdatedAt
            };
            db.PartKinds.Add(pk);
            await db.SaveChangesAsync();
            pkId = pk.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/part-kinds/{pkId}", new { name });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            Assert.False(await db.AuditEvents.AnyAsync(ae => ae.TargetEntityId == pkId));
            var stored = await db.PartKinds.FindAsync(pkId);
            Assert.NotNull(stored);
            Assert.Equal(originalUpdatedAt, stored.UpdatedAt);
        }
    }

    private async Task<(Guid PartKindId, List<Guid> TentIds, List<(Guid Id, string Name)> ModelIds)>
        SeedUsedPartKindAsync(string kindName)
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();

        var pk = new PartKind
        {
            Id = Guid.NewGuid(),
            Name = kindName,
            DisplayOrder = 100,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        db.PartKinds.Add(pk);

        var suffix = Guid.NewGuid().ToString("N")[..8];
        var modelA = new TentModel
        {
            Id = Guid.NewGuid(),
            Name = $"Modèle A {suffix}",
            IsActive = true,
            DisplayOrder = 100,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        var modelB = new TentModel
        {
            Id = Guid.NewGuid(),
            Name = $"Modèle B {suffix}",
            IsActive = true,
            DisplayOrder = 101,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        db.TentModels.AddRange(modelA, modelB);

        var tentA = new Tent
        {
            Id = Guid.NewGuid(),
            Name = $"Tente A {suffix}",
            Size = 4,
            TentModelId = modelA.Id,
            OverallState = TentOverallState.Good,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        };
        var tentB = new Tent
        {
            Id = Guid.NewGuid(),
            Name = $"Tente B {suffix}",
            Size = 4,
            TentModelId = modelB.Id,
            OverallState = TentOverallState.Good,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = CustomApiFactory.TestUserId,
            UpdatedByUserId = CustomApiFactory.TestUserId
        };
        db.Tents.AddRange(tentA, tentB);

        db.Parts.AddRange(
            new Part
            {
                Id = Guid.NewGuid(),
                TentId = tentA.Id,
                PartKindId = pk.Id,
                State = PartState.Good,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            },
            new Part
            {
                Id = Guid.NewGuid(),
                TentId = tentB.Id,
                PartKindId = pk.Id,
                State = PartState.Good,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });

        db.TentModelComponents.AddRange(
            new TentModelComponent { Id = Guid.NewGuid(), TentModelId = modelA.Id, PartKindId = pk.Id },
            new TentModelComponent { Id = Guid.NewGuid(), TentModelId = modelB.Id, PartKindId = pk.Id });

        await db.SaveChangesAsync();

        return (pk.Id, [tentA.Id, tentB.Id], [(modelA.Id, modelA.Name), (modelB.Id, modelB.Name)]);
    }

    private static int CountDetail(ActivityItemApi item, string label) =>
        int.Parse(Detail(item, label).Value ?? "0");

    private static ActivityDetailApi Detail(ActivityItemApi item, string label) =>
        Assert.Single(item.Details, d => d.Label == label);

    private static HistoryDetailApi Detail(HistoryItemApi item, string label) =>
        Assert.Single(item.Details, d => d.Label == label);

    private async Task ResetAuditEventsAsync()
    {
        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        db.AuditEvents.RemoveRange(db.AuditEvents);
        await db.SaveChangesAsync();
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


    private sealed class PartKindApiDto
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int DisplayOrder { get; set; }
        public int TentCount { get; set; }
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

    private sealed class HistoryItemApi
    {
        public Guid Id { get; set; }
        public string Action { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;
        public string? SubjectName { get; set; }
        public List<HistoryDetailApi> Details { get; set; } = [];
    }

    private sealed class HistoryDetailApi
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
