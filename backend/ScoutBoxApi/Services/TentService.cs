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
    private readonly IAuditService _auditService;
    private readonly ILogger<TentService> _logger;

    public TentService(ScoutBoxDbContext db, IAuditService auditService, ILogger<TentService> logger)
    {
        _db = db;
        _auditService = auditService;
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

    public async Task<IReadOnlyList<TentDto>> GetTentsAsync()
    {
        return await (
            from tent in _db.Tents.AsNoTracking()
            join shape in _db.TentShapes.AsNoTracking() on tent.TentShapeId equals shape.Id into shapeJoin
            from shape in shapeJoin.DefaultIfEmpty()
            orderby tent.UpdatedAt descending, tent.CreatedAt descending, tent.Id descending
            select new TentDto(
                tent.Id,
                tent.Name,
                tent.Size,
                tent.TentShapeId,
                shape != null ? shape.Name : null,
                tent.OverallState.ToString(),
                tent.Comments,
                tent.CreatedAt,
                tent.UpdatedAt,
                Array.Empty<PartDto>()
            )
        ).ToListAsync();
    }

    public async Task<TentDto?> GetTentByIdAsync(Guid id)
    {
        var tent = await _db.Tents
            .AsNoTracking()
            .Include(t => t.TentShape)
            .Include(t => t.Parts)
                .ThenInclude(p => p.PartKind)
            .FirstOrDefaultAsync(t => t.Id == id);

        if (tent == null)
        {
            return null;
        }

        var partDtos = tent.Parts
            .OrderBy(p => p.PartKind.DisplayOrder)
            .ThenBy(p => p.PartKindId)
            .Select(p => new PartDto(
                p.Id,
                p.PartKindId,
                p.PartKind.Name,
                p.PartKind.DisplayOrder,
                p.State.ToString(),
                p.Comments,
                p.CreatedAt,
                p.UpdatedAt
            ))
            .ToList();

        return new TentDto(
            tent.Id,
            tent.Name,
            tent.Size,
            tent.TentShapeId,
            tent.TentShape.Name,
            tent.OverallState.ToString(),
            tent.Comments,
            tent.CreatedAt,
            tent.UpdatedAt,
            partDtos
        );
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

        var shape = await _db.TentShapes
            .Include(s => s.TentShapeParts)
                .ThenInclude(sp => sp.PartKind)
            .Where(shape => shape.Id == request.TentShapeId && shape.IsActive)
            .FirstOrDefaultAsync();

        if (shape == null)
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

        await using var transaction = await _db.Database.BeginTransactionAsync();

        try
        {
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

            var orderedShapeParts = shape.TentShapeParts
                .OrderBy(sp => sp.PartKind.DisplayOrder)
                .ThenBy(sp => sp.PartKindId)
                .ToList();

            var createdParts = new List<Part>(orderedShapeParts.Count);

            foreach (var shapePart in orderedShapeParts)
            {
                var part = new Part
                {
                    Id = Guid.NewGuid(),
                    TentId = tent.Id,
                    PartKindId = shapePart.PartKindId,
                    State = PartState.Good,
                    Comments = null,
                    CreatedAt = now,
                    UpdatedAt = now,
                    CreatedByUserId = userId,
                    UpdatedByUserId = userId
                };
                _db.Parts.Add(part);
                createdParts.Add(part);
            }

            try
            {
                await _db.SaveChangesAsync();
            }
            catch (DbUpdateException ex) when (IsDuplicateTentNameViolation(ex))
            {
                await transaction.RollbackAsync();
                _logger.LogWarning(ex, "Duplicate tent name blocked by DB constraint: {TentName}", normalizedName);
                return (null, new ErrorResponse("Tent name already exists", "TENT_NAME_EXISTS"));
            }

            await transaction.CommitAsync();

            var partDtos = createdParts
                .OrderBy(p => p.PartKind.DisplayOrder)
                .ThenBy(p => p.PartKindId)
                .Select(p => new PartDto(
                    p.Id,
                    p.PartKindId,
                    p.PartKind.Name,
                    p.PartKind.DisplayOrder,
                    p.State.ToString(),
                    p.Comments,
                    p.CreatedAt,
                    p.UpdatedAt
                ))
                .ToList();

            var dto = new TentDto(
                tent.Id,
                tent.Name,
                tent.Size,
                tent.TentShapeId,
                shape.Name,
                tent.OverallState.ToString(),
                tent.Comments,
                tent.CreatedAt,
                tent.UpdatedAt,
                partDtos
            );

            return (dto, null);
        }
        catch (Exception ex)
        {
            await transaction.RollbackAsync();
            _logger.LogError(ex, "Failed to create tent {TentName} with shape {TentShapeId} for user {UserId}", normalizedName, request.TentShapeId, userId);
            throw;
        }
    }

    public async Task<(TentDto? Response, ErrorResponse? Error, bool NotFound)> UpdateTentAsync(Guid id, Guid userId, UpdateTentRequest request)
    {
        var rawName = request.Name ?? string.Empty;
        var normalizedName = rawName.Trim();

        if (string.IsNullOrWhiteSpace(normalizedName))
        {
            return (null, new ErrorResponse("Tent name is required", "TENT_NAME_REQUIRED"), false);
        }

        if (rawName.Length > MaxTentNameLength)
        {
            return (null, new ErrorResponse("Tent name exceeds maximum length", "TENT_UPDATE_FAILED"), false);
        }

        if (request.Size <= 0 || request.Size > MaxTentSize)
        {
            return (null, new ErrorResponse("Tent size must be between 1 and 100", "INVALID_TENT_SIZE"), false);
        }

        if (!Enum.TryParse<TentOverallState>(request.OverallState, true, out var overallState)
            || !Enum.IsDefined(overallState))
        {
            return (null, new ErrorResponse("Tent overall state is invalid", "INVALID_TENT_STATE"), false);
        }

        if (request.Comments != null && request.Comments.Length > MaxTentCommentsLength)
        {
            return (null, new ErrorResponse("Tent comments exceed maximum length", "TENT_UPDATE_FAILED"), false);
        }

        var tent = await _db.Tents
            .Include(t => t.TentShape)
            .Include(t => t.Parts)
                .ThenInclude(p => p.PartKind)
            .FirstOrDefaultAsync(t => t.Id == id);

        if (tent == null)
        {
            return (null, null, true);
        }

        var hasDuplicateName = await _db.Tents
            .AnyAsync(t => t.Name.ToLower() == normalizedName.ToLower() && t.Id != id);

        if (hasDuplicateName)
        {
            return (null, new ErrorResponse("Tent name already exists", "TENT_NAME_EXISTS"), false);
        }

        var oldName = tent.Name;
        var oldSize = tent.Size;
        var oldOverallState = tent.OverallState;
        var oldComments = tent.Comments;

        var now = DateTime.UtcNow;
        tent.Name = normalizedName;
        tent.Size = request.Size;
        tent.OverallState = overallState;
        tent.Comments = string.IsNullOrWhiteSpace(request.Comments) ? null : request.Comments.Trim();
        tent.UpdatedAt = now;
        tent.UpdatedByUserId = userId;

        var changedFields = new List<string>();
        if (oldName != tent.Name) changedFields.Add("name");
        if (oldSize != tent.Size) changedFields.Add("size");
        if (oldOverallState != tent.OverallState) changedFields.Add("overallState");
        var commentsChanged = oldComments != tent.Comments;
        if (commentsChanged) changedFields.Add("comments");

        if (changedFields.Count > 0)
        {
            _auditService.RecordEvent(
                AuditActions.TentUpdated,
                userId,
                targetEntityType: "Tent",
                targetEntityId: id,
                metadata: new Dictionary<string, object?>
                {
                    ["changedFields"] = changedFields,
                    ["oldName"] = oldName,
                    ["newName"] = tent.Name,
                    ["oldSize"] = oldSize,
                    ["newSize"] = tent.Size,
                    ["oldOverallState"] = oldOverallState.ToString(),
                    ["newOverallState"] = tent.OverallState.ToString(),
                    ["commentsChanged"] = commentsChanged
                }
            );
        }

        try
        {
            await _db.SaveChangesAsync();
        }
        catch (DbUpdateException ex) when (IsDuplicateTentNameViolation(ex))
        {
            _logger.LogWarning(ex, "Duplicate tent name blocked by DB constraint on update: {TentName}", normalizedName);
            return (null, new ErrorResponse("Tent name already exists", "TENT_NAME_EXISTS"), false);
        }

        var partDtos = tent.Parts
            .OrderBy(p => p.PartKind.DisplayOrder)
            .ThenBy(p => p.PartKindId)
            .Select(p => new PartDto(
                p.Id,
                p.PartKindId,
                p.PartKind.Name,
                p.PartKind.DisplayOrder,
                p.State.ToString(),
                p.Comments,
                p.CreatedAt,
                p.UpdatedAt
            ))
            .ToList();

        var dto = new TentDto(
            tent.Id,
            tent.Name,
            tent.Size,
            tent.TentShapeId,
            tent.TentShape.Name,
            tent.OverallState.ToString(),
            tent.Comments,
            tent.CreatedAt,
            tent.UpdatedAt,
            partDtos
        );

        return (dto, null, false);
    }

    private static bool IsDuplicateTentNameViolation(DbUpdateException exception)
    {
        var message = exception.InnerException?.Message ?? exception.Message;
        return message.Contains("UNIQUE constraint failed", StringComparison.OrdinalIgnoreCase)
            && message.Contains("Tents.Name", StringComparison.OrdinalIgnoreCase);
    }
}
