using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Models.DTOs;

public record PartDto(
    Guid Id,
    Guid PartKindId,
    string PartKindName,
    int DisplayOrder,
    string State,
    string? Comments,
    DateTime CreatedAt,
    DateTime UpdatedAt)
{
    public static PartDto FromPart(Part part) => new(
        part.Id,
        part.PartKindId,
        part.PartKind.Name,
        part.PartKind.DisplayOrder,
        part.State.ToString(),
        part.Comments,
        part.CreatedAt,
        part.UpdatedAt);
}