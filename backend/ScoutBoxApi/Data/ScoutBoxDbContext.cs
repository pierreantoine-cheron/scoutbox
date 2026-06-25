using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Data;

public class ScoutBoxDbContext : DbContext
{
    public ScoutBoxDbContext(DbContextOptions<ScoutBoxDbContext> options) : base(options)
    {
    }

    public DbSet<User> Users { get; set; }
    public DbSet<Invite> Invites { get; set; }
    public DbSet<RefreshToken> RefreshTokens { get; set; }
    public DbSet<AuditEvent> AuditEvents { get; set; }
    public DbSet<Tent> Tents { get; set; }
    public DbSet<TentModel> TentModels { get; set; }
    public DbSet<TentModelComponent> TentModelComponents { get; set; }
    public DbSet<PartKind> PartKinds { get; set; }
    public DbSet<Part> Parts { get; set; }
    public DbSet<Tag> Tags { get; set; }
    public DbSet<TentTag> TentTags { get; set; }
    public DbSet<SeedInfo> SeedInfos { get; set; }

    protected override void OnConfiguring(DbContextOptionsBuilder optionsBuilder)
    {
        base.OnConfiguring(optionsBuilder);

        optionsBuilder.ConfigureWarnings(warnings =>
            warnings.Ignore(CoreEventId.PossibleIncorrectRequiredNavigationWithQueryFilterInteractionWarning));
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
            if (entry.Entity is IHasName namedEntity)
            {
                if (string.IsNullOrWhiteSpace(namedEntity.Name))
                {
                    var entityType = entry.Entity.GetType().Name;
                    throw new InvalidOperationException($"{entityType}.Name cannot be empty or whitespace-only.");
                }
            }
        }
    }

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        modelBuilder.Entity<User>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Username).IsRequired().HasMaxLength(50);
            entity.Property(e => e.PasswordHash).IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.IsDeleted).IsRequired().HasDefaultValue(false);
            entity.HasIndex(e => e.Username).IsUnique();
            entity.HasIndex(e => e.IsDeleted);

            entity.HasQueryFilter(e => !e.IsDeleted);
        });

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

        modelBuilder.Entity<AuditEvent>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Action).IsRequired().HasMaxLength(50);
            entity.Property(e => e.OccurredAt).IsRequired();
            entity.Property(e => e.TargetEntityType).HasMaxLength(50);
            entity.Property(e => e.MetadataJson);

            entity.HasOne(e => e.Actor)
                .WithMany()
                .HasForeignKey(e => e.ActorUserId)
                .OnDelete(DeleteBehavior.SetNull);

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

            entity.HasOne(e => e.TentModel)
                .WithMany(e => e.Tents)
                .HasForeignKey(e => e.TentModelId)
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
            entity.HasIndex(e => e.TentModelId);
            entity.HasIndex(e => e.CreatedByUserId);
            entity.HasIndex(e => e.UpdatedByUserId);
            entity.HasIndex(e => e.IsArchived);
            entity.HasIndex(e => e.Name).IsUnique();
        });

        modelBuilder.Entity<TentModel>(entity =>
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
            entity.Property(e => e.DisplayOrder).IsRequired();
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired();

            entity.HasIndex(e => e.Name).IsUnique();
            entity.HasIndex(e => e.DisplayOrder);
            entity.HasIndex(e => e.CreatedAt);
        });

        modelBuilder.Entity<TentModelComponent>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.IsStandard).IsRequired();

            entity.HasOne(e => e.TentModel)
                .WithMany(e => e.TentModelComponents)
                .HasForeignKey(e => e.TentModelId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.PartKind)
                .WithMany(e => e.TentModelComponents)
                .HasForeignKey(e => e.PartKindId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasIndex(e => new { e.TentModelId, e.PartKindId }).IsUnique();
            entity.HasIndex(e => e.TentModelId);
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
            entity.HasIndex(e => new { e.TentId, e.PartKindId }).IsUnique();
            entity.HasIndex(e => e.CreatedAt);
            entity.HasIndex(e => e.PartKindId);
            entity.HasIndex(e => e.CreatedByUserId);
            entity.HasIndex(e => e.UpdatedByUserId);
        });

        modelBuilder.Entity<Tag>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.Name).IsRequired().HasMaxLength(30);
            entity.Property(e => e.Color).IsRequired().HasMaxLength(7);
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.UpdatedAt).IsRequired();
            entity.Property(e => e.CreatedByUserId).IsRequired();
            entity.Property(e => e.UpdatedByUserId).IsRequired();

            entity.HasOne(e => e.CreatedByUser)
                .WithMany(e => e.CreatedTags)
                .HasForeignKey(e => e.CreatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasOne(e => e.UpdatedByUser)
                .WithMany(e => e.UpdatedTags)
                .HasForeignKey(e => e.UpdatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(e => e.Name).IsUnique();
            entity.HasIndex(e => e.CreatedAt);
            entity.HasIndex(e => e.CreatedByUserId);
            entity.HasIndex(e => e.UpdatedByUserId);
        });

        modelBuilder.Entity<TentTag>(entity =>
        {
            entity.HasKey(e => new { e.TentId, e.TagId });
            entity.Property(e => e.CreatedAt).IsRequired();
            entity.Property(e => e.CreatedByUserId).IsRequired();

            entity.HasOne(e => e.Tent)
                .WithMany(e => e.TentTags)
                .HasForeignKey(e => e.TentId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.Tag)
                .WithMany(e => e.TentTags)
                .HasForeignKey(e => e.TagId)
                .OnDelete(DeleteBehavior.Cascade);

            entity.HasOne(e => e.CreatedByUser)
                .WithMany(e => e.CreatedTentTags)
                .HasForeignKey(e => e.CreatedByUserId)
                .OnDelete(DeleteBehavior.Restrict);

            entity.HasIndex(e => e.TagId);
            entity.HasIndex(e => e.CreatedByUserId);
        });

        modelBuilder.Entity<SeedInfo>(entity =>
        {
            entity.HasKey(e => e.Id);
            entity.Property(e => e.IsSeeded).IsRequired();
            entity.Property(e => e.SeededAt).IsRequired();
        });
    }
}
