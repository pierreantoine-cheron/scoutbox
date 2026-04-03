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

    public AuthController(AuthService authService, ICurrentUserAccessor currentUserAccessor)
    {
        _authService = authService;
        _currentUserAccessor = currentUserAccessor;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        var (response, error) = await _authService.RegisterAsync(request);

        if (error != null)
        {
            return BadRequest(error);
        }

        return Ok(response);
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginRequest request)
    {
        var (response, error) = await _authService.LoginAsync(request);

        if (error != null)
        {
            // Return 401 Unauthorized for authentication failures
            return Unauthorized(error);
        }

        return Ok(response);
    }

    [HttpPost("invites")]
    [Authorize]
    public async Task<IActionResult> CreateInvite([FromBody] CreateInviteRequest request)
    {
        var userId = _currentUserAccessor.GetValidatedUserId();

        var (response, error) = await _authService.CreateInviteAsync(userId, request);

        if (error != null)
        {
            return BadRequest(error);
        }

        return Ok(response);
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        var (response, error) = await _authService.RefreshTokenAsync(request.RefreshToken);

        if (error != null)
        {
            return BadRequest(error);
        }

        return Ok(response);
    }

    [HttpPost("logout")]
    [Authorize]
    public async Task<IActionResult> Logout([FromBody] LogoutRequest? request)
    {
        if (request == null)
        {
            return BadRequest(new ErrorResponse("Refresh token is required", "INVALID_REFRESH_TOKEN"));
        }

        var userId = _currentUserAccessor.GetValidatedUserId();

        var (response, error) = await _authService.LogoutAsync(userId, request.RefreshToken);

        if (error != null)
        {
            // Return 400 for validation errors (e.g., missing refresh token)
            // The client should still perform local cleanup
            return BadRequest(error);
        }

        return Ok(response);
    }
}
