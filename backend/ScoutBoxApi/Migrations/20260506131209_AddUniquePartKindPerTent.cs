using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.EntityFrameworkCore.Migrations;
using ScoutBoxApi.Data;

#nullable disable

namespace ScoutBoxApi.Migrations
{
    [Migration("20260506131209_AddUniquePartKindPerTent")]
    [DbContext(typeof(ScoutBoxDbContext))]
    public partial class AddUniquePartKindPerTent : Migration
    {
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_Parts_TentId_PartKindId",
                table: "Parts",
                columns: new[] { "TentId", "PartKindId" },
                unique: true);
        }

        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Parts_TentId_PartKindId",
                table: "Parts");
        }
    }
}
