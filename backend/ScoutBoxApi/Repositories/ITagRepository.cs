using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Repositories;

public interface ITagRepository
{
    Task<IReadOnlyList<TagDto>> GetTagsAsync();
    Task<bool> HasDuplicateNameAsync(string name);
    Task<bool> HasDuplicateNameAsync(string name, Guid? excludingId);
    Task<Tag?> GetTagByIdAsync(Guid id);
    void AddTag(Tag tag);
    void UpdateTag(Tag tag);
    void RemoveTag(Tag tag);
    Task SaveChangesAsync();
}
