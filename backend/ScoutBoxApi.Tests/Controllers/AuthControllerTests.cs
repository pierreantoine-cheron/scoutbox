using System;
using System.Security.Claims;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using ScoutBoxApi.Controllers;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Services;
using Xunit;

namespace ScoutBoxApi.Tests.Controllers;

public class AuthControllerTests : IDisposable
{
    private readonly ScoutBoxDbContext _db;
    private readonly AuthController _controller;
    private readonly AuthService _authService;
    private readonly TokenService _tokenService;
    private readonly Mock<ICurrentUserAccessor> _currentUserAccessorMock;

    public AuthControllerTests()
    {
        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _db = new ScoutBoxDbContext(options);

        var config = new ConfigurationBuilder()
            .AddInMemoryCollection(new[]
            {
                new KeyValuePair<string, string?>("Jwt:Key", "test-key-that-is-32-characters-long"),
                new KeyValuePair<string, string?>("Jwt:Issuer", "TestIssuer"),
                new KeyValuePair<string, string?>("Jwt:Audience", "TestAudience"),
            })
            .Build();

        var authServiceLoggerMock = new Mock<ILogger<AuthService>>();
        var auditServiceLoggerMock = new Mock<ILogger<AuditService>>();
        var inviteServiceLoggerMock = new Mock<ILogger<InviteService>>();

        _tokenService = new TokenService(config);
        var auditService = new AuditService(_db, auditServiceLoggerMock.Object);
        var inviteService = new InviteService(_db, auditService, inviteServiceLoggerMock.Object);
        _authService = new AuthService(_db, _tokenService, inviteService, auditService, authServiceLoggerMock.Object);
        _currentUserAccessorMock = new Mock<ICurrentUserAccessor>();
        _currentUserAccessorMock
            .Setup(accessor => accessor.GetValidatedUserId())
            .Throws(new UnauthorizedAccessException("Authentication required"));

        _controller = new AuthController(_authService, _currentUserAccessorMock.Object);
    }

    public void Dispose()
    {
        _db.Dispose();
    }

    private void SetControllerUser(Guid userId, string username)
    {
        _currentUserAccessorMock
            .Setup(accessor => accessor.GetValidatedUserId())
            .Returns(userId);

        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim(ClaimTypes.Name, username)
        };
        var identity = new ClaimsIdentity(claims, "TestAuth");
        var principal = new ClaimsPrincipal(identity);

        var httpContext = new DefaultHttpContext { User = principal };
        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = httpContext
        };
    }

    [Fact]
    public async Task Register_WithValidInvite_ReturnsOkResult()
    {
        var invite = new Invite
        {
            Id = Guid.NewGuid(),
            Code = "VALID-123",
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(30),
            IsUsed = false,
            CreatedByUserId = Guid.NewGuid()
        };
        _db.Invites.Add(invite);
        await _db.SaveChangesAsync();

        var request = new RegisterRequest("VALID-123", "testuser", "password123");

        var result = await _controller.Register(request);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<AuthResponse>(okResult.Value);
        Assert.NotNull(response.AccessToken);
        Assert.NotNull(response.RefreshToken);

        var updatedInvite = await _db.Invites.FindAsync(invite.Id);
        Assert.True(updatedInvite!.IsUsed);
        Assert.NotNull(updatedInvite.UsedByUserId);
        Assert.NotNull(updatedInvite.UsedAt);
    }

    [Fact]
    public async Task Register_WithInvalidInvite_ReturnsBadRequest()
    {
        var request = new RegisterRequest("INVALID-123", "testuser", "password123");

        var result = await _controller.Register(request);

        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_INVITE", error.Code);
        Assert.Equal("Invalid or expired invite code", error.Error);

        var createdUser = await _db.Users.FirstOrDefaultAsync(u => u.Username == "testuser");
        Assert.Null(createdUser);
    }

    [Fact]
    public async Task Register_WithUsedInvite_ReturnsBadRequest()
    {
        var invite = new Invite
        {
            Id = Guid.NewGuid(),
            Code = "USED-123",
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(30),
            IsUsed = true,
            CreatedByUserId = Guid.NewGuid(),
            UsedByUserId = Guid.NewGuid(),
            UsedAt = DateTime.UtcNow
        };
        _db.Invites.Add(invite);
        await _db.SaveChangesAsync();

        var request = new RegisterRequest("USED-123", "testuser", "password123");

        var result = await _controller.Register(request);

        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_INVITE", error.Code);
    }

    [Fact]
    public async Task Register_WithExpiredInvite_ReturnsBadRequest()
    {
        var invite = new Invite
        {
            Id = Guid.NewGuid(),
            Code = "EXPIRED-123",
            CreatedAt = DateTime.UtcNow.AddDays(-40),
            ExpiresAt = DateTime.UtcNow.AddDays(-10),
            IsUsed = false,
            CreatedByUserId = Guid.NewGuid()
        };
        _db.Invites.Add(invite);
        await _db.SaveChangesAsync();

        var request = new RegisterRequest("EXPIRED-123", "testuser", "password123");

        var result = await _controller.Register(request);

        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_INVITE", error.Code);
    }

    [Fact]
    public async Task Register_WithDuplicateUsername_ReturnsBadRequest()
    {
        var existingUser = new User
        {
            Id = Guid.NewGuid(),
            Username = "existinguser",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(existingUser);

        var invite = new Invite
        {
            Id = Guid.NewGuid(),
            Code = "VALID-456",
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(30),
            IsUsed = false,
            CreatedByUserId = Guid.NewGuid()
        };
        _db.Invites.Add(invite);
        await _db.SaveChangesAsync();

        var request = new RegisterRequest("VALID-456", "existinguser", "password123");

        var result = await _controller.Register(request);

        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("USERNAME_EXISTS", error.Code);
        Assert.Equal("This username already exists", error.Error);
    }

    [Fact]
    public async Task Register_PasswordIsHashedWithBCrypt()
    {
        var invite = new Invite
        {
            Id = Guid.NewGuid(),
            Code = "VALID-789",
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(30),
            IsUsed = false,
            CreatedByUserId = Guid.NewGuid()
        };
        _db.Invites.Add(invite);
        await _db.SaveChangesAsync();

        var request = new RegisterRequest("VALID-789", "newuser", "password123");

        await _controller.Register(request);

        var user = await _db.Users.FirstOrDefaultAsync(u => u.Username == "newuser");
        Assert.NotNull(user);
        Assert.True(BCrypt.Net.BCrypt.Verify("password123", user.PasswordHash));
    }

    [Fact]
    public async Task Register_CreatesRefreshToken()
    {
        var invite = new Invite
        {
            Id = Guid.NewGuid(),
            Code = "VALID-ABC",
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(30),
            IsUsed = false,
            CreatedByUserId = Guid.NewGuid()
        };
        _db.Invites.Add(invite);
        await _db.SaveChangesAsync();

        var request = new RegisterRequest("VALID-ABC", "usertest", "password123");

        var result = await _controller.Register(request);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<AuthResponse>(okResult.Value);

        var user = await _db.Users.FirstOrDefaultAsync(u => u.Username == "usertest");
        Assert.NotNull(user);

        var refreshToken = await _db.RefreshTokens.FirstOrDefaultAsync(rt => rt.UserId == user.Id);
        Assert.NotNull(refreshToken);
        Assert.False(refreshToken.IsRevoked);
        Assert.True(refreshToken.ExpiresAt > DateTime.UtcNow.AddDays(179));
        Assert.NotEqual(response.RefreshToken, refreshToken.Token);
        Assert.Equal(TokenService.HashRefreshToken(response.RefreshToken), refreshToken.Token);
    }

    [Fact]
    public async Task Login_WithValidCredentials_ReturnsOkResult()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "loginuser",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password123"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        var request = new LoginRequest("loginuser", "password123");

        var result = await _controller.Login(request);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<AuthResponse>(okResult.Value);
        Assert.False(string.IsNullOrWhiteSpace(response.AccessToken));
        Assert.False(string.IsNullOrWhiteSpace(response.RefreshToken));
    }

    [Fact]
    public async Task Login_WithUnknownUsername_ReturnsUnauthorized()
    {
        var request = new LoginRequest("unknown", "password123");

        var result = await _controller.Login(request);

        var unauthorizedResult = Assert.IsType<UnauthorizedObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(unauthorizedResult.Value);
        Assert.Equal("INVALID_CREDENTIALS", error.Code);
        Assert.Equal("Invalid credentials", error.Error);
    }

    [Fact]
    public async Task Login_WithWrongPassword_ReturnsUnauthorized()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "loginuser2",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password123"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        var request = new LoginRequest("loginuser2", "wrong-password");

        var result = await _controller.Login(request);

        var unauthorizedResult = Assert.IsType<UnauthorizedObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(unauthorizedResult.Value);
        Assert.Equal("INVALID_CREDENTIALS", error.Code);
        Assert.Equal("Invalid credentials", error.Error);
    }

    [Fact]
    public async Task Login_CreatesRefreshToken()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "loginuser3",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password123"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        var result = await _controller.Login(new LoginRequest("loginuser3", "password123"));

        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<AuthResponse>(okResult.Value);

        var refreshToken = await _db.RefreshTokens
            .Where(rt => rt.UserId == user.Id && !rt.IsRevoked)
            .OrderByDescending(rt => rt.CreatedAt)
            .FirstOrDefaultAsync();
        Assert.NotNull(refreshToken);
        Assert.True(refreshToken!.ExpiresAt > DateTime.UtcNow.AddDays(179));
        Assert.Equal(TokenService.HashRefreshToken(response.RefreshToken), refreshToken.Token);
    }

    [Fact]
    public async Task Login_WithEmptyUsername_ReturnsUnauthorized()
    {
        var request = new LoginRequest("", "password123");

        var result = await _controller.Login(request);

        var unauthorizedResult = Assert.IsType<UnauthorizedObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(unauthorizedResult.Value);
        Assert.Equal("INVALID_CREDENTIALS", error.Code);
        Assert.Equal("Invalid credentials", error.Error);
    }

    [Fact]
    public async Task Login_WithEmptyPassword_ReturnsUnauthorized()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "loginuser4",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password123"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        var request = new LoginRequest("loginuser4", "");

        var result = await _controller.Login(request);

        var unauthorizedResult = Assert.IsType<UnauthorizedObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(unauthorizedResult.Value);
        Assert.Equal("INVALID_CREDENTIALS", error.Code);
        Assert.Equal("Invalid credentials", error.Error);
    }

    [Fact]
    public async Task Login_WithDifferentCaseUsername_ReturnsUnauthorized()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "LoginUser",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password123"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        // Attempt login with different case - should fail due to case-sensitive lookup
        var request = new LoginRequest("loginuser", "password123");

        var result = await _controller.Login(request);

        var unauthorizedResult = Assert.IsType<UnauthorizedObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(unauthorizedResult.Value);
        Assert.Equal("INVALID_CREDENTIALS", error.Code);
        Assert.Equal("Invalid credentials", error.Error);
    }

    [Fact]
    public async Task RefreshToken_WithValidToken_ReturnsNewTokens()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "refreshuser",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);

        var oldRefreshToken = new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = TokenService.HashRefreshToken("valid-refresh-token"),
            UserId = user.Id,
            ExpiresAt = DateTime.UtcNow.AddDays(180),
            CreatedAt = DateTime.UtcNow,
            IsRevoked = false
        };
        _db.RefreshTokens.Add(oldRefreshToken);
        await _db.SaveChangesAsync();

        var request = new RefreshTokenRequest("valid-refresh-token");

        var result = await _controller.RefreshToken(request);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<AuthResponse>(okResult.Value);
        Assert.NotNull(response.AccessToken);
        Assert.NotNull(response.RefreshToken);
        Assert.NotEqual("valid-refresh-token", response.RefreshToken);

        var revokedToken = await _db.RefreshTokens.FindAsync(oldRefreshToken.Id);
        Assert.True(revokedToken!.IsRevoked);
        Assert.NotEqual(response.RefreshToken, revokedToken.ReplacedByToken);
        Assert.Equal(TokenService.HashRefreshToken(response.RefreshToken), revokedToken.ReplacedByToken);
    }

    [Fact]
    public async Task RefreshToken_WithInvalidToken_ReturnsBadRequest()
    {
        var request = new RefreshTokenRequest("invalid-token");

        var result = await _controller.RefreshToken(request);

        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_REFRESH_TOKEN", error.Code);
    }

    [Fact]
    public async Task RefreshToken_WithBlankToken_ReturnsBadRequest()
    {
        var result = await _controller.RefreshToken(new RefreshTokenRequest("   "));

        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_REFRESH_TOKEN", error.Code);
    }

    [Fact]
    public async Task RefreshToken_WithLegacyPlaintextStoredToken_ReturnsBadRequest()
    {
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "legacyrefreshuser",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);

        _db.RefreshTokens.Add(new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = "legacy-plain-text-token",
            UserId = user.Id,
            ExpiresAt = DateTime.UtcNow.AddDays(180),
            CreatedAt = DateTime.UtcNow,
            IsRevoked = false
        });
        await _db.SaveChangesAsync();

        var result = await _controller.RefreshToken(new RefreshTokenRequest("legacy-plain-text-token"));

        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_REFRESH_TOKEN", error.Code);
    }

    [Fact]
    public async Task CreateInvite_WithValidRequest_ReturnsInvite()
    {
        var owner = new User
        {
            Id = Guid.NewGuid(),
            Username = "owner",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(owner);
        await _db.SaveChangesAsync();

        SetControllerUser(owner.Id, owner.Username);

        var request = new CreateInviteRequest
        {
            ExpiresInDays = 7,
            ServerUrl = "https://test.scoutbox.local"
        };

        var result = await _controller.CreateInvite(request);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<InviteResponse>(okResult.Value);
        Assert.NotNull(response.Code);
        Assert.True(response.ExpiresAt >= DateTime.UtcNow.AddDays(6.9) && response.ExpiresAt <= DateTime.UtcNow.AddDays(7.1));
        Assert.NotNull(response.InviteLink);
        Assert.StartsWith("scoutbox://register?server=", response.InviteLink);
    }

    [Fact]
    public async Task CreateInvite_WithServerUrlInRequest_ReturnsInviteLinkWithCustomServer()
    {
        var owner = new User
        {
            Id = Guid.NewGuid(),
            Username = "owner-link",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(owner);
        await _db.SaveChangesAsync();

        SetControllerUser(owner.Id, owner.Username);

        var request = new CreateInviteRequest
        {
            ExpiresInDays = 7,
            ServerUrl = "https://custom-server.groupe.fr"
        };

        var result = await _controller.CreateInvite(request);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<InviteResponse>(okResult.Value);
        Assert.NotNull(response.InviteLink);
        Assert.Contains("server=https%3A%2F%2Fcustom-server.groupe.fr", response.InviteLink);
    }

    [Fact]
    public async Task CreateInvite_WithInvalidExpiresInDays_ReturnsBadRequest()
    {
        var owner = new User
        {
            Id = Guid.NewGuid(),
            Username = "owner4",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(owner);
        await _db.SaveChangesAsync();

        SetControllerUser(owner.Id, owner.Username);

        var request = new CreateInviteRequest { ExpiresInDays = 0 };

        var result = await _controller.CreateInvite(request);

        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_EXPIRES_IN_DAYS", error.Code);
    }

    [Fact]
    public async Task CreateInvite_WithMissingServerUrl_ReturnsBadRequest()
    {
        var owner = new User
        {
            Id = Guid.NewGuid(),
            Username = "owner-missing-server",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(owner);
        await _db.SaveChangesAsync();

        SetControllerUser(owner.Id, owner.Username);

        var request = new CreateInviteRequest { ExpiresInDays = 7 };

        var result = await _controller.CreateInvite(request);

        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_SERVER_URL", error.Code);
    }

    [Fact]
    public async Task CreateInvite_WithoutAuthHeader_ThrowsUnauthorizedAccessException()
    {
        // Arrange - no user set in controller context
        var request = new CreateInviteRequest { ExpiresInDays = 7 };

        // Act & Assert - should throw UnauthorizedAccessException (filter would convert to 401 in real request)
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => _controller.CreateInvite(request));
    }

    [Fact]
    public async Task Logout_WithValidToken_RevokesTokenAndReturnsSuccess()
    {
        // Arrange
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "logoutuser",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);

        var refreshToken = TokenService.GenerateRefreshToken();
        var refreshTokenHash = TokenService.HashRefreshToken(refreshToken);
        var token = new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = refreshTokenHash,
            UserId = user.Id,
            ExpiresAt = DateTime.UtcNow.AddDays(180),
            CreatedAt = DateTime.UtcNow,
            IsRevoked = false
        };
        _db.RefreshTokens.Add(token);
        await _db.SaveChangesAsync();

        SetControllerUser(user.Id, user.Username);

        var request = new LogoutRequest(refreshToken);

        // Act
        var result = await _controller.Logout(request);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var logoutResponse = Assert.IsType<LogoutResponse>(okResult.Value);
        Assert.True(logoutResponse.Success);

        // Verify token is revoked
        var revokedToken = await _db.RefreshTokens.FindAsync(token.Id);
        Assert.NotNull(revokedToken);
        Assert.True(revokedToken.IsRevoked);
        Assert.NotNull(revokedToken.RevokedAt);

        var auditEvents = await _db.AuditEvents.ToListAsync();
        Assert.Single(auditEvents);
        Assert.Equal(AuditActions.UserLogoutSucceeded, auditEvents[0].Action);
        Assert.Equal(user.Id, auditEvents[0].ActorUserId);
    }

    [Fact]
    public async Task Logout_WithAlreadyRevokedToken_ReturnsSuccess_Idempotent()
    {
        // Arrange
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "logoutuser2",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);

        var refreshToken = TokenService.GenerateRefreshToken();
        var refreshTokenHash = TokenService.HashRefreshToken(refreshToken);
        var token = new RefreshToken
        {
            Id = Guid.NewGuid(),
            Token = refreshTokenHash,
            UserId = user.Id,
            ExpiresAt = DateTime.UtcNow.AddDays(180),
            CreatedAt = DateTime.UtcNow,
            IsRevoked = true,
            RevokedAt = DateTime.UtcNow.AddHours(-1)
        };
        _db.RefreshTokens.Add(token);
        await _db.SaveChangesAsync();

        SetControllerUser(user.Id, user.Username);

        var request = new LogoutRequest(refreshToken);

        // Act
        var result = await _controller.Logout(request);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var logoutResponse = Assert.IsType<LogoutResponse>(okResult.Value);
        Assert.True(logoutResponse.Success);

        var auditEvents = await _db.AuditEvents.ToListAsync();
        Assert.Single(auditEvents);
        Assert.Equal(AuditActions.UserLogoutSucceeded, auditEvents[0].Action);
        Assert.Equal(user.Id, auditEvents[0].ActorUserId);
    }

    [Fact]
    public async Task Logout_WithEmptyRefreshToken_ReturnsBadRequest()
    {
        // Arrange
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "logoutuser3",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        SetControllerUser(user.Id, user.Username);

        var request = new LogoutRequest("");

        // Act
        var result = await _controller.Logout(request);

        // Assert
        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_REFRESH_TOKEN", error.Code);
    }

    [Fact]
    public async Task Logout_WithoutAuthHeader_ThrowsUnauthorizedAccessException()
    {
        // Arrange - no user set in controller context
        var request = new LogoutRequest("some-token");

        // Act & Assert - should throw UnauthorizedAccessException (filter would convert to 401 in real request)
        await Assert.ThrowsAsync<UnauthorizedAccessException>(() => _controller.Logout(request));
    }

    [Fact]
    public async Task Logout_WithNonExistentToken_ReturnsSuccess_Idempotent()
    {
        // Arrange
        var user = new User
        {
            Id = Guid.NewGuid(),
            Username = "logoutuser4",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        SetControllerUser(user.Id, user.Username);

        // Token that doesn't exist in database
        var nonExistentToken = TokenService.GenerateRefreshToken();
        var request = new LogoutRequest(nonExistentToken);

        // Act
        var result = await _controller.Logout(request);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var logoutResponse = Assert.IsType<LogoutResponse>(okResult.Value);
        Assert.True(logoutResponse.Success);

        var auditEvents = await _db.AuditEvents.ToListAsync();
        Assert.Single(auditEvents);
        Assert.Equal(AuditActions.UserLogoutSucceeded, auditEvents[0].Action);
        Assert.Equal(user.Id, auditEvents[0].ActorUserId);
    }

    [Fact]
    public async Task Logout_WithNullBody_ReturnsBadRequest()
    {
        // Act
        var result = await _controller.Logout(null!);

        // Assert
        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_REFRESH_TOKEN", error.Code);
    }
}
