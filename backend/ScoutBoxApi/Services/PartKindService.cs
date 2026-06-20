using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Services;

public class PartKindService
{
    private const int MinNameLength = 1;
    private const int MaxNameLength = 60;

    private readonly ScoutBoxDbContext _db;
    private readonly ILogger<PartKindService> _logger;

    public PartKindService(ScoutBoxDbContext db, ILogger<PartKindService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<IReadOnlyList<PartKindDto>> GetAllAsync()
    {
        return await _db.PartKinds
            .OrderBy(pk => pk.DisplayOrder)
            .Select(pk => new PartKindDto(pk.Id, pk.Name, pk.DisplayOrder, pk.Parts.Count))
            .ToListAsync();
    }

    public async Task<(PartKindDto? Response, ErrorResponse? Error)> CreateAsync(CreatePartKindRequest request)
    {
        var name = request.Name?.Trim() ?? string.Empty;

        var validationError = ValidateName(name);
        if (validationError != null) return (null, validationError);

        if (await _db.PartKinds.AnyAsync(pk => pk.Name == name))
        {
            return (null, new ErrorResponse("Part kind name already exists", "PART_KIND_NAME_EXISTS"));
        }

        var maxDisplayOrder = await _db.PartKinds.MaxAsync(pk => (int?)pk.DisplayOrder) ?? 0;

        var partKind = new PartKind
        {
            Id = Guid.NewGuid(),
            Name = name,
            DisplayOrder = maxDisplayOrder + 1,
            CreatedAt = DateTime.UtcNow,
            UpdatedAt = DateTime.UtcNow,
        };

        _db.PartKinds.Add(partKind);

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (DbExceptionHelper.IsConstraintViolation(ex, "PartKinds", "Name"))
        {
            _logger.LogWarning(ex, "Duplicate part kind name blocked by DB constraint: {Name}", name);
            return (null, new ErrorResponse("Part kind name already exists", "PART_KIND_NAME_EXISTS"));
        }

        return (new PartKindDto(partKind.Id, partKind.Name, partKind.DisplayOrder, 0), null);
    }

    public async Task<(PartKindDto? Response, ErrorResponse? Error, bool NotFound)> RenameAsync(
        Guid id, UpdatePartKindRequest request)
    {
        var partKind = await _db.PartKinds.FindAsync(id);
        if (partKind == null) return (null, null, true);

        var name = request.Name?.Trim() ?? string.Empty;

        var validationError = ValidateName(name);
        if (validationError != null) return (null, validationError, false);

        if (await _db.PartKinds.AnyAsync(pk => pk.Name == name && pk.Id != id))
        {
            return (null, new ErrorResponse("Part kind name already exists", "PART_KIND_NAME_EXISTS"), false);
        }

        partKind.Name = name;
        partKind.UpdatedAt = DateTime.UtcNow;

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (DbExceptionHelper.IsConstraintViolation(ex, "PartKinds", "Name"))
        {
            _logger.LogWarning(ex, "Duplicate part kind name blocked by DB constraint: {Name}", name);
            return (null, new ErrorResponse("Part kind name already exists", "PART_KIND_NAME_EXISTS"), false);
        }

        return (new PartKindDto(partKind.Id, partKind.Name, partKind.DisplayOrder,
            await _db.Parts.CountAsync(p => p.PartKindId == id)), null, false);
    }

    public async Task<(bool Success, ErrorResponse? Error, bool NotFound)> DeleteAsync(Guid id)
    {
        var partKind = await _db.PartKinds
            .Include(pk => pk.Parts)
            .Include(pk => pk.TentModelComponents)
            .FirstOrDefaultAsync(pk => pk.Id == id);

        if (partKind == null) return (false, null, true);

        _db.Parts.RemoveRange(partKind.Parts);
        _db.TentModelComponents.RemoveRange(partKind.TentModelComponents);
        _db.PartKinds.Remove(partKind);

        await _db.SaveChangesAsync();

        return (true, null, false);
    }

    private static ErrorResponse? ValidateName(string name)
    {
        if (name.Length == 0)
        {
            return new ErrorResponse("Part kind name is required", "PART_KIND_NAME_REQUIRED");
        }

        if (name.Length > MaxNameLength)
        {
            return new ErrorResponse("Part kind name is too long", "PART_KIND_NAME_TOO_LONG");
        }

        return null;
    }
}
