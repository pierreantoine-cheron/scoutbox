using System.ComponentModel.DataAnnotations;

namespace ScoutBoxApi.Models.DTOs;

public record UpdateTentRequest(
    [Required(ErrorMessage = "Tent name is required")]
    [TrimmedStringLength(100, MinimumLength = 1, ErrorMessage = "Tent name must be between 1 and 100 characters")]
    string Name,

    [Range(1, 100, ErrorMessage = "Tent size must be between 1 and 100")]
    int Size,

    [Required(ErrorMessage = "Tent overall state is required")]
    string OverallState,

    [TrimmedStringLength(500, ErrorMessage = "Tent comments cannot exceed 500 characters")]
    string? Comments);
