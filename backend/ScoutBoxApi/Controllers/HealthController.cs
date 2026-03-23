using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;

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
        if (await _db.Database.CanConnectAsync())
        {
            return Ok();
        }
        return StatusCode(503);
    }
}
