using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ScoutBoxApi.Migrations
{
    /// <inheritdoc />
    public partial class AddSchemaHardening : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<DateTime>(
                name: "UpdatedAt",
                table: "PartKinds",
                type: "TEXT",
                nullable: false,
                defaultValue: new DateTime(1, 1, 1, 0, 0, 0, 0, DateTimeKind.Unspecified));

            migrationBuilder.UpdateData(
                table: "PartKinds",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000101"),
                column: "UpdatedAt",
                value: new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc));

            migrationBuilder.UpdateData(
                table: "PartKinds",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000102"),
                column: "UpdatedAt",
                value: new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc));

            migrationBuilder.UpdateData(
                table: "PartKinds",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000103"),
                column: "UpdatedAt",
                value: new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc));

            migrationBuilder.UpdateData(
                table: "PartKinds",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000104"),
                column: "UpdatedAt",
                value: new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc));

            migrationBuilder.UpdateData(
                table: "PartKinds",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000105"),
                column: "UpdatedAt",
                value: new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc));

            migrationBuilder.UpdateData(
                table: "PartKinds",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000106"),
                column: "UpdatedAt",
                value: new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc));

            migrationBuilder.UpdateData(
                table: "PartKinds",
                keyColumn: "Id",
                keyValue: new Guid("00000000-0000-0000-0000-000000000107"),
                column: "UpdatedAt",
                value: new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc));

            migrationBuilder.AddCheckConstraint(
                name: "CK_TentShapes_DisplayOrder_Max",
                table: "TentShapes",
                sql: "DisplayOrder <= 999");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Tents_OverallState_Valid",
                table: "Tents",
                sql: "OverallState BETWEEN 1 AND 3");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Tents_Size_Max",
                table: "Tents",
                sql: "Size <= 100");

            migrationBuilder.AddCheckConstraint(
                name: "CK_Parts_State_Valid",
                table: "Parts",
                sql: "State BETWEEN 1 AND 4");

            migrationBuilder.AddCheckConstraint(
                name: "CK_PartKinds_DisplayOrder_Max",
                table: "PartKinds",
                sql: "DisplayOrder <= 999");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropCheckConstraint(
                name: "CK_TentShapes_DisplayOrder_Max",
                table: "TentShapes");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Tents_OverallState_Valid",
                table: "Tents");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Tents_Size_Max",
                table: "Tents");

            migrationBuilder.DropCheckConstraint(
                name: "CK_Parts_State_Valid",
                table: "Parts");

            migrationBuilder.DropCheckConstraint(
                name: "CK_PartKinds_DisplayOrder_Max",
                table: "PartKinds");

            migrationBuilder.DropColumn(
                name: "UpdatedAt",
                table: "PartKinds");
        }
    }
}
