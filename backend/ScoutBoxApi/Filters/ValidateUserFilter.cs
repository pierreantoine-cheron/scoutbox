using System.Security.Claims;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using ScoutBoxApi.Models.DTOs;

namespace ScoutBoxApi.Filters;

[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class)]
public class ValidateUserAttribute : ActionFilterAttribute
{
    public override void OnActionExecuting(ActionExecutingContext context)
    {
        try
        {
            var userId = context.HttpContext.GetUserId(skipCheck: false);
            context.HttpContext.Items["CurrentUserId"] = userId;
        }
        catch (UnauthorizedAccessException)
        {
            context.Result = new UnauthorizedObjectResult(
                new ErrorResponse("Authentication required", "AUTH_INVALID_TOKEN"));
        }
    }
}

public static class HttpContextExtensions
{
    public static Guid GetUserId(this HttpContext context, bool skipCheck = true)
    {
        if (context == null)
        {
            throw new UnauthorizedAccessException("Authentication required");
        }

        if (skipCheck && context.Items.TryGetValue("CurrentUserId", out var cached) && cached is Guid userId)
        {
            return userId;
        }

        var user = context.User;
        if (user == null || user.Identity?.IsAuthenticated != true)
        {
            throw new UnauthorizedAccessException("Authentication required");
        }

        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var id))
        {
            throw new UnauthorizedAccessException("Invalid identity claim in token");
        }

        return id;
    }
}
