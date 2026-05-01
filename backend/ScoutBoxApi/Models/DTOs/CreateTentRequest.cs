using System.ComponentModel.DataAnnotations;

namespace ScoutBoxApi.Models.DTOs;

public class CreateTentRequest
{
    [Required(ErrorMessage = "Tent name is required")]
    [TrimmedStringLength(100, MinimumLength = 1, ErrorMessage = "Tent name must be between 1 and 100 characters")]
    public string Name { get; set; } = string.Empty;

    [Range(1, 100, ErrorMessage = "Tent size must be between 1 and 100")]
    public int Size { get; set; }

    [Required(ErrorMessage = "Tent shape is required")]
    public Guid TentShapeId { get; set; }

    [Required(ErrorMessage = "Tent overall state is required")]
    public string OverallState { get; set; } = string.Empty;

    [TrimmedStringLength(500, ErrorMessage = "Tent comments cannot exceed 500 characters")]
    public string? Comments { get; set; }
}
