namespace ScoutBoxApi.Models.Entities;

public class TentTag
{
    public Guid TentId { get; set; }
    public Guid TagId { get; set; }
    public DateTime CreatedAt { get; set; }
    public Guid CreatedByUserId { get; set; }

    public Tent Tent { get; set; } = null!;
    public Tag Tag { get; set; } = null!;
    public User CreatedByUser { get; set; } = null!;
}
