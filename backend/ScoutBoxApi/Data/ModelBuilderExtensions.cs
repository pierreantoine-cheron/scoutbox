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
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000101"), Name = "toit", IsStandard = true, DisplayOrder = 1, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000102"), Name = "double toit", IsStandard = true, DisplayOrder = 2, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000103"), Name = "fetiere", IsStandard = true, DisplayOrder = 3, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000104"), Name = "piquets", IsStandard = true, DisplayOrder = 4, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000105"), Name = "tapis de sol", IsStandard = true, DisplayOrder = 5, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000106"), Name = "sac", IsStandard = true, DisplayOrder = 6, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000107"), Name = "sardines", IsStandard = true, DisplayOrder = 7, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc }
        };

        var tentShapes = new[]
        {
            new TentShape { Id = Guid.Parse("00000000-0000-0000-0000-000000000201"), Name = "Canadienne", Description = "Tente legere a double pente.", IsActive = true, DisplayOrder = 1, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new TentShape { Id = Guid.Parse("00000000-0000-0000-0000-000000000202"), Name = "Cabanon", Description = "Tente spacieuse avec murs droits.", IsActive = true, DisplayOrder = 2, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new TentShape { Id = Guid.Parse("00000000-0000-0000-0000-000000000203"), Name = "Tipi", Description = "Structure conique monomat.", IsActive = true, DisplayOrder = 3, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new TentShape { Id = Guid.Parse("00000000-0000-0000-0000-000000000204"), Name = "Marabout", Description = "Grande tente collective.", IsActive = true, DisplayOrder = 4, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc }
        };

        var tentShapeParts = new[]
        {
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000301"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000101") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000302"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000102") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000303"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000103") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000304"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000104") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000305"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000105") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000306"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000106") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000307"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000201"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000107") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000308"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000101") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000309"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000102") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000310"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000103") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000311"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000104") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000312"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000105") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000313"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000106") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000314"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000202"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000107") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000315"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000101") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000316"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000102") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000317"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000103") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000318"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000104") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000319"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000105") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000320"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000106") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000321"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000203"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000107") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000322"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000101") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000323"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000102") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000324"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000103") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000325"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000104") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000326"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000105") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000327"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000106") },
            new TentShapePart { Id = Guid.Parse("00000000-0000-0000-0000-000000000328"), TentShapeId = Guid.Parse("00000000-0000-0000-0000-000000000204"), PartKindId = Guid.Parse("00000000-0000-0000-0000-000000000107") }
        };

        modelBuilder.Entity<PartKind>().HasData(partKinds);
        modelBuilder.Entity<TentShape>().HasData(tentShapes);
        modelBuilder.Entity<TentShapePart>().HasData(tentShapeParts);
    }
}
