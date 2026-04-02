namespace ScoutBoxApi.Models.DTOs;

/// <summary>
/// Request payload for user logout.
/// Includes refresh token to revoke current session lineage.
/// </summary>
public record LogoutRequest(string? RefreshToken);
