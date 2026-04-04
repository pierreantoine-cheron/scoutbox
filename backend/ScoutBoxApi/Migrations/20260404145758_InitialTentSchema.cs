using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

#pragma warning disable CA1814 // Prefer jagged arrays over multidimensional

namespace ScoutBoxApi.Migrations
{
    /// <inheritdoc />
    public partial class InitialTentSchema : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateTable(
                name: "PartKinds",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                    IsStandard = table.Column<bool>(type: "INTEGER", nullable: false),
                    DisplayOrder = table.Column<int>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_PartKinds", x => x.Id);
                    table.CheckConstraint("CK_PartKinds_DisplayOrder_Positive", "DisplayOrder > 0");
                });

            migrationBuilder.CreateTable(
                name: "TentShapes",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                    Description = table.Column<string>(type: "TEXT", maxLength: 500, nullable: true),
                    IsActive = table.Column<bool>(type: "INTEGER", nullable: false),
                    DisplayOrder = table.Column<int>(type: "INTEGER", nullable: false),
                    CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TentShapes", x => x.Id);
                    table.CheckConstraint("CK_TentShapes_DisplayOrder_Positive", "DisplayOrder > 0");
                });

            migrationBuilder.CreateTable(
                name: "Tents",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    Name = table.Column<string>(type: "TEXT", maxLength: 100, nullable: false),
                    OverallState = table.Column<int>(type: "INTEGER", nullable: false),
                    Size = table.Column<int>(type: "INTEGER", nullable: false),
                    TentShapeId = table.Column<Guid>(type: "TEXT", nullable: false),
                    Comments = table.Column<string>(type: "TEXT", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    CreatedByUserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    UpdatedByUserId = table.Column<Guid>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Tents", x => x.Id);
                    table.CheckConstraint("CK_Tents_Size_Positive", "Size > 0");
                    table.ForeignKey(
                        name: "FK_Tents_TentShapes_TentShapeId",
                        column: x => x.TentShapeId,
                        principalTable: "TentShapes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Tents_Users_CreatedByUserId",
                        column: x => x.CreatedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Tents_Users_UpdatedByUserId",
                        column: x => x.UpdatedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.CreateTable(
                name: "TentShapeParts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    TentShapeId = table.Column<Guid>(type: "TEXT", nullable: false),
                    PartKindId = table.Column<Guid>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_TentShapeParts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_TentShapeParts_PartKinds_PartKindId",
                        column: x => x.PartKindId,
                        principalTable: "PartKinds",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_TentShapeParts_TentShapes_TentShapeId",
                        column: x => x.TentShapeId,
                        principalTable: "TentShapes",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                });

            migrationBuilder.CreateTable(
                name: "Parts",
                columns: table => new
                {
                    Id = table.Column<Guid>(type: "TEXT", nullable: false),
                    TentId = table.Column<Guid>(type: "TEXT", nullable: false),
                    PartKindId = table.Column<Guid>(type: "TEXT", nullable: false),
                    State = table.Column<int>(type: "INTEGER", nullable: false),
                    Comments = table.Column<string>(type: "TEXT", maxLength: 500, nullable: true),
                    CreatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    UpdatedAt = table.Column<DateTime>(type: "TEXT", nullable: false),
                    CreatedByUserId = table.Column<Guid>(type: "TEXT", nullable: false),
                    UpdatedByUserId = table.Column<Guid>(type: "TEXT", nullable: false)
                },
                constraints: table =>
                {
                    table.PrimaryKey("PK_Parts", x => x.Id);
                    table.ForeignKey(
                        name: "FK_Parts_PartKinds_PartKindId",
                        column: x => x.PartKindId,
                        principalTable: "PartKinds",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Parts_Tents_TentId",
                        column: x => x.TentId,
                        principalTable: "Tents",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Cascade);
                    table.ForeignKey(
                        name: "FK_Parts_Users_CreatedByUserId",
                        column: x => x.CreatedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                    table.ForeignKey(
                        name: "FK_Parts_Users_UpdatedByUserId",
                        column: x => x.UpdatedByUserId,
                        principalTable: "Users",
                        principalColumn: "Id",
                        onDelete: ReferentialAction.Restrict);
                });

            migrationBuilder.InsertData(
                table: "PartKinds",
                columns: new[] { "Id", "CreatedAt", "DisplayOrder", "IsStandard", "Name" },
                values: new object[,]
                {
                    { new Guid("00000000-0000-0000-0000-000000000101"), new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc), 1, true, "toit" },
                    { new Guid("00000000-0000-0000-0000-000000000102"), new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc), 2, true, "double toit" },
                    { new Guid("00000000-0000-0000-0000-000000000103"), new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc), 3, true, "fetiere" },
                    { new Guid("00000000-0000-0000-0000-000000000104"), new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc), 4, true, "piquets" },
                    { new Guid("00000000-0000-0000-0000-000000000105"), new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc), 5, true, "tapis de sol" },
                    { new Guid("00000000-0000-0000-0000-000000000106"), new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc), 6, true, "sac" },
                    { new Guid("00000000-0000-0000-0000-000000000107"), new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc), 7, true, "sardines" }
                });

            migrationBuilder.InsertData(
                table: "TentShapes",
                columns: new[] { "Id", "CreatedAt", "Description", "DisplayOrder", "IsActive", "Name", "UpdatedAt" },
                values: new object[,]
                {
                    { new Guid("00000000-0000-0000-0000-000000000201"), new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc), "Tente legere a double pente.", 1, true, "Canadienne", new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("00000000-0000-0000-0000-000000000202"), new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc), "Tente spacieuse avec murs droits.", 2, true, "Cabanon", new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("00000000-0000-0000-0000-000000000203"), new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc), "Structure conique monomat.", 3, true, "Tipi", new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc) },
                    { new Guid("00000000-0000-0000-0000-000000000204"), new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc), "Grande tente collective.", 4, true, "Marabout", new DateTime(2026, 4, 4, 0, 0, 0, 0, DateTimeKind.Utc) }
                });

            migrationBuilder.InsertData(
                table: "TentShapeParts",
                columns: new[] { "Id", "PartKindId", "TentShapeId" },
                values: new object[,]
                {
                    { new Guid("00000000-0000-0000-0000-000000000301"), new Guid("00000000-0000-0000-0000-000000000101"), new Guid("00000000-0000-0000-0000-000000000201") },
                    { new Guid("00000000-0000-0000-0000-000000000302"), new Guid("00000000-0000-0000-0000-000000000102"), new Guid("00000000-0000-0000-0000-000000000201") },
                    { new Guid("00000000-0000-0000-0000-000000000303"), new Guid("00000000-0000-0000-0000-000000000103"), new Guid("00000000-0000-0000-0000-000000000201") },
                    { new Guid("00000000-0000-0000-0000-000000000304"), new Guid("00000000-0000-0000-0000-000000000104"), new Guid("00000000-0000-0000-0000-000000000201") },
                    { new Guid("00000000-0000-0000-0000-000000000305"), new Guid("00000000-0000-0000-0000-000000000105"), new Guid("00000000-0000-0000-0000-000000000201") },
                    { new Guid("00000000-0000-0000-0000-000000000306"), new Guid("00000000-0000-0000-0000-000000000106"), new Guid("00000000-0000-0000-0000-000000000201") },
                    { new Guid("00000000-0000-0000-0000-000000000307"), new Guid("00000000-0000-0000-0000-000000000107"), new Guid("00000000-0000-0000-0000-000000000201") },
                    { new Guid("00000000-0000-0000-0000-000000000308"), new Guid("00000000-0000-0000-0000-000000000101"), new Guid("00000000-0000-0000-0000-000000000202") },
                    { new Guid("00000000-0000-0000-0000-000000000309"), new Guid("00000000-0000-0000-0000-000000000102"), new Guid("00000000-0000-0000-0000-000000000202") },
                    { new Guid("00000000-0000-0000-0000-000000000310"), new Guid("00000000-0000-0000-0000-000000000103"), new Guid("00000000-0000-0000-0000-000000000202") },
                    { new Guid("00000000-0000-0000-0000-000000000311"), new Guid("00000000-0000-0000-0000-000000000104"), new Guid("00000000-0000-0000-0000-000000000202") },
                    { new Guid("00000000-0000-0000-0000-000000000312"), new Guid("00000000-0000-0000-0000-000000000105"), new Guid("00000000-0000-0000-0000-000000000202") },
                    { new Guid("00000000-0000-0000-0000-000000000313"), new Guid("00000000-0000-0000-0000-000000000106"), new Guid("00000000-0000-0000-0000-000000000202") },
                    { new Guid("00000000-0000-0000-0000-000000000314"), new Guid("00000000-0000-0000-0000-000000000107"), new Guid("00000000-0000-0000-0000-000000000202") },
                    { new Guid("00000000-0000-0000-0000-000000000315"), new Guid("00000000-0000-0000-0000-000000000101"), new Guid("00000000-0000-0000-0000-000000000203") },
                    { new Guid("00000000-0000-0000-0000-000000000316"), new Guid("00000000-0000-0000-0000-000000000102"), new Guid("00000000-0000-0000-0000-000000000203") },
                    { new Guid("00000000-0000-0000-0000-000000000317"), new Guid("00000000-0000-0000-0000-000000000103"), new Guid("00000000-0000-0000-0000-000000000203") },
                    { new Guid("00000000-0000-0000-0000-000000000318"), new Guid("00000000-0000-0000-0000-000000000104"), new Guid("00000000-0000-0000-0000-000000000203") },
                    { new Guid("00000000-0000-0000-0000-000000000319"), new Guid("00000000-0000-0000-0000-000000000105"), new Guid("00000000-0000-0000-0000-000000000203") },
                    { new Guid("00000000-0000-0000-0000-000000000320"), new Guid("00000000-0000-0000-0000-000000000106"), new Guid("00000000-0000-0000-0000-000000000203") },
                    { new Guid("00000000-0000-0000-0000-000000000321"), new Guid("00000000-0000-0000-0000-000000000107"), new Guid("00000000-0000-0000-0000-000000000203") },
                    { new Guid("00000000-0000-0000-0000-000000000322"), new Guid("00000000-0000-0000-0000-000000000101"), new Guid("00000000-0000-0000-0000-000000000204") },
                    { new Guid("00000000-0000-0000-0000-000000000323"), new Guid("00000000-0000-0000-0000-000000000102"), new Guid("00000000-0000-0000-0000-000000000204") },
                    { new Guid("00000000-0000-0000-0000-000000000324"), new Guid("00000000-0000-0000-0000-000000000103"), new Guid("00000000-0000-0000-0000-000000000204") },
                    { new Guid("00000000-0000-0000-0000-000000000325"), new Guid("00000000-0000-0000-0000-000000000104"), new Guid("00000000-0000-0000-0000-000000000204") },
                    { new Guid("00000000-0000-0000-0000-000000000326"), new Guid("00000000-0000-0000-0000-000000000105"), new Guid("00000000-0000-0000-0000-000000000204") },
                    { new Guid("00000000-0000-0000-0000-000000000327"), new Guid("00000000-0000-0000-0000-000000000106"), new Guid("00000000-0000-0000-0000-000000000204") },
                    { new Guid("00000000-0000-0000-0000-000000000328"), new Guid("00000000-0000-0000-0000-000000000107"), new Guid("00000000-0000-0000-0000-000000000204") }
                });

            migrationBuilder.CreateIndex(
                name: "IX_PartKinds_CreatedAt",
                table: "PartKinds",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_PartKinds_DisplayOrder",
                table: "PartKinds",
                column: "DisplayOrder");

            migrationBuilder.CreateIndex(
                name: "IX_PartKinds_Name",
                table: "PartKinds",
                column: "Name",
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_Parts_CreatedAt",
                table: "Parts",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_Parts_CreatedByUserId",
                table: "Parts",
                column: "CreatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_Parts_PartKindId",
                table: "Parts",
                column: "PartKindId");

            migrationBuilder.CreateIndex(
                name: "IX_Parts_TentId",
                table: "Parts",
                column: "TentId");

            migrationBuilder.CreateIndex(
                name: "IX_Parts_UpdatedByUserId",
                table: "Parts",
                column: "UpdatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_Tents_CreatedAt",
                table: "Tents",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_Tents_CreatedByUserId",
                table: "Tents",
                column: "CreatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_Tents_TentShapeId",
                table: "Tents",
                column: "TentShapeId");

            migrationBuilder.CreateIndex(
                name: "IX_Tents_UpdatedByUserId",
                table: "Tents",
                column: "UpdatedByUserId");

            migrationBuilder.CreateIndex(
                name: "IX_TentShapeParts_PartKindId",
                table: "TentShapeParts",
                column: "PartKindId");

            migrationBuilder.CreateIndex(
                name: "IX_TentShapeParts_TentShapeId",
                table: "TentShapeParts",
                column: "TentShapeId");

            migrationBuilder.CreateIndex(
                name: "IX_TentShapeParts_TentShapeId_PartKindId",
                table: "TentShapeParts",
                columns: new[] { "TentShapeId", "PartKindId" },
                unique: true);

            migrationBuilder.CreateIndex(
                name: "IX_TentShapes_CreatedAt",
                table: "TentShapes",
                column: "CreatedAt");

            migrationBuilder.CreateIndex(
                name: "IX_TentShapes_DisplayOrder",
                table: "TentShapes",
                column: "DisplayOrder");

            migrationBuilder.CreateIndex(
                name: "IX_TentShapes_Name",
                table: "TentShapes",
                column: "Name",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropTable(
                name: "Parts");

            migrationBuilder.DropTable(
                name: "TentShapeParts");

            migrationBuilder.DropTable(
                name: "Tents");

            migrationBuilder.DropTable(
                name: "PartKinds");

            migrationBuilder.DropTable(
                name: "TentShapes");
        }
    }
}
