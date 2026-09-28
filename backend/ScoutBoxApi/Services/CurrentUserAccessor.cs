using System.Security.Claims;

namespace ScoutBoxApi.Services;

/// <summary>
/// Provides access to the current authenticated user's identity from the HTTP context.
/// </summary>
public interface ICurrentUserAccessor
{
    /// <summary>
    /// Validates that the current user has a valid identity claim and returns the user ID.
    /// Throws UnauthorizedAccessException if the identity is invalid.
    /// </summary>
    /// <returns>The validated user ID</returns>
    /// <exception cref="UnauthorizedAccessException">Thrown when user is not authenticated or has invalid identity claim</exception>
    Guid GetValidatedUserId();
}

/// <summary>
/// Implementation of ICurrentUserAccessor that extracts identity from HTTP context claims.
/// </summary>
public class CurrentUserAccessor : ICurrentUserAccessor
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public CurrentUserAccessor(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    public Guid GetValidatedUserId()
    {
        var httpContext = _httpContextAccessor.HttpContext;
        if (httpContext?.User?.Identity?.IsAuthenticated != true)
        {
            throw new UnauthorizedAccessException("Authentication required");
        }

        var userIdClaim = httpContext.User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
        {
            throw new UnauthorizedAccessException("Invalid identity claim in token");
        }

        return userId;
    }
}
