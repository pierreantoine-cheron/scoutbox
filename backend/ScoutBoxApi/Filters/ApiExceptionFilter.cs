using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Models.DTOs;

namespace ScoutBoxApi.Filters;

/// <summary>
/// Exception filter that maps specific exceptions to standardized API error responses.
/// Eliminates repetitive try/catch blocks in controllers.
/// </summary>
public class ApiExceptionFilter : IExceptionFilter
{
    private readonly ILogger<ApiExceptionFilter> _logger;

    public ApiExceptionFilter(ILogger<ApiExceptionFilter> logger)
    {
        _logger = logger;
    }

    public void OnException(ExceptionContext context)
    {
        switch (context.Exception)
        {
            case UnauthorizedAccessException ex:
                _logger.LogWarning(ex, "Authentication failure");
                context.Result = new UnauthorizedObjectResult(
                    new ErrorResponse(ex.Message, "AUTH_INVALID_TOKEN"));
                context.ExceptionHandled = true;
                break;

            case DbUpdateConcurrencyException ex:
                _logger.LogWarning(ex, "Concurrency conflict while processing request");
                context.Result = new ObjectResult(
                    new ErrorResponse("Resource was modified concurrently. Please retry.", "CONCURRENCY_CONFLICT"))
                {
                    StatusCode = 409
                };
                context.ExceptionHandled = true;
                break;

            default:
                _logger.LogError(context.Exception, "Unhandled exception occurred");
                context.Result = new ObjectResult(
                    new ErrorResponse("An internal error occurred", "INTERNAL_ERROR"))
                {
                    StatusCode = 500
                };
                context.ExceptionHandled = true;
                break;
        }
    }
}
