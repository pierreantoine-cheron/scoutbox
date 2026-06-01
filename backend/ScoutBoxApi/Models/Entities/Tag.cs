namespace ScoutBoxApi.Models.Entities;

public class Tag : IHasName, IAuditableEntity
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string Color { get; set; } = string.Empty;
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Guid CreatedByUserId { get; set; }
    public Guid UpdatedByUserId { get; set; }

    public User CreatedByUser { get; set; } = null!;
    public User UpdatedByUser { get; set; } = null!;
    public ICollection<TentTag> TentTags { get; set; } = new List<TentTag>();
}
