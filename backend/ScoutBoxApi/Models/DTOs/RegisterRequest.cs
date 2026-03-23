namespace ScoutBoxApi.Models.DTOs;

public record RegisterRequest(string InviteCode, string Username, string Password);