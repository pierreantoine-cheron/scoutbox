using System.Security.Claims;
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
    private readonly ILogger<AuthController> _logger;

    public AuthController(AuthService authService, ILogger<AuthController> logger)
    {
        _authService = authService;
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
            var userIdClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
            if (userIdClaim == null || !Guid.TryParse(userIdClaim, out var userId))
            {
                return Unauthorized(new ErrorResponse("Unauthorized user", "UNAUTHORIZED"));
            }

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
}
