using System;
using Microsoft.EntityFrameworkCore.Migrations;

#nullable disable

namespace ScoutBoxApi.Migrations
{
    /// <inheritdoc />
    public partial class MakeInviteCreatedByUserIdNonNullable : Migration
    {
        /// <inheritdoc />
        protected override void Up(MigrationBuilder migrationBuilder)
        {
            var systemUserId = new Guid("00000000-0000-0000-0000-000000000001");

            migrationBuilder.Sql(
                $"INSERT OR IGNORE INTO \"Users\" (\"Id\", \"Username\", \"PasswordHash\", \"CreatedAt\", \"IsDeleted\") " +
                $"VALUES ('{systemUserId}', 'SYSTEM', 'SYSTEM_NO_LOGIN', '{DateTime.UtcNow:yyyy-MM-dd HH:mm:ss.fff}', 0);");

            migrationBuilder.DropForeignKey(
                name: "FK_Invites_Users_CreatedByUserId",
                table: "Invites");

            migrationBuilder.AlterColumn<Guid>(
                name: "CreatedByUserId",
                table: "Invites",
                type: "TEXT",
                nullable: false,
                defaultValue: systemUserId,
                oldClrType: typeof(Guid),
                oldType: "TEXT",
                oldNullable: true);

            migrationBuilder.AddForeignKey(
                name: "FK_Invites_Users_CreatedByUserId",
                table: "Invites",
                column: "CreatedByUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.Restrict);
        }

        /// <inheritdoc />
        protected override void Down(MigrationBuilder migrationBuilder)
        {
            migrationBuilder.DropForeignKey(
                name: "FK_Invites_Users_CreatedByUserId",
                table: "Invites");

            migrationBuilder.AlterColumn<Guid>(
                name: "CreatedByUserId",
                table: "Invites",
                type: "TEXT",
                nullable: true,
                oldClrType: typeof(Guid),
                oldType: "TEXT");

            migrationBuilder.AddForeignKey(
                name: "FK_Invites_Users_CreatedByUserId",
                table: "Invites",
                column: "CreatedByUserId",
                principalTable: "Users",
                principalColumn: "Id",
                onDelete: ReferentialAction.SetNull);
        }
    }
}
