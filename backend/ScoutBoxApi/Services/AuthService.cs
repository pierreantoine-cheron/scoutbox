using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Services;

public class AuthService
{
    private readonly ScoutBoxDbContext _db;
    private readonly TokenService _tokenService;
    private readonly ILogger<AuthService> _logger;

    public AuthService(ScoutBoxDbContext db, TokenService tokenService, ILogger<AuthService> logger)
    {
        _db = db;
        _tokenService = tokenService;
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
        var isRelational = _db.Database.IsRelational();

        await using var transaction = isRelational
            ? await _db.Database.BeginTransactionAsync()
            : null;

        var user = new User
        {
            Id = userId,
            Username = request.Username,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
            CreatedAt = now
        };
        var accessToken = _tokenService.GenerateAccessToken(user.Id, user.Username);
        var refreshToken = TokenService.GenerateRefreshToken();
        var refreshTokenHash = TokenService.HashRefreshToken(refreshToken);

        if (isRelational)
        {
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

            var relationalInviteConsumed = await TryConsumeInviteAsync(request.InviteCode, userId, now);
            if (!relationalInviteConsumed)
            {
                _logger.LogWarning("Invalid or expired invite code attempted: {InviteCode}", request.InviteCode);
                return (null, new ErrorResponse("Invalid or expired invite code", "INVALID_INVITE"));
            }

            await _db.RefreshTokens.AddAsync(new RefreshToken
            {
                Id = Guid.NewGuid(),
                Token = refreshTokenHash,
                UserId = user.Id,
                ExpiresAt = now.AddDays(180),
                CreatedAt = now,
                IsRevoked = false
            });

            await _db.SaveChangesAsync();
            await transaction!.CommitAsync();

            _logger.LogInformation("User registered successfully: {Username} (ID: {UserId})", user.Username, user.Id);
            return (new AuthResponse(accessToken, refreshToken, now.AddMinutes(15), now.AddDays(180)), null);
        }

        var inviteWasConsumed = await TryConsumeInviteAsync(request.InviteCode, userId, now);
        if (!inviteWasConsumed)
        {
            _logger.LogWarning("Invalid or expired invite code attempted: {InviteCode}", request.InviteCode);
            return (null, new ErrorResponse("Invalid or expired invite code", "INVALID_INVITE"));
        }

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

        await _db.RefreshTokens.AddAsync(new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = refreshTokenHash,
            UserId = user.Id,
            ExpiresAt = now.AddDays(180),
            CreatedAt = now,
            IsRevoked = false
        });

        await _db.SaveChangesAsync();

        _logger.LogInformation("User registered successfully: {Username} (ID: {UserId})", user.Username, user.Id);

        return (new AuthResponse(accessToken, refreshToken, now.AddMinutes(15), now.AddDays(180)), null);
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
        await _db.SaveChangesAsync();

        _logger.LogInformation("Invite created: {Code} by user {UserId}", code, createdByUserId);

        return (new InviteResponse(invite.Id, invite.Code, invite.ExpiresAt, invite.IsUsed), null);
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

        var now = DateTime.UtcNow;
        var accessToken = _tokenService.GenerateAccessToken(user.Id, user.Username);
        var refreshToken = TokenService.GenerateRefreshToken();
        var refreshTokenHash = TokenService.HashRefreshToken(refreshToken);

        await _db.RefreshTokens.AddAsync(new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = refreshTokenHash,
            UserId = user.Id,
            ExpiresAt = now.AddDays(180),
            CreatedAt = now,
            IsRevoked = false
        });

        await _db.SaveChangesAsync();

        return (new AuthResponse(accessToken, refreshToken, now.AddMinutes(15), now.AddDays(180)), null);
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

        storedToken.IsRevoked = true;
        storedToken.RevokedAt = DateTime.UtcNow;

        var newAccessToken = _tokenService.GenerateAccessToken(storedToken.User.Id, storedToken.User.Username);
        var newRefreshToken = TokenService.GenerateRefreshToken();
        var newRefreshTokenHash = TokenService.HashRefreshToken(newRefreshToken);

        storedToken.ReplacedByToken = newRefreshTokenHash;

        await _db.RefreshTokens.AddAsync(new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = newRefreshTokenHash,
            UserId = storedToken.UserId,
            ExpiresAt = DateTime.UtcNow.AddDays(180),
            CreatedAt = DateTime.UtcNow,
            IsRevoked = false
        });

        await _db.SaveChangesAsync();

        return (new AuthResponse(newAccessToken, newRefreshToken, DateTime.UtcNow.AddMinutes(15), DateTime.UtcNow.AddDays(180)), null);
    }

    private async Task<bool> TryConsumeInviteAsync(string inviteCode, Guid userId, DateTime consumedAt)
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

    private static bool IsDuplicateUsernameConstraintViolation(DbUpdateException ex)
    {
        var message = ex.InnerException?.Message ?? ex.Message;
        return message.Contains("Users.Username", StringComparison.OrdinalIgnoreCase)
               || message.Contains("IX_Users_Username", StringComparison.OrdinalIgnoreCase);
    }
}
