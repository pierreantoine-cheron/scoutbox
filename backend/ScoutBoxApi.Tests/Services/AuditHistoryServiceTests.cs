using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using ScoutBoxApi.Data;
using ScoutBoxApi.Services;
using ScoutBoxApi.Tests.Fixtures;
using Xunit;

namespace ScoutBoxApi.Tests.Services;

public class AuditHistoryServiceTests : TestBase
{
    private readonly AuditHistoryService _service;
    private readonly Mock<ILogger<AuditHistoryService>> _loggerMock;

    public AuditHistoryServiceTests()
    {
        _loggerMock = Fixtures.MockFactory.CreateLogger<AuditHistoryService>();
        _service = new AuditHistoryService(Db, _loggerMock.Object);
    }

    [Fact]
    public async Task GetTentHistory_IncludesTagAssignmentEvents()
    {
        var user = Builder.CreateUser("taguser");
        var tentId = Guid.NewGuid();

        Builder.CreateAuditEvent(
            AuditActions.TagAssigned,
            user.Id,
            "TentTag",
            tentId,
            DateTime.UtcNow.AddMinutes(-2),
            new Dictionary<string, object?>
            {
                ["tagId"] = Guid.NewGuid(),
                ["tagName"] = "Patrouille"
            });

        await Builder.SaveChangesAsync();

        var history = await _service.GetTentHistoryAsync(tentId);

        var item = Assert.Single(history);
        Assert.Equal(AuditActions.TagAssigned, item.Action);
        Assert.Equal("tags", item.Category);
        Assert.Equal("Patrouille", item.SubjectName);
        Assert.Equal("Étiquette", Assert.Single(item.Details).Label);
        Assert.Equal("Patrouille", item.Details[0].Value);
    }

    [Fact]
    public async Task GetTentHistory_WithTagsCategory_ReturnsOnlyTagEvents()
    {
        var user = Builder.CreateUser("taguser");
        var tentId = Guid.NewGuid();

        Builder.CreateAuditEvent(
            AuditActions.TentUpdated,
            user.Id,
            "Tent",
            tentId,
            DateTime.UtcNow.AddMinutes(-3));

        Builder.CreateAuditEvent(
            AuditActions.TagRemoved,
            user.Id,
            "TentTag",
            tentId,
            DateTime.UtcNow.AddMinutes(-2),
            new Dictionary<string, object?>
            {
                ["tagId"] = Guid.NewGuid(),
                ["tagName"] = "Rouge"
            });

        await Builder.SaveChangesAsync();

        var history = await _service.GetTentHistoryAsync(tentId, TentHistoryCategory.Tags);

        var item = Assert.Single(history);
        Assert.Equal(AuditActions.TagRemoved, item.Action);
        Assert.Equal("tags", item.Category);
        Assert.Equal("Rouge", item.SubjectName);
    }

    [Fact]
    public async Task GetTentHistory_WithArchiveCategory_IncludesUnarchiveEvents()
    {
        var user = Builder.CreateUser("archiveuser");
        var tentId = Guid.NewGuid();

        Builder.CreateAuditEvent(
            AuditActions.TentArchived,
            user.Id,
            "Tent",
            tentId,
            DateTime.UtcNow.AddMinutes(-2));

        Builder.CreateAuditEvent(
            AuditActions.TentUnarchived,
            user.Id,
            "Tent",
            tentId,
            DateTime.UtcNow.AddMinutes(-1));

        await Builder.SaveChangesAsync();

        var history = await _service.GetTentHistoryAsync(tentId, TentHistoryCategory.Archive);

        Assert.Equal(2, history.Count);
        Assert.Contains(history, h => h.Action == AuditActions.TentArchived);
        Assert.Contains(history, h => h.Action == AuditActions.TentUnarchived);
    }
}
