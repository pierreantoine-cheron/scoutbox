namespace ScoutBoxApi.Models.Entities;

public class PartKind : IHasName
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public int DisplayOrder { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ICollection<Part> Parts { get; set; } = new List<Part>();
    public ICollection<TentModelComponent> TentModelComponents { get; set; } = new List<TentModelComponent>();
}
