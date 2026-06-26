using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Services;

public class InviteService
{
    private readonly ScoutBoxDbContext _db;
    private readonly IAuditService _auditService;
    private readonly ILogger<InviteService> _logger;
    private readonly IConfiguration _configuration;

    public InviteService(ScoutBoxDbContext db, IAuditService auditService, ILogger<InviteService> logger, IConfiguration configuration)
    {
        _db = db;
        _auditService = auditService;
        _logger = logger;
        _configuration = configuration;
    }

    public async Task<(InviteResponse? Response, ErrorResponse? Error)> CreateInviteAsync(Guid createdByUserId, CreateInviteRequest request)
    {
        if (request.ExpiresInDays is < 1 or > 365)
        {
            return (null, new ErrorResponse("Invite expiration must be between 1 and 365 days", "INVALID_EXPIRES_IN_DAYS"));
        }

        string? code;

        if (!string.IsNullOrEmpty(request.Code))
        {
            if (await _db.Invites.AnyAsync(i => i.Code == request.Code))
            {
                return (null, new ErrorResponse("This invite code already exists", "DUPLICATE_CODE"));
            }
            code = request.Code;
        }
        else
        {
            code = await GenerateAvailableCodeAsync();

            if (code == null)
            {
                return (null, new ErrorResponse("Unable to generate an available invite code. Please provide a custom code.", "CODE_GENERATION_FAILED"));
            }
        }

        var invite = new Invite
        {
            Id = Guid.NewGuid(),
            Code = code,
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(request.ExpiresInDays),
            IsUsed = false,
            CreatedByUserId = createdByUserId
        };

        await _db.Invites.AddAsync(invite);

        _auditService.RecordEvent(
            AuditActions.InviteCreated,
            createdByUserId,
            nameof(Invite),
            invite.Id,
            new Dictionary<string, object?>
            {
                ["code"] = code,
                ["expiresInDays"] = request.ExpiresInDays,
                ["isCustomCode"] = !string.IsNullOrEmpty(request.Code)
            });

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (IsDuplicateInviteCodeViolation(ex))
        {
            _logger.LogWarning(ex, "Duplicate invite code blocked by DB constraint: {Code}", code);
            return (null, new ErrorResponse("This invite code already exists", "DUPLICATE_CODE"));
        }

        _logger.LogInformation("Invite created: {Code} by user {UserId}", code, createdByUserId);

        var serverUrl = request.ServerUrl ?? _configuration["Server:Url"] ?? "";
        var inviteLink = invite.GenerateInviteLink(serverUrl);

        return (new InviteResponse(invite.Id, invite.Code, invite.ExpiresAt, invite.IsUsed, inviteLink), null);
    }

    public async Task<bool> TryConsumeInviteAsync(string inviteCode, Guid userId, DateTime consumedAt)
    {
        if (_db.Database.IsRelational())
        {
            var affectedRows = await _db.Invites
                .Where(i => i.Code == inviteCode && !i.IsUsed && i.ExpiresAt > consumedAt)
                .ExecuteUpdateAsync(setters => setters
                    .SetProperty(i => i.IsUsed, true)
                    .SetProperty(i => i.UsedByUserId, userId)
                    .SetProperty(i => i.UsedAt, consumedAt));

            return affectedRows == 1;
        }

        var invite = await _db.Invites
            .FirstOrDefaultAsync(i => i.Code == inviteCode);

        if (invite == null || invite.IsUsed || invite.ExpiresAt <= consumedAt)
        {
            return false;
        }

        invite.IsUsed = true;
        invite.UsedByUserId = userId;
        invite.UsedAt = consumedAt;

        return true;
    }

    private async Task<string?> GenerateAvailableCodeAsync(int maxAttempts = 3)
    {
        for (int attempt = 0; attempt < maxAttempts; attempt++)
        {
            var code = TokenService.GenerateRandomCode(9);

            if (!await _db.Invites.AnyAsync(i => i.Code == code))
            {
                return code;
            }

            _logger.LogWarning("Generated invite code collision on attempt {Attempt}: {Code}", attempt + 1, code);
        }

        return null;
    }

    private static bool IsDuplicateInviteCodeViolation(DbUpdateException exception)
    {
        var message = exception.InnerException?.Message ?? exception.Message;
        return message.Contains("Invites.Code", StringComparison.OrdinalIgnoreCase)
            || message.Contains("IX_Invites_Code", StringComparison.OrdinalIgnoreCase);
    }
}
