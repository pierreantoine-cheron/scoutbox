namespace ScoutBoxApi.Models.DTOs;

public class CreateInviteRequest
{
    public string? Code { get; set; }
    public int ExpiresInDays { get; set; } = 30;
}
