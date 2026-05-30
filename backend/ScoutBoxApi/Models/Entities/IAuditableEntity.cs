namespace ScoutBoxApi.Models.Entities;

public interface IAuditableEntity
{
    Guid Id { get; set; }
    DateTime CreatedAt { get; set; }
    DateTime UpdatedAt { get; set; }
    Guid CreatedByUserId { get; set; }
    Guid UpdatedByUserId { get; set; }
}
