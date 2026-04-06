namespace ScoutBoxApi.Models.DTOs;

public class CreateTentRequest
{
    public string Name { get; set; } = string.Empty;
    public int Size { get; set; }
    public Guid TentShapeId { get; set; }
    public string OverallState { get; set; } = string.Empty;
    public string? Comments { get; set; }
}
