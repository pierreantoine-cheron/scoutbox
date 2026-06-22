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

public class TentModelsControllerIntegrationTests : IClassFixture<CustomApiFactory>
{
    private readonly CustomApiFactory _factory;

    public TentModelsControllerIntegrationTests(CustomApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task GetTentModels_Authenticated_ReturnsModelsWithCounts()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var partKindIds = await db.PartKinds.Take(2).Select(pk => pk.Id).ToListAsync();

            var model = new TentModel
            {
                Id = Guid.NewGuid(),
                Name = $"Test Model {prefix}",
                DisplayOrder = 999,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                TentModelComponents = partKindIds.Select(pkId => new TentModelComponent
                {
                    Id = Guid.NewGuid(),
                    PartKindId = pkId,
                    IsStandard = true
                }).ToList()
            };
            db.TentModels.Add(model);
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/tent-models");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TentModelApiDto>>>();
        Assert.NotNull(payload?.Data);

        var models = payload.Data.Where(m => m.Name.EndsWith(prefix, StringComparison.Ordinal)).ToList();
        Assert.Single(models);
        Assert.Equal(0, models[0].TentCount);
        Assert.Equal(2, models[0].ComponentCount);
        Assert.NotNull(models[0].ComponentIds);
        Assert.Equal(2, models[0].ComponentIds.Count);
    }

    [Fact]
    public async Task CreateTentModel_WithValidPayload_ReturnsCreatedModelAndAuditEvent()
    {
        await EnsureTestUserExistsAsync();
        var name = $"Dôme {Guid.NewGuid():N}"[..20];

        List<Guid> partKindIds;
        using (var setupScope = _factory.Services.CreateScope())
        {
            var dbContext = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            partKindIds = await dbContext.PartKinds.Take(2).Select(pk => pk.Id).ToListAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/tent-models", new
        {
            name,
            componentIds = partKindIds
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentModelApiDto>>();
        Assert.NotNull(payload?.Data);
        Assert.Equal(name, payload.Data.Name);
        Assert.True(payload.Data.DisplayOrder > 0);
        Assert.True(payload.Data.IsActive);
        Assert.Equal(0, payload.Data.TentCount);
        Assert.Equal(2, payload.Data.ComponentCount);
        Assert.Equal(partKindIds.Count, payload.Data.ComponentIds.Count);

        using (var verifyScope = _factory.Services.CreateScope())
        {
            var verifyDb = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var audit = await verifyDb.AuditEvents.FirstOrDefaultAsync(a =>
                a.TargetEntityId == payload.Data.Id && a.Action == "model_created");
            Assert.NotNull(audit);
            Assert.Equal(CustomApiFactory.TestUserId, audit.ActorUserId);
            Assert.Equal("TentModel", audit.TargetEntityType);
        }
    }

    [Fact]
    public async Task CreateTentModel_MissingName_ReturnsBadRequest()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/tent-models", new
        {
            name = "",
            componentIds = new List<Guid> { Guid.NewGuid() }
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("MODEL_NAME_REQUIRED", payload.Code);
    }

    [Fact]
    public async Task CreateTentModel_EmptyComponentIds_ReturnsSuccessWithZeroComponents()
    {
        await EnsureTestUserExistsAsync();
        var name = $"No Parts {Guid.NewGuid():N}"[..20];

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/tent-models", new
        {
            name,
            componentIds = new List<Guid>()
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentModelApiDto>>();
        Assert.NotNull(payload?.Data);
        Assert.Equal(name, payload.Data.Name);
        Assert.Equal(0, payload.Data.ComponentCount);
        Assert.Empty(payload.Data.ComponentIds);
    }

    [Fact]
    public async Task CreateTentModel_InvalidComponentId_ReturnsBadRequest()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/tent-models", new
        {
            name = "Test Model",
            componentIds = new List<Guid> { Guid.NewGuid() }
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("INVALID_COMPONENT_IDS", payload.Code);
    }

    [Fact]
    public async Task CreateTentModel_DuplicateName_ReturnsBadRequest()
    {
        await EnsureTestUserExistsAsync();
        var name = $"Duplicate {Guid.NewGuid():N}"[..20];

        List<Guid> partKindIds;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            partKindIds = await db.PartKinds.Take(2).Select(pk => pk.Id).ToListAsync();

            db.TentModels.Add(new TentModel
            {
                Id = Guid.NewGuid(),
                Name = name,
                DisplayOrder = 999,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/tent-models", new
        {
            name,
            componentIds = partKindIds
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("MODEL_NAME_EXISTS", payload.Code);
    }

    [Fact]
    public async Task UpdateTentModel_NameOnly_ReturnsUpdatedModelAndAuditEvent()
    {
        await EnsureTestUserExistsAsync();
        var originalName = $"Original {Guid.NewGuid():N}"[..20];
        var newName = $"Renamed {Guid.NewGuid():N}"[..20];

        Guid modelId;
        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var partKindIds = await db.PartKinds.Take(2).Select(pk => pk.Id).ToListAsync();

            var model = new TentModel
            {
                Id = Guid.NewGuid(),
                Name = originalName,
                DisplayOrder = 999,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                TentModelComponents = partKindIds.Select(pkId => new TentModelComponent
                {
                    Id = Guid.NewGuid(),
                    PartKindId = pkId,
                    IsStandard = true
                }).ToList()
            };
            db.TentModels.Add(model);
            await db.SaveChangesAsync();
            modelId = model.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tent-models/{modelId}", new
        {
            name = newName
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentModelApiDto>>();
        Assert.NotNull(payload?.Data);
        Assert.Equal(newName, payload.Data.Name);
        Assert.Equal(2, payload.Data.ComponentCount);

        using (var verifyScope = _factory.Services.CreateScope())
        {
            var db = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var audit = await db.AuditEvents.FirstOrDefaultAsync(a =>
                a.TargetEntityId == modelId && a.Action == "model_renamed");
            Assert.NotNull(audit);
            Assert.Equal(CustomApiFactory.TestUserId, audit.ActorUserId);
        }
    }

    [Fact]
    public async Task UpdateTentModel_ComponentsOnly_ReturnsUpdatedModel()
    {
        await EnsureTestUserExistsAsync();
        var name = $"Components {Guid.NewGuid():N}"[..20];

        Guid modelId;
        List<Guid> initialComponentIds;
        List<Guid> newComponentIds;
        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var allPartKindIds = await db.PartKinds.Select(pk => pk.Id).ToListAsync();
            initialComponentIds = allPartKindIds.Take(2).ToList();
            newComponentIds = allPartKindIds.Skip(2).Take(2).ToList();

            var model = new TentModel
            {
                Id = Guid.NewGuid(),
                Name = name,
                DisplayOrder = 999,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                TentModelComponents = initialComponentIds.Select(pkId => new TentModelComponent
                {
                    Id = Guid.NewGuid(),
                    PartKindId = pkId,
                    IsStandard = true
                }).ToList()
            };
            db.TentModels.Add(model);
            await db.SaveChangesAsync();
            modelId = model.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tent-models/{modelId}", new
        {
            componentIds = newComponentIds
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentModelApiDto>>();
        Assert.NotNull(payload?.Data);
        Assert.Equal(name, payload.Data.Name);
        Assert.Equal(2, payload.Data.ComponentCount);
        Assert.True(newComponentIds.All(id => payload.Data.ComponentIds.Contains(id)));
    }

    [Fact]
    public async Task UpdateTentModel_NonExistentId_ReturnsNotFound()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tent-models/{Guid.NewGuid()}", new
        {
            name = "New Name"
        });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TENT_MODEL_NOT_FOUND", payload.Code);
    }

    [Fact]
    public async Task UpdateTentModel_DuplicateName_ReturnsBadRequest()
    {
        await EnsureTestUserExistsAsync();
        var suffix = Guid.NewGuid().ToString("N")[..8];

        Guid modelId;
        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var partKindIds = await db.PartKinds.Take(1).Select(pk => pk.Id).ToListAsync();

            db.TentModels.Add(new TentModel
            {
                Id = Guid.NewGuid(),
                Name = $"Existing {suffix}",
                DisplayOrder = 999,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            });

            var target = new TentModel
            {
                Id = Guid.NewGuid(),
                Name = $"Target {suffix}",
                DisplayOrder = 998,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.TentModels.Add(target);
            await db.SaveChangesAsync();
            modelId = target.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tent-models/{modelId}", new
        {
            name = $"Existing {suffix}"
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("MODEL_NAME_EXISTS", payload.Code);
    }

    [Fact]
    public async Task DeleteTentModel_WithNoTents_ReturnsNoContent()
    {
        await EnsureTestUserExistsAsync();
        var name = $"DeleteMe {Guid.NewGuid():N}"[..20];

        Guid modelId;
        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var partKindId = await db.PartKinds.Select(pk => pk.Id).FirstAsync();

            var model = new TentModel
            {
                Id = Guid.NewGuid(),
                Name = name,
                DisplayOrder = 999,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                TentModelComponents = new List<TentModelComponent>
                {
                    new()
                    {
                        Id = Guid.NewGuid(),
                        PartKindId = partKindId,
                        IsStandard = true
                    }
                }
            };
            db.TentModels.Add(model);
            await db.SaveChangesAsync();
            modelId = model.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/tent-models/{modelId}");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);

        using (var verifyScope = _factory.Services.CreateScope())
        {
            var db = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var model = await db.TentModels.IgnoreQueryFilters().FirstOrDefaultAsync(m => m.Id == modelId);
            Assert.Null(model);
            var components = await db.TentModelComponents.Where(mc => mc.TentModelId == modelId).ToListAsync();
            Assert.Empty(components);

            var audit = await db.AuditEvents.FirstOrDefaultAsync(a =>
                a.TargetEntityId == modelId && a.Action == "model_deleted");
            Assert.NotNull(audit);
            Assert.Equal(CustomApiFactory.TestUserId, audit.ActorUserId);
        }
    }

    [Fact]
    public async Task DeleteTentModel_WithTents_ReturnsBadRequest()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        Guid modelId;
        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var partKindId = await db.PartKinds.Select(pk => pk.Id).FirstAsync();

            var model = new TentModel
            {
                Id = Guid.NewGuid(),
                Name = $"In Use {prefix}",
                DisplayOrder = 999,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.TentModels.Add(model);

            db.Tents.Add(new Tent
            {
                Id = Guid.NewGuid(),
                Name = $"Tent {prefix}",
                Size = 6,
                TentModelId = model.Id,
                OverallState = TentOverallState.Good,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
            modelId = model.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/tent-models/{modelId}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("MODEL_IN_USE", payload.Code);
    }

    [Fact]
    public async Task DeleteTentModel_NonExistentId_ReturnsNotFound()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.DeleteAsync($"/api/tent-models/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TENT_MODEL_NOT_FOUND", payload.Code);
    }

    [Fact]
    public async Task CreateTentModel_DisplayOrderAutoIncrements()
    {
        await EnsureTestUserExistsAsync();
        var suffix = Guid.NewGuid().ToString("N")[..8];

        List<Guid> partKindIds;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            partKindIds = await db.PartKinds.Take(1).Select(pk => pk.Id).ToListAsync();
        }

        using var client = CreateAuthenticatedClient();
        var firstResponse = await client.PostAsJsonAsync("/api/tent-models", new
        {
            name = $"First {suffix}",
            componentIds = partKindIds
        });
        var firstPayload = await firstResponse.Content.ReadFromJsonAsync<DataEnvelope<TentModelApiDto>>();

        var secondResponse = await client.PostAsJsonAsync("/api/tent-models", new
        {
            name = $"Second {suffix}",
            componentIds = partKindIds
        });
        var secondPayload = await secondResponse.Content.ReadFromJsonAsync<DataEnvelope<TentModelApiDto>>();

        Assert.NotNull(firstPayload?.Data);
        Assert.NotNull(secondPayload?.Data);
        Assert.True(secondPayload.Data.DisplayOrder > firstPayload.Data.DisplayOrder);
    }

    [Fact]
    public async Task GetTentModels_ExistingModelWithTent_ShowsTentCount()
    {
        await EnsureTestUserExistsAsync();
        var prefix = Guid.NewGuid().ToString("N")[..8];

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();

            var activeModel = new TentModel
            {
                Id = Guid.NewGuid(),
                Name = $"Count Test {prefix}",
                DisplayOrder = 999,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.TentModels.Add(activeModel);

            db.Tents.Add(new Tent
            {
                Id = Guid.NewGuid(),
                Name = $"Count Tent {prefix}",
                Size = 4,
                TentModelId = activeModel.Id,
                OverallState = TentOverallState.Good,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/tent-models");
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TentModelApiDto>>>();
        var model = payload!.Data.First(m => m.Name.EndsWith(prefix, StringComparison.Ordinal));

        Assert.Equal(1, model.TentCount);
    }

    [Fact]
    public async Task GetTentModels_BackwardCompatible_ArrayResponse()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/tent-models");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TentModelApiDto>>>();
        Assert.NotNull(payload?.Data);
        Assert.IsType<List<TentModelApiDto>>(payload.Data);
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

    private sealed class DataEnvelope<T>
    {
        public T Data { get; set; } = default!;
    }

    private sealed class TentModelApiDto
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int DisplayOrder { get; set; }
        public bool IsActive { get; set; }
        public int TentCount { get; set; }
        public int ComponentCount { get; set; }
        public List<Guid> ComponentIds { get; set; } = [];
    }

    private sealed class ErrorPayload
    {
        public string Error { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
    }
}
