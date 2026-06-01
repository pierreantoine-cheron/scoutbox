namespace ScoutBoxApi.Models.DTOs;

public record AssignTagsRequest(IReadOnlyList<Guid> TagIds);
