using System.ComponentModel.DataAnnotations;

namespace ScoutBoxApi.Models.DTOs;

public record CreateInviteRequest([Range(1, 365)] int ExpiresInDays = 30, string? ServerUrl = null);
