namespace ScoutBoxApi.Models.Entities;

public class Invite
{
    public Guid Id { get; set; }
    public string Code { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime ExpiresAt { get; set; }
    public bool IsUsed { get; set; }
    public Guid? CreatedByUserId { get; set; }
    public Guid? UsedByUserId { get; set; }
    public DateTime? UsedAt { get; set; }

    public User? CreatedBy { get; set; }
    public User? UsedBy { get; set; }
}
