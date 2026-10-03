using System.Net;
using System.Text;

public static class InvoiceRenderer
{
    public static string Render(CheckoutOrder order)
    {
        static string E(object? value) => WebUtility.HtmlEncode(value?.ToString() ?? string.Empty);
        var rows = new StringBuilder();
        foreach (var line in order.Lines)
        {
            rows.Append("<tr><td>" + E(line.ProductTitle) + "</td><td>" + E(line.VariantLabel) + "</td><td>" +
                E(line.Quantity) + "</td><td>" + E(line.LineTotal.ToString("N0")) + " ریال</td></tr>");
        }

        var html = """
            <!doctype html>
            <html lang="fa" dir="rtl">
            <head>
              <meta charset="utf-8">
              <meta name="viewport" content="width=device-width,initial-scale=1">
              <title>فاکتور مزه‌دونه - __ORDER_ID__</title>
              <style>
                :root { color-scheme: light; font-family: Tahoma, Arial, sans-serif; }
                body { margin:0; background:#f6f8f3; color:#19352c; }
                .sheet { max-width:860px; margin:32px auto; padding:36px; background:#fffdf8; border:1px solid #dfe8df; border-radius:24px; box-shadow:0 18px 50px #19352c18; }
                header { display:flex; justify-content:space-between; align-items:flex-start; gap:24px; border-bottom:3px solid #31584a; padding-bottom:22px; }
                .brand { color:#31584a; font-size:28px; font-weight:900; } .muted { color:#718078; font-size:13px; line-height:1.8; }
                h1 { margin:0 0 8px; font-size:24px; } h2 { font-size:17px; margin:28px 0 12px; }
                .meta { display:grid; grid-template-columns:repeat(2,1fr); gap:8px; margin-top:22px; }
                .meta div { background:#f1f6f0; border-radius:12px; padding:11px; } .meta b { display:block; margin-top:4px; }
                table { width:100%; border-collapse:collapse; margin-top:12px; } th,td { text-align:right; padding:12px 10px; border-bottom:1px solid #e5ece4; } th { color:#718078; font-size:12px; }
                .summary { max-width:420px; margin:22px 0 0 auto; } .summary p { display:flex; justify-content:space-between; border-bottom:1px dashed #dce6dc; padding:8px 0; margin:0; } .total { font-size:18px; font-weight:900; color:#31584a; }
                .print { display:inline-block; margin-top:26px; padding:12px 18px; border-radius:12px; background:#31584a; color:#fff; text-decoration:none; }
                @media print { body,.sheet { background:#fff; } .sheet { margin:0; max-width:none; border:0; box-shadow:none; } .print { display:none; } }
                @media (max-width:620px) { .sheet { margin:0; padding:20px; border-radius:0; } header { display:block; } .meta { grid-template-columns:1fr; } th,td { padding:9px 5px; font-size:12px; } }
              </style>
            </head>
            <body><main class="sheet">
              <header><div><div class="brand">مزه‌دونه</div><div class="muted">دست‌چین لحظه‌های خوش · فاکتور فروش</div></div><div class="muted">شماره سفارش<br><b dir="ltr">__ORDER_ID__</b></div></header>
              <section class="meta">
                <div><span class="muted">خریدار</span><b>__CUSTOMER__</b></div>
                <div><span class="muted">روش ارسال</span><b>__SHIPPING_METHOD__</b></div>
                <div><span class="muted">شهر</span><b>__CITY__</b></div>
                <div><span class="muted">تاریخ ثبت</span><b dir="ltr">__CREATED_AT__ UTC</b></div>
              </section>
              <h2>اقلام سفارش</h2>
              <table><thead><tr><th>محصول</th><th>بسته</th><th>تعداد</th><th>مبلغ</th></tr></thead><tbody>__ROWS__</tbody></table>
              <section class="summary">
                <p><span>جمع کالاها</span><b>__SUBTOTAL__ ریال</b></p>
                <p><span>ارسال</span><b>__SHIPPING__ ریال</b></p>
                <p><span>مالیات (__TAX_RATE__٪)</span><b>__TAX__ ریال</b></p>
                <p class="total"><span>مبلغ قابل پرداخت</span><b>__PAYABLE__ ریال</b></p>
              </section>
              <p class="muted">این فاکتور بر اساس snapshot سفارش صادر شده و تغییرات بعدی تنظیمات قیمت‌گذاری روی آن اثر ندارد.</p>
              <a class="print" href="#" onclick="window.print();return false">چاپ / ذخیره به PDF</a>
            </main></body></html>
            """;
        return html
            .Replace("__ORDER_ID__", E(order.Id))
            .Replace("__CUSTOMER__", E(order.CustomerName))
            .Replace("__SHIPPING_METHOD__", E(order.ShippingMethod))
            .Replace("__CITY__", E(order.Province + "، " + order.City))
            .Replace("__CREATED_AT__", E(order.CreatedAt.ToString("yyyy-MM-dd HH:mm")))
            .Replace("__ROWS__", rows.ToString())
            .Replace("__SUBTOTAL__", E(order.Subtotal.ToString("N0")))
            .Replace("__SHIPPING__", E(order.Shipping.ToString("N0")))
            .Replace("__TAX_RATE__", E(order.TaxRatePercent.ToString("0.##")))
            .Replace("__TAX__", E(order.Tax.ToString("N0")))
            .Replace("__PAYABLE__", E(order.Payable.ToString("N0")));
    }
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
