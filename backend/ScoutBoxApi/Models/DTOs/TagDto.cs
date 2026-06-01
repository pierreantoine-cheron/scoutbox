using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Models.DTOs;

public record TagDto(Guid Id, string Name, string Color, DateTime CreatedAt, int TentCount)
{
    public static TagDto FromTag(Tag tag)
    {
        return new TagDto(tag.Id, tag.Name, tag.Color, tag.CreatedAt, tag.TentTags.Count);
    }
}
