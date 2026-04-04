namespace ScoutBoxApi.Models.Entities;

public class PartKind
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public bool IsStandard { get; set; }
    public int DisplayOrder { get; set; }
    public DateTime CreatedAt { get; set; }

    public ICollection<Part> Parts { get; set; } = new List<Part>();
    public ICollection<TentShapePart> TentShapeParts { get; set; } = new List<TentShapePart>();
}
