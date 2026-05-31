namespace ScoutBoxApi.Models.Entities;

public class TentModel : IHasName
{
    public Guid Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public string? Description { get; set; }
    public bool IsActive { get; set; }
    public int DisplayOrder { get; set; }
    public DateTime CreatedAt { get; set; }
    public DateTime UpdatedAt { get; set; }

    public ICollection<TentModelComponent> TentModelComponents { get; set; } = new List<TentModelComponent>();
    public ICollection<Tent> Tents { get; set; } = new List<Tent>();
}
