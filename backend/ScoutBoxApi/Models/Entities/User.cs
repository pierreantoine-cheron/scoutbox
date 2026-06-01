namespace ScoutBoxApi.Models.Entities;

/// <summary>
/// User entity with soft-delete support for audit trail integrity.
/// IMPORTANT: Users should only be soft-deleted (IsDeleted = true), never hard-deleted,
/// to preserve foreign key references in AuditEvents and other historical records.
/// The global query filter automatically excludes deleted users from normal queries.
/// Use IgnoreQueryFilters() when you need to access deleted users (e.g., for audit history).
/// </summary>
public class User
{
    public Guid Id { get; set; }
    public string Username { get; set; } = string.Empty;
    public string PasswordHash { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }

    // Soft delete fields for audit trail integrity
    // Historical records (AuditEvents, etc.) maintain FK associations via SetNull behavior
    // Deleted users display as "Utilisateur supprimé" in history views
    public bool IsDeleted { get; set; }
    public DateTime? DeletedAt { get; set; }

    public ICollection<Invite> CreatedInvites { get; set; } = new List<Invite>();
    public ICollection<Invite> UsedInvites { get; set; } = new List<Invite>();
    public ICollection<RefreshToken> RefreshTokens { get; set; } = new List<RefreshToken>();
    public ICollection<Tent> CreatedTents { get; set; } = new List<Tent>();
    public ICollection<Tent> UpdatedTents { get; set; } = new List<Tent>();
    public ICollection<Part> CreatedParts { get; set; } = new List<Part>();
    public ICollection<Part> UpdatedParts { get; set; } = new List<Part>();
    public ICollection<Tag> CreatedTags { get; set; } = new List<Tag>();
    public ICollection<Tag> UpdatedTags { get; set; } = new List<Tag>();
    public ICollection<TentTag> CreatedTentTags { get; set; } = new List<TentTag>();
}
