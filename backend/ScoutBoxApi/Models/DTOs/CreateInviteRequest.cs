using System.ComponentModel.DataAnnotations;

namespace ScoutBoxApi.Models.DTOs;

public record CreateInviteRequest(string? Code = null, [Range(1, 365)] int ExpiresInDays = 30);