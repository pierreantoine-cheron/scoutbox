using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.Extensions.DependencyInjection;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Filters;

[AttributeUsage(AttributeTargets.Method | AttributeTargets.Class)]
public class ValidateUserAttribute : ActionFilterAttribute
{
    public override void OnActionExecuting(ActionExecutingContext context)
    {
        try
        {
            var currentUserAccessor = context.HttpContext.RequestServices.GetRequiredService<ICurrentUserAccessor>();
            var userId = currentUserAccessor.GetValidatedUserId();
            context.HttpContext.Items["CurrentUserId"] = userId;
        }
        catch (UnauthorizedAccessException)
        {
            context.Result = new UnauthorizedObjectResult(
                new ErrorResponse("Authentication required", "AUTH_INVALID_TOKEN"));
        }
    }
}
