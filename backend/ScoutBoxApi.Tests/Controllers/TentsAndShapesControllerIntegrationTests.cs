using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Services;
using Xunit;

namespace ScoutBoxApi.Tests.Controllers;

public class TentsAndShapesControllerIntegrationTests : IClassFixture<CustomApiFactory>
{
    private readonly CustomApiFactory _factory;

    public TentsAndShapesControllerIntegrationTests(CustomApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task GetTentShapes_ReturnsOnlyActiveShapesOrderedByDisplayOrder()
    {
        await EnsureTestUserExistsAsync();

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeToDisable = await db.TentModels.OrderBy(x => x.DisplayOrder).FirstAsync();
            shapeToDisable.IsActive = false;
            shapeToDisable.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/tent-models");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TentModelApiDto>>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.NotEmpty(payload.Data);
        Assert.True(payload.Data.All(s => s.IsActive));

        var orders = payload.Data.Select(s => s.DisplayOrder).ToList();
        var ordered = orders.OrderBy(x => x).ToList();
        Assert.Equal(ordered, orders);
    }

    [Fact]
    public async Task CreateTent_WithValidPayload_ReturnsCreatedTentEnvelope()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = "Tente A",
            size = 6,
            tentModelId = shapeId,
            overallState = "Good",
            comments = "Commentaire"
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.Equal("Tente A", payload.Data.Name);
        Assert.Equal(6, payload.Data.Size);
        Assert.Equal(shapeId, payload.Data.TentModelId);
        Assert.Equal("Good", payload.Data.OverallState);
        Assert.Equal("Commentaire", payload.Data.Comments);

        using var auditScope = _factory.Services.CreateScope();
        var auditDb = auditScope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
        var audit = await auditDb.AuditEvents
            .FirstOrDefaultAsync(a => a.TargetEntityId == payload.Data.Id && a.Action == "tent_created");
        Assert.NotNull(audit);
        Assert.Equal(CustomApiFactory.TestUserId, audit.ActorUserId);
        Assert.Equal("Tent", audit.TargetEntityType);
    }

    [Fact]
    public async Task GetTents_ReturnsEnvelopeWithRequiredFieldsIncludingShapeName()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        string shapeName;
        var tentName = $"Tente Liste {Guid.NewGuid():N}";
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shape = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .FirstAsync();

            shapeId = shape.Id;
            shapeName = shape.Name;

            db.Tents.Add(new Tent
            {
                Id = Guid.NewGuid(),
                Name = tentName,
                Size = 5,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = "Test list",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/tents");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TentApiDto>>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);

        var createdTent = payload.Data.FirstOrDefault(t => t.Name == tentName);
        Assert.NotNull(createdTent);
        Assert.NotEqual(Guid.Empty, createdTent.Id);
        Assert.Equal(5, createdTent.Size);
        Assert.Equal(shapeId, createdTent.TentModelId);
        Assert.Equal(shapeName, createdTent.TentModelName);
        Assert.Equal("Good", createdTent.OverallState);
        Assert.Empty(createdTent.Parts);
    }

    [Fact]
    public async Task GetTentById_ReturnsDetailEnvelope_WithOrderedParts()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shape = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .FirstAsync();

            var partKinds = await db.PartKinds
                .OrderBy(x => x.DisplayOrder)
                .ThenBy(x => x.Id)
                .Take(2)
                .ToListAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = $"Tente Detail {Guid.NewGuid():N}",
                Size = 4,
                TentModelId = shape.Id,
                OverallState = TentOverallState.NeedsRepair,
                Comments = "Commentaire détail",
                CreatedAt = DateTime.UtcNow.AddDays(-1),
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });

            db.Parts.Add(new Part
            {
                Id = Guid.NewGuid(),
                TentId = tentId,
                PartKindId = partKinds[1].Id,
                State = PartState.Unusable,
                Comments = "Partie 2",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });

            db.Parts.Add(new Part
            {
                Id = Guid.NewGuid(),
                TentId = tentId,
                PartKindId = partKinds[0].Id,
                State = PartState.Good,
                Comments = "Partie 1",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });

            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync($"/api/tents/{tentId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.Equal(tentId, payload.Data.Id);
        Assert.Equal(2, payload.Data.Parts.Count);

        for (int i = 1; i < payload.Data.Parts.Count; i++)
        {
            var previous = payload.Data.Parts[i - 1];
            var current = payload.Data.Parts[i];
            var isOrdered = previous.DisplayOrder < current.DisplayOrder
                || (previous.DisplayOrder == current.DisplayOrder
                    && previous.PartKindId.CompareTo(current.PartKindId) <= 0);
            Assert.True(isOrdered, "Parts are not ordered by DisplayOrder then PartKindId");
        }
    }

    [Fact]
    public async Task GetTentById_WithUnknownId_ReturnsNotFoundErrorCode()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync($"/api/tents/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TENT_NOT_FOUND", payload.Code);
    }

    [Fact]
    public async Task GetTentById_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });

        var response = await client.GetAsync($"/api/tents/{Guid.NewGuid()}");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetTents_ReturnsDeterministicOrderingByUpdatedAtThenCreatedAtDesc()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        Guid firstId;
        Guid secondId;
        Guid fourthId;
        string firstName;
        string secondName;
        string thirdName;
        string fourthName;

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            var baseTime = DateTime.UtcNow;
            var tiedCreatedAt = baseTime.AddMinutes(-4);
            firstId = Guid.Parse("11111111-1111-1111-1111-111111111111");
            secondId = Guid.Parse("99999999-9999-9999-9999-999999999999");
            fourthId = Guid.Parse("aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa");
            firstName = $"Order-A-{Guid.NewGuid():N}";
            secondName = $"Order-B-{Guid.NewGuid():N}";
            thirdName = $"Order-C-{Guid.NewGuid():N}";
            fourthName = $"Order-D-{Guid.NewGuid():N}";

            db.Tents.AddRange(
                new Tent
                {
                    Id = firstId,
                    Name = firstName,
                    Size = 4,
                    TentModelId = shapeId,
                    OverallState = TentOverallState.Good,
                    CreatedAt = tiedCreatedAt,
                    UpdatedAt = baseTime,
                    CreatedByUserId = CustomApiFactory.TestUserId,
                    UpdatedByUserId = CustomApiFactory.TestUserId
                },
                new Tent
                {
                    Id = secondId,
                    Name = secondName,
                    Size = 4,
                    TentModelId = shapeId,
                    OverallState = TentOverallState.Good,
                    CreatedAt = tiedCreatedAt,
                    UpdatedAt = baseTime,
                    CreatedByUserId = CustomApiFactory.TestUserId,
                    UpdatedByUserId = CustomApiFactory.TestUserId
                },
                new Tent
                {
                    Id = Guid.NewGuid(),
                    Name = thirdName,
                    Size = 4,
                    TentModelId = shapeId,
                    OverallState = TentOverallState.Good,
                    CreatedAt = baseTime.AddMinutes(-2),
                    UpdatedAt = baseTime.AddMinutes(-1),
                    CreatedByUserId = CustomApiFactory.TestUserId,
                    UpdatedByUserId = CustomApiFactory.TestUserId
                },
                new Tent
                {
                    Id = fourthId,
                    Name = fourthName,
                    Size = 4,
                    TentModelId = shapeId,
                    OverallState = TentOverallState.Good,
                    CreatedAt = tiedCreatedAt,
                    UpdatedAt = baseTime,
                    CreatedByUserId = CustomApiFactory.TestUserId,
                    UpdatedByUserId = CustomApiFactory.TestUserId
                }
            );

            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/tents");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TentApiDto>>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);

        var orderedNames = payload.Data
            .Where(t => t.Name == firstName || t.Name == secondName || t.Name == thirdName || t.Name == fourthName)
            .Select(t => t.Name)
            .ToList();

        Assert.Equal(new[] { fourthName, secondName, firstName, thirdName }, orderedNames);
    }

    [Theory]
    [InlineData("", 6, "Name")]
    [InlineData("Tente", 0, "Size")]
    [InlineData("Tente", -1, "Size")]
    [InlineData("Tente", 101, "Size")]
    public async Task CreateTent_WithInvalidDto_ReturnsApiValidationError(string name, int size, string expectedField)
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name,
            size,
            tentModelId = shapeId,
            overallState = "Good",
            comments = "test"
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>();
        Assert.NotNull(payload);
        Assert.True(payload.Errors.ContainsKey(expectedField));
    }

    [Fact]
    public async Task CreateTent_WithWhitespaceName_ReturnsApiValidationError()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = "   ",
            size = 6,
            tentModelId = shapeId,
            overallState = "Good",
            comments = "test"
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>();
        Assert.NotNull(payload);
        Assert.True(payload.Errors.ContainsKey("Name"));
    }

    [Fact]
    public async Task CreateTent_WithTooLongComments_ReturnsApiValidationError()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PostAsJsonAsync("/api/tents", new
        {
            name = "Tente Long Comments",
            size = 6,
            tentModelId = shapeId,
            overallState = "Good",
            comments = new string('x', 501)
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>();
        Assert.NotNull(payload);
        Assert.True(payload.Errors.ContainsKey("Comments"));
    }

    [Fact]
    public async Task CreateTent_WithInvalidOverallState_ReturnsInvalidTentStateError()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = "Tente Etat Invalide",
            size = 6,
            tentModelId = shapeId,
            overallState = "BrokenBeyondRepair",
            comments = "test"
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.False(string.IsNullOrWhiteSpace(payload.Error));
        Assert.Equal("INVALID_TENT_STATE", payload.Code);
    }

    [Fact]
    public async Task CreateTent_WithUnknownShape_ReturnsInvalidShapeError()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = "Tente Shape Invalide",
            size = 6,
            tentModelId = Guid.NewGuid(),
            overallState = "Good",
            comments = "test"
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.False(string.IsNullOrWhiteSpace(payload.Error));
        Assert.Equal("INVALID_TENT_MODEL", payload.Code);
    }

    [Fact]
    public async Task CreateTent_WithDuplicateName_ReturnsTentNameExistsError()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            db.Tents.Add(new Tent
            {
                Id = Guid.NewGuid(),
                Name = "Tente Dupliquee",
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = "seed",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = "Tente Dupliquee",
            size = 6,
            tentModelId = shapeId,
            overallState = "Good",
            comments = "new"
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.False(string.IsNullOrWhiteSpace(payload.Error));
        Assert.Equal("TENT_NAME_EXISTS", payload.Code);
    }

    // --- Story 2.3: Auto-generate parts tests ---

    [Fact]
    public async Task CreateTent_WithCanadienneShape_ReturnsSevenStandardParts()
    {
        await EnsureTestUserExistsAsync();

        Guid canadienneShapeId;
        int expectedPartCount;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shape = await db.TentModels
                .Include(s => s.TentModelComponents)
                .Where(x => x.Name == "Canadienne")
                .FirstOrDefaultAsync();
            if (shape == null || !shape.IsActive)
            {
                shape = await db.TentModels
                    .Include(s => s.TentModelComponents)
                    .Where(x => x.IsActive && x.TentModelComponents.Any())
                    .OrderBy(x => x.DisplayOrder)
                    .FirstAsync();
            }
            canadienneShapeId = shape.Id;
            expectedPartCount = shape.TentModelComponents.Count;
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = $"Tente Parts Test {Guid.NewGuid():N}",
            size = 6,
            tentModelId = canadienneShapeId,
            overallState = "Good",
            comments = null as string
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.NotNull(payload.Data.Parts);
        Assert.Equal(expectedPartCount, payload.Data.Parts.Count);

        foreach (var part in payload.Data.Parts)
        {
            Assert.NotEqual(Guid.Empty, part.Id);
            Assert.Equal("Good", part.State);
            Assert.Null(part.Comments);
        }
    }

    [Fact]
    public async Task CreateTent_WithCustomShapeConfig_ReturnsExactConfiguredPartCount()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        int expectedPartCount;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await GetFirstActiveModelWithComponentsAsync(db);
            expectedPartCount = await db.TentModelComponents
                .CountAsync(sp => sp.TentModelId == shapeId);
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = $"Tente Cabanon Test {Guid.NewGuid():N}",
            size = 8,
            tentModelId = shapeId,
            overallState = "Good",
            comments = null as string
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.NotNull(payload.Data.Parts);
        Assert.Equal(expectedPartCount, payload.Data.Parts.Count);
    }

    [Fact]
    public async Task CreateTent_WithShapeWithZeroDefaults_CreatesTentWithEmptyParts()
    {
        await EnsureTestUserExistsAsync();

        Guid emptyShapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();

            var shape = new TentModel
            {
                Id = Guid.NewGuid(),
                Name = "Empty Shape Test",
                IsActive = true,
                DisplayOrder = 99,
                Description = "Shape with no default parts",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.TentModels.Add(shape);
            await db.SaveChangesAsync();
            emptyShapeId = shape.Id;
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = "Tente No Parts Test",
            size = 2,
            tentModelId = emptyShapeId,
            overallState = "Good",
            comments = null as string
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.NotNull(payload.Data.Parts);
        Assert.Empty(payload.Data.Parts);
    }

    [Fact]
    public async Task CreateTent_AutoGeneratedParts_HaveGoodStateAndAuditAttribution()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await GetFirstActiveModelWithComponentsAsync(db);
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = $"Tente Audit Test {Guid.NewGuid():N}",
            size = 4,
            tentModelId = shapeId,
            overallState = "Good",
            comments = null as string
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.NotNull(payload.Data.Parts);
        Assert.NotEmpty(payload.Data.Parts);

        foreach (var part in payload.Data.Parts)
        {
            Assert.Equal("Good", part.State);
            Assert.Null(part.Comments);
            Assert.NotEqual(Guid.Empty, part.PartKindId);
            Assert.False(string.IsNullOrWhiteSpace(part.PartKindName));
            Assert.True(part.DisplayOrder > 0);
            Assert.True(part.CreatedAt <= DateTime.UtcNow);
            Assert.True(part.UpdatedAt <= DateTime.UtcNow);
        }

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var dbParts = await db.Parts
                .Where(p => p.TentId == payload.Data.Id)
                .ToListAsync();

            Assert.Equal(payload.Data.Parts.Count, dbParts.Count);

            foreach (var dbPart in dbParts)
            {
                Assert.Equal(PartState.Good, dbPart.State);
                Assert.Null(dbPart.Comments);
                Assert.Equal(CustomApiFactory.TestUserId, dbPart.CreatedByUserId);
                Assert.Equal(CustomApiFactory.TestUserId, dbPart.UpdatedByUserId);
                Assert.True(dbPart.CreatedAt <= DateTime.UtcNow);
                Assert.True(dbPart.UpdatedAt <= DateTime.UtcNow);
            }
        }
    }

    [Fact]
    public async Task CreateTent_AutoGeneratedParts_AreOrderedByDisplayOrderThenPartKindId()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await GetFirstActiveModelWithComponentsAsync(db);
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = $"Tente Order Test {Guid.NewGuid():N}",
            size = 4,
            tentModelId = shapeId,
            overallState = "Good",
            comments = null as string
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.NotNull(payload.Data.Parts);

        var displayOrders = payload.Data.Parts.Select(p => p.DisplayOrder).ToList();
        for (int i = 1; i < displayOrders.Count; i++)
        {
            Assert.True(displayOrders[i] >= displayOrders[i - 1],
                $"Parts not ordered: part {i} has DisplayOrder {displayOrders[i]} < part {i - 1} has DisplayOrder {displayOrders[i - 1]}");
        }

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var dbParts = await db.Parts
                .Where(p => p.TentId == payload.Data.Id)
                .Include(p => p.PartKind)
                .OrderBy(p => p.PartKind.DisplayOrder)
                .ThenBy(p => p.PartKindId)
                .ToListAsync();

            Assert.Equal(payload.Data.Parts.Count, dbParts.Count);

            for (int i = 0; i < dbParts.Count; i++)
            {
                Assert.Equal(dbParts[i].PartKindId, payload.Data.Parts[i].PartKindId);
            }
        }
    }

    [Fact]
    public async Task CreateTent_OnFailure_NoPartialPersistenceRemains()
    {
        await EnsureTestUserExistsAsync();

        var uniqueName = $"Tente Atomic Test {Guid.NewGuid():N}";
        var tentsCountBefore = 0;
        var partsCountBefore = 0;
        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await GetFirstActiveModelWithComponentsAsync(db);
            tentsCountBefore = await db.Tents.CountAsync();
            partsCountBefore = await db.Parts.CountAsync();

            db.Tents.Add(new Tent
            {
                Id = Guid.NewGuid(),
                Name = uniqueName,
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = "seed",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();

            tentsCountBefore = await db.Tents.CountAsync();
            partsCountBefore = await db.Parts.CountAsync();
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = uniqueName,
            size = 4,
            tentModelId = shapeId,
            overallState = "Good",
            comments = null as string
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TENT_NAME_EXISTS", payload.Code);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var tentsCountAfter = await db.Tents.CountAsync();
            var partsCountAfter = await db.Parts.CountAsync();

            Assert.Equal(tentsCountBefore, tentsCountAfter);
            Assert.Equal(partsCountBefore, partsCountAfter);
        }
    }

    [Fact]
    public async Task CreateTent_ExistingFieldsStillWork_AfterPartsAutoGeneration()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await GetFirstActiveModelWithComponentsAsync(db);
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = $"Tente Compatibility Test {Guid.NewGuid():N}",
            size = 8,
            tentModelId = shapeId,
            overallState = "Good",
            comments = "Test compatibility"
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.NotEqual(Guid.Empty, payload.Data.Id);
        Assert.Equal(8, payload.Data.Size);
        Assert.Equal(shapeId, payload.Data.TentModelId);
        Assert.Equal("Good", payload.Data.OverallState);
        Assert.Equal("Test compatibility", payload.Data.Comments);
        Assert.NotNull(payload.Data.Parts);
        Assert.NotEmpty(payload.Data.Parts);
    }

    private static async Task<Guid> GetFirstActiveModelWithComponentsAsync(ScoutBoxDbContext db)
    {
        var canadienne = await db.TentModels
            .Where(x => x.Name == "Canadienne" && x.IsActive)
            .Select(x => x.Id)
            .FirstOrDefaultAsync();

        if (canadienne != Guid.Empty)
            return canadienne;

        return await db.TentModels
            .Where(x => x.IsActive && x.TentModelComponents.Any())
            .OrderBy(x => x.DisplayOrder)
            .Select(x => x.Id)
            .FirstAsync();
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
    }

    private sealed class TentApiDto
    {
        public Guid Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public int Size { get; set; }
        public Guid TentModelId { get; set; }
        public string? TentModelName { get; set; }
        public string OverallState { get; set; } = string.Empty;
        public bool IsArchived { get; set; }
        public string? Comments { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
        public List<PartApiDto> Parts { get; set; } = new();
    }

    private sealed class PartApiDto
    {
        public Guid Id { get; set; }
        public Guid PartKindId { get; set; }
        public string PartKindName { get; set; } = string.Empty;
        public int DisplayOrder { get; set; }
        public string State { get; set; } = string.Empty;
        public string? Comments { get; set; }
        public DateTime CreatedAt { get; set; }
        public DateTime UpdatedAt { get; set; }
    }

    // --- Story 2.8: Update tent tests ---

    [Fact]
    public async Task UpdateTent_WithValidPayload_ReturnsUpdatedTentEnvelope()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        Guid shapeId;
        var createdAt = DateTime.UtcNow.AddDays(-1);
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = "Tente A Modifier",
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = "Commentaire avant",
                CreatedAt = createdAt,
                UpdatedAt = createdAt,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = "Tente A Modifiée",
            size = 8,
            overallState = "NeedsRepair",
            comments = "Commentaire après"
        };

        var response = await client.PutAsJsonAsync($"/api/tents/{tentId}", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.Equal(tentId, payload.Data.Id);
        Assert.Equal("Tente A Modifiée", payload.Data.Name);
        Assert.Equal(8, payload.Data.Size);
        Assert.Equal("NeedsRepair", payload.Data.OverallState);
        Assert.Equal("Commentaire après", payload.Data.Comments);
        Assert.Equal(shapeId, payload.Data.TentModelId);
        Assert.NotNull(payload.Data.TentModelName);
        Assert.True(payload.Data.UpdatedAt > createdAt);
    }

    [Fact]
    public async Task UpdateTent_BlankComments_StoredAsNull()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = $"Tente Comments Test {Guid.NewGuid():N}",
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = "Existing comment",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tents/{tentId}", new
        {
            name = "Tente Comments Test Updated",
            size = 4,
            overallState = "Good",
            comments = "   "
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.Null(payload.Data.Comments);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var tent = await db.Tents.FindAsync(tentId);
            Assert.Null(tent!.Comments);
        }
    }

    [Fact]
    public async Task UpdateTent_UpdatesAuditFields()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        var originalUpdatedAt = DateTime.UtcNow.AddDays(-2);
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = $"Tente Audit Test {Guid.NewGuid():N}",
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = null,
                CreatedAt = originalUpdatedAt,
                UpdatedAt = originalUpdatedAt,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tents/{tentId}", new
        {
            name = "Tente Audit Test New",
            size = 6,
            overallState = "NeedsRepair",
            comments = "Audit update"
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var tent = await db.Tents.FindAsync(tentId);
            Assert.NotNull(tent);
            Assert.Equal(CustomApiFactory.TestUserId, tent.UpdatedByUserId);
            Assert.True(tent.UpdatedAt > originalUpdatedAt);

            var audit = await db.AuditEvents
                .FirstOrDefaultAsync(a => a.TargetEntityId == tentId && a.Action == "tent_updated");
            Assert.NotNull(audit);
            Assert.Equal(CustomApiFactory.TestUserId, audit.ActorUserId);
            Assert.Equal("Tent", audit.TargetEntityType);
        }
    }

    [Fact]
    public async Task UpdateTent_NoChanges_DoesNotCreateAuditEvent()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        var existingName = $"Tente No Change {Guid.NewGuid():N}";
        var originalUpdatedAt = DateTime.UtcNow.AddDays(-1);
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = existingName,
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = null,
                CreatedAt = originalUpdatedAt,
                UpdatedAt = originalUpdatedAt,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        int auditCountBefore;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            auditCountBefore = await db.AuditEvents.CountAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tents/{tentId}", new
        {
            name = existingName,
            size = 4,
            overallState = "Good",
            comments = (string?)null
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var auditCountAfter = await db.AuditEvents.CountAsync();
            Assert.Equal(auditCountBefore, auditCountAfter);

            var tent = await db.Tents.FindAsync(tentId);
            Assert.NotNull(tent);
            Assert.Equal(originalUpdatedAt, tent.UpdatedAt);
        }
    }

    [Fact]
    public async Task UpdateTent_WithTrimmedValuesAtMaxLength_AcceptsRequest()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = $"Tente Trim Source {Guid.NewGuid():N}",
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        var maxLengthName = new string('N', 100);
        var maxLengthComments = new string('C', 500);

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tents/{tentId}", new
        {
            name = $" {maxLengthName} ",
            size = 4,
            overallState = "Good",
            comments = $" {maxLengthComments} "
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.Equal(maxLengthName, payload.Data.Name);
        Assert.Equal(maxLengthComments, payload.Data.Comments);
    }

    [Fact]
    public async Task UpdateTent_WithParts_ReturnsPartsOrdered()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        var existingName = $"Tente Parts Update {Guid.NewGuid():N}";
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shape = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .FirstAsync();

            var partKinds = await db.PartKinds
                .OrderBy(x => x.DisplayOrder)
                .ThenBy(x => x.Id)
                .Take(3)
                .ToListAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = existingName,
                Size = 4,
                TentModelId = shape.Id,
                OverallState = TentOverallState.Good,
                Comments = null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });

            db.Parts.Add(new Part
            {
                Id = Guid.NewGuid(),
                TentId = tentId,
                PartKindId = partKinds[2].Id,
                State = PartState.Good,
                Comments = null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            db.Parts.Add(new Part
            {
                Id = Guid.NewGuid(),
                TentId = tentId,
                PartKindId = partKinds[0].Id,
                State = PartState.Good,
                Comments = null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });

            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tents/{tentId}", new
        {
            name = $"{existingName} Modified",
            size = 4,
            overallState = "Good",
            comments = (string?)null
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.Equal(2, payload.Data.Parts.Count);

        for (int i = 1; i < payload.Data.Parts.Count; i++)
        {
            var previous = payload.Data.Parts[i - 1];
            var current = payload.Data.Parts[i];
            var isOrdered = previous.DisplayOrder < current.DisplayOrder
                || (previous.DisplayOrder == current.DisplayOrder
                    && previous.PartKindId.CompareTo(current.PartKindId) <= 0);
            Assert.True(isOrdered, "Parts are not ordered by DisplayOrder then PartKindId");
        }
    }

    [Fact]
    public async Task UpdateTent_WithUnknownId_ReturnsNotFound()
    {
        await EnsureTestUserExistsAsync();

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tents/{Guid.NewGuid()}", new
        {
            name = "Tent",
            size = 4,
            overallState = "Good",
            comments = (string?)null
        });

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TENT_NOT_FOUND", payload.Code);
    }

    [Fact]
    public async Task UpdateTent_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });

        var response = await client.PutAsJsonAsync($"/api/tents/{Guid.NewGuid()}", new
        {
            name = "Tent",
            size = 4,
            overallState = "Good",
            comments = (string?)null
        });

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task UpdateTent_WithDuplicateName_ReturnsTentNameExistsError()
    {
        await EnsureTestUserExistsAsync();

        var duplicateName = $"Tente Dupliquee Update {Guid.NewGuid():N}";
        Guid tentId;
        Guid otherTentId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            tentId = Guid.NewGuid();
            otherTentId = Guid.NewGuid();

            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = $"Original Name {Guid.NewGuid():N}",
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });

            db.Tents.Add(new Tent
            {
                Id = otherTentId,
                Name = duplicateName,
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });

            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tents/{tentId}", new
        {
            name = duplicateName,
            size = 4,
            overallState = "Good",
            comments = (string?)null
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TENT_NAME_EXISTS", payload.Code);
    }

    [Fact]
    public async Task UpdateTent_SameNameAsCurrent_IsAllowed()
    {
        await EnsureTestUserExistsAsync();

        var tentName = $"Tente Same Name {Guid.NewGuid():N}";
        Guid tentId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = tentName,
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });

            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tents/{tentId}", new
        {
            name = tentName,
            size = 8,
            overallState = "NeedsRepair",
            comments = "Updated"
        });

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.Equal(tentName, payload.Data.Name);
        Assert.Equal(8, payload.Data.Size);
    }

    [Theory]
    [InlineData("", 4, "Name")]
    [InlineData("Tente", 0, "Size")]
    [InlineData("Tente", -1, "Size")]
    [InlineData("Tente", 101, "Size")]
    public async Task UpdateTent_WithInvalidDto_ReturnsApiValidationError(string name, int size, string expectedField)
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        var originalName = $"Tente Invalid Update {Guid.NewGuid():N}";
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = originalName,
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tents/{tentId}", new
        {
            name,
            size,
            overallState = "Good",
            comments = (string?)null
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>();
        Assert.NotNull(payload);
        Assert.True(payload.Errors.ContainsKey(expectedField));
    }

    [Fact]
    public async Task UpdateTent_WithWhitespaceName_ReturnsApiValidationError()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        var originalName = $"Tente Whitespace Update {Guid.NewGuid():N}";
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = originalName,
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tents/{tentId}", new
        {
            name = "   ",
            size = 4,
            overallState = "Good",
            comments = (string?)null
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>();
        Assert.NotNull(payload);
        Assert.True(payload.Errors.ContainsKey("Name"));
    }

    [Fact]
    public async Task UpdateTent_WithInvalidOverallState_ReturnsInvalidTentStateError()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        var originalName = $"Tente Invalid State Update {Guid.NewGuid():N}";
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = originalName,
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tents/{tentId}", new
        {
            name = originalName,
            size = 4,
            overallState = "BrokenBeyondRepair",
            comments = (string?)null
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("INVALID_TENT_STATE", payload.Code);
    }

    [Fact]
    public async Task UpdateTent_WithTooLongComments_ReturnsError()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        var originalName = $"Tente Long Comments {Guid.NewGuid():N}";
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = originalName,
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = null,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        var longComments = new string('x', 501);

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsJsonAsync($"/api/tents/{tentId}", new
        {
            name = originalName,
            size = 4,
            overallState = "Good",
            comments = longComments
        });

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ValidationProblemDetails>();
        Assert.NotNull(payload);
        Assert.True(payload.Errors.ContainsKey("Comments"));
    }

    [Fact]
    public async Task ArchiveTent_WithValidTent_SetsIsArchivedAndReturnsEnvelope()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = $"Archive-{Guid.NewGuid():N}",
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                CreatedAt = DateTime.UtcNow.AddHours(-1),
                UpdatedAt = DateTime.UtcNow.AddHours(-1),
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsync($"/api/tents/{tentId}/archive", null);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.True(payload.Data.IsArchived);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var tent = await db.Tents.FirstAsync(t => t.Id == tentId);
            Assert.True(tent.IsArchived);
            Assert.Equal(CustomApiFactory.TestUserId, tent.UpdatedByUserId);
            Assert.Single(await db.AuditEvents.Where(a => a.Action == "tent_archived" && a.TargetEntityId == tentId).ToListAsync());
        }
    }

    [Fact]
    public async Task ArchiveTent_WhenAlreadyArchived_IsIdempotent()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        DateTime firstUpdatedAt;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();
            firstUpdatedAt = DateTime.UtcNow.AddMinutes(-10);
            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = $"Archive-idempotent-{Guid.NewGuid():N}",
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                IsArchived = true,
                CreatedAt = firstUpdatedAt,
                UpdatedAt = firstUpdatedAt,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.PutAsync($"/api/tents/{tentId}/archive", null);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var tent = await db.Tents.FirstAsync(t => t.Id == tentId);
            Assert.Equal(firstUpdatedAt, tent.UpdatedAt);
            Assert.Empty(await db.AuditEvents.Where(a => a.Action == "tent_archived" && a.TargetEntityId == tentId).ToListAsync());
        }
    }

    [Fact]
    public async Task GetTents_ExcludesArchivedTents()
    {
        await EnsureTestUserExistsAsync();
        string archivedName = $"Archived-{Guid.NewGuid():N}";
        string activeName = $"Active-{Guid.NewGuid():N}";

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();

            db.Tents.Add(new Tent
            {
                Id = Guid.NewGuid(),
                Name = archivedName,
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                IsArchived = true,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            db.Tents.Add(new Tent
            {
                Id = Guid.NewGuid(),
                Name = activeName,
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                IsArchived = false,
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow,
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/tents");
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TentApiDto>>>();
        Assert.NotNull(payload);
        Assert.DoesNotContain(payload.Data, t => t.Name == archivedName);
        Assert.Contains(payload.Data, t => t.Name == activeName);
    }

    [Fact]
    public async Task ArchiveTent_WithUnknownId_ReturnsNotFound()
    {
        await EnsureTestUserExistsAsync();
        using var client = CreateAuthenticatedClient();

        var response = await client.PutAsync($"/api/tents/{Guid.NewGuid()}/archive", null);
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TENT_NOT_FOUND", payload.Code);
    }

    [Fact]
    public async Task ArchiveTent_WithoutAuthentication_ReturnsUnauthorized()
    {
        using var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });

        var response = await client.PutAsync($"/api/tents/{Guid.NewGuid()}/archive", null);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task GetTentDetail_ForArchivedTent_ReturnsFullDetail()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        var tentName = $"Archived-Detail-{Guid.NewGuid():N}";
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            var shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();

            tentId = Guid.NewGuid();
            db.Tents.Add(new Tent
            {
                Id = tentId,
                Name = tentName,
                Size = 4,
                TentModelId = shapeId,
                OverallState = TentOverallState.Good,
                Comments = "Comments on archived",
                IsArchived = true,
                CreatedAt = DateTime.UtcNow.AddHours(-2),
                UpdatedAt = DateTime.UtcNow.AddHours(-1),
                CreatedByUserId = CustomApiFactory.TestUserId,
                UpdatedByUserId = CustomApiFactory.TestUserId
            });
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync($"/api/tents/{tentId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.Equal(tentId, payload.Data.Id);
        Assert.Equal(tentName, payload.Data.Name);
        Assert.True(payload.Data.IsArchived);
        Assert.Equal("Comments on archived", payload.Data.Comments);
    }

    // --- Story 3.3: Tent History tests ---

    [Fact]
    public async Task GetTentHistory_UnknownTent_Returns404()
    {
        await EnsureTestUserExistsAsync();
        using var client = CreateAuthenticatedClient();

        var response = await client.GetAsync($"/api/tents/{Guid.NewGuid()}/history");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("TENT_NOT_FOUND", payload.Code);
    }

    [Fact]
    public async Task GetTentHistory_WithoutAuthentication_Returns401()
    {
        using var client = _factory.CreateClient(new WebApplicationFactoryClientOptions
        {
            BaseAddress = new Uri("https://localhost")
        });

        var response = await client.GetAsync($"/api/tents/{Guid.NewGuid()}/history");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(101)]
    public async Task GetTentHistory_InvalidLimit_Returns400(int invalidLimit)
    {
        await EnsureTestUserExistsAsync();
        using var client = CreateAuthenticatedClient();

        var response = await client.GetAsync(
            $"/api/tents/{Guid.NewGuid()}/history?limit={invalidLimit}");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("INVALID_REQUEST", payload.Code);
    }

    [Fact]
    public async Task GetTentHistory_InvalidCategory_Returns400()
    {
        await EnsureTestUserExistsAsync();
        using var client = CreateAuthenticatedClient();

        var response = await client.GetAsync(
            $"/api/tents/{Guid.NewGuid()}/history?category=invalid_category");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.Equal("INVALID_REQUEST", payload.Code);
    }

    [Fact]
    public async Task GetTentHistory_ForExistingTent_ReturnsTentEventsNewestFirst()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();
        }

        using (var client = CreateAuthenticatedClient())
        {
            var createResponse = await client.PostAsJsonAsync("/api/tents", new
            {
                name = $"History-Test-{Guid.NewGuid():N}",
                size = 4,
                tentModelId = shapeId,
                overallState = "Good"
            });
            createResponse.EnsureSuccessStatusCode();
            var created = await createResponse.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
            tentId = created!.Data.Id;

            await Task.Delay(50);

            var updateResponse = await client.PutAsJsonAsync($"/api/tents/{tentId}", new
            {
                name = "History-Test-Updated",
                size = 6,
                overallState = "NeedsRepair",
                comments = "Updated for history test"
            });
            updateResponse.EnsureSuccessStatusCode();
        }

        using var historyClient = CreateAuthenticatedClient();
        var response = await historyClient.GetAsync($"/api/tents/{tentId}/history");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TentHistoryApiItem>>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);
        Assert.NotEmpty(payload.Data);

        var tentEvents = payload.Data.Where(e => e.Category == "tent_info").ToList();
        Assert.NotEmpty(tentEvents);
        Assert.Contains(tentEvents, e => e.Action == "tent_created");
        Assert.Contains(tentEvents, e => e.Action == "tent_updated");

        for (int i = 1; i < tentEvents.Count; i++)
        {
            Assert.True(tentEvents[i - 1].OccurredAt >= tentEvents[i].OccurredAt);
        }
    }

    [Fact]
    public async Task GetTentHistory_PartEvents_IncludePartStateChanges()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        Guid partId;
        using (var client = CreateAuthenticatedClient())
        {
            Guid shapeId;
            using (var scope = _factory.Services.CreateScope())
            {
                var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
                shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();
            }

            var createResponse = await client.PostAsJsonAsync("/api/tents", new
            {
                name = $"History-Parts-{Guid.NewGuid():N}",
                size = 4,
                tentModelId = shapeId,
                overallState = "Good"
            });
            createResponse.EnsureSuccessStatusCode();
            var created = await createResponse.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
            tentId = created!.Data.Id;
            partId = created.Data.Parts[0].Id;

            await Task.Delay(50);

            var updatePartResponse = await client.PutAsJsonAsync($"/api/parts/{partId}", new
            {
                state = "NeedsRepair",
                comments = "Test comment"
            });
            updatePartResponse.EnsureSuccessStatusCode();
        }

        using var historyClient = CreateAuthenticatedClient();
        var response = await historyClient.GetAsync($"/api/tents/{tentId}/history");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TentHistoryApiItem>>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);

        Assert.Contains(payload.Data, e => e.Action == AuditActions.TentCreated);
        Assert.Contains(payload.Data, e => e.Action == AuditActions.PartStateChanged);
    }

    [Fact]
    public async Task GetTentHistory_PartEventsFromOtherTents_AreExcluded()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId1;
        Guid tentId2;
        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();
        }

        DataEnvelope<TentApiDto>? tent1Dto = null;
        using (var client = CreateAuthenticatedClient())
        {
            var create1 = await client.PostAsJsonAsync("/api/tents", new
            {
                name = $"History-Other-1-{Guid.NewGuid():N}",
                size = 4,
                tentModelId = shapeId,
                overallState = "Good"
            });
            create1.EnsureSuccessStatusCode();
            tent1Dto = await create1.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
            tentId1 = tent1Dto!.Data.Id;

            var create2 = await client.PostAsJsonAsync("/api/tents", new
            {
                name = $"History-Other-2-{Guid.NewGuid():N}",
                size = 4,
                tentModelId = shapeId,
                overallState = "Good"
            });
            create2.EnsureSuccessStatusCode();
            tentId2 = (await create2.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>())!.Data.Id;

            var partId = tent1Dto.Data.Parts[0].Id;

            var updatePartResponse = await client.PutAsJsonAsync($"/api/parts/{partId}", new
            {
                state = "NeedsRepair",
                comments = "Test comment"
            });
            updatePartResponse.EnsureSuccessStatusCode();
        }

        using var historyClient = CreateAuthenticatedClient();

        var response1 = await historyClient.GetAsync($"/api/tents/{tentId1}/history");
        var payload1 = await response1.Content.ReadFromJsonAsync<DataEnvelope<List<TentHistoryApiItem>>>();
        Assert.NotNull(payload1!.Data);
        Assert.Contains(payload1.Data, e => e.Action == AuditActions.PartStateChanged);

        var response2 = await historyClient.GetAsync($"/api/tents/{tentId2}/history");
        var payload2 = await response2.Content.ReadFromJsonAsync<DataEnvelope<List<TentHistoryApiItem>>>();
        Assert.NotNull(payload2!.Data);
        Assert.DoesNotContain(payload2.Data, e => e.Action == AuditActions.PartStateChanged);
    }

    [Fact]
    public async Task GetTentHistory_ArchivedTent_StillReturnsHistory()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();
        }

        using (var client = CreateAuthenticatedClient())
        {
            var createResponse = await client.PostAsJsonAsync("/api/tents", new
            {
                name = $"History-Archived-{Guid.NewGuid():N}",
                size = 4,
                tentModelId = shapeId,
                overallState = "Good"
            });
            createResponse.EnsureSuccessStatusCode();
            tentId = (await createResponse.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>())!.Data.Id;

            var archiveResponse = await client.PutAsync($"/api/tents/{tentId}/archive", null);
            archiveResponse.EnsureSuccessStatusCode();
        }

        using var historyClient = CreateAuthenticatedClient();
        var response = await historyClient.GetAsync($"/api/tents/{tentId}/history");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TentHistoryApiItem>>>();
        Assert.NotNull(payload);
        Assert.NotNull(payload.Data);

        Assert.Contains(payload.Data, e => e.Action == AuditActions.TentCreated);
        Assert.Contains(payload.Data, e => e.Action == AuditActions.TentArchived);
    }

    [Fact]
    public async Task GetTentHistory_CategoryFilter_ReturnsFilteredResults()
    {
        await EnsureTestUserExistsAsync();

        Guid tentId;
        Guid shapeId;
        Guid partId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentModels.Where(x => x.IsActive).Select(x => x.Id).FirstAsync();
        }

        using (var client = CreateAuthenticatedClient())
        {
            var createResponse = await client.PostAsJsonAsync("/api/tents", new
            {
                name = $"History-Filter-{Guid.NewGuid():N}",
                size = 4,
                tentModelId = shapeId,
                overallState = "Good"
            });
            createResponse.EnsureSuccessStatusCode();
            var created = await createResponse.Content.ReadFromJsonAsync<DataEnvelope<TentApiDto>>();
            tentId = created!.Data.Id;
            partId = created.Data.Parts[0].Id;

            var updatePartResponse = await client.PutAsJsonAsync($"/api/parts/{partId}", new
            {
                state = "NeedsRepair",
                comments = "Test comment"
            });
            updatePartResponse.EnsureSuccessStatusCode();
        }

        using var historyClient = CreateAuthenticatedClient();

        var allResponse = await historyClient.GetAsync($"/api/tents/{tentId}/history");
        var allPayload = await allResponse.Content.ReadFromJsonAsync<DataEnvelope<List<TentHistoryApiItem>>>();
        Assert.NotNull(allPayload!.Data);
        Assert.True(allPayload.Data.Count >= 2);

        var partStateResponse = await historyClient.GetAsync($"/api/tents/{tentId}/history?category=part_state");
        var partStatePayload = await partStateResponse.Content.ReadFromJsonAsync<DataEnvelope<List<TentHistoryApiItem>>>();
        Assert.NotNull(partStatePayload!.Data);

        Assert.Contains(partStatePayload.Data, e => e.Action == AuditActions.PartStateChanged);
        Assert.DoesNotContain(partStatePayload.Data, e => e.Action == AuditActions.TentCreated);

        var tentResponse = await historyClient.GetAsync($"/api/tents/{tentId}/history?category=tent_info");
        var tentPayload = await tentResponse.Content.ReadFromJsonAsync<DataEnvelope<List<TentHistoryApiItem>>>();
        Assert.NotNull(tentPayload!.Data);

        Assert.Contains(tentPayload.Data, e => e.Action == AuditActions.TentCreated);
        Assert.DoesNotContain(tentPayload.Data, e => e.Action == AuditActions.PartStateChanged);
    }

    // --- DTOs for history test deserialization ---

    private sealed class TentHistoryApiItem
    {
        public Guid Id { get; set; }
        public string Action { get; set; } = string.Empty;
        public string Category { get; set; } = string.Empty;
        public DateTime OccurredAt { get; set; }
        public string? ActorUserId { get; set; }
        public string ActorDisplayName { get; set; } = string.Empty;
    }

    private sealed class ErrorPayload
    {
        public string Error { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
    }
}
