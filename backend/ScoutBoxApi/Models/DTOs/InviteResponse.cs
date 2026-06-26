namespace ScoutBoxApi.Models.DTOs;

public record InviteResponse(Guid Id, string Code, DateTime ExpiresAt, bool IsUsed, string? InviteLink = null);