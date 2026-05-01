using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Services;

public class AuthService
{
    private readonly ScoutBoxDbContext _db;
    private readonly TokenService _tokenService;
    private readonly InviteService _inviteService;
    private readonly IAuditService _auditService;
    private readonly ILogger<AuthService> _logger;

    public AuthService(ScoutBoxDbContext db, TokenService tokenService, InviteService inviteService, IAuditService auditService, ILogger<AuthService> logger)
    {
        _db = db;
        _tokenService = tokenService;
        _inviteService = inviteService;
        _auditService = auditService;
        _logger = logger;
    }

    public async Task<(AuthResponse? Response, ErrorResponse? Error)> RegisterAsync(RegisterRequest request)
    {
        if (await _db.Users.AnyAsync(u => u.Username == request.Username))
        {
            _logger.LogWarning("Duplicate username registration attempted: {Username}", request.Username);
            return (null, new ErrorResponse("This username already exists", "USERNAME_EXISTS"));
        }

        var now = DateTime.UtcNow;
        var userId = Guid.NewGuid();

        // Prepare user entity early (shared between relational and non-relational paths)
        var user = new User
        {
            Id = userId,
            Username = request.Username,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            CreatedAt = now
        };

        // For relational databases, use transaction; otherwise use manual compensation on failure
        var isRelational = _db.Database.IsRelational();
        await using var transaction = isRelational
            ? await _db.Database.BeginTransactionAsync()
            : null;

        // Persist user first (required for FK constraint when consuming invite relationally)
        await _db.Users.AddAsync(user);

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (IsDuplicateUsernameConstraintViolation(ex))
        {
            _logger.LogWarning("Duplicate username registration blocked by database constraint: {Username}", request.Username);
            return (null, new ErrorResponse("This username already exists", "USERNAME_EXISTS"));
        }

        // Consume invite
        var inviteConsumed = await _inviteService.TryConsumeInviteAsync(request.InviteCode, userId, now);

        if (!inviteConsumed)
        {
            if (transaction != null)
            {
                await transaction.RollbackAsync();
            }
            else
            {
                _db.Users.Remove(user);
                await _db.SaveChangesAsync();
            }

            _logger.LogWarning("Invalid or expired invite code attempted: {InviteCode}", request.InviteCode);
            return (null, new ErrorResponse("Invalid or expired invite code", "INVALID_INVITE"));
        }

        // Issue session (generates tokens, persists refresh token, records audit)
        var (response, error) = await IssueSessionAsync(user.Id, user.Username, AuditActions.UserRegisteredFromInvite, new Dictionary<string, object?>
        {
            ["username"] = user.Username,
            ["inviteCode"] = request.InviteCode
        });

        if (error != null)
        {
            return (null, error);
        }

        if (transaction != null)
        {
            await transaction.CommitAsync();
        }

        _logger.LogInformation("User registered successfully: {Username} (ID: {UserId})", user.Username, user.Id);
        return (response, null);
    }

    public async Task<(InviteResponse? Response, ErrorResponse? Error)> CreateInviteAsync(Guid createdByUserId, CreateInviteRequest request)
    {
        return await _inviteService.CreateInviteAsync(createdByUserId, request);
    }

    public async Task<(AuthResponse? Response, ErrorResponse? Error)> LoginAsync(LoginRequest request)
    {
        // Username lookup is case-sensitive. "User" and "user" are treated as different usernames.
        // This is intentional for security - prevents accidental account access due to case confusion.
        var user = await _db.Users
            .FirstOrDefaultAsync(u => u.Username == request.Username);

        // Use a dummy hash when user not found to prevent timing attacks
        // This ensures both "user not found" and "wrong password" take similar time
        var hashToVerify = user?.PasswordHash ?? "$2a$10$AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA";

        // Always perform verification to equalize timing between null user and wrong password
        var isValidPassword = BCrypt.Net.BCrypt.Verify(request.Password, hashToVerify);

        if (user == null || !isValidPassword)
        {
            return (null, new ErrorResponse("Invalid credentials", "INVALID_CREDENTIALS"));
        }

        return await IssueSessionAsync(user.Id, user.Username, AuditActions.UserLoginSucceeded, new Dictionary<string, object?>
        {
            ["username"] = user.Username
        });
    }

    /// <summary>
    /// Issues a new session: generates access/refresh tokens, persists refresh token, records audit event.
    /// </summary>
    private async Task<(AuthResponse Response, ErrorResponse? Error)> IssueSessionAsync(
        Guid userId,
        string username,
        string auditAction,
        Dictionary<string, object?> auditDetails)
    {
        var now = DateTime.UtcNow;
        var accessToken = _tokenService.GenerateAccessToken(userId, username);
        var refreshToken = TokenService.GenerateRefreshToken();
        var refreshTokenHash = TokenService.HashRefreshToken(refreshToken);

        await _db.RefreshTokens.AddAsync(new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = refreshTokenHash,
            UserId = userId,
            ExpiresAt = now.AddDays(_tokenService.RefreshTokenLifetimeDays),
            CreatedAt = now,
            IsRevoked = false
        });

        // Record audit event
        _auditService.RecordEvent(
            auditAction,
            userId,
            nameof(User),
            userId,
            auditDetails);

        await _db.SaveChangesAsync();

        return (new AuthResponse(
            accessToken,
            refreshToken,
            now.AddMinutes(_tokenService.AccessTokenLifetimeMinutes),
            now.AddDays(_tokenService.RefreshTokenLifetimeDays)), null);
    }

    public async Task<(AuthResponse? Response, ErrorResponse? Error)> RefreshTokenAsync(string refreshToken)
    {
        var refreshTokenHash = TokenService.HashRefreshToken(refreshToken);

        var storedToken = await _db.RefreshTokens
            .Include(rt => rt.User)
            .OrderByDescending(rt => rt.CreatedAt)
            .FirstOrDefaultAsync(rt => rt.Token == refreshTokenHash && !rt.IsRevoked);

        if (storedToken == null || storedToken.ExpiresAt < DateTime.UtcNow)
        {
            return (null, new ErrorResponse("Invalid or expired refresh token", "INVALID_REFRESH_TOKEN"));
        }

        // Handle soft-deleted users: User property will be null due to global query filter
        // Load user with IgnoreQueryFilters to check existence and deletion state
        User? user = storedToken.User;
        if (user == null)
        {
            user = await _db.Users
                .IgnoreQueryFilters()
                .FirstOrDefaultAsync(u => u.Id == storedToken.UserId);

            // If user is soft-deleted or truly missing, reject the refresh
            if (user == null || user.IsDeleted)
            {
                _logger.LogWarning(
                    "Refresh token rejected for {Status} user {UserId}",
                    user == null ? "missing" : "deleted",
                    storedToken.UserId);
                return (null, new ErrorResponse("Invalid or expired refresh token", "INVALID_REFRESH_TOKEN"));
            }
        }

        storedToken.IsRevoked = true;
        storedToken.RevokedAt = DateTime.UtcNow;

        var newAccessToken = _tokenService.GenerateAccessToken(user.Id, user.Username);
        var newRefreshToken = TokenService.GenerateRefreshToken();
        var newRefreshTokenHash = TokenService.HashRefreshToken(newRefreshToken);

        storedToken.ReplacedByToken = newRefreshTokenHash;

        var now = DateTime.UtcNow;
        await _db.RefreshTokens.AddAsync(new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = newRefreshTokenHash,
            UserId = user.Id,
            ExpiresAt = now.AddDays(_tokenService.RefreshTokenLifetimeDays),
            CreatedAt = now,
            IsRevoked = false
        });

        // Record audit event for token rotation
        _auditService.RecordEvent(
            AuditActions.UserRefreshTokenRotated,
            user.Id,
            nameof(RefreshToken),
            storedToken.Id,
            new Dictionary<string, object?>
            {
                ["username"] = user.Username
            });

        await _db.SaveChangesAsync();

        return (new AuthResponse(
            newAccessToken,
            newRefreshToken,
            now.AddMinutes(_tokenService.AccessTokenLifetimeMinutes),
            now.AddDays(_tokenService.RefreshTokenLifetimeDays)), null);
    }

    public async Task<(LogoutResponse? Response, ErrorResponse? Error)> LogoutAsync(Guid userId, string? refreshToken)
    {
        // Validate refresh token is provided
        if (string.IsNullOrWhiteSpace(refreshToken))
        {
            return (null, new ErrorResponse("Refresh token is required", "INVALID_REFRESH_TOKEN"));
        }

        var refreshTokenHash = TokenService.HashRefreshToken(refreshToken);
        var now = DateTime.UtcNow;

        // Find the refresh token for this user (include revoked to handle idempotency)
        var storedToken = await _db.RefreshTokens
            .FirstOrDefaultAsync(rt => rt.Token == refreshTokenHash && rt.UserId == userId);

        if (storedToken != null && !storedToken.IsRevoked)
        {
            // Revoke the token
            storedToken.IsRevoked = true;
            storedToken.RevokedAt = now;
            _logger.LogInformation("Refresh token revoked for user {UserId}", userId);
        }
        // If token not found or already revoked, treat as idempotent success

        // Record audit event for logout
        _auditService.RecordEvent(
            AuditActions.UserLogoutSucceeded,
            userId,
            nameof(User),
            userId,
            new Dictionary<string, object?> { });

        await _db.SaveChangesAsync();

        return (new LogoutResponse(true), null);
    }

    private static bool IsDuplicateUsernameConstraintViolation(DbUpdateException ex)
    {
        var message = ex.InnerException?.Message ?? ex.Message;
        return message.Contains("Users.Username", StringComparison.OrdinalIgnoreCase)
               || message.Contains("IX_Users_Username", StringComparison.OrdinalIgnoreCase);
    }
}
