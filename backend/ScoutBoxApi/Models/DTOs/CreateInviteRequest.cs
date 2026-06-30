using System.ComponentModel.DataAnnotations;

namespace ScoutBoxApi.Models.DTOs;

public record CreateInviteRequest(string ServerUrl, [Range(1, 365)] int ExpiresInDays = 30);
