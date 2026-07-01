using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Data;

public static class DataSeeder
{
    private static readonly Guid SystemUserId = Guid.Parse("00000000-0000-0000-0000-000000000001");

    private static Guid Pk(string suffix) => Guid.Parse("00000000-0000-0000-0000-00000000" + suffix);

    public static void Seed(ScoutBoxDbContext context)
    {
        if (context.Set<SeedInfo>().Any(s => s.IsSeeded))
            return;

        if (context.PartKinds.Any()
            || context.TentModels.Any()
            || context.TentModelComponents.Any()
            || context.Tags.Any()
            || context.Invites.Any())
        {
            context.Set<SeedInfo>().Add(new SeedInfo { Id = 1, IsSeeded = true, SeededAt = DateTime.UtcNow });
            context.SaveChanges();
            return;
        }

        SeedSystemUser(context);
        SeedPartKinds(context);
        SeedTentModels(context);
        SeedTentModelComponents(context);
        SeedTags(context);
        SeedAdminInvite(context);

        context.Set<SeedInfo>().Add(new SeedInfo { Id = 1, IsSeeded = true, SeededAt = DateTime.UtcNow });
        context.SaveChanges();
    }

    private static bool SeedSystemUser(ScoutBoxDbContext context)
    {
        if (context.Users.Any(u => u.Username == "SYSTEM"))
            return false;

        var systemUser = new User
        {
            Id = SystemUserId,
            Username = "SYSTEM",
            PasswordHash = "SYSTEM_NO_LOGIN",
            CreatedAt = DateTime.UtcNow,
            IsDeleted = false
        };

        context.Users.Add(systemUser);
        return true;
    }

    private static bool SeedPartKinds(ScoutBoxDbContext context)
    {
        if (context.PartKinds.Any())
            return false;

        var now = DateTime.UtcNow;
        var partKinds = new[]
        {
            new PartKind { Id = Pk("0101"), Name = "Toit",          DisplayOrder = 1,  CreatedAt = now, UpdatedAt = now },
            new PartKind { Id = Pk("0102"), Name = "Double toit",   DisplayOrder = 2,  CreatedAt = now, UpdatedAt = now },
            new PartKind { Id = Pk("0103"), Name = "Fêtière",       DisplayOrder = 3,  CreatedAt = now, UpdatedAt = now },
            new PartKind { Id = Pk("0104"), Name = "Piquets",       DisplayOrder = 4,  CreatedAt = now, UpdatedAt = now },
            new PartKind { Id = Pk("0105"), Name = "Tapis de sol",  DisplayOrder = 5,  CreatedAt = now, UpdatedAt = now },
            new PartKind { Id = Pk("0106"), Name = "Sac",           DisplayOrder = 6,  CreatedAt = now, UpdatedAt = now },
            new PartKind { Id = Pk("0107"), Name = "Sardines",      DisplayOrder = 7,  CreatedAt = now, UpdatedAt = now },
            new PartKind { Id = Pk("0108"), Name = "Chambre",       DisplayOrder = 8,  CreatedAt = now, UpdatedAt = now },
            new PartKind { Id = Pk("0109"), Name = "Arceaux",       DisplayOrder = 9,  CreatedAt = now, UpdatedAt = now },
            new PartKind { Id = Pk("010A"), Name = "Armature",      DisplayOrder = 10, CreatedAt = now, UpdatedAt = now }
        };

        context.PartKinds.AddRange(partKinds);
        return true;
    }

    private static bool SeedTentModels(ScoutBoxDbContext context)
    {
        if (context.TentModels.Any())
            return false;

        var now = DateTime.UtcNow;
        var tentModels = new[]
        {
            new TentModel { Id = Pk("0201"), Name = "Canadienne", Description = "Tente légère à double pente.",      IsActive = true, DisplayOrder = 1, CreatedAt = now, UpdatedAt = now },
            new TentModel { Id = Pk("0202"), Name = "Cabanon",    Description = "Tente spacieuse avec murs droits.",  IsActive = true, DisplayOrder = 2, CreatedAt = now, UpdatedAt = now },
            new TentModel { Id = Pk("0203"), Name = "Tipi",       Description = "Structure conique monomât.",          IsActive = true, DisplayOrder = 3, CreatedAt = now, UpdatedAt = now },
            new TentModel { Id = Pk("0204"), Name = "Marabout",   Description = "Grande tente collective.",            IsActive = true, DisplayOrder = 4, CreatedAt = now, UpdatedAt = now },
            new TentModel { Id = Pk("0205"), Name = "Autre",      Description = null,                                  IsActive = true, DisplayOrder = 5, CreatedAt = now, UpdatedAt = now },
            new TentModel { Id = Pk("0206"), Name = "2 secondes", Description = null,                                  IsActive = true, DisplayOrder = 6, CreatedAt = now, UpdatedAt = now }
        };

        context.TentModels.AddRange(tentModels);
        return true;
    }

    private static bool SeedTentModelComponents(ScoutBoxDbContext context)
    {
        if (context.TentModelComponents.Any())
            return false;

        var toitId       = Pk("0101");
        var doubleToitId = Pk("0102");
        var fetiereId    = Pk("0103");
        var piquetsId    = Pk("0104");
        var tapisDeSolId = Pk("0105");
        var sacId        = Pk("0106");
        var sardinesId   = Pk("0107");
        var chambreId    = Pk("0108");
        var armatureId   = Pk("010A");

        var canadienneId = Pk("0201");
        var cabanonId    = Pk("0202");
        var tipiId       = Pk("0203");
        var maraboutId   = Pk("0204");
        var deuxSecondesId = Pk("0206");

        var components = new List<TentModelComponent>();

        // Canadienne
        components.Add(C(canadienneId, toitId));
        components.Add(C(canadienneId, doubleToitId));
        components.Add(C(canadienneId, fetiereId));
        components.Add(C(canadienneId, piquetsId));
        components.Add(C(canadienneId, tapisDeSolId));
        components.Add(C(canadienneId, sacId));
        components.Add(C(canadienneId, sardinesId));

        // Cabanon
        components.Add(C(cabanonId, toitId));
        components.Add(C(cabanonId, doubleToitId));
        components.Add(C(cabanonId, fetiereId));
        components.Add(C(cabanonId, piquetsId));
        components.Add(C(cabanonId, tapisDeSolId));
        components.Add(C(cabanonId, sacId));
        components.Add(C(cabanonId, sardinesId));

        // Tipi (without Fêtière and Double toit)
        components.Add(C(tipiId, toitId));
        components.Add(C(tipiId, piquetsId));
        components.Add(C(tipiId, tapisDeSolId));
        components.Add(C(tipiId, sacId));
        components.Add(C(tipiId, sardinesId));

        // Marabout (without Fêtière, Double toit, Tapis de sol; with Armature)
        components.Add(C(maraboutId, toitId));
        components.Add(C(maraboutId, piquetsId));
        components.Add(C(maraboutId, sacId));
        components.Add(C(maraboutId, sardinesId));
        components.Add(C(maraboutId, armatureId));

        // 2 secondes
        components.Add(C(deuxSecondesId, chambreId));
        components.Add(C(deuxSecondesId, Pk("0109"))); // Arceaux
        components.Add(C(deuxSecondesId, sardinesId));

        // Autre: no components

        context.TentModelComponents.AddRange(components);
        return true;
    }

    private static TentModelComponent C(Guid modelId, Guid partKindId) =>
        new() { Id = Guid.NewGuid(), TentModelId = modelId, PartKindId = partKindId, IsStandard = true };

    private static bool SeedTags(ScoutBoxDbContext context)
    {
        if (context.Tags.Any())
            return false;

        var now = DateTime.UtcNow;
        var tags = new[]
        {
            new Tag { Name = "Farfadets",              Color = "#65bc99", CreatedAt = now, UpdatedAt = now, CreatedByUserId = SystemUserId, UpdatedByUserId = SystemUserId },
            new Tag { Name = "Louveteaux-Jeannettes",  Color = "#ff8300", CreatedAt = now, UpdatedAt = now, CreatedByUserId = SystemUserId, UpdatedByUserId = SystemUserId },
            new Tag { Name = "Scouts-Guides",          Color = "#0077b3", CreatedAt = now, UpdatedAt = now, CreatedByUserId = SystemUserId, UpdatedByUserId = SystemUserId },
            new Tag { Name = "Pionniers-Caravelles",   Color = "#d03f15", CreatedAt = now, UpdatedAt = now, CreatedByUserId = SystemUserId, UpdatedByUserId = SystemUserId },
            new Tag { Name = "Compagnons",             Color = "#007254", CreatedAt = now, UpdatedAt = now, CreatedByUserId = SystemUserId, UpdatedByUserId = SystemUserId }
        };

        context.Tags.AddRange(tags);
        return true;
    }

    private static bool SeedAdminInvite(ScoutBoxDbContext context)
    {
        if (context.Invites.Any())
            return false;

        var code = TokenService.GenerateRandomCode(9);
        var adminInvite = new Invite
        {
            Id = Guid.NewGuid(),
            Code = code,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(30),
            IsUsed = false,
            CreatedByUserId = SystemUserId
        };

        context.Invites.Add(adminInvite);
        Console.WriteLine($"[SETUP] Admin invite code: {code}");
        Console.WriteLine($"[SETUP] Use this code to register the first user.");

        return true;
    }
}
