using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;

namespace ScoutBoxApi.Controllers;

[Route("api/health")]
[ApiController]
public class HealthController : ControllerBase
{
    private readonly ScoutBoxDbContext _db;

    public HealthController(ScoutBoxDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> Get()
    {
        try
        {
            await _db.Database.CanConnectAsync();
            return Ok(new HealthCheckResponse { Timestamp = DateTime.UtcNow });
        }
        catch
        {
            return StatusCode(503, new HealthCheckResponse { Timestamp = DateTime.UtcNow });
        }
    }
}
