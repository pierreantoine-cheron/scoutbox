using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;
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
    public async Task DeletePartKind_NonExistent_ReturnsNotFound()
    {
        await EnsureTestUserExistsAsync();
        var id = Guid.NewGuid();

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/part-kinds/{id}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
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

    private sealed class ErrorPayload
    {
        public string Error { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
    }
}
