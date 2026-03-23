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

    public AuthControllerTests()
    {
        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _db = new ScoutBoxDbContext(options);

        var configMock = new Mock<IConfiguration>();
        configMock.Setup(x => x["Jwt:Key"]).Returns("test-key-that-is-32-characters-long");
        configMock.Setup(x => x["Jwt:Issuer"]).Returns("TestIssuer");
        configMock.Setup(x => x["Jwt:Audience"]).Returns("TestAudience");

        var loggerMock = new Mock<ILogger<AuthController>>();
        var authServiceLoggerMock = new Mock<ILogger<AuthService>>();

        _tokenService = new TokenService(configMock.Object);
        _authService = new AuthService(_db, _tokenService, authServiceLoggerMock.Object);
        _controller = new AuthController(_authService, loggerMock.Object);
    }

    public void Dispose()
    {
        _db.Dispose();
    }

    private void SetControllerUser(Guid userId, string username)
    {
        var claims = new List<Claim>
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim(ClaimTypes.Name, username)
        };
        var identity = new ClaimsIdentity(claims, "TestAuth");
        var principal = new ClaimsPrincipal(identity);

        _controller.ControllerContext = new ControllerContext
        {
            HttpContext = new DefaultHttpContext { User = principal }
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
            IsUsed = false
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
            IsUsed = false
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
            IsUsed = false
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
            IsUsed = false
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
            IsUsed = false
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
            Token = "valid-refresh-token",
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

        var request = new CreateInviteRequest(null, 7);

        var result = await _controller.CreateInvite(request);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<InviteResponse>(okResult.Value);
        Assert.NotNull(response.Code);
        Assert.True(response.ExpiresAt >= DateTime.UtcNow.AddDays(6.9) && response.ExpiresAt <= DateTime.UtcNow.AddDays(7.1));
    }

    [Fact]
    public async Task CreateInvite_WithCustomCode_ReturnsCustomCode()
    {
        var owner = new User
        {
            Id = Guid.NewGuid(),
            Username = "owner2",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(owner);
        await _db.SaveChangesAsync();

        SetControllerUser(owner.Id, owner.Username);

        var request = new CreateInviteRequest("CUSTOM-123", 30);

        var result = await _controller.CreateInvite(request);

        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<InviteResponse>(okResult.Value);
        Assert.Equal("CUSTOM-123", response.Code);
    }

    [Fact]
    public async Task CreateInvite_WithDuplicateCode_ReturnsBadRequest()
    {
        var owner = new User
        {
            Id = Guid.NewGuid(),
            Username = "owner3",
            PasswordHash = BCrypt.Net.BCrypt.HashPassword("password"),
            CreatedAt = DateTime.UtcNow
        };
        _db.Users.Add(owner);

        var existingInvite = new Invite
        {
            Id = Guid.NewGuid(),
            Code = "EXISTING-999",
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(30),
            IsUsed = false
        };
        _db.Invites.Add(existingInvite);
        await _db.SaveChangesAsync();

        SetControllerUser(owner.Id, owner.Username);

        var request = new CreateInviteRequest("EXISTING-999", 30);

        var result = await _controller.CreateInvite(request);

        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("DUPLICATE_CODE", error.Code);
    }
}
