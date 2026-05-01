using System.ComponentModel.DataAnnotations;

namespace ScoutBoxApi.Models.DTOs;

public record RegisterRequest(
    [Required(ErrorMessage = "Invite code is required")]
    [StringLength(64, MinimumLength = 1, ErrorMessage = "Invite code must be between 1 and 64 characters")]
    string InviteCode,

    [Required(ErrorMessage = "Username is required")]
    [StringLength(50, MinimumLength = 1, ErrorMessage = "Username must be between 1 and 50 characters")]
    string Username,

    [Required(ErrorMessage = "Password is required")]
    [StringLength(100, MinimumLength = 1, ErrorMessage = "Password is required")]
    string Password);
