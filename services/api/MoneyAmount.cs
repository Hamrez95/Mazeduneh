/// <summary>All stored monetary values are rials, with at most two decimal places.
/// Reject values that PostgreSQL numeric(18,2) would silently round.</summary>
public static class MoneyAmount
{
    public static bool IsNonNegative(decimal amount) =>
        amount is >= 0 and <= 1_000_000_000_000m && amount == decimal.Round(amount, 2);
}
