using System.Net;

internal static class InvoiceFixture
{
    public static void Run()
    {
        static void Check(bool condition, string message) { if (!condition) throw new Exception(message); }
        var created = new DateTimeOffset(2026, 10, 22, 21, 0, 0, TimeSpan.Zero);
        var order = new CheckoutOrder(Guid.Parse("2a306b34-f031-f83a-92b5-026cb57bce63"), "secret-receipt-token", "سارا رضایی", "09120000000",
            "تهران", "تهران", "private-address", "1234567890", "IRR",
            [new("کوکی پروتئینی", "COOKIE-250", "۲۵۰ گرم", 1, 2000001, 2000001, 1234567), new("کوکی پروتئینی", "COOKIE-500", "۵۰۰ گرم", 1, 3800000, 3800000)],
            "post", 5800001, 750000, 320000, 500000, 0, 0, 6050001, OrderState.Paid, created, created.AddMinutes(20), []);
        var html = InvoiceRenderer.Render(order);
        var decoded = WebUtility.HtmlDecode(html);
        Check(decoded.Contains("۶۰۵,۰۰۰.۱") && decoded.Contains("۲۰۰,۰۰۰.۱") && decoded.Contains("۵۰,۰۰۰"), "Invoice rounded a fractional-toman amount or omitted the discount");
        Check(decoded.Contains("۱۴۰۵/۰۸/۰۱") && decoded.Contains("۰۰:۳۰"), "Invoice date did not use Jalali date at Tehran midnight");
        Check(decoded.Contains("مبلغ پرداخت‌شده") && decoded.Contains("ممنون از خرید و اعتمادت"), "Paid invoice omitted confirmation or appreciation");
        Check(html.Contains("data:font/ttf;base64,") && !html.Contains("@import") && !html.Contains("<link"), "Downloaded invoice depends on an external font");
        Check(!html.Contains(order.ReceiptToken) && !html.Contains(order.Mobile) && !html.Contains(order.Address), "Invoice leaked private contact, address or receipt token");
        var hostile = InvoiceRenderer.Render(order with { CustomerName = "<script>alert(1)</script> __ROWS__", Lines = [order.Lines.First() with { ProductTitle = "<img src=x onerror=alert(1)>", VariantLabel = "<b>unsafe</b>" }] });
        Check(!hostile.Contains("<script>") && !hostile.Contains("<img src=x") && !hostile.Contains("<b>unsafe</b>") && hostile.Contains("__ROWS__"), "Invoice interpreted customer content as markup or template tokens");
        foreach (var state in new[] { OrderState.AwaitingPayment, OrderState.Expired, OrderState.Cancelled })
        {
            var unpaid = InvoiceRenderer.Render(order with { State = state });
            Check(!unpaid.Contains("مبلغ پرداخت‌شده") && !unpaid.Contains("ممنون از خرید و اعتمادت"), "Unconfirmed invoice claimed successful payment");
        }
        var previewDirectory = Environment.GetEnvironmentVariable("MAZEDUNEH_INVOICE_PREVIEW_DIR");
        if (!string.IsNullOrWhiteSpace(previewDirectory))
        {
            Directory.CreateDirectory(previewDirectory);
            File.WriteAllText(Path.Combine(previewDirectory, "invoice-preview.html"), html);
            File.WriteAllText(Path.Combine(previewDirectory, "invoice-long-preview.html"), InvoiceRenderer.Render(order with { Lines = Enumerable.Range(1, 70).Select(i => order.Lines.First() with { ProductTitle = $"محصول نمونه {i}" }).ToArray() }));
        }
        Console.WriteLine("Invoice: exact money, discount, Jalali/Tehran date, embedded fonts, escaping, privacy and payment-state checks passed");
    }
}
