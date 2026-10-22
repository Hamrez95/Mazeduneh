using System.Net;
using System.Text;

public static class InvoiceRenderer
{
    public static string Render(CheckoutOrder order) => CustomerInvoice.Render(order);
}

public static class PackingSlipRenderer
{
    public static string Render(CheckoutOrder order)
    {
        static string E(object? value) => WebUtility.HtmlEncode(value?.ToString() ?? string.Empty);
        var rows = new StringBuilder();
        foreach (var line in order.Lines)
            rows.Append("<tr><td><strong>" + E(line.ProductTitle) + "</strong><br><span>" + E(line.Sku) + " · " + E(line.VariantLabel) + "</span></td><td class=\"check\">□</td><td>" + E(line.Quantity) + "</td></tr>");

        var html = """
            <!doctype html>
            <html lang="fa" dir="rtl">
            <head>
              <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
              <title>برگه بسته‌بندی مزه‌دونه - __ORDER_ID__</title>
              <style>
                :root { font-family: Tahoma, Arial, sans-serif; color:#19352c; }
                body { margin:0; background:#f6f8f3; } .sheet { max-width:760px; margin:32px auto; padding:32px; background:#fff; border:1px solid #dfe8df; border-radius:20px; }
                header { display:flex; justify-content:space-between; gap:20px; border-bottom:3px solid #31584a; padding-bottom:18px; } .brand { color:#31584a; font-size:25px; font-weight:900; }
                .muted { color:#718078; font-size:13px; line-height:1.8; } h1 { margin:22px 0 6px; font-size:23px; } .meta { display:grid; grid-template-columns:repeat(2,1fr); gap:10px; margin:20px 0; }
                .meta div { background:#f1f6f0; border-radius:12px; padding:11px; } .meta b { display:block; margin-top:4px; } table { width:100%; border-collapse:collapse; margin-top:18px; }
                th,td { text-align:right; padding:14px 10px; border-bottom:1px solid #e5ece4; } th { color:#718078; font-size:12px; } .check { width:52px; font-size:28px; text-align:center; }
                .hint { margin-top:22px; padding:14px; background:#fff5df; border:1px solid #f0d69a; border-radius:12px; } .print { display:inline-block; margin-top:22px; padding:12px 18px; border-radius:12px; background:#31584a; color:#fff; text-decoration:none; }
                @media print { body,.sheet { background:#fff; } .sheet { margin:0; max-width:none; border:0; border-radius:0; } .print { display:none; } } @media(max-width:620px) { .sheet { margin:0; padding:20px; border-radius:0; } header { display:block; } .meta { grid-template-columns:1fr; } th,td { padding:10px 5px; font-size:12px; } }
              </style>
            </head>
            <body><main class="sheet">
              <header><div><div class="brand">مزه‌دونه</div><div class="muted">برگهٔ جمع‌آوری و بسته‌بندی سفارش</div></div><div class="muted">شماره سفارش<br><b dir="ltr">__ORDER_ID__</b></div></header>
              <h1>اقلامی که باید جمع‌آوری شوند</h1><div class="muted">هر قلم را پس از برداشتن علامت بزنید. ترتیب برداشت با تاریخ نزدیک‌تر انجام شود.</div>
              <section class="meta"><div><span class="muted">مشتری</span><b>__CUSTOMER__</b></div><div><span class="muted">شهر</span><b>__CITY__</b></div><div><span class="muted">نشانی</span><b>__ADDRESS__</b></div><div><span class="muted">روش ارسال</span><b>__SHIPPING_METHOD__</b></div></section>
              <table><thead><tr><th>محصول و SKU</th><th class="check">برداشت</th><th>تعداد</th></tr></thead><tbody>__ROWS__</tbody></table>
              <div class="hint"><strong>کنترل نهایی:</strong> تعداد اقلام، سلامت بسته و آدرس گیرنده را پیش از تحویل به شرکت حمل بررسی کنید.</div>
              <a class="print" href="#" onclick="window.print();return false">چاپ برگه / ذخیره به PDF</a>
            </main></body></html>
            """;
        return html
            .Replace("__ORDER_ID__", E(order.Id))
            .Replace("__CUSTOMER__", E(order.CustomerName))
            .Replace("__CITY__", E(order.Province + "، " + order.City))
            .Replace("__ADDRESS__", E(order.Address))
            .Replace("__SHIPPING_METHOD__", E(order.ShippingMethod))
            .Replace("__ROWS__", rows.ToString());
    }
}
