using System.Security.Claims;

namespace ScoutBoxApi.Services;

/// <summary>
/// Provides access to the current authenticated user's identity from the HTTP context.
/// </summary>
public interface ICurrentUserAccessor
{
    /// <summary>
    /// Gets the current user's ID from the JWT token's NameIdentifier claim.
    /// Returns null if the user is not authenticated or the claim is missing/invalid.
    /// </summary>
    Guid? GetCurrentUserId();

    /// <summary>
    /// Gets the current user's ID or throws an exception if not authenticated.
    /// Use this when the endpoint requires authentication and the user must exist.
    /// </summary>
    /// <returns>The authenticated user's ID</returns>
    /// <exception cref="UnauthorizedAccessException">Thrown when user is not authenticated</exception>
    Guid GetCurrentUserIdOrThrow();

    /// <summary>
    /// Gets the current user's username from the JWT token's Name claim.
    /// Returns null if the user is not authenticated or the claim is missing.
    /// </summary>
    string? GetCurrentUsername();

    /// <summary>
    /// Validates that the current user has a valid identity claim and returns the user ID.
    /// Throws UnauthorizedAccessException if the identity is invalid (combines ValidateCurrentUserIdentity + GetCurrentUserId).
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

    public Guid? GetCurrentUserId()
    {
        var user = _httpContextAccessor.HttpContext?.User;
        if (user?.Identity?.IsAuthenticated != true)
        {
            return null;
        }

        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (string.IsNullOrEmpty(userIdClaim) || !Guid.TryParse(userIdClaim, out var userId))
        {
            return null;
        }

        return userId;
    }

    public Guid GetCurrentUserIdOrThrow()
    {
        var userId = GetCurrentUserId();
        if (userId == null)
        {
            throw new UnauthorizedAccessException("User is not authenticated or has an invalid identity claim");
        }
        return userId.Value;
    }

    public string? GetCurrentUsername()
    {
        var user = _httpContextAccessor.HttpContext?.User;
        if (user?.Identity?.IsAuthenticated != true)
        {
            return null;
        }

        return user.FindFirst(ClaimTypes.Name)?.Value;
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
