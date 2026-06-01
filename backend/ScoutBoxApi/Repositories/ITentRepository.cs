using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Repositories;

public interface ITentRepository
{
    Task<IReadOnlyList<Models.DTOs.TentModelDto>> GetActiveModelsAsync();
    Task<IReadOnlyList<Models.DTOs.TentDto>> GetTentsAsync();
    Task<Tent?> GetTentByIdAsync(Guid id);
    Task<Tent?> GetTentByIdForUpdateAsync(Guid id);
    Task<Part?> GetPartByIdForUpdateAsync(Guid id);
    Task<TentModel?> GetActiveTentModelByIdAsync(Guid id);
    Task<bool> HasDuplicateTentNameAsync(string normalizedName, Guid? excludedTentId = null);
    Task<List<PartKind>> GetAllPartKindsAsync();
    Task<Part?> GetPartByIdIncludingTentAsync(Guid id);
    Task<List<Part>> GetPartsByIdsAsync(List<Guid> ids);
    Task<List<Tag>> GetTagsByIdsAsync(IReadOnlyCollection<Guid> ids);

    void AddTent(Tent tent);
    void AddPart(Part part);
    void AddParts(IEnumerable<Part> parts);
    void RemovePart(Part part);
    void AddTentTag(TentTag tentTag);
    void RemoveTentTag(TentTag tentTag);

    Task BeginTransactionAsync();
    Task CommitTransactionAsync();
    Task RollbackTransactionAsync();
    Task SaveChangesAsync();
}
