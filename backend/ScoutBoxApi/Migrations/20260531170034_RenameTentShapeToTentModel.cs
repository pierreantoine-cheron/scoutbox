using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace ScoutBoxApi.Migrations
{
    /// <inheritdoc />
    public partial class RenameTentShapeToTentModel : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            // Drop FK before renaming table
            migrationBuilder.DropForeignKey(
                name: "FK_Tents_TentShapes_TentShapeId",
                table: "Tents");

            // Rename TentShapes -> TentModels
            migrationBuilder.RenameTable(
                name: "TentShapes",
                newName: "TentModels");

            // Rename TentShapeParts -> TentModelComponents
            migrationBuilder.RenameTable(
                name: "TentShapeParts",
                newName: "TentModelComponents");

            // Rename TentShapeId -> TentModelId in Tents
            migrationBuilder.RenameColumn(
                name: "TentShapeId",
                table: "Tents",
                newName: "TentModelId");

            // Rename index on Tents
            migrationBuilder.RenameIndex(
                name: "IX_Tents_TentShapeId",
                table: "Tents",
                newName: "IX_Tents_TentModelId");

            // Rename TentShapeId -> TentModelId in TentModelComponents
            migrationBuilder.RenameColumn(
                name: "TentShapeId",
                table: "TentModelComponents",
                newName: "TentModelId");

            // Rename index on TentModelComponents
            migrationBuilder.RenameIndex(
                name: "IX_TentShapeParts_TentShapeId",
                table: "TentModelComponents",
                newName: "IX_TentModelComponents_TentModelId");

            // Rename composite index
            migrationBuilder.RenameIndex(
                name: "IX_TentShapeParts_TentShapeId_PartKindId",
                table: "TentModelComponents",
                newName: "IX_TentModelComponents_TentModelId_PartKindId");

            // Rename PartKind index
            migrationBuilder.RenameIndex(
                name: "IX_TentShapeParts_PartKindId",
                table: "TentModelComponents",
                newName: "IX_TentModelComponents_PartKindId");

            // Rename primary key
            migrationBuilder.DropPrimaryKey(
                name: "PK_TentShapeParts",
                table: "TentModelComponents");

            migrationBuilder.AddPrimaryKey(
                name: "PK_TentModelComponents",
                table: "TentModelComponents",
                column: "Id");

            // Rename TentShapes PK
            migrationBuilder.DropPrimaryKey(
                name: "PK_TentShapes",
                table: "TentModels");

            migrationBuilder.AddPrimaryKey(
                name: "PK_TentModels",
                table: "TentModels",
                column: "Id");

            // Rename TentShapes indexes
            migrationBuilder.RenameIndex(
                name: "IX_TentShapes_CreatedAt",
                table: "TentModels",
                newName: "IX_TentModels_CreatedAt");

            migrationBuilder.RenameIndex(
                name: "IX_TentShapes_DisplayOrder",
                table: "TentModels",
                newName: "IX_TentModels_DisplayOrder");

            migrationBuilder.RenameIndex(
                name: "IX_TentShapes_Name",
                table: "TentModels",
                newName: "IX_TentModels_Name");

            // Add IsStandard column to TentModelComponents
            migrationBuilder.AddColumn<bool>(
                name: "IsStandard",
                table: "TentModelComponents",
                type: "INTEGER",
                nullable: false,
                defaultValue: true);

            // Drop IsStandard from PartKinds
            migrationBuilder.DropColumn(
                name: "IsStandard",
                table: "PartKinds");

            // Re-add FK on Tents
            migrationBuilder.AddForeignKey(
                name: "FK_Tents_TentModels_TentModelId",
                table: "Tents",
                column: "TentModelId",
                principalTable: "TentModels",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Tents_TentModels_TentModelId",
                table: "Tents");

            migrationBuilder.AddColumn<bool>(
                name: "IsStandard",
                table: "PartKinds",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);

            migrationBuilder.Sql("UPDATE PartKinds SET IsStandard = 1");

            migrationBuilder.DropColumn(
                name: "IsStandard",
                table: "TentModelComponents");

            migrationBuilder.DropPrimaryKey(
                name: "PK_TentModels",
                table: "TentModels");

            migrationBuilder.AddPrimaryKey(
                name: "PK_TentShapes",
                table: "TentModels",
                column: "Id");

            migrationBuilder.DropPrimaryKey(
                name: "PK_TentModelComponents",
                table: "TentModelComponents");

            migrationBuilder.AddPrimaryKey(
                name: "PK_TentShapeParts",
                table: "TentModelComponents",
                column: "Id");

            migrationBuilder.RenameIndex(
                name: "IX_TentModels_Name",
                table: "TentModels",
                newName: "IX_TentShapes_Name");

            migrationBuilder.RenameIndex(
                name: "IX_TentModels_DisplayOrder",
                table: "TentModels",
                newName: "IX_TentShapes_DisplayOrder");

            migrationBuilder.RenameIndex(
                name: "IX_TentModels_CreatedAt",
                table: "TentModels",
                newName: "IX_TentShapes_CreatedAt");

            migrationBuilder.RenameIndex(
                name: "IX_TentModelComponents_PartKindId",
                table: "TentModelComponents",
                newName: "IX_TentShapeParts_PartKindId");

            migrationBuilder.RenameIndex(
                name: "IX_TentModelComponents_TentModelId_PartKindId",
                table: "TentModelComponents",
                newName: "IX_TentShapeParts_TentShapeId_PartKindId");

            migrationBuilder.RenameIndex(
                name: "IX_TentModelComponents_TentModelId",
                table: "TentModelComponents",
                newName: "IX_TentShapeParts_TentShapeId");

            migrationBuilder.RenameColumn(
                name: "TentModelId",
                table: "TentModelComponents",
                newName: "TentShapeId");

            migrationBuilder.RenameIndex(
                name: "IX_Tents_TentModelId",
                table: "Tents",
                newName: "IX_Tents_TentShapeId");

            migrationBuilder.RenameColumn(
                name: "TentModelId",
                table: "Tents",
                newName: "TentShapeId");

            migrationBuilder.RenameTable(
                name: "TentModelComponents",
                newName: "TentShapeParts");

            migrationBuilder.RenameTable(
                name: "TentModels",
                newName: "TentShapes");

            migrationBuilder.AddForeignKey(
                name: "FK_Tents_TentShapes_TentShapeId",
                table: "Tents",
                column: "TentShapeId",
                principalTable: "TentShapes",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }
    }
}
