using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Repositories;

public class TentRepository : ITentRepository
{
    private readonly ScoutBoxDbContext _db;
    private Microsoft.EntityFrameworkCore.Storage.IDbContextTransaction? _transaction;

    public TentRepository(ScoutBoxDbContext db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<TentModelDto>> GetActiveModelsAsync()
    {
        return await _db.TentModels
            .AsNoTracking()
            .Where(model => model.IsActive)
            .OrderBy(model => model.DisplayOrder)
            .Select(model => new TentModelDto(model.Id, model.Name, model.DisplayOrder, model.IsActive))
            .ToListAsync();
    }

    public async Task<IReadOnlyList<TentDto>> GetTentsAsync()
    {
        var tents = await _db.Tents
            .AsNoTracking()
            .Include(t => t.TentModel)
            .Include(t => t.TentTags)
                .ThenInclude(tt => tt.Tag)
            .OrderByDescending(tent => tent.UpdatedAt)
            .ThenByDescending(tent => tent.CreatedAt)
            .ThenByDescending(tent => tent.Id)
            .AsSplitQuery()
            .ToListAsync();

        return tents.Select(tent => new TentDto(
            tent.Id,
            tent.Name,
            tent.Size,
            tent.TentModelId,
            tent.TentModel?.Name,
            tent.OverallState.ToString(),
            tent.IsArchived,
            tent.Comments,
            tent.CreatedAt,
            tent.UpdatedAt,
            Array.Empty<PartDto>(),
            ToTagDtos(tent.TentTags)
        )).ToList();
    }

    public async Task<Tent?> GetTentByIdAsync(Guid id)
    {
        return await _db.Tents
            .AsNoTracking()
            .Include(t => t.TentModel)
            .Include(t => t.Parts)
                .ThenInclude(p => p.PartKind)
            .Include(t => t.TentTags)
                .ThenInclude(tt => tt.Tag)
            .FirstOrDefaultAsync(t => t.Id == id);
    }

    public async Task<Tent?> GetTentByIdForUpdateAsync(Guid id)
    {
        return await _db.Tents
            .Include(t => t.TentModel)
            .Include(t => t.Parts)
                .ThenInclude(p => p.PartKind)
            .Include(t => t.TentTags)
                .ThenInclude(tt => tt.Tag)
            .FirstOrDefaultAsync(t => t.Id == id);
    }

    public async Task<Part?> GetPartByIdForUpdateAsync(Guid id)
    {
        return await _db.Parts
            .Include(p => p.PartKind)
            .Include(p => p.Tent)
            .FirstOrDefaultAsync(p => p.Id == id);
    }

    public async Task<TentModel?> GetActiveTentModelByIdAsync(Guid id)
    {
        return await _db.TentModels
            .Include(m => m.TentModelComponents)
                .ThenInclude(mc => mc.PartKind)
            .Where(model => model.Id == id && model.IsActive)
            .FirstOrDefaultAsync();
    }

    public async Task<List<PartKind>> GetAllPartKindsAsync()
    {
        return await _db.PartKinds
            .OrderBy(pk => pk.DisplayOrder)
            .ToListAsync();
    }

    public async Task<Part?> GetPartByIdIncludingTentAsync(Guid id)
    {
        return await _db.Parts
            .Include(p => p.Tent)
            .FirstOrDefaultAsync(p => p.Id == id);
    }

    public async Task<List<Part>> GetPartsByIdsAsync(List<Guid> ids)
    {
        return await _db.Parts
            .AsNoTracking()
            .Include(p => p.PartKind)
            .Where(p => ids.Contains(p.Id))
            .OrderBy(p => p.PartKind.DisplayOrder)
            .ThenBy(p => p.PartKindId)
            .ToListAsync();
    }

    public async Task<List<Tag>> GetTagsByIdsAsync(IReadOnlyCollection<Guid> ids)
    {
        return await _db.Tags
            .Where(tag => ids.Contains(tag.Id))
            .ToListAsync();
    }

    public async Task<bool> HasDuplicateTentNameAsync(string normalizedName, Guid? excludedTentId = null)
    {
        return await _db.Tents.AnyAsync(tent =>
            tent.Name.ToLower() == normalizedName.ToLower()
            && (excludedTentId == null || tent.Id != excludedTentId));
    }

    public void AddTent(Tent tent)
    {
        _db.Tents.Add(tent);
    }

    public void AddPart(Part part)
    {
        _db.Parts.Add(part);
    }

    public void AddParts(IEnumerable<Part> parts)
    {
        _db.Parts.AddRange(parts);
    }

    public void RemovePart(Part part)
    {
        _db.Parts.Remove(part);
    }

    public void AddTentTag(TentTag tentTag)
    {
        _db.TentTags.Add(tentTag);
    }

    public void RemoveTentTag(TentTag tentTag)
    {
        _db.TentTags.Remove(tentTag);
    }

    public static List<TagDto> ToTagDtos(IEnumerable<TentTag> tentTags)
    {
        return tentTags
            .Select(tt => tt.Tag)
            .OrderBy(tag => tag.Name)
            .ThenBy(tag => tag.Id)
            .Select(TagDto.FromTag)
            .ToList();
    }

    public async Task BeginTransactionAsync()
    {
        _transaction = await _db.Database.BeginTransactionAsync();
    }

    public async Task CommitTransactionAsync()
    {
        if (_transaction != null)
        {
            await _transaction.CommitAsync();
            _transaction = null;
        }
    }

    public async Task RollbackTransactionAsync()
    {
        if (_transaction != null)
        {
            await _transaction.RollbackAsync();
            _transaction = null;
        }
    }

    public async Task SaveChangesAsync()
    {
        await _db.SaveChangesAsync();
    }
}
