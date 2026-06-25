using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace ScoutBoxApi.Migrations
{
    /// <inheritdoc />
    public partial class ReplaceHasDataWithRuntimeSeeder : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "SeedInfos",
                columns: table => new
                {
                    Id = table.Column<int>(type: "INTEGER", nullable: false)
                        .Annotation("Sqlite:Autoincrement", true),
                    IsSeeded = table.Column<bool>(type: "INTEGER", nullable: false),
                    SeededAt = table.Column<DateTime>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_SeedInfos", x => x.Id);
                });

            // Clean up old HasData rows only on fresh databases where
            // nothing references them yet.  On existing databases the
            // NOT EXISTS clauses prevent any row from being deleted.
            // Order matters: children first, then parents.
            migrationBuilder.Sql("""
                DELETE FROM TentModelComponents
                WHERE TentModelId IN (
                    '00000000-0000-0000-0000-000000000201',
                    '00000000-0000-0000-0000-000000000202',
                    '00000000-0000-0000-0000-000000000203',
                    '00000000-0000-0000-0000-000000000204'
                ) AND TentModelId IN (
                    SELECT Id FROM TentModels
                    WHERE NOT EXISTS (SELECT 1 FROM Tents WHERE TentModelId = TentModels.Id)
                );

                DELETE FROM TentModels WHERE Id IN (
                    '00000000-0000-0000-0000-000000000201',
                    '00000000-0000-0000-0000-000000000202',
                    '00000000-0000-0000-0000-000000000203',
                    '00000000-0000-0000-0000-000000000204'
                ) AND NOT EXISTS (SELECT 1 FROM Tents WHERE TentModelId = TentModels.Id);

                DELETE FROM PartKinds WHERE Id IN (
                    '00000000-0000-0000-0000-000000000101',
                    '00000000-0000-0000-0000-000000000102',
                    '00000000-0000-0000-0000-000000000103',
                    '00000000-0000-0000-0000-000000000104',
                    '00000000-0000-0000-0000-000000000105',
                    '00000000-0000-0000-0000-000000000106',
                    '00000000-0000-0000-0000-000000000107',
                    '00000000-0000-0000-0000-000000000108'
                ) AND NOT EXISTS (SELECT 1 FROM Parts WHERE PartKindId = PartKinds.Id);
            """);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "SeedInfos");
        }
    }
}
