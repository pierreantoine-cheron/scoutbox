namespace ScoutBoxApi.Models.DTOs;

public class InviteResponse
{
    public Guid Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public DateTime ExpiresAt { get; set; }
    public bool IsUsed { get; set; }
}
