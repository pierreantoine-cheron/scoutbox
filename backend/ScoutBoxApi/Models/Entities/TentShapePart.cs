namespace ScoutBoxApi.Models.Entities;

public class TentShapePart
{
    public Guid Id { get; set; }
    public Guid TentShapeId { get; set; }
    public Guid PartKindId { get; set; }

    public TentShape TentShape { get; set; } = null!;
    public PartKind PartKind { get; set; } = null!;
}
