using System.ComponentModel.DataAnnotations;

namespace ScoutBoxApi.Models.DTOs;

[AttributeUsage(AttributeTargets.Property | AttributeTargets.Parameter)]
public sealed class TrimmedStringLengthAttribute : ValidationAttribute
{
    private readonly int _maximumLength;

    public TrimmedStringLengthAttribute(int maximumLength)
    {
        _maximumLength = maximumLength;
    }

    public int MinimumLength { get; set; }

    public override bool IsValid(object? value)
    {
        if (value == null)
        {
            return true;
        }

        if (value is not string text)
        {
            return false;
        }

        var length = text.Trim().Length;
        return length >= MinimumLength && length <= _maximumLength;
    }
}
