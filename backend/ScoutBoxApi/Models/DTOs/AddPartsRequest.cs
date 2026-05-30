using System.ComponentModel.DataAnnotations;

namespace ScoutBoxApi.Models.DTOs;

public record AddPartsRequest(
    [Required(ErrorMessage = "At least one part kind is required")]
    List<Guid>? PartKindIds);
