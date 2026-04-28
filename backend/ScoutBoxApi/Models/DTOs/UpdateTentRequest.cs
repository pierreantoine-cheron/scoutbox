namespace ScoutBoxApi.Models.DTOs;

public record UpdateTentRequest(
    string Name,
    int Size,
    string OverallState,
    string? Comments);
