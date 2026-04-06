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

    [Theory]
    [InlineData("", 6, "TENT_NAME_REQUIRED")]
    [InlineData("   ", 6, "TENT_NAME_REQUIRED")]
    [InlineData("Tente", 0, "INVALID_TENT_SIZE")]
    [InlineData("Tente", -1, "INVALID_TENT_SIZE")]
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
        public string OverallState { get; set; } = string.Empty;
        public string? Comments { get; set; }
    }

    private sealed class ErrorPayload
    {
        public string Error { get; set; } = string.Empty;
        public string Code { get; set; } = string.Empty;
    }
}
