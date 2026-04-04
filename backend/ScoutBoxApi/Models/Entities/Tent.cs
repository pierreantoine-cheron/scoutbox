namespace ScoutBoxApi.Models.Entities;

public class Tent
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public TentOverallState OverallState { get; set; }
    public int Size { get; set; }
    public Guid TentShapeId { get; set; }
    public string? Comments { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }
    public Guid CreatedByUserId { get; set; }
    public Guid UpdatedByUserId { get; set; }

    public TentShape TentShape { get; set; } = null!;
    public User CreatedByUser { get; set; } = null!;
    public User UpdatedByUser { get; set; } = null!;
    public ICollection<Part> Parts { get; set; } = new List<Part>();
}
