using Microsoft.AspNetCore.Mvc;
using ScoutBoxApi.Models.DTOs;

namespace ScoutBoxApi.Controllers;

public static class ControllerExtensions
{
    public static IActionResult OkOrBadRequest<T>(this ControllerBase controller, (T? Response, ErrorResponse? Error) result)
    {
        if (result.Error != null)
        {
            return controller.BadRequest(result.Error);
        }

        return controller.Ok(result.Response);
    }

    public static IActionResult OkDataOrBadRequest<T>(this ControllerBase controller, (T? Response, ErrorResponse? Error) result)
    {
        if (result.Error != null)
        {
            return controller.BadRequest(result.Error);
        }

        return controller.Ok(new { data = result.Response });
    }
}
