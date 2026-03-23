namespace ScoutBoxApi.Models.DTOs;

public record AuthResponse(string AccessToken, string RefreshToken, DateTime AccessTokenExpires, DateTime RefreshTokenExpires);