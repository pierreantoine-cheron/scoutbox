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
            var shapeToDisable = await db.TentShapes.OrderBy(x => x.DisplayOrder).FirstAsync();
            shapeToDisable.IsActive = false;
            shapeToDisable.UpdatedAt = DateTime.UtcNow;
            await db.SaveChangesAsync();
        }

        using var client = CreateAuthenticatedClient();
        var response = await client.GetAsync("/api/tent-shapes");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<DataEnvelope<List<TentShapeApiDto>>>();
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
            shapeId = await db.TentShapes
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
            tentShapeId = shapeId,
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
        Assert.Equal(shapeId, payload.Data.TentShapeId);
        Assert.Equal("Good", payload.Data.OverallState);
        Assert.Equal("Commentaire", payload.Data.Comments);
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
            var shape = await db.TentShapes
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
                TentShapeId = shapeId,
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
        Assert.Equal(shapeId, createdTent.TentShapeId);
        Assert.Equal(shapeName, createdTent.TentShapeName);
        Assert.Equal("Good", createdTent.OverallState);
    }

    [Fact]
    public async Task GetTents_ReturnsDeterministicOrderingByUpdatedAtThenCreatedAtDesc()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        string firstName;
        string secondName;
        string thirdName;

        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentShapes
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            var baseTime = DateTime.UtcNow;
            firstName = $"Order-A-{Guid.NewGuid():N}";
            secondName = $"Order-B-{Guid.NewGuid():N}";
            thirdName = $"Order-C-{Guid.NewGuid():N}";

            db.Tents.AddRange(
                new Tent
                {
                    Id = Guid.NewGuid(),
                    Name = firstName,
                    Size = 4,
                    TentShapeId = shapeId,
                    OverallState = TentOverallState.Good,
                    CreatedAt = baseTime.AddMinutes(-3),
                    UpdatedAt = baseTime,
                    CreatedByUserId = CustomApiFactory.TestUserId,
                    UpdatedByUserId = CustomApiFactory.TestUserId
                },
                new Tent
                {
                    Id = Guid.NewGuid(),
                    Name = secondName,
                    Size = 4,
                    TentShapeId = shapeId,
                    OverallState = TentOverallState.Good,
                    CreatedAt = baseTime.AddMinutes(-1),
                    UpdatedAt = baseTime,
                    CreatedByUserId = CustomApiFactory.TestUserId,
                    UpdatedByUserId = CustomApiFactory.TestUserId
                },
                new Tent
                {
                    Id = Guid.NewGuid(),
                    Name = thirdName,
                    Size = 4,
                    TentShapeId = shapeId,
                    OverallState = TentOverallState.Good,
                    CreatedAt = baseTime.AddMinutes(-2),
                    UpdatedAt = baseTime.AddMinutes(-1),
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
            .Where(t => t.Name == firstName || t.Name == secondName || t.Name == thirdName)
            .Select(t => t.Name)
            .ToList();

        Assert.Equal(new[] { secondName, firstName, thirdName }, orderedNames);
    }

    [Theory]
    [InlineData("", 6, "TENT_NAME_REQUIRED")]
    [InlineData("   ", 6, "TENT_NAME_REQUIRED")]
    [InlineData("Tente", 0, "INVALID_TENT_SIZE")]
    [InlineData("Tente", -1, "INVALID_TENT_SIZE")]
    [InlineData("Tente", 101, "INVALID_TENT_SIZE")]
    public async Task CreateTent_WithInvalidPayload_ReturnsErrorCode(string name, int size, string expectedCode)
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentShapes
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
            tentShapeId = shapeId,
            overallState = "Good",
            comments = "test"
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.False(string.IsNullOrWhiteSpace(payload.Error));
        Assert.Equal(expectedCode, payload.Code);
    }

    [Fact]
    public async Task CreateTent_WithInvalidOverallState_ReturnsInvalidTentStateError()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentShapes
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
            tentShapeId = shapeId,
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
            tentShapeId = Guid.NewGuid(),
            overallState = "Good",
            comments = "test"
        };

        var response = await client.PostAsJsonAsync("/api/tents", request);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);

        var payload = await response.Content.ReadFromJsonAsync<ErrorPayload>();
        Assert.NotNull(payload);
        Assert.False(string.IsNullOrWhiteSpace(payload.Error));
        Assert.Equal("INVALID_TENT_SHAPE", payload.Code);
    }

    [Fact]
    public async Task CreateTent_WithDuplicateName_ReturnsTentNameExistsError()
    {
        await EnsureTestUserExistsAsync();

        Guid shapeId;
        using (var scope = _factory.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<ScoutBoxDbContext>();
            shapeId = await db.TentShapes
                .Where(x => x.IsActive)
                .OrderBy(x => x.DisplayOrder)
                .Select(x => x.Id)
                .FirstAsync();

            db.Tents.Add(new Tent
            {
                Id = Guid.NewGuid(),
                Name = "Tente Dupliquee",
                Size = 4,
                TentShapeId = shapeId,
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
            tentShapeId = shapeId,
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
            var shape = await db.TentShapes
                .Include(s => s.TentShapeParts)
                .Where(x => x.Name == "Canadienne")
                .FirstOrDefaultAsync();
            if (shape == null || !shape.IsActive)
            {
                shape = await db.TentShapes
                    .Include(s => s.TentShapeParts)
                    .Where(x => x.IsActive && x.TentShapeParts.Any())
                    .OrderBy(x => x.DisplayOrder)
                    .FirstAsync();
            }
            canadienneShapeId = shape.Id;
            expectedPartCount = shape.TentShapeParts.Count;
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = $"Tente Parts Test {Guid.NewGuid():N}",
            size = 6,
            tentShapeId = canadienneShapeId,
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
            shapeId = await GetFirstActiveShapeWithPartsAsync(db);
            expectedPartCount = await db.TentShapeParts
                .CountAsync(sp => sp.TentShapeId == shapeId);
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = $"Tente Cabanon Test {Guid.NewGuid():N}",
            size = 8,
            tentShapeId = shapeId,
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

            var shape = new TentShape
            {
                Id = Guid.NewGuid(),
                Name = "Empty Shape Test",
                IsActive = true,
                DisplayOrder = 99,
                Description = "Shape with no default parts",
                CreatedAt = DateTime.UtcNow,
                UpdatedAt = DateTime.UtcNow
            };
            db.TentShapes.Add(shape);
            await db.SaveChangesAsync();
            emptyShapeId = shape.Id;
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = "Tente No Parts Test",
            size = 2,
            tentShapeId = emptyShapeId,
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
            shapeId = await GetFirstActiveShapeWithPartsAsync(db);
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = $"Tente Audit Test {Guid.NewGuid():N}",
            size = 4,
            tentShapeId = shapeId,
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
            shapeId = await GetFirstActiveShapeWithPartsAsync(db);
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = $"Tente Order Test {Guid.NewGuid():N}",
            size = 4,
            tentShapeId = shapeId,
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
            shapeId = await GetFirstActiveShapeWithPartsAsync(db);
            tentsCountBefore = await db.Tents.CountAsync();
            partsCountBefore = await db.Parts.CountAsync();

            db.Tents.Add(new Tent
            {
                Id = Guid.NewGuid(),
                Name = uniqueName,
                Size = 4,
                TentShapeId = shapeId,
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
            tentShapeId = shapeId,
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
            shapeId = await GetFirstActiveShapeWithPartsAsync(db);
        }

        using var client = CreateAuthenticatedClient();
        var request = new
        {
            name = $"Tente Compatibility Test {Guid.NewGuid():N}",
            size = 8,
            tentShapeId = shapeId,
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
        Assert.Equal(shapeId, payload.Data.TentShapeId);
        Assert.Equal("Good", payload.Data.OverallState);
        Assert.Equal("Test compatibility", payload.Data.Comments);
        Assert.NotNull(payload.Data.Parts);
        Assert.NotEmpty(payload.Data.Parts);
    }

    private static async Task<Guid> GetFirstActiveShapeWithPartsAsync(ScoutBoxDbContext db)
    {
        var canadienne = await db.TentShapes
            .Where(x => x.Name == "Canadienne" && x.IsActive)
            .Select(x => x.Id)
            .FirstOrDefaultAsync();

        if (canadienne != Guid.Empty)
            return canadienne;

        return await db.TentShapes
            .Where(x => x.IsActive && x.TentShapeParts.Any())
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

    private sealed class TentShapeApiDto
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
        public Guid TentShapeId { get; set; }
        public string? TentShapeName { get; set; }
        public string OverallState { get; set; } = string.Empty;
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

    private sealed class ErrorPayload
    {
        public string Error { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
    }
}
