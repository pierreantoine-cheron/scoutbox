using Microsoft.AspNetCore.Mvc;
using ScoutBoxApi.Models.DTOs;

namespace ScoutBoxApi.Controllers;

[Route("api/health")]
[ApiController]
public class HealthController : ControllerBase
{
    [HttpGet]
    public IActionResult Get()
    {
        return Ok(new HealthCheckResponse
        {
            Timestamp = DateTime.UtcNow
        });
    }
}
