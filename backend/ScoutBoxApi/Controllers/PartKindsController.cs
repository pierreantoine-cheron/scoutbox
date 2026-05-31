using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;

namespace ScoutBoxApi.Controllers;

[Route("api/part-kinds")]
[ApiController]
[Authorize]
public class PartKindsController : ControllerBase
{
    private readonly ScoutBoxDbContext _db;

    public PartKindsController(ScoutBoxDbContext db)
    {
        _db = db;
    }

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var partKinds = await _db.PartKinds
            .OrderBy(pk => pk.DisplayOrder)
            .Select(pk => new PartKindDto(pk.Id, pk.Name, pk.DisplayOrder))
            .ToListAsync();

        return Ok(new { data = partKinds });
    }
}
