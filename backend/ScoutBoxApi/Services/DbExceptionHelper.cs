using Microsoft.EntityFrameworkCore;

namespace ScoutBoxApi.Services;

public static class DbExceptionHelper
{
    public static bool IsConstraintViolation(DbUpdateException exception, params string[] substrings)
    {
        var message = exception.InnerException?.Message ?? exception.Message;
        return substrings.All(s => message.Contains(s, StringComparison.OrdinalIgnoreCase));
    }

    public static bool IsAnyConstraintViolation(DbUpdateException exception, params string[] substrings)
    {
        var message = exception.InnerException?.Message ?? exception.Message;
        return substrings.Any(s => message.Contains(s, StringComparison.OrdinalIgnoreCase));
    }
}
