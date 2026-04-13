namespace ScoutBoxApi.Models.DTOs;

public record PartDto(
    Guid Id,
    Guid PartKindId,
    string PartKindName,
    int DisplayOrder,
    string State,
    string? Comments,
    DateTime CreatedAt,
    DateTime UpdatedAt);