using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.Entities;
using Xunit;

namespace ScoutBoxApi.Tests.Data;

public class TentSchemaMigrationTests : IDisposable
{
    private readonly SqliteConnection _connection;
    private readonly ScoutBoxDbContext _db;

    public TentSchemaMigrationTests()
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
    public async Task Migrate_CreatesTentDomainTables()
    {
        var tableNames = new List<string>();

        await using var command = _connection.CreateCommand();
        command.CommandText = "SELECT name FROM sqlite_master WHERE type = 'table';";
        await using var reader = await command.ExecuteReaderAsync();

        while (await reader.ReadAsync())
        {
            tableNames.Add(reader.GetString(0));
        }

        Assert.Contains("Tents", tableNames);
        Assert.Contains("TentModels", tableNames);
        Assert.Contains("TentModelComponents", tableNames);
        Assert.Contains("PartKinds", tableNames);
        Assert.Contains("Parts", tableNames);
        Assert.Contains("Tags", tableNames);
        Assert.Contains("TentTags", tableNames);
    }

    [Fact]
    public async Task Migrate_SeedsPartKindsAndTentShapesDeterministically()
    {
        var partKinds = await _db.PartKinds
            .OrderBy(x => x.DisplayOrder)
            .Select(x => x.Name)
            .ToListAsync();

        var tentModels = await _db.TentModels
            .OrderBy(x => x.DisplayOrder)
            .Select(x => x.Name)
            .ToListAsync();

        Assert.Equal(new[]
        {
            "toit",
            "double toit",
            "fetiere",
            "piquets",
            "tapis de sol",
            "sac",
            "sardines",
            "Chambre"
        }, partKinds);

        Assert.Equal(new[]
        {
            "Canadienne",
            "Cabanon",
            "Tipi",
            "Marabout"
        }, tentModels);

        var modelComponentCount = await _db.TentModelComponents.CountAsync();
        Assert.Equal(24, modelComponentCount);
    }

    [Fact]
    public async Task Constraints_RejectInvalidName()
    {
        _db.TentModels.Add(new TentModel
        {
            Id = Guid.NewGuid(),
            Name = "   ",
            Description = null,
            IsActive = true,
            DisplayOrder = 99,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow
        });

        await Assert.ThrowsAsync<InvalidOperationException>(() => _db.SaveChangesAsync());
    }

    [Fact]
    public async Task ForeignKeys_RestrictDeletingUserReferencedByTent()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "tent_owner",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow,
            IsDeleted = false
        };
        _db.Users.Add(user);

        var shapeId = await _db.TentModels
            .OrderBy(x => x.DisplayOrder)
            .Select(x => x.Id)
            .FirstAsync();

        _db.Tents.Add(new Tent
        {
            Id = Guid.NewGuid(),
            Name = "Test Tent",
            OverallState = TentOverallState.Good,
            Size = 6,
            TentModelId = shapeId,
            Comments = "ok",
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
            CreatedByUserId = user.Id,
            UpdatedByUserId = user.Id
        });

        await _db.SaveChangesAsync();

        var exception = await Assert.ThrowsAsync<SqliteException>(() =>
            _db.Database.ExecuteSqlInterpolatedAsync($"DELETE FROM Users WHERE Id = {user.Id}"));

        Assert.Contains("FOREIGN KEY constraint failed", exception.Message);
    }

    [Fact]
    public async Task Constraints_RejectDuplicatePartKindOnSameTent()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "part_unique_owner",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow,
            IsDeleted = false
        };
        _db.Users.Add(user);

        var shapeId = await _db.TentModels
            .OrderBy(x => x.DisplayOrder)
            .Select(x => x.Id)
            .FirstAsync();
        var partKindId = await _db.PartKinds
            .OrderBy(x => x.DisplayOrder)
            .Select(x => x.Id)
            .FirstAsync();

        var tentId = Guid.NewGuid();
        var now = DateTime.UtcNow;
        _db.Tents.Add(new Tent
        {
            Id = tentId,
            Name = "Duplicate PartKind Tent",
            OverallState = TentOverallState.Good,
            Size = 6,
            TentModelId = shapeId,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = user.Id,
            UpdatedByUserId = user.Id
        });

        _db.Parts.AddRange(
            new Part
            {
                Id = Guid.NewGuid(),
                TentId = tentId,
                PartKindId = partKindId,
                State = PartState.Good,
                CreatedAt = now,
                UpdatedAt = now,
                CreatedByUserId = user.Id,
                UpdatedByUserId = user.Id
            },
            new Part
            {
                Id = Guid.NewGuid(),
                TentId = tentId,
                PartKindId = partKindId,
                State = PartState.Good,
                CreatedAt = now,
                UpdatedAt = now,
                CreatedByUserId = user.Id,
                UpdatedByUserId = user.Id
            });

        await Assert.ThrowsAsync<DbUpdateException>(() => _db.SaveChangesAsync());
    }

    [Fact]
    public async Task Constraints_AllowCaseSensitiveTagNamesButRejectExactDuplicates()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "tag_owner",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow,
            IsDeleted = false
        };
        _db.Users.Add(user);
        var now = DateTime.UtcNow;

        _db.Tags.AddRange(
            new Tag
            {
                Id = Guid.NewGuid(),
                Name = "Groupe A",
                Color = "#2196F3",
                CreatedAt = now,
                UpdatedAt = now,
                CreatedByUserId = user.Id,
                UpdatedByUserId = user.Id
            },
            new Tag
            {
                Id = Guid.NewGuid(),
                Name = "groupe A",
                Color = "#4CAF50",
                CreatedAt = now,
                UpdatedAt = now,
                CreatedByUserId = user.Id,
                UpdatedByUserId = user.Id
            });
        await _db.SaveChangesAsync();

        _db.Tags.Add(new Tag
        {
            Id = Guid.NewGuid(),
            Name = "Groupe A",
            Color = "#F44336",
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = user.Id,
            UpdatedByUserId = user.Id
        });

        await Assert.ThrowsAsync<DbUpdateException>(() => _db.SaveChangesAsync());
    }

    [Fact]
    public async Task Constraints_RejectDuplicateTentTagRelationship()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "tent_tag_owner",
            PasswordHash = "hash",
            CreatedAt = DateTime.UtcNow,
            IsDeleted = false
        };
        _db.Users.Add(user);

        var modelId = await _db.TentModels
            .OrderBy(x => x.DisplayOrder)
            .Select(x => x.Id)
            .FirstAsync();
        var now = DateTime.UtcNow;
        var tentId = Guid.NewGuid();
        var tagId = Guid.NewGuid();

        _db.Tents.Add(new Tent
        {
            Id = tentId,
            Name = "Tent Tag Unique Tent",
            OverallState = TentOverallState.Good,
            Size = 6,
            TentModelId = modelId,
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = user.Id,
            UpdatedByUserId = user.Id
        });
        _db.Tags.Add(new Tag
        {
            Id = tagId,
            Name = "Tent Tag Unique Tag",
            Color = "#2196F3",
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = user.Id,
            UpdatedByUserId = user.Id
        });
        _db.TentTags.Add(new TentTag
        {
            TentId = tentId,
            TagId = tagId,
            CreatedAt = now,
            CreatedByUserId = user.Id
        });
        await _db.SaveChangesAsync();

        await Assert.ThrowsAsync<SqliteException>(() =>
            _db.Database.ExecuteSqlInterpolatedAsync(
                $"INSERT INTO TentTags (TentId, TagId, CreatedAt, CreatedByUserId) VALUES ({tentId}, {tagId}, {now}, {user.Id})"));
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
        GC.SuppressFinalize(this);
    }
}
