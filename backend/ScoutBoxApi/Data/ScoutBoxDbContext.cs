using Microsoft.EntityFrameworkCore;
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
    }
}
