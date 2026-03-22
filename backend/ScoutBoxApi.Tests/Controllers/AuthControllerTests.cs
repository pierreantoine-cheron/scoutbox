using System;
using System.Threading.Tasks;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Logging;
using Moq;
using ScoutBoxApi.Controllers;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;
using Xunit;

namespace ScoutBoxApi.Tests.Controllers;

public class AuthControllerTests : IDisposable
{
    private readonly ScoutBoxDbContext _db;
    private readonly AuthController _controller;
    private readonly Mock<IConfiguration> _configMock;
    private readonly Mock<ILogger<AuthController>> _loggerMock;

    public AuthControllerTests()
    {
        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;
        
        _db = new ScoutBoxDbContext(options);
        
        _configMock = new Mock<IConfiguration>();
        _configMock.Setup(x => x["Jwt:Key"]).Returns("test-key-that-is-32-characters-long");
        _configMock.Setup(x => x["Jwt:Issuer"]).Returns("TestIssuer");
        _configMock.Setup(x => x["Jwt:Audience"]).Returns("TestAudience");
        _configMock.Setup(x => x["ServerUrl"]).Returns("https://test.example.com");
        
        _loggerMock = new Mock<ILogger<AuthController>>();
        
        _controller = new AuthController(_db, _configMock.Object, _loggerMock.Object);
    }

    public void Dispose()
    {
        _db.Dispose();
    }

    [Fact]
    public async Task Register_WithValidInvite_ReturnsOkResult()
    {
        // Arrange
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

        var request = new RegisterRequest
        {
            InviteCode = "VALID-123",
            Username = "testuser",
            Password = "password123",
            ServerUrl = "https://test.example.com"
        };

        // Act
        var result = await _controller.Register(request);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<AuthResponse>(okResult.Value);
        Assert.NotNull(response.AccessToken);
        Assert.NotNull(response.RefreshToken);
        
        // Verify invite is marked as used
        var updatedInvite = await _db.Invites.FindAsync(invite.Id);
        Assert.True(updatedInvite!.IsUsed);
        Assert.NotNull(updatedInvite.UsedByUserId);
        Assert.NotNull(updatedInvite.UsedAt);
    }

    [Fact]
    public async Task Register_WithInvalidInvite_ReturnsBadRequest()
    {
        // Arrange
        var request = new RegisterRequest
        {
            InviteCode = "INVALID-123",
            Username = "testuser",
            Password = "password123",
            ServerUrl = "https://test.example.com"
        };

        // Act
        var result = await _controller.Register(request);

        // Assert
        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_INVITE", error.Code);
        Assert.Equal("Code d'invitation invalide ou expiré", error.Error);
    }

    [Fact]
    public async Task Register_WithUsedInvite_ReturnsBadRequest()
    {
        // Arrange
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

        var request = new RegisterRequest
        {
            InviteCode = "USED-123",
            Username = "testuser",
            Password = "password123",
            ServerUrl = "https://test.example.com"
        };

        // Act
        var result = await _controller.Register(request);

        // Assert
        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_INVITE", error.Code);
    }

    [Fact]
    public async Task Register_WithExpiredInvite_ReturnsBadRequest()
    {
        // Arrange
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

        var request = new RegisterRequest
        {
            InviteCode = "EXPIRED-123",
            Username = "testuser",
            Password = "password123",
            ServerUrl = "https://test.example.com"
        };

        // Act
        var result = await _controller.Register(request);

        // Assert
        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("INVALID_INVITE", error.Code);
    }

    [Fact]
    public async Task Register_WithDuplicateUsername_ReturnsBadRequest()
    {
        // Arrange
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

        var request = new RegisterRequest
        {
            InviteCode = "VALID-456",
            Username = "existinguser",
            Password = "password123",
            ServerUrl = "https://test.example.com"
        };

        // Act
        var result = await _controller.Register(request);

        // Assert
        var badRequestResult = Assert.IsType<BadRequestObjectResult>(result);
        var error = Assert.IsType<ErrorResponse>(badRequestResult.Value);
        Assert.Equal("USERNAME_EXISTS", error.Code);
        Assert.Equal("Ce nom d'utilisateur existe déjà", error.Error);
    }

    [Fact]
    public async Task Register_PasswordIsHashedWithBCrypt()
    {
        // Arrange
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

        var request = new RegisterRequest
        {
            InviteCode = "VALID-789",
            Username = "newuser",
            Password = "password123",
            ServerUrl = "https://test.example.com"
        };

        // Act
        await _controller.Register(request);

        // Assert
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Username == "newuser");
        Assert.NotNull(user);
        Assert.True(BCrypt.Net.BCrypt.Verify("password123", user.PasswordHash));
    }

    [Fact]
    public async Task Register_CreatesRefreshToken()
    {
        // Arrange
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

        var request = new RegisterRequest
        {
            InviteCode = "VALID-ABC",
            Username = "usertest",
            Password = "password123",
            ServerUrl = "https://test.example.com"
        };

        // Act
        var result = await _controller.Register(request);

        // Assert
        var okResult = Assert.IsType<OkObjectResult>(result);
        var response = Assert.IsType<AuthResponse>(okResult.Value);
        
        var user = await _db.Users.FirstOrDefaultAsync(u => u.Username == "usertest");
        Assert.NotNull(user);
        
        var refreshToken = await _db.RefreshTokens.FirstOrDefaultAsync(rt => rt.UserId == user.Id);
        Assert.NotNull(refreshToken);
        Assert.False(refreshToken.IsRevoked);
        Assert.True(refreshToken.ExpiresAt > DateTime.UtcNow.AddDays(179));
    }
}
