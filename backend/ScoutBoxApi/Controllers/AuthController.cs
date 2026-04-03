using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Controllers;

[Route("api/auth")]
[ApiController]
[EnableRateLimiting("auth")]
public class AuthController : ControllerBase
{
    private readonly AuthService _authService;
    private readonly ICurrentUserAccessor _currentUserAccessor;
    private readonly ILogger<AuthController> _logger;

    public AuthController(AuthService authService, ICurrentUserAccessor currentUserAccessor, ILogger<AuthController> logger)
    {
        _authService = authService;
        _currentUserAccessor = currentUserAccessor;
        _logger = logger;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        try
        {
            var (response, error) = await _authService.RegisterAsync(request);

            if (error != null)
            {
                return BadRequest(error);
            }

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during user registration");
            return StatusCode(500, new ErrorResponse("An error occurred during registration", "INTERNAL_ERROR"));
        }
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        try
        {
            var (response, error) = await _authService.LoginAsync(request);

            if (error != null)
            {
                // Return 401 Unauthorized for authentication failures
                return Unauthorized(error);
            }

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during user login");
            return StatusCode(500, new ErrorResponse("An error occurred during login", "INTERNAL_ERROR"));
        }
    }

    [HttpPost("invites")]
    [Authorize]
    public async Task<IActionResult> CreateInvite([FromBody] CreateInviteRequest request)
    {
        try
        {
            // Use the current user accessor for standardized identity validation
            var identityError = _currentUserAccessor.ValidateCurrentUserIdentity();
            if (identityError != null)
            {
                return Unauthorized(identityError);
            }

            var userId = _currentUserAccessor.GetCurrentUserId()!.Value;

            var (response, error) = await _authService.CreateInviteAsync(userId, request);

            if (error != null)
            {
                return BadRequest(error);
            }

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error creating invite");
            return StatusCode(500, new ErrorResponse("Error during invite creation", "INTERNAL_ERROR"));
        }
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        try
        {
            var (response, error) = await _authService.RefreshTokenAsync(request.RefreshToken);

            if (error != null)
            {
                return BadRequest(error);
            }

            return Ok(response);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error refreshing token");
            return StatusCode(500, new ErrorResponse("Error while refreshing token", "INTERNAL_ERROR"));
        }
    }

    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout([FromBody] LogoutRequest? request)
    {
        try
        {
            if (request == null)
            {
                return BadRequest(new ErrorResponse("Refresh token is required", "INVALID_REFRESH_TOKEN"));
            }

            // Validate current user identity
            var identityError = _currentUserAccessor.ValidateCurrentUserIdentity();
            if (identityError != null)
            {
                return Unauthorized(identityError);
            }

            var userId = _currentUserAccessor.GetCurrentUserId()!.Value;

            var (response, error) = await _authService.LogoutAsync(userId, request.RefreshToken);

            if (error != null)
            {
                // Return 400 for validation errors (e.g., missing refresh token)
                // The client should still perform local cleanup
                return BadRequest(error);
            }

            return Ok(new { data = response });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error during logout");
            // Even on server error, client should perform local cleanup
            // Return 500 with error details but client must not treat this as "stay logged in"
            return StatusCode(500, new ErrorResponse("Error during logout processing", "INTERNAL_ERROR"));
        }
    }
}
