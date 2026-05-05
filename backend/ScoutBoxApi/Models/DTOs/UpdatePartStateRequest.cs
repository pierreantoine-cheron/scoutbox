namespace ScoutBoxApi.Models.DTOs;

public class UpdatePartStateRequest
{
    private string? _comments;

    public string? State { get; set; }

    public string? Comments
    {
        get => _comments;
        set
        {
            HasComments = true;
            _comments = value;
        }
    }

    public bool HasComments { get; private set; }
}
