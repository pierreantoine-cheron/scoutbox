using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ScoutBoxApi.Migrations
{
    /// <inheritdoc />
    public partial class RemoveRedundantTentTagIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_TentTags_TentId_TagId",
                table: "TentTags");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_TentTags_TentId_TagId",
                table: "TentTags",
                columns: new[] { "TentId", "TagId" },
                unique: true);
        }
    }
}
