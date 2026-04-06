using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ScoutBoxApi.Migrations
{
    /// <inheritdoc />
    public partial class AddUniqueTentNameIndex : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.CreateIndex(
                name: "IX_Tents_Name",
                table: "Tents",
                column: "Name",
                unique: true);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Tents_Name",
                table: "Tents");
        }
    }
}
