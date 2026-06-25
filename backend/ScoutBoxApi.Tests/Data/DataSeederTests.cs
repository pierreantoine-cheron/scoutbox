using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;
using Xunit;

namespace ScoutBoxApi.Tests.Data;

public class DataSeederTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly ScoutBoxDbContext _db;

    public DataSeederTests()
    {
        _connection = new SqliteConnection("Data Source=:memory:");
        _connection.Open();

        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseSqlite(_connection)
            .Options;

        _db = new ScoutBoxDbContext(options);
        _db.Database.Migrate();
    }

    [Fact]
    public async Task Seed_OnFreshDatabase_PopulatesAllTables()
    {
        DataSeeder.Seed(_db);

        Assert.Equal(10, await _db.PartKinds.CountAsync());
        Assert.Equal(6, await _db.TentModels.CountAsync());
        Assert.Equal(27, await _db.TentModelComponents.CountAsync());
        Assert.Equal(1, await _db.Invites.CountAsync());

        var seedInfo = await _db.Set<SeedInfo>().SingleAsync();
        Assert.True(seedInfo.IsSeeded);

        var partKindNames = await _db.PartKinds.OrderBy(x => x.DisplayOrder).Select(x => x.Name).ToListAsync();
        Assert.Contains("Arceaux", partKindNames);
        Assert.Contains("Armature", partKindNames);

        var tentModelNames = await _db.TentModels.OrderBy(x => x.DisplayOrder).Select(x => x.Name).ToListAsync();
        Assert.Contains("Autre", tentModelNames);
        Assert.Contains("2 secondes", tentModelNames);

        var tipiComponents = await _db.TentModelComponents
            .Include(c => c.PartKind)
            .Where(c => c.TentModelId == new Guid("00000000-0000-0000-0000-000000000203"))
            .Select(c => c.PartKind.Name)
            .ToListAsync();
        Assert.DoesNotContain("Fêtière", tipiComponents);
        Assert.DoesNotContain("Double toit", tipiComponents);
        Assert.Equal(5, tipiComponents.Count);

        var maraboutComponents = await _db.TentModelComponents
            .Include(c => c.PartKind)
            .Where(c => c.TentModelId == new Guid("00000000-0000-0000-0000-000000000204"))
            .Select(c => c.PartKind.Name)
            .ToListAsync();
        Assert.DoesNotContain("Fêtière", maraboutComponents);
        Assert.Contains("Armature", maraboutComponents);
        Assert.Equal(5, maraboutComponents.Count);

        var deuxSecondesComponents = await _db.TentModelComponents
            .Include(c => c.PartKind)
            .Where(c => c.TentModelId == new Guid("00000000-0000-0000-0000-000000000206"))
            .Select(c => c.PartKind.Name)
            .ToListAsync();
        Assert.Equal(3, deuxSecondesComponents.Count);
        Assert.Contains("Chambre", deuxSecondesComponents);
        Assert.Contains("Arceaux", deuxSecondesComponents);
        Assert.Contains("Sardines", deuxSecondesComponents);

        var autreComponents = await _db.TentModelComponents
            .CountAsync(c => c.TentModelId == new Guid("00000000-0000-0000-0000-000000000205"));
        Assert.Equal(0, autreComponents);

        Assert.Equal(1, await _db.Invites.CountAsync(i => i.Code == "ADMIN-SETUP"));
    }

    [Fact]
    public async Task Seed_OnAlreadySeededDatabase_DoesNotModifyData()
    {
        DataSeeder.Seed(_db);
        var initialPartKindCount = await _db.PartKinds.CountAsync();

        var customPartKind = new PartKind
        {
            Id = Guid.NewGuid(),
            Name = "Bâche",
            DisplayOrder = 99,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _db.PartKinds.Add(customPartKind);
        await _db.SaveChangesAsync();

        DataSeeder.Seed(_db);

        Assert.Equal(initialPartKindCount + 1, await _db.PartKinds.CountAsync());
        Assert.NotNull(await _db.PartKinds.SingleOrDefaultAsync(p => p.Name == "Bâche"));
        Assert.Equal(1, await _db.Set<SeedInfo>().CountAsync());
    }

    [Fact]
    public async Task Seed_WithExistingDataButNoFlag_MarksAsSeededWithoutReSeeding()
    {
        var partKind = new PartKind
        {
            Id = Guid.NewGuid(),
            Name = "Lanterne",
            DisplayOrder = 99,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        };
        _db.PartKinds.Add(partKind);
        await _db.SaveChangesAsync();

        var seedInfos = await _db.Set<SeedInfo>().ToListAsync();
        Assert.Empty(seedInfos);

        DataSeeder.Seed(_db);

        Assert.NotNull(await _db.PartKinds.SingleOrDefaultAsync(p => p.Name == "Lanterne"));
        seedInfos = await _db.Set<SeedInfo>().ToListAsync();
        Assert.Single(seedInfos);
        Assert.True(seedInfos[0].IsSeeded);
        Assert.Equal(1, await _db.PartKinds.CountAsync());
    }

    [Fact]
    public async Task Seed_TagsSkippedWhenNoUserExists()
    {
        DataSeeder.Seed(_db);

        Assert.Empty(await _db.Tags.ToListAsync());
    }

    [Fact]
    public async Task Seed_TagsSeededWhenUserExists()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "chef",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow,
            IsDeleted = false
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        DataSeeder.Seed(_db);

        var tags = await _db.Tags.OrderBy(t => t.Name).ToListAsync();
        Assert.Equal(5, tags.Count);
        Assert.Equal("Compagnons", tags[0].Name);
        Assert.Equal("#007254", tags[0].Color);
        Assert.Equal("Farfadets", tags[1].Name);
        Assert.Equal("#65bc99", tags[1].Color);
        Assert.Equal("Louveteaux-Jeannettes", tags[2].Name);
        Assert.Equal("#ff8300", tags[2].Color);
        Assert.Equal("Pionniers-Caravelles", tags[3].Name);
        Assert.Equal("#d03f15", tags[3].Color);
        Assert.Equal("Scouts-Guides", tags[4].Name);
        Assert.Equal("#0077b3", tags[4].Color);
    }

    [Fact]
    public async Task Seed_IsIdempotent()
    {
        DataSeeder.Seed(_db);
        var initialPartKindCount = await _db.PartKinds.CountAsync();
        var initialTentModelCount = await _db.TentModels.CountAsync();
        var initialComponentCount = await _db.TentModelComponents.CountAsync();
        var initialInviteCount = await _db.Invites.CountAsync();

        DataSeeder.Seed(_db);

        Assert.Equal(initialPartKindCount, await _db.PartKinds.CountAsync());
        Assert.Equal(initialTentModelCount, await _db.TentModels.CountAsync());
        Assert.Equal(initialComponentCount, await _db.TentModelComponents.CountAsync());
        Assert.Equal(initialInviteCount, await _db.Invites.CountAsync());
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
        GC.SuppressFinalize(this);
    }
}
