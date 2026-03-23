using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Controllers;

[Route("api/auth")]
[ApiController]
[EnableRateLimiting("auth")]
public class AuthController : ControllerBase
{
    private readonly ScoutBoxDbContext _db;
    private readonly IConfiguration _configuration;
    private readonly ILogger<AuthController> _logger;

    public AuthController(ScoutBoxDbContext db, IConfiguration configuration, ILogger<AuthController> logger)
    {
        _db = db;
        _configuration = configuration;
        _logger = logger;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        try
        {
            // 1. Validate invite code
            var invite = await _db.Invites
                .FirstOrDefaultAsync(i => i.Code == request.InviteCode);
            
            if (invite == null || invite.IsUsed || invite.ExpiresAt < DateTime.UtcNow)
            {
                _logger.LogWarning("Invalid or expired invite code attempted: {InviteCode}", request.InviteCode);
                return BadRequest(new ErrorResponse 
                { 
                    Error = "Invalid or expired invite code", 
                    Code = "INVALID_INVITE" 
                });
            }
            
            // 2. Check username uniqueness
            if (await _db.Users.AnyAsync(u => u.Username == request.Username))
            {
                _logger.LogWarning("Duplicate username registration attempted: {Username}", request.Username);
                return BadRequest(new ErrorResponse 
                { 
                    Error = "This username already exists",
                    Code = "USERNAME_EXISTS"
                });
            }
            
            // 3. Create user with bcrypt hashing
            var user = new User
            {
                Id = Guid.NewGuid(),
                Username = request.Username,
                PasswordHash = BCrypt.Net.BCrypt.HashPassword(request.Password),
                CreatedAt = DateTime.UtcNow
            };
            await _db.Users.AddAsync(user);
            
            // 4. Mark invite as used
            invite.IsUsed = true;
            invite.UsedByUserId = user.Id;
            invite.UsedAt = DateTime.UtcNow;
            
            // 5. Generate JWT tokens
            var accessToken = GenerateAccessToken(user);
            var refreshToken = GenerateRefreshToken();
            
            await _db.RefreshTokens.AddAsync(new RefreshToken
            {
                Id = Guid.NewGuid(),
                Token = refreshToken,
                UserId = user.Id,
                ExpiresAt = DateTime.UtcNow.AddDays(180),
                CreatedAt = DateTime.UtcNow,
                IsRevoked = false
            });
            
            await _db.SaveChangesAsync();
            
            _logger.LogInformation("User registered successfully: {Username} (ID: {UserId})", user.Username, user.Id);
            
            return Ok(new AuthResponse
            {
                AccessToken = accessToken,
                RefreshToken = refreshToken,
                AccessTokenExpires = DateTime.UtcNow.AddMinutes(15),
                RefreshTokenExpires = DateTime.UtcNow.AddDays(180)
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during user registration");
            return StatusCode(500, new ErrorResponse 
            { 
                Error = "An error occurred during registration",
                Code = "INTERNAL_ERROR"
            });
        }
    }
    
    [HttpPost("invites")]
    [Authorize]
    public async Task<IActionResult> CreateInvite([FromBody] CreateInviteRequest request)
    {
        try
        {
            // Get current user ID from claims
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
            {
                return Unauthorized(new ErrorResponse 
                { 
                    Error = "Unauthorized user",
                    Code = "UNAUTHORIZED"
                });
            }
            
            // Generate code if not provided
            var code = request.Code ?? GenerateRandomCode(9);
            
            // Check if code already exists
            if (await _db.Invites.AnyAsync(i => i.Code == code))
            {
                return BadRequest(new ErrorResponse 
                { 
                    Error = "This invite code already exist",
                    Code = "DUPLICATE_CODE"
                });
            }
            
            var invite = new Invite
            {
                Id = Guid.NewGuid(),
                Code = code,
                CreatedAt = DateTime.UtcNow,
                ExpiresAt = DateTime.UtcNow.AddDays(request.ExpiresInDays),
                IsUsed = false,
                CreatedByUserId = userId
            };
            
            await _db.Invites.AddAsync(invite);
            await _db.SaveChangesAsync();
            
            _logger.LogInformation("Invite created: {Code} by user {UserId}", code, userId);
            
            return Ok(new InviteResponse
            {
                Id = invite.Id,
                Code = invite.Code,
                ExpiresAt = invite.ExpiresAt,
                IsUsed = invite.IsUsed
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating invite");
            return StatusCode(500, new ErrorResponse 
            { 
                Error = "Error during invite creation",
                Code = "INTERNAL_ERROR"
            });
        }
    }
    
    [HttpPost("refresh")]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        try
        {
            var storedToken = await _db.RefreshTokens
                .Include(rt => rt.User)
                .FirstOrDefaultAsync(rt => rt.Token == request.RefreshToken && !rt.IsRevoked);
            
            if (storedToken == null || storedToken.ExpiresAt < DateTime.UtcNow)
            {
                return BadRequest(new ErrorResponse 
                { 
                    Error = "Invalid or expired refresh token",
                    Code = "INVALID_REFRESH_TOKEN"
                });
            }
            
            // Revoke old token
            storedToken.IsRevoked = true;
            storedToken.RevokedAt = DateTime.UtcNow;
            
            // Generate new tokens
            var newAccessToken = GenerateAccessToken(storedToken.User);
            var newRefreshToken = GenerateRefreshToken();
            
            await _db.RefreshTokens.AddAsync(new RefreshToken
            {
                Id = Guid.NewGuid(),
                Token = newRefreshToken,
                UserId = storedToken.UserId,
                ExpiresAt = DateTime.UtcNow.AddDays(180),
                CreatedAt = DateTime.UtcNow,
                IsRevoked = false,
                ReplacedByToken = newRefreshToken
            });
            
            await _db.SaveChangesAsync();
            
            return Ok(new AuthResponse
            {
                AccessToken = newAccessToken,
                RefreshToken = newRefreshToken,
                AccessTokenExpires = DateTime.UtcNow.AddMinutes(15),
                RefreshTokenExpires = DateTime.UtcNow.AddDays(180)
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error refreshing token");
            return StatusCode(500, new ErrorResponse 
            { 
                Error = "Une erreur est survenue lors du rafraîchissement du token",
                Code = "INTERNAL_ERROR"
            });
        }
    }
    
    private string GenerateAccessToken(User user)
    {
        var jwtKey = _configuration["Jwt:Key"] ?? throw new InvalidOperationException("JWT Key not configured");
        var jwtIssuer = _configuration["Jwt:Issuer"] ?? "ScoutBox";
        var jwtAudience = _configuration["Jwt:Audience"] ?? "ScoutBoxUsers";
        
        var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey));
        var credentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256);
        
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Name, user.Username),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };
        
        var token = new JwtSecurityToken(
            issuer: jwtIssuer,
            audience: jwtAudience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(15),
            signingCredentials: credentials
        );
        
        return new JwtSecurityTokenHandler().WriteToken(token);
    }
    
    private static string GenerateRefreshToken()
    {
        var randomBytes = new byte[32];
        using (var rng = RandomNumberGenerator.Create())
        {
            rng.GetBytes(randomBytes);
        }
        return Convert.ToBase64String(randomBytes);
    }
    
    private static string GenerateRandomCode(int length)
    {
        const string chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
        var randomBytes = new byte[length];
        using (var rng = RandomNumberGenerator.Create())
        {
            rng.GetBytes(randomBytes);
        }
        
        var result = new char[length];
        for (int i = 0; i < length; i++)
        {
            result[i] = chars[randomBytes[i] % chars.Length];
        }
        
        return new string(result);
    }
}

public class RefreshTokenRequest
{
    public string RefreshToken { get; set; } = string.Empty;
}
