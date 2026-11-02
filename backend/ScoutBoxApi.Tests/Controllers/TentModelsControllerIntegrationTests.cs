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
                    PartKindId = pkId
                }).ToList()
            };
            db.TentModels.Add(model);
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/tent-models");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<List<TentModelApiDto>>();
        Assert.NotNull(payload);

        var models = payload.Where(m => m.Name.EndsWith(prefix, StringComparison.Ordinal)).ToList();
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
        var payload = await response.Content.ReadFromJsonAsync<TentModelApiDto>();
        Assert.NotNull(payload);
        Assert.Equal(name, payload.Name);
        Assert.True(payload.DisplayOrder > 0);
        Assert.True(payload.IsActive);
        Assert.Equal(0, payload.TentCount);
        Assert.Equal(2, payload.ComponentCount);
        Assert.Equal(partKindIds.Count, payload.ComponentIds.Count);

        using (var verifyScope = _factory.Services.CreateScope())
        {
            var verifyDb = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var audit = await verifyDb.AuditEvents.FirstOrDefaultAsync(a =>
                a.TargetEntityId == payload.Id && a.Action == "model_created");
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
        var payload = await response.Content.ReadFromJsonAsync<TentModelApiDto>();
        Assert.NotNull(payload);
        Assert.Equal(name, payload.Name);
        Assert.Equal(0, payload.ComponentCount);
        Assert.Empty(payload.ComponentIds);
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
    public async Task CreateTentModel_DuplicateNameWithInactiveModel_ReturnsBadRequest()
    {
        await EnsureTestUserExistsAsync();
        var name = $"Inactive {Guid.NewGuid():N}"[..20];

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
                IsActive = false,
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
                    PartKindId = pkId
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
        var payload = await response.Content.ReadFromJsonAsync<TentModelApiDto>();
        Assert.NotNull(payload);
        Assert.Equal(newName, payload.Name);
        Assert.Equal(2, payload.ComponentCount);

        using (var verifyScope = _factory.Services.CreateScope())
        {
            var db = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var audit = await db.AuditEvents.FirstOrDefaultAsync(a =>
                a.TargetEntityId == modelId && a.Action == "model_renamed");
            Assert.NotNull(audit);
            Assert.Equal(CustomApiFactory.TestUserId, audit.ActorUserId);
            using var metadata = JsonDocument.Parse(audit.MetadataJson!);
            Assert.Equal(originalName, metadata.RootElement.GetProperty("oldName").GetString());
            Assert.Equal(newName, metadata.RootElement.GetProperty("newName").GetString());

            var componentChanges = await db.AuditEvents.CountAsync(a =>
                a.TargetEntityId == modelId && a.Action == "model_components_changed");
            Assert.Equal(0, componentChanges);
        }
    }

    [Fact]
    public async Task UpdateTentModel_NameAndComponents_RecordsBothChanges()
    {
        await EnsureTestUserExistsAsync();
        var originalName = $"Both Old {Guid.NewGuid():N}"[..20];
        var newName = $"Both New {Guid.NewGuid():N}"[..20];

        Guid modelId;
        List<string> initialComponentNames;
        List<string> newComponentNames;
        List<Guid> newComponentIds;
        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var partKinds = await db.PartKinds.Select(pk => new { pk.Id, pk.Name }).ToListAsync();
            initialComponentNames = partKinds.Take(2).Select(pk => pk.Name).ToList();
            newComponentIds = partKinds.Skip(2).Take(2).Select(pk => pk.Id).ToList();
            newComponentNames = partKinds.Skip(2).Take(2).Select(pk => pk.Name).ToList();

            var model = new TentModel
            {
                Id = Guid.NewGuid(),
                Name = originalName,
                DisplayOrder = 999,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                TentModelComponents = partKinds.Take(2).Select(pk => new TentModelComponent
                {
                    Id = Guid.NewGuid(),
                    PartKindId = pk.Id
                }).ToList()
            };
            db.TentModels.Add(model);
            await db.SaveChangesAsync();
            modelId = model.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tent-models/{modelId}", new
        {
            name = newName,
            componentIds = newComponentIds
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using (var verifyScope = _factory.Services.CreateScope())
        {
            var db = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var audits = await db.AuditEvents
                .Where(a => a.TargetEntityId == modelId)
                .ToListAsync();

            var rename = Assert.Single(audits, a => a.Action == "model_renamed");
            using (var metadata = JsonDocument.Parse(rename.MetadataJson!))
            {
                Assert.Equal(originalName, metadata.RootElement.GetProperty("oldName").GetString());
                Assert.Equal(newName, metadata.RootElement.GetProperty("newName").GetString());
            }

            var componentChange = Assert.Single(audits, a => a.Action == "model_components_changed");
            using (var metadata = JsonDocument.Parse(componentChange.MetadataJson!))
            {
                Assert.Equal(newName, metadata.RootElement.GetProperty("name").GetString());
                Assert.Equal(
                    initialComponentNames.OrderBy(n => n, StringComparer.Ordinal),
                    metadata.RootElement.GetProperty("oldComponentNames").EnumerateArray()
                        .Select(e => e.GetString()!).OrderBy(n => n, StringComparer.Ordinal));
                Assert.Equal(
                    newComponentNames.OrderBy(n => n, StringComparer.Ordinal),
                    metadata.RootElement.GetProperty("newComponentNames").EnumerateArray()
                        .Select(e => e.GetString()!).OrderBy(n => n, StringComparer.Ordinal));
            }
        }
    }

    [Fact]
    public async Task UpdateTentModel_UnchangedNameAndSameComponentSetInAnotherOrder_RecordsNothing()
    {
        await EnsureTestUserExistsAsync();
        var name = $"NoOp {Guid.NewGuid():N}"[..20];

        Guid modelId;
        List<Guid> componentIds;
        List<Guid> componentRowIds;
        DateTime updatedAt;
        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            componentIds = await db.PartKinds.Take(2).Select(pk => pk.Id).ToListAsync();

            var model = new TentModel
            {
                Id = Guid.NewGuid(),
                Name = name,
                DisplayOrder = 999,
                IsActive = true,
                CreatedAt = DateTime.UtcNow.AddDays(-1),
                UpdatedAt = DateTime.UtcNow.AddDays(-1),
                TentModelComponents = componentIds.Select(pkId => new TentModelComponent
                {
                    Id = Guid.NewGuid(),
                    PartKindId = pkId
                }).ToList()
            };
            db.TentModels.Add(model);
            await db.SaveChangesAsync();
            modelId = model.Id;
            componentRowIds = model.TentModelComponents.Select(mc => mc.Id).ToList();
            updatedAt = model.UpdatedAt;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tent-models/{modelId}", new
        {
            name,
            componentIds = Enumerable.Reverse(componentIds).ToList()
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<TentModelApiDto>();
        Assert.NotNull(payload);
        Assert.Equal(name, payload.Name);
        Assert.Equal(2, payload.ComponentCount);

        using (var verifyScope = _factory.Services.CreateScope())
        {
            var db = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var auditCount = await db.AuditEvents.CountAsync(a => a.TargetEntityId == modelId);
            Assert.Equal(0, auditCount);

            var model = await db.TentModels.AsNoTracking().FirstAsync(m => m.Id == modelId);
            Assert.Equal(updatedAt, model.UpdatedAt);

            var currentRowIds = await db.TentModelComponents
                .Where(mc => mc.TentModelId == modelId)
                .Select(mc => mc.Id)
                .ToListAsync();
            Assert.Equal(
                componentRowIds.OrderBy(id => id),
                currentRowIds.OrderBy(id => id));
        }
    }

    [Fact]
    public async Task UpdateTentModel_DuplicateComponentIds_ReturnsBadRequest()
    {
        await EnsureTestUserExistsAsync();
        var name = $"Duplicate Components {Guid.NewGuid():N}"[..30];

        Guid modelId;
        Guid partKindId;
        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            partKindId = await db.PartKinds.Select(pk => pk.Id).FirstAsync();

            var model = new TentModel
            {
                Id = Guid.NewGuid(),
                Name = name,
                DisplayOrder = 999,
                IsActive = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.TentModels.Add(model);
            await db.SaveChangesAsync();
            modelId = model.Id;
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tent-models/{modelId}", new
        {
            componentIds = new[] { partKindId, partKindId }
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("INVALID_COMPONENT_IDS", payload.Code);
    }

    [Fact]
    public async Task UpdateTentModel_ComponentsOnly_RecordsComponentChangeAndNoRename()
    {
        await EnsureTestUserExistsAsync();
        var name = $"Components {Guid.NewGuid():N}"[..20];

        Guid modelId;
        List<Guid> initialComponentIds;
        List<Guid> newComponentIds;
        List<string> initialComponentNames;
        List<string> newComponentNames;
        using (var setupScope = _factory.Services.CreateScope())
        {
            var db = setupScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var partKinds = await db.PartKinds.Select(pk => new { pk.Id, pk.Name }).ToListAsync();
            initialComponentIds = partKinds.Take(2).Select(pk => pk.Id).ToList();
            newComponentIds = partKinds.Skip(2).Take(2).Select(pk => pk.Id).ToList();
            initialComponentNames = partKinds.Take(2).Select(pk => pk.Name).ToList();
            newComponentNames = partKinds.Skip(2).Take(2).Select(pk => pk.Name).ToList();

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
                    PartKindId = pkId
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
        var payload = await response.Content.ReadFromJsonAsync<TentModelApiDto>();
        Assert.NotNull(payload);
        Assert.Equal(name, payload.Name);
        Assert.Equal(2, payload.ComponentCount);
        Assert.True(newComponentIds.All(id => payload.ComponentIds.Contains(id)));

        using (var verifyScope = _factory.Services.CreateScope())
        {
            var db = verifyScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var audit = await db.AuditEvents.FirstOrDefaultAsync(a =>
                a.TargetEntityId == modelId && a.Action == "model_components_changed");
            Assert.NotNull(audit);
            Assert.Equal(CustomApiFactory.TestUserId, audit.ActorUserId);
            using var metadata = JsonDocument.Parse(audit.MetadataJson!);
            Assert.Equal(name, metadata.RootElement.GetProperty("name").GetString());
            Assert.Equal(
                initialComponentNames.OrderBy(n => n, StringComparer.Ordinal),
                metadata.RootElement.GetProperty("oldComponentNames").EnumerateArray()
                    .Select(e => e.GetString()!).OrderBy(n => n, StringComparer.Ordinal));
            Assert.Equal(
                newComponentNames.OrderBy(n => n, StringComparer.Ordinal),
                metadata.RootElement.GetProperty("newComponentNames").EnumerateArray()
                    .Select(e => e.GetString()!).OrderBy(n => n, StringComparer.Ordinal));

            var renames = await db.AuditEvents.CountAsync(a =>
                a.TargetEntityId == modelId && a.Action == "model_renamed");
            Assert.Equal(0, renames);
        }
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
                        PartKindId = partKindId
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
        var firstPayload = await firstResponse.Content.ReadFromJsonAsync<TentModelApiDto>();

        var secondResponse = await client.PostAsJsonAsync("/api/tent-models", new
        {
            name = $"Second {suffix}",
            componentIds = partKindIds
        });
        var secondPayload = await secondResponse.Content.ReadFromJsonAsync<TentModelApiDto>();

        Assert.NotNull(firstPayload);
        Assert.NotNull(secondPayload);
        Assert.True(secondPayload.DisplayOrder > firstPayload.DisplayOrder);
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
        var payload = await response.Content.ReadFromJsonAsync<List<TentModelApiDto>>();
        var model = payload!.First(m => m.Name.EndsWith(prefix, StringComparison.Ordinal));

        Assert.Equal(1, model.TentCount);
    }

    [Fact]
    public async Task GetTentModels_BackwardCompatible_ArrayResponse()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/tent-models");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<List<TentModelApiDto>>();
        Assert.NotNull(payload);
        Assert.IsType<List<TentModelApiDto>>(payload);
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
