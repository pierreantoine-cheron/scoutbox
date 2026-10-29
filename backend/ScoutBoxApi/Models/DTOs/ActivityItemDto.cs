namespace ScoutBoxApi.Models.DTOs;

public record ActivityItemDto(
    Guid Id,
    string Action,
    string Category,
    DateTime OccurredAt,
    Guid ActorUserId,
    string ActorDisplayName,
    Guid? TentId,
    string? TentName,
    string? SubjectName,
    List<TentHistoryDetailDto> Details);

public record ActivityPageDto(
    List<ActivityItemDto> Items,
    string? NextCursor);
