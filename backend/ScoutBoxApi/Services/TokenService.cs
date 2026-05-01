using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Microsoft.IdentityModel.Tokens;

namespace ScoutBoxApi.Services;

public class TokenService
{
    private const int MinimumJwtKeyLength = 32;
    private const string JwtKeyPlaceholder = "__SET_JWT_KEY_IN_ENV__";

    // Token lifetime defaults (overridable via appsettings.json Jwt section)
    private const int DefaultAccessTokenLifetimeMinutes = 15;
    private const int DefaultRefreshTokenLifetimeDays = 180;

    private readonly int _accessTokenLifetimeMinutes;
    private readonly int _refreshTokenLifetimeDays;
    private readonly string _jwtKey;
    private readonly string _jwtIssuer;
    private readonly string _jwtAudience;

    public TokenService(IConfiguration configuration)
    {
        var settings = GetValidatedJwtSettings(configuration);
        _jwtKey = settings.Key;
        _jwtIssuer = settings.Issuer;
        _jwtAudience = settings.Audience;

        _accessTokenLifetimeMinutes = configuration.GetValue("Jwt:AccessTokenLifetimeMinutes", DefaultAccessTokenLifetimeMinutes);
        _refreshTokenLifetimeDays = configuration.GetValue("Jwt:RefreshTokenLifetimeDays", DefaultRefreshTokenLifetimeDays);
    }

    public int AccessTokenLifetimeMinutes => _accessTokenLifetimeMinutes;
    public int RefreshTokenLifetimeDays => _refreshTokenLifetimeDays;

    public static (string Key, string Issuer, string Audience) GetValidatedJwtSettings(IConfiguration configuration)
    {
        var jwtKey = configuration["Jwt:Key"];
        if (string.IsNullOrWhiteSpace(jwtKey) || jwtKey == JwtKeyPlaceholder)
        {
            throw new InvalidOperationException("JWT Key is not configured. Set Jwt:Key via environment or local secrets.");
        }

        if (jwtKey.Length < MinimumJwtKeyLength)
        {
            throw new InvalidOperationException($"JWT Key must be at least {MinimumJwtKeyLength} characters.");
        }

        var jwtIssuer = configuration["Jwt:Issuer"] ?? "ScoutBox";
        var jwtAudience = configuration["Jwt:Audience"] ?? "ScoutBoxUsers";
        return (jwtKey, jwtIssuer, jwtAudience);
    }

    public string GenerateAccessToken(Guid userId, string username)
    {
        var securityKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_jwtKey));
        var credentials = new SigningCredentials(securityKey, SecurityAlgorithms.HmacSha256);

        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim(ClaimTypes.Name, username),
            new Claim(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString())
        };

        var token = new JwtSecurityToken(
            issuer: _jwtIssuer,
            audience: _jwtAudience,
            claims: claims,
            expires: DateTime.UtcNow.AddMinutes(_accessTokenLifetimeMinutes),
            signingCredentials: credentials
        );

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    public static string GenerateRefreshToken()
    {
        var randomBytes = new byte[32];
        using (var rng = RandomNumberGenerator.Create())
        {
            rng.GetBytes(randomBytes);
        }
        return Convert.ToBase64String(randomBytes);
    }

    public static string HashRefreshToken(string refreshToken)
    {
        var tokenBytes = Encoding.UTF8.GetBytes(refreshToken);
        var hashBytes = SHA256.HashData(tokenBytes);
        return Convert.ToHexString(hashBytes);
    }

    public static string GenerateRandomCode(int length)
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
