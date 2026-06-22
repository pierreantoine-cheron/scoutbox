using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Models.DTOs;

public record TentModelDto(
    Guid Id,
    string Name,
    int DisplayOrder,
    bool IsActive,
    int TentCount,
    int ComponentCount,
    List<Guid> ComponentIds
)
{
    public static TentModelDto FromTentModel(TentModel model)
    {
        return new TentModelDto(
            model.Id,
            model.Name,
            model.DisplayOrder,
            model.IsActive,
            model.Tents?.Count ?? 0,
            model.TentModelComponents?.Count ?? 0,
            model.TentModelComponents?.Select(mc => mc.PartKindId).ToList() ?? []
        );
    }
}
