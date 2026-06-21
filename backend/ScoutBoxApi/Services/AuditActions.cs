namespace ScoutBoxApi.Services;

/// <summary>
/// Canonical action names for audit events.
/// Use these constants to ensure consistency across the application.
/// Future stories must extend this contract rather than inventing ad hoc action labels.
/// </summary>
public static class AuditActions
{
    // Invite management actions
    public const string InviteCreated = "invite_created";
    public const string InviteRevoked = "invite_revoked";

    // User authentication actions
    public const string UserRegisteredFromInvite = "user_registered_from_invite";
    public const string UserLoginSucceeded = "user_login_succeeded";
    public const string UserRefreshTokenRotated = "user_refresh_token_rotated";
    public const string UserLogoutSucceeded = "user_logout_succeeded";

    // Tent management actions (for future stories)
    public const string TentCreated = "tent_created";
    public const string TentUpdated = "tent_updated";
    public const string TentArchived = "tent_archived";
    public const string TentUnarchived = "tent_unarchived";

    // Part management actions (for future stories)
    public const string PartStateChanged = "part_state_changed";
    public const string PartCommentsChanged = "part_comments_changed";
    public const string PartAdded = "part_added";
    public const string PartDeleted = "part_deleted";
    public const string PartRemoved = "part_removed";

    // Photo management actions (for future stories)
    public const string PhotoUploaded = "photo_uploaded";
    public const string PhotoDeleted = "photo_deleted";

    // Tag management actions (for future stories)
    public const string TagCreated = "tag_created";
    public const string TagRenamed = "tag_renamed";
    public const string TagDeleted = "tag_deleted";
    public const string TagAssigned = "tag_assigned";
    public const string TagRemoved = "tag_removed";
}
