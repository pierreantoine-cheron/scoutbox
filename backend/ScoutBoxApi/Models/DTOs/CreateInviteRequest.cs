namespace ScoutBoxApi.Models.DTOs;

public record CreateInviteRequest(string? Code = null, int ExpiresInDays = 30);