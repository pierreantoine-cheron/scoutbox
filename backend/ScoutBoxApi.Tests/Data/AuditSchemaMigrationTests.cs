using System;
using System.Linq;
using System.Threading.Tasks;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using ScoutBoxApi.Data;
using Xunit;

namespace ScoutBoxApi.Tests.Data;

public class AuditSchemaMigrationTests : IDisposable
{
    private const string PreviousMigration = "20260701122234_RemoveIsStandardFromTentModelComponent";

    private static readonly Guid SystemUserId = Guid.Parse("00000000-0000-0000-0000-000000000001");

    private readonly SqliteConnection _connection;
    private readonly ScoutBoxDbContext _db;

    public AuditSchemaMigrationTests()
    {
        _connection = new SqliteConnection("Data Source=:memory:");
        _connection.Open();

        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseSqlite(_connection)
            .Options;

        _db = new ScoutBoxDbContext(options);
    }

    [Fact]
    public async Task Migrate_BackfillsMissingActorToSystemAccount()
    {
        var eventId = Guid.NewGuid();
        var migrator = _db.GetService<IMigrator>();
        await migrator.MigrateAsync(PreviousMigration);

        await using (var command = _connection.CreateCommand())
        {
            command.CommandText =
                "INSERT INTO \"AuditEvents\" (\"Id\", \"Action\", \"ActorUserId\", \"OccurredAt\") " +
                "VALUES ($id, 'tent_created', NULL, '2026-01-01 00:00:00.000');";
            command.Parameters.AddWithValue("$id", eventId);
            await command.ExecuteNonQueryAsync();
        }

        await migrator.MigrateAsync();

        var actorUserId = await _db.AuditEvents
            .Where(e => e.Id == eventId)
            .Select(e => e.ActorUserId)
            .SingleAsync();

        Assert.Equal(SystemUserId, actorUserId);
    }

    [Fact]
    public async Task Migrate_RejectsAuditEventWithoutActor()
    {
        await _db.Database.MigrateAsync();

        await using var command = _connection.CreateCommand();
        command.CommandText =
            "INSERT INTO \"AuditEvents\" (\"Id\", \"Action\", \"ActorUserId\", \"OccurredAt\") " +
            "VALUES ($id, 'tent_created', NULL, '2026-01-01 00:00:00.000');";
        command.Parameters.AddWithValue("$id", Guid.NewGuid());

        var exception = await Assert.ThrowsAsync<SqliteException>(() => command.ExecuteNonQueryAsync());

        Assert.Contains("NOT NULL constraint failed: AuditEvents.ActorUserId", exception.Message);
    }

    [Fact]
    public async Task Migrate_RestrictsDeletingUserReferencedByAuditEvent()
    {
        await _db.Database.MigrateAsync();

        await using (var insert = _connection.CreateCommand())
        {
            insert.CommandText =
                "INSERT INTO \"AuditEvents\" (\"Id\", \"Action\", \"ActorUserId\", \"OccurredAt\") " +
                "VALUES ($id, 'tent_created', $actorUserId, '2026-01-01 00:00:00.000');";
            insert.Parameters.AddWithValue("$id", Guid.NewGuid());
            insert.Parameters.AddWithValue("$actorUserId", SystemUserId);
            await insert.ExecuteNonQueryAsync();
        }

        await using var command = _connection.CreateCommand();
        command.CommandText = "DELETE FROM \"Users\" WHERE \"Id\" = $id;";
        command.Parameters.AddWithValue("$id", SystemUserId);

        var exception = await Assert.ThrowsAsync<SqliteException>(() => command.ExecuteNonQueryAsync());

        Assert.Contains("FOREIGN KEY constraint failed", exception.Message);
    }

    public void Dispose()
    {
        _db.Dispose();
        _connection.Dispose();
        GC.SuppressFinalize(this);
    }
}
