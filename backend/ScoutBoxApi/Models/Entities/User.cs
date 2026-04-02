namespace ScoutBoxApi.Models.Entities;

public class User
{
    public Guid Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }

    // Soft delete fields for audit trail integrity
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAt { get; set; }

    public ICollection<Invite> CreatedInvites { get; set; } = new List<Invite>();
    public ICollection<Invite> UsedInvites { get; set; } = new List<Invite>();
    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
}

