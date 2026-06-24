using System.ComponentModel.DataAnnotations;
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
    private readonly ICurrentUserAccessor _currentUserAccessor;

    public AuthController(AuthService authService, ICurrentUserAccessor currentUserAccessor)
    {
        _authService = authService;
        _currentUserAccessor = currentUserAccessor;
    }

    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody, Required] RegisterRequest request)
    {
        return this.OkDataOrBadRequest(await _authService.RegisterAsync(request));
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody, Required] LoginRequest request)
    {
        var (response, error) = await _authService.LoginAsync(request);

        if (error != null)
        {
            // Return 401 Unauthorized for authentication failures
            return Unauthorized(error);
        }

        return Ok(new { data = response });
    }

    [HttpPost("invites")]
    [Authorize]
    [ValidateUser]
    public async Task<IActionResult> CreateInvite([FromBody, Required] CreateInviteRequest request)
    {
        var userId = _currentUserAccessor.GetValidatedUserId();
        return this.OkDataOrBadRequest(await _authService.CreateInviteAsync(userId, request));
    }

    [HttpPost("refresh")]
    public async Task<IActionResult> RefreshToken([FromBody, Required] RefreshTokenRequest request)
    {
        if (string.IsNullOrWhiteSpace(request.RefreshToken))
        {
            return BadRequest(new ErrorResponse("Refresh token is required", "INVALID_REFRESH_TOKEN"));
        }

        return this.OkDataOrBadRequest(await _authService.RefreshTokenAsync(request.RefreshToken));
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

        var userId = _currentUserAccessor.GetValidatedUserId();
        return this.OkDataOrBadRequest(await _authService.LogoutAsync(userId, request.RefreshToken));
    }
}
