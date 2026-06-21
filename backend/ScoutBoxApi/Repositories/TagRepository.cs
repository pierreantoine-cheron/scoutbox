using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Repositories;

public class TagRepository : ITagRepository
{
    private readonly ScoutBoxDbContext _db;

    public TagRepository(ScoutBoxDbContext db)
    {
        _db = db;
    }

    public async Task<IReadOnlyList<TagDto>> GetTagsAsync()
    {
        return await _db.Tags
            .AsNoTracking()
            .OrderBy(tag => tag.Name)
            .Select(tag => new TagDto(
                tag.Id,
                tag.Name,
                tag.Color,
                tag.CreatedAt,
                tag.TentTags.Count))
            .ToListAsync();
    }

    public async Task<bool> HasDuplicateNameAsync(string name)
    {
        return await HasDuplicateNameAsync(name, null);
    }

    public async Task<bool> HasDuplicateNameAsync(string name, Guid? excludingId)
    {
        return await _db.Tags.AnyAsync(tag =>
            tag.Name == name &&
            (excludingId == null || tag.Id != excludingId));
    }

    public async Task<Tag?> GetTagByIdAsync(Guid id)
    {
        return await _db.Tags
            .Include(tag => tag.TentTags)
            .FirstOrDefaultAsync(tag => tag.Id == id);
    }

    public void AddTag(Tag tag)
    {
        _db.Tags.Add(tag);
    }

    public void UpdateTag(Tag tag)
    {
        _db.Tags.Update(tag);
    }

    public void RemoveTag(Tag tag)
    {
        _db.Tags.Remove(tag);
    }

    public async Task SaveChangesAsync()
    {
        await _db.SaveChangesAsync();
    }
}
