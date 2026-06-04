namespace ScoutBoxApi.Models.DTOs;

public record SetTentTagsRequest(IReadOnlyList<Guid> TagIds);
