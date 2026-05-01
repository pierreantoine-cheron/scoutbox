using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ScoutBoxApi.Migrations
{
    /// <inheritdoc />
    public partial class AddTentArchiveSoftDelete : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.AddColumn<bool>(
                name: "IsArchived",
                table: "Tents",
                type: "INTEGER",
                nullable: false,
                defaultValue: false);

            migrationBuilder.CreateIndex(
                name: "IX_Tents_IsArchived",
                table: "Tents",
                column: "IsArchived");
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropIndex(
                name: "IX_Tents_IsArchived",
                table: "Tents");

            migrationBuilder.DropColumn(
                name: "IsArchived",
                table: "Tents");
        }
    }
}
