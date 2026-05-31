using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Data;

public static class ModelBuilderExtensions
{
    private static readonly DateTime SeedTimestampUtc = new(2026, 4, 4, 0, 0, 0, DateTimeKind.Utc);

    private static Guid Pk(string suffix) => Guid.Parse("00000000-0000-0000-0000-00000000" + suffix);

    public static void SeedTentReferenceData(this ModelBuilder modelBuilder)
    {
        var toitId       = Pk("0101");
        var doubleToitId = Pk("0102");
        var fetiereId    = Pk("0103");
        var piquetsId    = Pk("0104");
        var tapisDeSolId = Pk("0105");
        var sacId        = Pk("0106");
        var sardinesId   = Pk("0107");
        var chambreId    = Pk("0108");

        var canadienneId = Pk("0201");
        var cabanonId    = Pk("0202");
        var tipiId       = Pk("0203");
        var maraboutId   = Pk("0204");

        var partKinds = new[]
        {
            new PartKind { Id = toitId,       Name = "toit",        DisplayOrder = 1, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = doubleToitId, Name = "double toit", DisplayOrder = 2, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = fetiereId,    Name = "fetiere",     DisplayOrder = 3, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = piquetsId,    Name = "piquets",     DisplayOrder = 4, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = tapisDeSolId, Name = "tapis de sol",DisplayOrder = 5, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = sacId,        Name = "sac",         DisplayOrder = 6, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = sardinesId,   Name = "sardines",    DisplayOrder = 7, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new PartKind { Id = chambreId,    Name = "Chambre",     DisplayOrder = 8, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc }
        };

        var tentModels = new[]
        {
            new TentModel { Id = canadienneId, Name = "Canadienne", Description = "Tente legere a double pente.",         IsActive = true, DisplayOrder = 1, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new TentModel { Id = cabanonId,    Name = "Cabanon",    Description = "Tente spacieuse avec murs droits.",     IsActive = true, DisplayOrder = 2, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new TentModel { Id = tipiId,       Name = "Tipi",       Description = "Structure conique monomat.",            IsActive = true, DisplayOrder = 3, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc },
            new TentModel { Id = maraboutId,   Name = "Marabout",   Description = "Grande tente collective.",              IsActive = true, DisplayOrder = 4, CreatedAt = SeedTimestampUtc, UpdatedAt = SeedTimestampUtc }
        };

        TentModelComponent C(string id, Guid modelId, Guid partKindId) =>
            new TentModelComponent { Id = Pk(id), TentModelId = modelId, PartKindId = partKindId, IsStandard = true };

        var tentModelComponents = new[]
        {
            // --- Canadienne ---
            C("0301", canadienneId, toitId),
            C("0302", canadienneId, doubleToitId),
            C("0303", canadienneId, fetiereId),
            C("0304", canadienneId, piquetsId),
            C("0305", canadienneId, tapisDeSolId),
            C("0306", canadienneId, sacId),
            C("0307", canadienneId, sardinesId),

            // --- Cabanon ---
            C("0308", cabanonId, toitId),
            C("0309", cabanonId, doubleToitId),
            C("0310", cabanonId, fetiereId),
            C("0311", cabanonId, piquetsId),
            C("0312", cabanonId, tapisDeSolId),
            C("0313", cabanonId, sacId),
            C("0314", cabanonId, sardinesId),

            // --- Tipi ---
            C("0315", tipiId, toitId),
            // pas de double toit (0316)
            C("0317", tipiId, fetiereId),
            C("0318", tipiId, piquetsId),
            C("0319", tipiId, tapisDeSolId),
            C("0320", tipiId, sacId),
            C("0321", tipiId, sardinesId),

            // --- Marabout ---
            C("0322", maraboutId, toitId),
            // pas de double toit (0323), pas de fetiere (0324)
            C("0325", maraboutId, piquetsId),
            // pas de tapis de sol (0326)
            C("0327", maraboutId, sacId),
            C("0328", maraboutId, sardinesId),
        };

        modelBuilder.Entity<PartKind>().HasData(partKinds);
        modelBuilder.Entity<TentModel>().HasData(tentModels);
        modelBuilder.Entity<TentModelComponent>().HasData(tentModelComponents);
    }
}
