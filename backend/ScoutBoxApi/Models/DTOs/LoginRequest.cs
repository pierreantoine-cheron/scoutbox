using System.ComponentModel.DataAnnotations;

namespace ScoutBoxApi.Models.DTOs;

public record LoginRequest(
    [Required(AllowEmptyStrings = false, ErrorMessage = "Username is required")]
    [StringLength(50, MinimumLength = 1, ErrorMessage = "Username must be between 1 and 50 characters")]
    [RegularExpression(@".*\S.*", ErrorMessage = "Username is required")]
    string Username,

    [Required(AllowEmptyStrings = false, ErrorMessage = "Password is required")]
    [StringLength(100, MinimumLength = 1, ErrorMessage = "Password is required")]
    [RegularExpression(@".*\S.*", ErrorMessage = "Password is required")]
    string Password
);
