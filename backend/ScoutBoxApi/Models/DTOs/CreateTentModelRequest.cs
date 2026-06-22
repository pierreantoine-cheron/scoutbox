namespace ScoutBoxApi.Models.DTOs;

public record CreateTentModelRequest(string Name, List<Guid> ComponentIds);
