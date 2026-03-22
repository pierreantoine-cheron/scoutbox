namespace ScoutBoxApi.Models.DTOs;

public class RegisterRequest
{
    public string InviteCode { get; set; } = string.Empty;
    public string Username { get; set; } = string.Empty;
    public string Password { get; set; } = string.Empty;
    public string ServerUrl { get; set; } = string.Empty;
}
