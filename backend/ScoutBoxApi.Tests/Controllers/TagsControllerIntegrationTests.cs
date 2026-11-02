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
        var payload = await response.Content.ReadFromJsonAsync<List<TagApiDto>>();
        Assert.NotNull(payload);

        var tags = payload.Where(tag => tag.Name.EndsWith(prefix, StringComparison.Ordinal)).ToList();
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
        var payload = await response.Content.ReadFromJsonAsync<List<TagApiDto>>();
        Assert.NotNull(payload);
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
        var payload = await response.Content.ReadFromJsonAsync<TagApiDto>();
        Assert.NotNull(payload);
        Assert.Equal(name, payload.Name);
        Assert.Equal("#F44336", payload.Color);
        Assert.Equal(0, payload.TentCount);

        using var scope = _factory.Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var audit = await db.AuditEvents.FirstOrDefaultAsync(a =>
            a.TargetEntityId == payload.Id && a.Action == "tag_created");
        Assert.NotNull(audit);
        Assert.Equal(CustomApiFactory.TestUserId, audit.ActorUserId);
        Assert.Equal("Tag", audit.TargetEntityType);
        Assert.NotNull(audit.MetadataJson);
        using var metadata = JsonDocument.Parse(audit.MetadataJson);
        Assert.Equal(name, metadata.RootElement.GetProperty("name").GetString());
        Assert.Equal("#F44336", metadata.RootElement.GetProperty("color").GetString());
    }

    [Fact]
    public async Task CreateTag_TrimsNameAndRejectsBlankColor()
    {
        await EnsureTestUserExistsAsync();
        var name = $"Hangar {Guid.NewGuid():N}"[..24];

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/tags", new { name = $"  {name}  ", color = " " });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("INVALID_TAG_COLOR", payload.Code);
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
    public async Task UpdateTag_WithValidPayload_ReturnsUpdatedTagAndAuditEvent()
    {
        await EnsureTestUserExistsAsync();
        var originalName = $"Original {Guid.NewGuid():N}"[..24];
        var newName = $"Renamed {Guid.NewGuid():N}"[..24];

        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            db.Tags.Add(CreateTag(originalName, "#2196F3"));
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var getResponse = await client.GetAsync("/api/tags");
        var getPayload = await getResponse.Content.ReadFromJsonAsync<List<TagApiDto>>();
        var tag = getPayload!.First(t => t.Name == originalName);

        var response = await client.PutAsJsonAsync($"/api/tags/{tag.Id}", new { name = newName, color = "#4CAF50" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<TagApiDto>();
        Assert.NotNull(payload);
        Assert.Equal(newName, payload.Name);
        Assert.Equal("#4CAF50", payload.Color);
        Assert.Equal(0, payload.TentCount);

        using (var verifyScope = _factory.Services.CreateScope())
        {
            var db = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var audits = await db.AuditEvents
                .Where(a => a.TargetEntityId == tag.Id)
                .ToListAsync();
            Assert.Equal(2, audits.Count);
            var renameAudit = Assert.Single(audits.Where(a => a.Action == "tag_renamed").ToList());
            Assert.Equal(CustomApiFactory.TestUserId, renameAudit.ActorUserId);
            using (var metadata = JsonDocument.Parse(renameAudit.MetadataJson!))
            {
                Assert.Equal(originalName, metadata.RootElement.GetProperty("oldName").GetString());
                Assert.Equal(newName, metadata.RootElement.GetProperty("newName").GetString());
            }

            var colorAudit = Assert.Single(audits.Where(a => a.Action == "tag_color_changed").ToList());
            using (var metadata = JsonDocument.Parse(colorAudit.MetadataJson!))
            {
                Assert.Equal("#2196F3", metadata.RootElement.GetProperty("oldColor").GetString());
                Assert.Equal("#4CAF50", metadata.RootElement.GetProperty("newColor").GetString());
            }
        }
    }

    [Fact]
    public async Task UpdateTag_RenameOnly_RecordsOnlyTheRename()
    {
        await EnsureTestUserExistsAsync();
        var originalName = $"RenameOnly {Guid.NewGuid():N}"[..24];
        var newName = $"RenamedOnly {Guid.NewGuid():N}"[..24];

        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            db.Tags.Add(CreateTag(originalName, "#2196F3"));
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var getResponse = await client.GetAsync("/api/tags");
        var getPayload = await getResponse.Content.ReadFromJsonAsync<List<TagApiDto>>();
        var tag = getPayload!.First(t => t.Name == originalName);

        var response = await client.PutAsJsonAsync($"/api/tags/{tag.Id}", new { name = newName, color = "#2196F3" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using var verifyScope = _factory.Services.CreateScope();
        var auditDb = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var audit = Assert.Single(await auditDb.AuditEvents
            .Where(a => a.TargetEntityId == tag.Id)
            .ToListAsync());
        Assert.Equal("tag_renamed", audit.Action);
        using var metadata = JsonDocument.Parse(audit.MetadataJson!);
        Assert.Equal(originalName, metadata.RootElement.GetProperty("oldName").GetString());
        Assert.Equal(newName, metadata.RootElement.GetProperty("newName").GetString());
    }

    [Fact]
    public async Task UpdateTag_SameNameSameColor_RecordsNothingAndKeepsUpdatedAt()
    {
        await EnsureTestUserExistsAsync();
        var name = $"Unchanged {Guid.NewGuid():N}"[..24];
        DateTime originalUpdatedAt;

        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var createdTag = CreateTag(name, "#2196F3");
            createdTag.UpdatedAt = new DateTime(2026, 1, 2, 3, 4, 5, DateTimeKind.Utc);
            originalUpdatedAt = createdTag.UpdatedAt;
            db.Tags.Add(createdTag);
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var getResponse = await client.GetAsync("/api/tags");
        var getPayload = await getResponse.Content.ReadFromJsonAsync<List<TagApiDto>>();
        var tag = getPayload!.First(t => t.Name == name);

        var response = await client.PutAsJsonAsync($"/api/tags/{tag.Id}", new { name, color = "#2196F3" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<TagApiDto>();
        Assert.NotNull(payload);
        Assert.Equal(name, payload.Name);

        using (var verifyScope = _factory.Services.CreateScope())
        {
            var db = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var tagEntity = await db.Tags.AsNoTracking().FirstAsync(t => t.Id == tag.Id);
            Assert.Equal(originalUpdatedAt, tagEntity.UpdatedAt);
            Assert.Equal(CustomApiFactory.TestUserId, tagEntity.UpdatedByUserId);

            var audits = await db.AuditEvents
                .Where(a => a.TargetEntityId == tag.Id)
                .ToListAsync();
            Assert.Empty(audits);
        }
    }

    [Fact]
    public async Task UpdateTag_ColorOnly_RecordsColorChangedEvent()
    {
        await EnsureTestUserExistsAsync();
        var name = $"Color {Guid.NewGuid():N}"[..24];

        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            db.Tags.Add(CreateTag(name, "#2196F3"));
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var getResponse = await client.GetAsync("/api/tags");
        var getPayload = await getResponse.Content.ReadFromJsonAsync<List<TagApiDto>>();
        var tag = getPayload!.First(t => t.Name == name);

        var response = await client.PutAsJsonAsync($"/api/tags/{tag.Id}", new { name, color = "#F44336" });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using var verifyScope = _factory.Services.CreateScope();
        var auditDb = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var audit = Assert.Single(await auditDb.AuditEvents
            .Where(a => a.TargetEntityId == tag.Id)
            .ToListAsync());
        Assert.Equal("tag_color_changed", audit.Action);
        Assert.Contains("\"oldColor\":\"#2196F3\"", audit.MetadataJson);
        Assert.Contains("\"newColor\":\"#F44336\"", audit.MetadataJson);
    }

    [Fact]
    public async Task UpdateTag_InvalidColor_ReturnsBadRequest()
    {
        await EnsureTestUserExistsAsync();
        var name = $"Valid {Guid.NewGuid():N}"[..24];

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            db.Tags.Add(CreateTag(name, "#2196F3"));
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var getResponse = await client.GetAsync("/api/tags");
        var getPayload = await getResponse.Content.ReadFromJsonAsync<List<TagApiDto>>();
        var tag = getPayload!.First(t => t.Name == name);

        var response = await client.PutAsJsonAsync($"/api/tags/{tag.Id}", new { name, color = "blue" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("INVALID_TAG_COLOR", payload.Code);
    }

    [Fact]
    public async Task UpdateTag_DuplicateName_ReturnsConflict()
    {
        await EnsureTestUserExistsAsync();
        var suffix = Guid.NewGuid().ToString("N")[..8];

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            db.Tags.Add(CreateTag($"Existing {suffix}", "#2196F3"));
            db.Tags.Add(CreateTag($"Target {suffix}", "#4CAF50"));
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var getResponse = await client.GetAsync("/api/tags");
        var getPayload = await getResponse.Content.ReadFromJsonAsync<List<TagApiDto>>();
        var target = getPayload!.First(t => t.Name == $"Target {suffix}");

        var response = await client.PutAsJsonAsync($"/api/tags/{target.Id}", new { name = $"Existing {suffix}", color = "#2196F3" });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TAG_NAME_EXISTS", payload.Code);
    }

    [Fact]
    public async Task UpdateTag_NonExistentId_ReturnsNotFound()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tags/{Guid.NewGuid()}", new { name = "New Name", color = "#2196F3" });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TAG_NOT_FOUND", payload.Code);
    }

    [Fact]
    public async Task DeleteTag_WithNoTentAssociations_RecordsOnlyTheSummary()
    {
        await EnsureTestUserExistsAsync();
        var name = $"DeleteMe {Guid.NewGuid():N}"[..24];

        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            db.Tags.Add(CreateTag(name, "#2196F3"));
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var getResponse = await client.GetAsync("/api/tags");
        var getPayload = await getResponse.Content.ReadFromJsonAsync<List<TagApiDto>>();
        var tag = getPayload!.First(t => t.Name == name);

        var response = await client.DeleteAsync($"/api/tags/{tag.Id}");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        var getAfter = await client.GetAsync("/api/tags");
        var getAfterPayload = await getAfter.Content.ReadFromJsonAsync<List<TagApiDto>>();
        Assert.DoesNotContain(getAfterPayload!, t => t.Name == name);

        using (var verifyScope = _factory.Services.CreateScope())
        {
            var db = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var audit = Assert.Single(await db.AuditEvents
                .Where(a => a.TargetEntityId == tag.Id)
                .ToListAsync());
            Assert.Equal("tag_deleted", audit.Action);
            using var metadata = JsonDocument.Parse(audit.MetadataJson!);
            Assert.Equal(name, metadata.RootElement.GetProperty("name").GetString());
            Assert.Equal(0, metadata.RootElement.GetProperty("tentCount").GetInt32());

            var removals = await db.AuditEvents
                .Where(a => a.Action == "tag_removed" && a.MetadataJson != null &&
                            a.MetadataJson.Contains(tag.Id.ToString()))
                .ToListAsync();
            Assert.Empty(removals);
        }
    }

    [Fact]
    public async Task DeleteTag_WithSeveralTents_RecordsOneRemovalPerTentThenTheSummary()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];
        var name = $"Cascade {prefix}";
        Guid firstTentId;
        Guid secondTentId;

        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var firstTent = await CreateTentAsync(db, $"Tag Cascade Tent A {prefix}");
            var secondTent = await CreateTentAsync(db, $"Tag Cascade Tent B {prefix}");
            firstTentId = firstTent.Id;
            secondTentId = secondTent.Id;
            var createdTag = CreateTag(name, "#F44336");
            db.Tags.Add(createdTag);
            db.TentTags.AddRange(
                new TentTag
                {
                    TentId = firstTent.Id,
                    TagId = createdTag.Id,
                    CreatedAt = DateTime.UtcNow,
                    CreatedByUserId = CustomApiFactory.TestUserId
                },
                new TentTag
                {
                    TentId = secondTent.Id,
                    TagId = createdTag.Id,
                    CreatedAt = DateTime.UtcNow,
                    CreatedByUserId = CustomApiFactory.TestUserId
                });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var getResponse = await client.GetAsync("/api/tags");
        var getPayload = await getResponse.Content.ReadFromJsonAsync<List<TagApiDto>>();
        var tag = getPayload!.First(t => t.Name == name);

        var response = await client.DeleteAsync($"/api/tags/{tag.Id}");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        using (var verifyScope = _factory.Services.CreateScope())
        {
            var db = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var tagEntity = await db.Tags.IgnoreQueryFilters().FirstOrDefaultAsync(t => t.Id == tag.Id);
            Assert.Null(tagEntity);
            var tentTag = await db.TentTags.FirstOrDefaultAsync(tt => tt.TagId == tag.Id);
            Assert.Null(tentTag);

            var removals = await db.AuditEvents
                .Where(a => a.Action == "tag_removed" && a.MetadataJson != null &&
                            a.MetadataJson.Contains(tag.Id.ToString()))
                .ToListAsync();
            Assert.Equal(2, removals.Count);
            Assert.Equal(
                new[] { firstTentId, secondTentId }.OrderBy(id => id),
                removals.Select(a => a.TargetEntityId!.Value).OrderBy(id => id));
            foreach (var removal in removals)
            {
                Assert.Equal("TentTag", removal.TargetEntityType);
                using var metadata = JsonDocument.Parse(removal.MetadataJson!);
                var tentId = metadata.RootElement.GetProperty("tentId").GetGuid();
                Assert.Equal(removal.TargetEntityId, tentId);
                Assert.Equal(tag.Id, metadata.RootElement.GetProperty("tagId").GetGuid());
                Assert.Equal(name, metadata.RootElement.GetProperty("tagName").GetString());
                Assert.Equal("tag_deleted", metadata.RootElement.GetProperty("reason").GetString());
            }

            var summary = await db.AuditEvents.SingleAsync(a =>
                a.TargetEntityId == tag.Id && a.Action == "tag_deleted");
            using var summaryMetadata = JsonDocument.Parse(summary.MetadataJson!);
            Assert.Equal(name, summaryMetadata.RootElement.GetProperty("name").GetString());
            Assert.Equal(2, summaryMetadata.RootElement.GetProperty("tentCount").GetInt32());
            Assert.All(removals, removal => Assert.True(summary.OccurredAt >= removal.OccurredAt));
        }

        var activity = await client.GetFromJsonAsync<JsonElement>(
            "/api/activity?category=tags&window=all");
        var journalActions = activity.GetProperty("items").EnumerateArray()
            .Where(item =>
                item.TryGetProperty("subjectName", out var subject) &&
                subject.ValueKind == JsonValueKind.String &&
                subject.GetString() == name)
            .Select(item => item.GetProperty("action").GetString())
            .ToList();
        Assert.Equal(3, journalActions.Count);
        Assert.Equal("tag_deleted", journalActions[0]);
        Assert.All(journalActions.Skip(1), action => Assert.Equal("tag_removed", action));

        var history = await client.GetFromJsonAsync<List<JsonElement>>(
            $"/api/tents/{firstTentId}/history?category=tags");
        Assert.NotNull(history);
        var historyRemoval = Assert.Single(history);
        Assert.Equal("tag_removed", historyRemoval.GetProperty("action").GetString());
        Assert.Equal(name, historyRemoval.GetProperty("subjectName").GetString());
        var reasonDetail = Assert.Single(
            historyRemoval.GetProperty("details").EnumerateArray()
                .Where(detail =>
                    detail.TryGetProperty("valueType", out var valueType) &&
                    valueType.ValueKind == JsonValueKind.String &&
                    valueType.GetString() == "reason")
                .ToList());
        Assert.Equal("tag_deleted", reasonDetail.GetProperty("value").GetString());
    }

    [Fact]
    public async Task DeleteTag_NonExistentId_ReturnsNotFound()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/tags/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TAG_NOT_FOUND", payload.Code);
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
