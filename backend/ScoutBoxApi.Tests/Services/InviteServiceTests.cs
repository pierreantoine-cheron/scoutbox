using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;
using ScoutBoxApi.Services;
using Xunit;

namespace ScoutBoxApi.Tests.Services;

public class InviteServiceTests : IDisposable
{
    private readonly ScoutBoxDbContext _db;
    private readonly InviteService _inviteService;

    public InviteServiceTests()
    {
        var options = new DbContextOptionsBuilder<ScoutBoxDbContext>()
            .UseInMemoryDatabase(databaseName: Guid.NewGuid().ToString())
            .Options;

        _db = new ScoutBoxDbContext(options);

        var auditServiceLoggerMock = new Mock<ILogger<AuditService>>();
        var auditService = new AuditService(_db, auditServiceLoggerMock.Object);
        var inviteServiceLoggerMock = new Mock<ILogger<InviteService>>();

        _inviteService = new InviteService(_db, auditService, inviteServiceLoggerMock.Object);
    }

    public void Dispose()
    {
        _db.Dispose();
    }

    [Fact]
    public void GenerateInviteLink_ReturnsCorrectlyFormattedUrl()
    {
        var invite = new Invite
        {
            Id = Guid.NewGuid(),
            Code = "TEST-123",
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(30),
            IsUsed = false,
            CreatedByUserId = Guid.NewGuid()
        };

        var link = invite.GenerateInviteLink("https://tentes.groupe.fr");

        Assert.Equal("scoutbox://register?server=https%3A%2F%2Ftentes.groupe.fr&invite=TEST-123", link);
    }

    [Fact]
    public void GenerateInviteLink_EncodesSpecialCharacters()
    {
        var invite = new Invite
        {
            Id = Guid.NewGuid(),
            Code = "CODE+123",
            CreatedAt = DateTime.UtcNow,
            ExpiresAt = DateTime.UtcNow.AddDays(30),
            IsUsed = false,
            CreatedByUserId = Guid.NewGuid()
        };

        var link = invite.GenerateInviteLink("https://my-server.com/path?param=value");

        Assert.Contains("server=https%3A%2F%2Fmy-server.com%2Fpath%3Fparam%3Dvalue", link);
        Assert.Contains("invite=CODE%2B123", link);
    }

    [Fact]
    public async Task CreateInviteAsync_WithServerUrlInRequest_IncludesInviteLinkInResponse()
    {
        var userId = Guid.NewGuid();
        var request = new CreateInviteRequest(ExpiresInDays: 30, ServerUrl: "https://custom-server.fr");

        var (response, error) = await _inviteService.CreateInviteAsync(userId, request);

        Assert.Null(error);
        Assert.NotNull(response);
        Assert.NotNull(response!.InviteLink);
        Assert.StartsWith("scoutbox://register?server=", response.InviteLink);
        Assert.Contains("server=https%3A%2F%2Fcustom-server.fr", response.InviteLink);
        Assert.Contains("invite=", response.InviteLink);
    }

    [Fact]
    public async Task CreateInviteAsync_WithoutServerUrlInRequest_ReturnsInvalidServerUrl()
    {
        var userId = Guid.NewGuid();
        var request = new CreateInviteRequest(ExpiresInDays: 30);

        var (response, error) = await _inviteService.CreateInviteAsync(userId, request);

        Assert.Null(response);
        Assert.NotNull(error);
        Assert.Equal("INVALID_SERVER_URL", error!.Code);
    }

    [Fact]
    public async Task CreateInviteAsync_WithBlankServerUrlInRequest_ReturnsInvalidServerUrl()
    {
        var userId = Guid.NewGuid();
        var request = new CreateInviteRequest(ExpiresInDays: 30, ServerUrl: "   ");

        var (response, error) = await _inviteService.CreateInviteAsync(userId, request);

        Assert.Null(response);
        Assert.NotNull(error);
        Assert.Equal("INVALID_SERVER_URL", error!.Code);
    }

}
