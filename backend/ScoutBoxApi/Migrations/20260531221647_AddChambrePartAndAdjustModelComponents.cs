using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace ScoutBoxApi.Migrations
{
    /// <inheritdoc />
    public partial class AddChambrePartAndAdjustModelComponents : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "TentModelComponents",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000316"));

            migrationBuilder.DeleteData(
                table: "TentModelComponents",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000323"));

            migrationBuilder.DeleteData(
                table: "TentModelComponents",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000324"));

            migrationBuilder.DeleteData(
                table: "TentModelComponents",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000326"));

            migrationBuilder.InsertData(
                table: "PartKinds",
                columns: new[] { "Id", "CreatedAt", "DisplayOrder", "Name", "UpdatedAt" },
                values: new object[] { new Guid("00000000-0000-0000-0000-000000000108"), new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc), 8, "Chambre", new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc) });
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DeleteData(
                table: "PartKinds",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000108"));

            migrationBuilder.InsertData(
                table: "TentModelComponents",
                columns: new[] { "Id", "IsStandard", "PartKindId", "TentModelId" },
                values: new object[,]
                {
                    { new Guid("00000000-0000-0000-0000-000000000316"), true, new Guid("00000000-0000-0000-0000-000000000102"), new Guid("00000000-0000-0000-0000-000000000203") },
                    { new Guid("00000000-0000-0000-0000-000000000323"), true, new Guid("00000000-0000-0000-0000-000000000102"), new Guid("00000000-0000-0000-0000-000000000204") },
                    { new Guid("00000000-0000-0000-0000-000000000324"), true, new Guid("00000000-0000-0000-0000-000000000103"), new Guid("00000000-0000-0000-0000-000000000204") },
                    { new Guid("00000000-0000-0000-0000-000000000326"), true, new Guid("00000000-0000-0000-0000-000000000105"), new Guid("00000000-0000-0000-0000-000000000204") }
                });
        }
    }
}
