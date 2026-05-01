using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using ScoutBoxApi.Filters;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Services;

namespace ScoutBoxApi.Controllers;

[Route("api/auth")]
[ApiController]
[EnableRateLimiting("auth")]
public class AuthController : ControllerBase
{
    private readonly AuthService _authService;

    public AuthController(AuthService authService)
    {
        _authService = authService;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterRequest request)
    {
        return this.OkOrBadRequest(await _authService.RegisterAsync(request));
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
    [ValidateUser]
    public async Task<IActionResult> CreateInvite([FromBody] CreateInviteRequest request)
    {
        var userId = HttpContext.GetUserId();
        return this.OkOrBadRequest(await _authService.CreateInviteAsync(userId, request));
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> RefreshToken([FromBody] RefreshTokenRequest request)
    {
        return this.OkOrBadRequest(await _authService.RefreshTokenAsync(request.RefreshToken));
    }

    [HttpPost("logout")]
    [Authorize]
    [ValidateUser]
    public async Task<IActionResult> Logout([FromBody] LogoutRequest? request)
    {
        if (request == null)
        {
            return BadRequest(new ErrorResponse("Refresh token is required", "INVALID_REFRESH_TOKEN"));
        }

        var userId = HttpContext.GetUserId();
        return this.OkOrBadRequest(await _authService.LogoutAsync(userId, request.RefreshToken));
    }
}
