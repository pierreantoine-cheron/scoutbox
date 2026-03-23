namespace ScoutBoxApi.Models.DTOs;

public record HealthCheckResponse(string Status = "healthy", DateTime Timestamp = default);