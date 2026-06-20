namespace ScoutBoxApi.Models.DTOs;

public record PartKindDto(Guid Id, string Name, int DisplayOrder, int TentCount = 0);
