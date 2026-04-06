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
            migrationBuilder.Sql(
                """
                UPDATE Tents
                SET Name = TRIM(Name)
                WHERE Name <> TRIM(Name);
                """);

            migrationBuilder.Sql(
                """
                WITH RankedTents AS (
                    SELECT
                        Id,
                        ROW_NUMBER() OVER (
                            PARTITION BY LOWER(Name)
                            ORDER BY CreatedAt ASC, Id ASC
                        ) AS RowNumber
                    FROM Tents
                )
                DELETE FROM Tents
                WHERE Id IN (
                    SELECT Id
                    FROM RankedTents
                    WHERE RowNumber > 1
                );
                """);

            migrationBuilder.Sql(
                """
                CREATE UNIQUE INDEX IX_Tents_Name
                ON Tents (Name COLLATE NOCASE);
                """);
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
