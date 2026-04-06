using Microsoft.EntityFrameworkCore;
using ScoutBoxApi.Data;
using ScoutBoxApi.Models.DTOs;
using ScoutBoxApi.Models.Entities;

namespace ScoutBoxApi.Services;

public class TentService
{
    private const int MaxTentNameLength = 100;
    private const int MaxTentCommentsLength = 500;
    private const int MaxTentSize = 100;

    private readonly ScoutBoxDbContext _db;
    private readonly ILogger<TentService> _logger;

    public TentService(ScoutBoxDbContext db, ILogger<TentService> logger)
    {
        _db = db;
        _logger = logger;
    }

    public async Task<IReadOnlyList<TentShapeDto>> GetActiveShapesAsync()
    {
        return await _db.TentShapes
            .AsNoTracking()
            .Where(shape => shape.IsActive)
            .OrderBy(shape => shape.DisplayOrder)
            .Select(shape => new TentShapeDto(shape.Id, shape.Name, shape.DisplayOrder, shape.IsActive))
            .ToListAsync();
    }

    public async Task<(TentDto? Response, ErrorResponse? Error)> CreateTentAsync(Guid userId, CreateTentRequest request)
    {
        var rawName = request.Name ?? string.Empty;
        var normalizedName = rawName.Trim();

        if (string.IsNullOrWhiteSpace(normalizedName))
        {
            return (null, new ErrorResponse("Tent name is required", "TENT_NAME_REQUIRED"));
        }

        if (rawName.Length > MaxTentNameLength)
        {
            return (null, new ErrorResponse("Tent name exceeds maximum length", "TENT_CREATE_FAILED"));
        }

        if (request.Size <= 0)
        {
            return (null, new ErrorResponse("Tent size must be a positive integer", "INVALID_TENT_SIZE"));
        }

        if (request.Size > MaxTentSize)
        {
            return (null, new ErrorResponse("Tent size exceeds maximum allowed value", "INVALID_TENT_SIZE"));
        }

        if (request.Comments != null && request.Comments.Length > MaxTentCommentsLength)
        {
            return (null, new ErrorResponse("Tent comments exceed maximum length", "TENT_CREATE_FAILED"));
        }

        var hasShape = await _db.TentShapes
            .AnyAsync(shape => shape.Id == request.TentShapeId && shape.IsActive);

        if (!hasShape)
        {
            return (null, new ErrorResponse("Tent shape does not exist", "INVALID_TENT_SHAPE"));
        }

        var hasDuplicateName = await _db.Tents
            .AnyAsync(tent => tent.Name.ToLower() == normalizedName.ToLower());

        if (hasDuplicateName)
        {
            return (null, new ErrorResponse("Tent name already exists", "TENT_NAME_EXISTS"));
        }

        if (!Enum.TryParse<TentOverallState>(request.OverallState, true, out var overallState)
            || !Enum.IsDefined(overallState))
        {
            return (null, new ErrorResponse("Tent overall state is invalid", "INVALID_TENT_STATE"));
        }

        var now = DateTime.UtcNow;
        var tent = new Tent
        {
            Id = Guid.NewGuid(),
            Name = normalizedName,
            Size = request.Size,
            TentShapeId = request.TentShapeId,
            OverallState = overallState,
            Comments = string.IsNullOrWhiteSpace(request.Comments) ? null : request.Comments.Trim(),
            CreatedAt = now,
            UpdatedAt = now,
            CreatedByUserId = userId,
            UpdatedByUserId = userId
        };

        _db.Tents.Add(tent);

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateConcurrencyException ex)
        {
            _logger.LogError(ex, "Tent creation failed due to a concurrency conflict for {TentName}", normalizedName);
            return (null, new ErrorResponse("Failed to create tent", "TENT_CREATE_FAILED"));
        }
        catch (DbUpdateException ex) when (IsDuplicateTentNameViolation(ex))
        {
            _logger.LogWarning(ex, "Duplicate tent name blocked by DB constraint: {TentName}", normalizedName);
            return (null, new ErrorResponse("Tent name already exists", "TENT_NAME_EXISTS"));
        }
        catch (DbUpdateException ex)
        {
            _logger.LogError(ex, "Tent creation failed due to database error for {TentName}", normalizedName);
            return (null, new ErrorResponse("Failed to create tent", "TENT_CREATE_FAILED"));
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to create tent {TentName}", normalizedName);
            return (null, new ErrorResponse("Failed to create tent", "TENT_CREATE_FAILED"));
        }

        var dto = new TentDto(
            tent.Id,
            tent.Name,
            tent.Size,
            tent.TentShapeId,
            tent.OverallState.ToString(),
            tent.Comments,
            tent.CreatedAt,
            tent.UpdatedAt);

        return (dto, null);
    }

    private static bool IsDuplicateTentNameViolation(DbUpdateException exception)
    {
        var message = exception.InnerException?.Message ?? exception.Message;
        return message.Contains("UNIQUE constraint failed", StringComparison.OrdinalIgnoreCase)
            && message.Contains("Tents.Name", StringComparison.OrdinalIgnoreCase);
    }
}
