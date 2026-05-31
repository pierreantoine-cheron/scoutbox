using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Data;

public static class ModelBuilderExtensions
{
    private static readonly DateTime SeedTimestampUtc = new(2026, 4, 4, 0, 0, 0, DateTimeKind.Utc);

    public static void SeedTentReferenceData(this ModelBuilder modelBuilder)
    {
        var partKinds = new[]
        {
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000101"), Name = "toit", DisplayOrder = 1, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000102"), Name = "double toit", DisplayOrder = 2, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000103"), Name = "fetiere", DisplayOrder = 3, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000104"), Name = "piquets", DisplayOrder = 4, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000105"), Name = "tapis de sol", DisplayOrder = 5, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000106"), Name = "sac", DisplayOrder = 6, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000107"), Name = "sardines", DisplayOrder = 7, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc }
        };

        var tentModels = new[]
        {
            new TentModel { Id = Guid.Parse("00000000-0000-0000-0000-000000000201"), Name = "Canadienne", Description = "Tente legere a double pente.", IsActive = true, DisplayOrder = 1, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new TentModel { Id = Guid.Parse("00000000-0000-0000-0000-000000000202"), Name = "Cabanon", Description = "Tente spacieuse avec murs droits.", IsActive = true, DisplayOrder = 2, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new TentModel { Id = Guid.Parse("00000000-0000-0000-0000-000000000203"), Name = "Tipi", Description = "Structure conique monomat.", IsActive = true, DisplayOrder = 3, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new TentModel { Id = Guid.Parse("00000000-0000-0000-0000-000000000204"), Name = "Marabout", Description = "Grande tente collective.", IsActive = true, DisplayOrder = 4, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc }
        };

        var tentModelComponents = new[]
        {
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000301"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000101"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000302"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000102"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000303"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000103"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000304"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000104"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000305"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000105"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000306"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000106"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000307"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000107"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000308"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000101"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000309"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000102"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000310"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000103"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000311"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000104"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000312"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000105"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000313"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000106"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000314"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000107"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000315"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000101"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000316"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000102"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000317"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000103"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000318"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000104"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000319"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000105"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000320"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000106"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000321"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000107"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000322"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000101"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000323"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000102"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000324"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000103"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000325"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000104"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000326"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000105"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000327"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000106"), IsStandard = true },
            new TentModelComponent { Id = Guid.Parse("00000000-0000-0000-0000-000000000328"), TentModelId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000107"), IsStandard = true }
        };

        modelBuilder.Entity<PartKind>().HasData(partKinds);
        modelBuilder.Entity<TentModel>().HasData(tentModels);
        modelBuilder.Entity<TentModelComponent>().HasData(tentModelComponents);
    }
}
