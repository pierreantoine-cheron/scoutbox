using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Data;

public class ScoutBoxDbContext : DbContext
{
    private static readonly DateTime TentSeedTimestampUtc = new(2026, 4, 4, 0, 0, 0, DateTimeKind.Utc);

    public ScoutBoxDbContext(DbContextOptions<ScoutBoxDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users { get; set; }
    public DbSet<Invite> Invites { get; set; }
    public DbSet<RefreshToken> RefreshTokens { get; set; }
    public DbSet<AuditEvent> AuditEvents { get; set; }
    public DbSet<Tent> Tents { get; set; }
    public DbSet<TentShape> TentShapes { get; set; }
    public DbSet<TentShapePart> TentShapeParts { get; set; }
    public DbSet<PartKind> PartKinds { get; set; }
    public DbSet<Part> Parts { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        base.OnConfiguring(optionsBuilder);

        // Configure data seeding - creates admin invite on first run
        optionsBuilder.UseSeeding((context, _) =>
        {
            SeedAdminInvite(context);
        });

        optionsBuilder.UseAsyncSeeding(async (context, _, cancellationToken) =>
        {
            await Task.Run(() => SeedAdminInvite(context), cancellationToken);
        });
    }

    private static void SeedAdminInvite(DbContext context)
    {
        // Only create admin invite if no invites exist (first-time setup)
        if (!context.Set<Invite>().Any())
        {
            var adminInvite = new Invite
            {
                Id = Guid.NewGuid(),
                Code = "ADMIN-SETUP",
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = DateTime.UtcNow.AddDays(30),
                IsUsed = false,
                CreatedByUserId = null
            };
            context.Set<Invite>().Add(adminInvite);
            context.SaveChanges();

            Console.WriteLine($"[SETUP] Admin invite created: {adminInvite.Code}");
            Console.WriteLine($"[SETUP] Use this code to register the first user.");
        }
    }

    public override int SaveChanges(bool acceptAllChangesOnSuccess)
    {
        ValidateNameFields();
        return base.SaveChanges(acceptAllChangesOnSuccess);
    }

    public override async Task<int> SaveChangesAsync(bool acceptAllChangesOnSuccess, CancellationToken cancellationToken = default)
    {
        ValidateNameFields();
        return await base.SaveChangesAsync(acceptAllChangesOnSuccess, cancellationToken);
    }

    private void ValidateNameFields()
    {
        var entities = ChangeTracker.Entries()
            .Where(e => e.State == EntityState.Added || e.State == EntityState.Modified);

        foreach (var entry in entities)
        {
            string? nameValue = null;
            string entityType = entry.Entity.GetType().Name;

            switch (entry.Entity)
            {
                case Tent tent:
                    nameValue = tent.Name;
                    break;
                case TentShape shape:
                    nameValue = shape.Name;
                    break;
                case PartKind partKind:
                    nameValue = partKind.Name;
                    break;
            }

            if (nameValue is not null)
            {
                if (string.IsNullOrWhiteSpace(nameValue))
                {
                    throw new InvalidOperationException($"{entityType}.Name cannot be empty or whitespace-only.");
                }
            }
        }
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User configuration
        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Username).IsRequired().HasMaxLength(50);
            entity.Property(e => e.PasswordHash).IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.IsDeleted).IsRequired().HasDefaultValue(false);
            entity.HasIndex(e => e.Username).IsUnique();
            entity.HasIndex(e => e.IsDeleted);

            // Soft delete filter - exclude deleted users by default
            entity.HasQueryFilter(e => !e.IsDeleted);
        });

        // Invite configuration
        modelBuilder.Entity<Invite>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Code).IsRequired().HasMaxLength(64);
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.ExpiresAt).IsRequired();
            entity.Property(e => e.IsUsed).IsRequired();
            entity.HasIndex(e => e.Code).IsUnique();
            entity.HasIndex(e => e.IsUsed);

            entity.HasOne(e => e.CreatedBy)
                .WithMany(u => u.CreatedInvites)
                .HasForeignKey(e => e.CreatedByUserId)
                .OnDelete(DeleteBehavior.SetNull);

            entity.HasOne(e => e.UsedBy)
                .WithMany(u => u.UsedInvites)
                .HasForeignKey(e => e.UsedByUserId)
                .OnDelete(DeleteBehavior.SetNull);
        });

        // RefreshToken configuration
        modelBuilder.Entity<RefreshToken>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Token).IsRequired();
            entity.Property(e => e.ExpiresAt).IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.IsRevoked).IsRequired();
            entity.HasIndex(e => e.Token).IsUnique();
            entity.HasIndex(e => e.UserId);

            entity.HasOne(e => e.User)
                .WithMany(u => u.RefreshTokens)
                .HasForeignKey(e => e.UserId)
                .OnDelete(DeleteBehavior.Cascade);
        });

        // AuditEvent configuration
        modelBuilder.Entity<AuditEvent>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Action).IsRequired().HasMaxLength(50);
            entity.Property(e => e.OccurredAt).IsRequired();
            entity.Property(e => e.TargetEntityType).HasMaxLength(50);
            entity.Property(e => e.MetadataJson);

            // Foreign key to User with SetNull to preserve history when user is soft-deleted
            entity.HasOne(e => e.Actor)
                .WithMany()
                .HasForeignKey(e => e.ActorUserId)
                .OnDelete(DeleteBehavior.SetNull);

            // Indexes for reporting queries
            entity.HasIndex(e => e.OccurredAt);
            entity.HasIndex(e => e.ActorUserId);
            entity.HasIndex(e => e.Action);
            entity.HasIndex(e => new { e.ActorUserId, e.OccurredAt });
            entity.HasIndex(e => new { e.Action, e.OccurredAt });
            entity.HasIndex(e => e.TargetEntityType);
            entity.HasIndex(e => e.TargetEntityId);
        });

        modelBuilder.Entity<Tent>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).UseCollation("NOCASE").IsRequired().HasMaxLength(100);
            entity.Property(e => e.OverallState).HasConversion<int>().IsRequired();
            entity.Property(e => e.Size).IsRequired();
            entity.Property(e => e.Comments).HasMaxLength(500);
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired();
            entity.Property(e => e.CreatedByUserId).IsRequired();
            entity.Property(e => e.UpdatedByUserId).IsRequired();
            entity.Property(e => e.IsArchived).IsRequired().HasDefaultValue(false);

            entity.HasOne(e => e.TentShape)
                .WithMany(e => e.Tents)
                .HasForeignKey(e => e.TentShapeId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.CreatedByUser)
                .WithMany(e => e.CreatedTents)
                .HasForeignKey(e => e.CreatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.UpdatedByUser)
                .WithMany(e => e.UpdatedTents)
                .HasForeignKey(e => e.UpdatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(e => e.CreatedAt);
            entity.HasIndex(e => e.TentShapeId);
            entity.HasIndex(e => e.CreatedByUserId);
            entity.HasIndex(e => e.UpdatedByUserId);
            entity.HasIndex(e => e.IsArchived);
            entity.HasIndex(e => e.Name).IsUnique();
        });

        modelBuilder.Entity<TentShape>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(100);
            entity.Property(e => e.Description).HasMaxLength(500);
            entity.Property(e => e.IsActive).IsRequired();
            entity.Property(e => e.DisplayOrder).IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired();

            entity.HasIndex(e => e.Name).IsUnique();
            entity.HasIndex(e => e.DisplayOrder);
            entity.HasIndex(e => e.CreatedAt);
        });

        modelBuilder.Entity<PartKind>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(100);
            entity.Property(e => e.IsStandard).IsRequired();
            entity.Property(e => e.DisplayOrder).IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired();

            entity.HasIndex(e => e.Name).IsUnique();
            entity.HasIndex(e => e.DisplayOrder);
            entity.HasIndex(e => e.CreatedAt);
        });

        modelBuilder.Entity<TentShapePart>(entity =>
        {
            entity.HasKey(e => e.Id);

            entity.HasOne(e => e.TentShape)
                .WithMany(e => e.TentShapeParts)
                .HasForeignKey(e => e.TentShapeId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.PartKind)
                .WithMany(e => e.TentShapeParts)
                .HasForeignKey(e => e.PartKindId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => new { e.TentShapeId, e.PartKindId }).IsUnique();
            entity.HasIndex(e => e.TentShapeId);
            entity.HasIndex(e => e.PartKindId);
        });

        modelBuilder.Entity<Part>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.State).HasConversion<int>().IsRequired();
            entity.Property(e => e.Comments).HasMaxLength(500);
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired();
            entity.Property(e => e.CreatedByUserId).IsRequired();
            entity.Property(e => e.UpdatedByUserId).IsRequired();

            entity.HasOne(e => e.Tent)
                .WithMany(e => e.Parts)
                .HasForeignKey(e => e.TentId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.PartKind)
                .WithMany(e => e.Parts)
                .HasForeignKey(e => e.PartKindId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.CreatedByUser)
                .WithMany(e => e.CreatedParts)
                .HasForeignKey(e => e.CreatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.UpdatedByUser)
                .WithMany(e => e.UpdatedParts)
                .HasForeignKey(e => e.UpdatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(e => e.TentId);
            entity.HasIndex(e => e.CreatedAt);
            entity.HasIndex(e => e.PartKindId);
            entity.HasIndex(e => e.CreatedByUserId);
            entity.HasIndex(e => e.UpdatedByUserId);
        });

        SeedTentReferenceData(modelBuilder);
    }

    private static void SeedTentReferenceData(ModelBuilder modelBuilder)
    {
        var partKinds = new[]
        {
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000101"), Name = "toit", IsStandard = true, DisplayOrder = 1, CreatedAt = TentSeedTimestampUtc, UpdatedAt = TentSeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000102"), Name = "double toit", IsStandard = true, DisplayOrder = 2, CreatedAt = TentSeedTimestampUtc, UpdatedAt = TentSeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000103"), Name = "fetiere", IsStandard = true, DisplayOrder = 3, CreatedAt = TentSeedTimestampUtc, UpdatedAt = TentSeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000104"), Name = "piquets", IsStandard = true, DisplayOrder = 4, CreatedAt = TentSeedTimestampUtc, UpdatedAt = TentSeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000105"), Name = "tapis de sol", IsStandard = true, DisplayOrder = 5, CreatedAt = TentSeedTimestampUtc, UpdatedAt = TentSeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000106"), Name = "sac", IsStandard = true, DisplayOrder = 6, CreatedAt = TentSeedTimestampUtc, UpdatedAt = TentSeedTimestampUtc },
            new PartKind { Id = Guid.Parse("00000000-0000-0000-0000-000000000107"), Name = "sardines", IsStandard = true, DisplayOrder = 7, CreatedAt = TentSeedTimestampUtc, UpdatedAt = TentSeedTimestampUtc }
        };

        var tentShapes = new[]
        {
            new TentShape { Id = Guid.Parse("00000000-0000-0000-0000-000000000201"), Name = "Canadienne", Description = "Tente legere a double pente.", IsActive = true, DisplayOrder = 1, CreatedAt = TentSeedTimestampUtc, UpdatedAt = TentSeedTimestampUtc },
            new TentShape { Id = Guid.Parse("00000000-0000-0000-0000-000000000202"), Name = "Cabanon", Description = "Tente spacieuse avec murs droits.", IsActive = true, DisplayOrder = 2, CreatedAt = TentSeedTimestampUtc, UpdatedAt = TentSeedTimestampUtc },
            new TentShape { Id = Guid.Parse("00000000-0000-0000-0000-000000000203"), Name = "Tipi", Description = "Structure conique monomat.", IsActive = true, DisplayOrder = 3, CreatedAt = TentSeedTimestampUtc, UpdatedAt = TentSeedTimestampUtc },
            new TentShape { Id = Guid.Parse("00000000-0000-0000-0000-000000000204"), Name = "Marabout", Description = "Grande tente collective.", IsActive = true, DisplayOrder = 4, CreatedAt = TentSeedTimestampUtc, UpdatedAt = TentSeedTimestampUtc }
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
