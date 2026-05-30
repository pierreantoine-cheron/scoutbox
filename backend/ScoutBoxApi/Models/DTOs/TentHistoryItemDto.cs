namespace ScoutBoxApi.Models.DTOs;

public record TentHistoryItemDto(
    Guid Id,
    string Action,
    string Category,
    DateTime OccurredAt,
    Guid? ActorUserId,
    string ActorDisplayName,
    string? SubjectName,
    List<TentHistoryDetailDto> Details,
    string? TargetEntityType,
    Guid? TargetEntityId);

public record TentHistoryDetailDto(
    string Label,
    string? OldValue,
    string? NewValue,
    string? Value,
    string? ValueType);
