namespace ScoutBoxApi.Models.DTOs;

public class HealthCheckResponse
{
    public string Status { get; set; } = "healthy";
    public DateTime Timestamp { get; set; }
}
