namespace ScoutBoxApi.Models.Entities;

public class TentModelComponent
{
    public Guid Id { get; set; }
    public Guid TentModelId { get; set; }
    public Guid PartKindId { get; set; }
    public bool IsStandard { get; set; }

    public TentModel TentModel { get; set; } = null!;
    public PartKind PartKind { get; set; } = null!;
}
