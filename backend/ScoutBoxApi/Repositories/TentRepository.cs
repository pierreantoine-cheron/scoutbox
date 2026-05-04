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

    public async Task<IReadOnlyList<TentShapeDto>> GetActiveShapesAsync()
    {
        return await _db.TentShapes
            .AsNoTracking()
            .Where(shape => shape.IsActive)
            .OrderBy(shape => shape.DisplayOrder)
            .Select(shape => new TentShapeDto(shape.Id, shape.Name, shape.DisplayOrder, shape.IsActive))
            .ToListAsync();
    }

    public async Task<IReadOnlyList<TentDto>> GetTentsAsync()
    {
        return await (
            from tent in _db.Tents.AsNoTracking()
            where !tent.IsArchived
            join shape in _db.TentShapes.AsNoTracking() on tent.TentShapeId equals shape.Id into shapeJoin
            from shape in shapeJoin.DefaultIfEmpty()
            orderby tent.UpdatedAt descending, tent.CreatedAt descending, tent.Id descending
            select new TentDto(
                tent.Id,
                tent.Name,
                tent.Size,
                tent.TentShapeId,
                shape != null ? shape.Name : null,
                tent.OverallState.ToString(),
                tent.IsArchived,
                tent.Comments,
                tent.CreatedAt,
                tent.UpdatedAt,
                Array.Empty<PartDto>()
            )
        ).ToListAsync();
    }

    public async Task<Tent?> GetTentByIdAsync(Guid id)
    {
        return await _db.Tents
            .AsNoTracking()
            .Include(t => t.TentShape)
            .Include(t => t.Parts)
                .ThenInclude(p => p.PartKind)
            .FirstOrDefaultAsync(t => t.Id == id);
    }

    public async Task<Tent?> GetTentByIdForUpdateAsync(Guid id)
    {
        return await _db.Tents
            .Include(t => t.TentShape)
            .Include(t => t.Parts)
                .ThenInclude(p => p.PartKind)
            .FirstOrDefaultAsync(t => t.Id == id);
    }

    public async Task<Part?> GetPartByIdForUpdateAsync(Guid id)
    {
        return await _db.Parts
            .Include(p => p.PartKind)
            .Include(p => p.Tent)
            .FirstOrDefaultAsync(p => p.Id == id);
    }

    public async Task<TentShape?> GetActiveTentShapeByIdAsync(Guid id)
    {
        return await _db.TentShapes
            .Include(s => s.TentShapeParts)
                .ThenInclude(sp => sp.PartKind)
            .Where(shape => shape.Id == id && shape.IsActive)
            .FirstOrDefaultAsync();
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
