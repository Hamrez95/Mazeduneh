using System.Globalization;
using System.Net;
using System.Text;

// A self-contained document: downloaded HTML retains its fonts without network access.
public static class CustomerInvoice
{
    private static readonly Lazy<string> RegularFont = new(() => ReadBase64Resource("Invoice.Font.Regular"));
    private static readonly Lazy<string> BoldFont = new(() => ReadBase64Resource("Invoice.Font.Bold"));
    private static readonly Lazy<string> Brand = new(() => ReadBase64Resource("Invoice.Brand"));
    private static readonly Lazy<string> FontLicense = new(() => {
        using var stream = typeof(CustomerInvoice).Assembly.GetManifestResourceStream("Invoice.Font.License")!;
        using var reader = new StreamReader(stream);
        return reader.ReadToEnd();
    });
    private static readonly string[] ClosingLines = [
        "امیدواریم اولین لقمه، لبخند روی لبت بیاورد. نوش جان!",
        "این بسته بهانه‌ای است برای یک حال خوب؛ سهم خوشمزگی امروزت، نوش جان!",
        "برای وقت‌های چای، گپ و استراحتت، یک همراه خوشمزه انتخاب کردی. نوش جان!",
        "خوشحالیم مزه‌دونه مهمان لحظه‌های توست. به خوشی بخوری و لبخند بزنی!"
    ];

    public static string Render(CheckoutOrder order)
    {
        static string E(object? value) => WebUtility.HtmlEncode(value?.ToString() ?? string.Empty);
        static string Digits(string value) => string.Concat(value.Select(c => c is >= '0' and <= '9' ? (char)('۰' + c - '0') : c));
        static string Number(decimal value) => Digits(value.ToString("#,0.############################", CultureInfo.InvariantCulture));
        static string Money(decimal rials) => Number(rials / 10m) + " <small>تومان</small>";

        var confirmed = order.State is OrderState.Paid or OrderState.Preparing or OrderState.Shipped or OrderState.Delivered;
        var state = order.State switch
        {
            OrderState.Paid => "پرداخت تأییدشده",
            OrderState.Preparing => "در حال آماده‌سازی",
            OrderState.Shipped => "ارسال‌شده",
            OrderState.Delivered => "تحویل‌شده",
            OrderState.Cancelled => "لغوشده",
            OrderState.Expired => "مهلت پرداخت پایان‌یافته",
            _ => "در انتظار پرداخت"
        };
        var localDate = order.CreatedAt.ToOffset(TimeSpan.FromMinutes(210));
        var calendar = new PersianCalendar();
        var date = Digits($"{calendar.GetYear(localDate.DateTime):0000}/{calendar.GetMonth(localDate.DateTime):00}/{calendar.GetDayOfMonth(localDate.DateTime):00}");
        var time = Digits(localDate.ToString("HH:mm", CultureInfo.InvariantCulture));
        var shippingMethod = order.ShippingMethod switch { "post" => "پست", "courier" => "پیک فروشگاه", _ => order.ShippingMethod };
        var closing = confirmed
            ? ClosingLines[byte.Parse(order.Id.ToString("N")[..2], NumberStyles.HexNumber, CultureInfo.InvariantCulture) % ClosingLines.Length]
            : "هر وقت برای انتخاب خوشمزه‌ات آماده بودی، مزه‌دونه همین‌جاست.";
        var rows = new StringBuilder();
        var index = 0;
        foreach (var line in order.Lines)
        {
            rows.Append($"<tr><td class=\"row-number\">{Number(++index)}</td><td><strong>{E(Digits(line.ProductTitle))}</strong><span class=\"variant\">{E(Digits(line.VariantLabel))}</span></td><td class=\"numeric\">{Number(line.Quantity)}</td><td class=\"numeric\">{Money(line.UnitPrice)}</td><td class=\"numeric\"><strong>{Money(line.LineTotal)}</strong></td></tr>");
        }

        return $$$"""
            <!doctype html>
            <html lang="fa" dir="rtl">
            <head>
              <meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
              <title>فاکتور مزه‌دونه | {{{E(order.Id)}}}</title>
              <style>
                @font-face{font-family:Vazirmatn;src:url(data:font/ttf;base64,{{{RegularFont.Value}}}) format('truetype');font-weight:400;font-style:normal;font-display:swap}
                @font-face{font-family:Vazirmatn;src:url(data:font/ttf;base64,{{{BoldFont.Value}}}) format('truetype');font-weight:700 900;font-style:normal;font-display:swap}
                :root{color-scheme:light;font-family:Vazirmatn,Tahoma,sans-serif;color:#24483e;background:#f5f2eb}
                *{box-sizing:border-box}body{margin:0;line-height:1.8}h1,h2,p{margin:0}small{font-size:11px;font-weight:400}bdi{overflow-wrap:anywhere}
                .toolbar{max-width:920px;margin:24px auto 14px;display:flex;align-items:center;justify-content:space-between;gap:16px;padding:0 12px;font-size:12px;color:#5a6d64}
                button{font:inherit;font-weight:700;background:#155c49;color:white;border:0;border-radius:12px;min-height:44px;padding:10px 20px;cursor:pointer}button:focus-visible{outline:3px solid #c17c30;outline-offset:3px}
                .sheet{max-width:920px;margin:0 auto 32px;background:#fffefb;border:1px solid #e6e0d3;border-radius:24px;overflow:hidden;box-shadow:0 16px 60px #24483e10}
                header{display:flex;justify-content:space-between;gap:28px;padding:32px 36px;background:#eaf1e8;border-bottom:1px solid #d8e3d5}
                .brand{display:flex;gap:12px;align-items:center}.mark{width:48px;height:48px;flex:none}.brand-name{font-size:27px;font-weight:900;line-height:1.5}.tagline{font-size:11px;color:#596d60}
                .invoice-title{text-align:end}h1{font-size:21px}.status{display:inline-block;margin-top:8px;padding:4px 12px;border:1px solid #c7d9ce;border-radius:100px;background:white;font-size:11px}
                .body{padding:28px 36px}.reference{display:flex;justify-content:space-between;gap:20px;padding-bottom:20px;border-bottom:1px solid #e8e4da;font-size:12px}.label{display:block;font-size:11px;color:#64756c;margin-bottom:5px}.reference bdi{font-size:11px}
                .details{display:grid;grid-template-columns:1fr 1fr;gap:20px;margin:24px 0}.details section{padding:18px;border:1px solid #e8e4da;border-radius:14px}.details h2{font-size:12px;color:#64756c;margin-bottom:7px}.details strong{font-size:16px}.details p{font-size:12px;margin-top:5px;overflow-wrap:anywhere}
                h2{font-size:16px}.table-wrap{overflow-x:auto;margin-top:12px}table{width:100%;border-collapse:collapse;font-size:12px}th{text-align:start;padding:12px 9px;background:#f3f5ef;font-size:11px;font-weight:400;color:#596d60}td{padding:15px 9px;border-bottom:1px solid #eae7df;vertical-align:top}.row-number{color:#768379;width:32px}.variant{display:block;font-size:11px;color:#64756c;margin-top:3px}.numeric{white-space:nowrap;text-align:end}thead{display:table-header-group}tr{break-inside:avoid}
                .bottom{display:flex;gap:32px;align-items:flex-start;justify-content:space-between;margin-top:24px}.note{max-width:285px;font-size:12px;color:#64756c;padding-top:12px}.totals{width:340px;max-width:100%;margin-inline-start:auto}.totals p{display:flex;justify-content:space-between;gap:20px;padding:8px 0;font-size:12px}.discount{color:#207454}.total{margin-top:8px;padding:16px!important;border-radius:14px;background:#155c49;color:white;font-size:16px!important}.total b{white-space:nowrap}
                footer{margin-top:30px;text-align:center;padding:24px 20px;border-top:1px dashed #d5dece;background:#faf6eb;break-inside:avoid}footer strong{font-size:17px}footer p{margin:8px 0;font-size:13px}footer small{color:#64756c}
                @media print{header{padding:14px 0!important}.body{padding:14px 0!important}.reference{padding-bottom:14px}.details{margin:16px 0;gap:12px}.details section{padding:12px}th,td{padding:9px 7px}.bottom{margin-top:16px}.totals p{padding:5px 0}.total{padding:12px!important}footer{margin-top:18px;padding:16px}footer strong{font-size:15px}footer p{font-size:12px}}
                @page{size:A4;margin:12mm}@media print{:root,body{background:white;color:#173d32}.toolbar{display:none}.sheet{border:0;border-radius:0;box-shadow:none;margin:0;max-width:none}.body{padding:20px 0}header{padding:20px 0;background:white;border-bottom:2px solid #155c49}.details section,.totals,.bottom,.total,footer{break-inside:avoid}.table-wrap{overflow:visible}.total{background:#edf3eb!important;color:#173d32!important;border:1px solid #c5d6c9}th{border-bottom:1px solid #aabaaf}footer{background:white}*{-webkit-print-color-adjust:exact;print-color-adjust:exact}}
                @media(max-width:600px){.toolbar{align-items:flex-start}.toolbar span{max-width:50%}.sheet{margin:0 8px 20px;border-radius:16px}header,.body{padding:20px 16px}header{gap:12px}.brand-name{font-size:22px}h1{font-size:17px}.mark{width:36px;height:36px}.details{grid-template-columns:1fr;gap:10px}.reference{flex-direction:column;gap:12px}.bottom{flex-direction:column;gap:12px}.note{max-width:none}.totals{width:100%}th,td{padding:10px 6px}.table-wrap table{min-width:470px}footer strong{font-size:15px}}
              </style>
            </head>
            <body>
              <template id="font-license">{{{E(FontLicense.Value)}}}</template>
              <div class="toolbar"><span>نسخهٔ سفارش خودت را نگه دار.</span><button type="button" onclick="window.print()">چاپ / ذخیره به PDF</button></div>
              <main class="sheet">
                <header><div class="brand"><img class="mark" src="data:image/svg+xml;base64,{{{Brand.Value}}}" alt=""><div><div class="brand-name">مزه‌دونه</div><div class="tagline">خوش‌خوراکِ هر روز</div></div></div><div class="invoice-title"><h1>{{{(confirmed ? "فاکتور خرید" : "صورتحساب سفارش")}}}</h1><span class="status">{{{state}}}</span></div></header>
                <div class="body">
                  <section class="reference"><div><span class="label">شناسهٔ سفارش</span><bdi dir="ltr">{{{E(order.Id)}}}</bdi></div><div><span class="label">تاریخ ثبت، به وقت تهران</span><strong>{{{date}}} · {{{time}}}</strong></div></section>
                  <div class="details"><section><h2>خریدار</h2><strong>{{{E(order.CustomerName)}}}</strong><p>{{{E(order.Province)}}}، {{{E(order.City)}}}</p></section><section><h2>تحویل سفارش</h2><strong>{{{E(shippingMethod)}}}</strong><p>برای پیگیری، شناسهٔ سفارش را نزد خود نگه دار.</p></section></div>
                  <h2>انتخاب‌های خوشمزهٔ تو</h2>
                  <div class="table-wrap" role="region" aria-label="اقلام فاکتور" tabindex="0"><table><thead><tr><th>ردیف</th><th>محصول و بسته</th><th class="numeric">تعداد</th><th class="numeric">قیمت واحد</th><th class="numeric">جمع</th></tr></thead><tbody>{{{rows}}}</tbody></table></div>
                  <div class="bottom"><p class="note">همهٔ مبلغ‌ها به تومان است.<br>قیمت و تخفیف این فاکتور مربوط به زمان ثبت سفارش است.</p><section class="totals" aria-label="خلاصهٔ مبالغ"><p><span>جمع کالاها</span><b>{{{Money(order.Subtotal)}}}</b></p><p class="discount"><span>تخفیف</span><b>{{{Money(order.Discount)}}}</b></p><p><span>هزینهٔ ارسال</span><b>{{{Money(order.Shipping)}}}</b></p><p><span>مالیات ({{{Number(order.TaxRatePercent)}}}٪)</span><b>{{{Money(order.Tax)}}}</b></p><p class="total"><span>{{{(confirmed ? "مبلغ پرداخت‌شده" : order.State == OrderState.AwaitingPayment ? "مبلغ قابل پرداخت" : "مبلغ سفارش")}}}</span><b>{{{Money(order.Payable)}}}</b></p></section></div>
                  <footer><strong>{{{E(order.CustomerName)}}} عزیز، {{{(confirmed ? "ممنون از خرید و اعتمادت به مزه‌دونه!" : "ممنون که مزه‌دونه را انتخاب کردی.")}}}</strong><p>{{{closing}}}</p><small>با مهر، تیم مزه‌دونه</small></footer>
                </div>
              </main>
            </body></html>
            """;
    }

    private static string ReadBase64Resource(string resource)
    {
        using var stream = typeof(CustomerInvoice).Assembly.GetManifestResourceStream(resource)
            ?? throw new InvalidOperationException("An invoice resource is missing.");
        using var buffer = new MemoryStream();
        stream.CopyTo(buffer);
        return Convert.ToBase64String(buffer.ToArray());
    }
}
