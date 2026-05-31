namespace ScoutBoxApi.Models.DTOs;

public record TentDto(
    Guid Id,
    string Name,
    int Size,
    Guid TentModelId,
    string? TentModelName,
    string OverallState,
    bool IsArchived,
    string? Comments,
    DateTime CreatedAt,
    DateTime UpdatedAt,
    IReadOnlyList<PartDto> Parts);
