namespace ScoutBoxApi.Models.DTOs;

public record UpdateTentModelRequest(string? Name, List<Guid>? ComponentIds);
