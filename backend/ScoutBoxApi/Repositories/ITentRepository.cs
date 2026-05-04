using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Repositories;

public interface ITentRepository
{
    Task<IReadOnlyList<Models.DTOs.TentShapeDto>> GetActiveShapesAsync();
    Task<IReadOnlyList<Models.DTOs.TentDto>> GetTentsAsync();
    Task<Tent?> GetTentByIdAsync(Guid id);
    Task<Tent?> GetTentByIdForUpdateAsync(Guid id);
    Task<Part?> GetPartByIdForUpdateAsync(Guid id);
    Task<TentShape?> GetActiveTentShapeByIdAsync(Guid id);
    Task<bool> HasDuplicateTentNameAsync(string normalizedName, Guid? excludedTentId = null);

    void AddTent(Tent tent);
    void AddPart(Part part);

    Task BeginTransactionAsync();
    Task CommitTransactionAsync();
    Task RollbackTransactionAsync();
    Task SaveChangesAsync();
}
