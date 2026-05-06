namespace ScoutBoxApi.Models.Entities;

public class Part
{
    public Guid Id { get; set; }
    public Guid TentId { get; set; }
    public Guid PartKindId { get; set; }
    public PartState State { get; set; }
    public string? Comments { get; set; }
    public int DisplayOrder { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Guid CreatedByUserId { get; set; }
    public Guid UpdatedByUserId { get; set; }

    public Tent Tent { get; set; } = null!;
    public PartKind PartKind { get; set; } = null!;
    public User CreatedByUser { get; set; } = null!;
    public User UpdatedByUser { get; set; } = null!;
}
