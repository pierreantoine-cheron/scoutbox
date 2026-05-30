using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Services;

public static class EntityFactory
{
    public static void SetCreationAudit<T>(T entity, Guid userId) where T : IAuditableEntity
    {
        entity.Id = Guid.NewGuid();
        var now = DateTime.UtcNow;
        entity.CreatedAt = now;
        entity.UpdatedAt = now;
        entity.CreatedByUserId = userId;
        entity.UpdatedByUserId = userId;
    }
}
