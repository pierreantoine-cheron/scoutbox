using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;
using Moq;
using ScoutBoxApi.Filters;
using ScoutBoxApi.Models.DTOs;
using Xunit;

namespace ScoutBoxApi.Tests.Filters;

public class ApiExceptionFilterTests
{
    [Fact]
    public void OnException_WithUnauthorizedAccessException_Returns401WithExpectedCode()
    {
        var filter = CreateFilter();
        var context = CreateExceptionContext(new UnauthorizedAccessException("Authentication required"));

        filter.OnException(context);

        var result = Assert.IsType<UnauthorizedObjectResult>(context.Result);
        var payload = Assert.IsType<ErrorResponse>(result.Value);
        Assert.Equal(401, result.StatusCode);
        Assert.Equal("AUTH_INVALID_TOKEN", payload.Code);
        Assert.Equal("Authentication required", payload.Error);
        Assert.True(context.ExceptionHandled);
    }

    [Fact]
    public void OnException_WithDbUpdateConcurrencyException_Returns409WithExpectedCode()
    {
        var filter = CreateFilter();
        var context = CreateExceptionContext(new DbUpdateConcurrencyException("Concurrency failure"));

        filter.OnException(context);

        var result = Assert.IsType<ObjectResult>(context.Result);
        var payload = Assert.IsType<ErrorResponse>(result.Value);
        Assert.Equal(409, result.StatusCode);
        Assert.Equal("CONCURRENCY_CONFLICT", payload.Code);
        Assert.Equal("Resource was modified concurrently. Please retry.", payload.Error);
        Assert.True(context.ExceptionHandled);
    }

    [Fact]
    public void OnException_WithUnhandledException_Returns500WithExpectedCode()
    {
        var filter = CreateFilter();
        var context = CreateExceptionContext(new InvalidOperationException("Unexpected"));

        filter.OnException(context);

        var result = Assert.IsType<ObjectResult>(context.Result);
        var payload = Assert.IsType<ErrorResponse>(result.Value);
        Assert.Equal(500, result.StatusCode);
        Assert.Equal("INTERNAL_ERROR", payload.Code);
        Assert.Equal("An internal error occurred", payload.Error);
        Assert.True(context.ExceptionHandled);
    }

    private static ApiExceptionFilter CreateFilter()
    {
        var logger = new Mock<ILogger<ApiExceptionFilter>>();
        return new ApiExceptionFilter(logger.Object);
    }

    private static ExceptionContext CreateExceptionContext(Exception exception)
    {
        var actionContext = new ActionContext(
            new DefaultHttpContext(),
            new RouteData(),
            new ActionDescriptor());

        return new ExceptionContext(actionContext, new List<IFilterMetadata>())
        {
            Exception = exception
        };
    }
}
