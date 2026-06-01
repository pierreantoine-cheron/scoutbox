using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Repositories;

public interface ITagRepository
{
    Task<IReadOnlyList<TagDto>> GetTagsAsync();
    Task<bool> HasDuplicateNameAsync(string name);
    void AddTag(Tag tag);
    Task SaveChangesAsync();
}
