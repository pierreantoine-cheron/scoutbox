namespace ScoutBoxApi.Models.DTOs;

public record TentDto(
    Guid Id,
    string Name,
    int Size,
    Guid TentShapeId,
    string OverallState,
    string? Comments,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    IReadOnlyList<PartDto> Parts = null!);