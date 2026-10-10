/// <summary>Common server-side contact policy for all admin response projections.</summary>
public static class CustomerPrivacy
{
    public const string Hidden = "مخفی بر اساس نقش";
    public static string AnonymousName(Guid id) => $"مشتری {id.ToString("N")[..6]}";
    public static bool CanReadPii(HttpContext context) =>
        context.Items["AdminPrincipal"] is AdminPrincipal principal &&
        AdminPermissionCatalog.Allows(principal, AdminPermissionCatalog.CustomersPiiRead);
}

public static class OrderPrivacy
{
    public static AdminOrderSummary Project(AdminOrderSummary row, HttpContext context) => CustomerPrivacy.CanReadPii(context) ? row : row with
    {
        CustomerName = CustomerPrivacy.AnonymousName(row.Id), Mobile = CustomerPrivacy.Hidden,
        Province = CustomerPrivacy.Hidden, City = CustomerPrivacy.Hidden, PaymentReference = null
    };

    public static AdminOrderDetail Project(AdminOrderDetail row, HttpContext context) => CustomerPrivacy.CanReadPii(context) ? row : row with
    {
        Summary = Project(row.Summary, context), Address = CustomerPrivacy.Hidden, PostalCode = CustomerPrivacy.Hidden,
        ShippingCarrier = null, TrackingCode = null,
        Notes = Array.Empty<AdminOrderNote>(),
        Transitions = row.Transitions.Select(item => item with { Actor = CustomerPrivacy.Hidden, Reason = CustomerPrivacy.Hidden }).ToArray(),
        Payment = row.Payment is null ? null : row.Payment with { Reference = null }
    };

    public static AdminOverdueShipment Project(AdminOverdueShipment row, HttpContext context) => CustomerPrivacy.CanReadPii(context) ? row : row with
    {
        CustomerName = CustomerPrivacy.AnonymousName(row.Id), Mobile = CustomerPrivacy.Hidden,
        Province = CustomerPrivacy.Hidden, City = CustomerPrivacy.Hidden, ShippingCarrier = null, TrackingCode = null
    };

    public static AdminOrderNote Project(AdminOrderNote row, HttpContext context) => CustomerPrivacy.CanReadPii(context) ? row : row with
    {
        Note = CustomerPrivacy.Hidden, Actor = CustomerPrivacy.Hidden
    };
}
