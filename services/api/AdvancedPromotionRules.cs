using System.Text.RegularExpressions;

public sealed record PromotionBundleItem(string Sku, int Quantity);
public sealed record PromotionContext(string Mobile = "", string City = "", IReadOnlyDictionary<string,string>? Categories = null, int ExistingOrders = 0, int CustomerUses = 0);

public static class AdvancedPromotionRules
{
    public static string Text(string? value) => Regex.Replace((value ?? "").Trim().Replace('ي','ی').Replace('ك','ک'), @"\s+", " ").ToUpperInvariant();
    public static string Mobile(string? value)
    {
        var digits = string.Concat((value ?? "").Select(c => "۰۱۲۳۴۵۶۷۸۹".Contains(c) ? (char)('0'+"۰۱۲۳۴۵۶۷۸۹".IndexOf(c)) : "٠١٢٣٤٥٦٧٨٩".Contains(c) ? (char)('0'+"٠١٢٣٤٥٦٧٨٩".IndexOf(c)) : c).Where(c => c is >= '0' and <= '9' or '+'));
        if(digits.StartsWith("+98")) digits="0"+digits[3..];
        else if(digits.StartsWith("0098")) digits="0"+digits[4..];
        else if(digits.StartsWith("98")) digits="0"+digits[2..];
        return digits;
    }
    public static bool ValidMobile(string? value) => Regex.IsMatch(Mobile(value), "^09[0-9]{9}$");
    public static void Validate(PromotionInput r, Dictionary<string,string[]> errors)
    {
        if(r.Categories is {Count:>30} || r.Categories?.Any(x=>string.IsNullOrWhiteSpace(x)||x.Length>120)==true) errors["categories"]=["حداکثر ۳۰ دستهٔ معتبر وارد کنید."];
        if(r.Cities is {Count:>100} || r.Cities?.Any(x=>string.IsNullOrWhiteSpace(x)||x.Length>120)==true) errors["cities"]=["حداکثر ۱۰۰ شهر معتبر وارد کنید."];
        if(r.CustomerMobiles is {Count:>100} || r.CustomerMobiles?.Any(x=>!ValidMobile(x))==true) errors["customers"]=["حداکثر ۱۰۰ شماره موبایل معتبر وارد کنید."];
        if(r.MaxUsesPerCustomer is <=0 or >10000000 || r.Priority is <0 or >1000 || r.MaxApplications is <=0 or >1500) errors["advancedLimits"]=["سقف هر مشتری، تعداد اعمال و اولویت معتبر نیستند."];
        if(r.CombinationPolicy!="Exclusive") errors["combinationPolicy"]=["هر سفارش یک تخفیف دارد؛ ترکیب تخفیف‌ها مجاز نیست."];
        if(r.Kind=="BuyGet" && (r.BuyQuantity is <1 or >50 || r.GetQuantity is <1 or >50)) errors["buyGet"]=["تعداد خرید و هدیه باید بین ۱ و ۵۰ باشد."];
        if(r.RewardSkus is {Count:>30} || r.RewardSkus?.Any(x=>string.IsNullOrWhiteSpace(x)||x.Length>100)==true) errors["rewardSkus"]=["SKU هدیه معتبر نیست."];
        if(r.Kind=="Bundle")
        {
            if(r.BundleItems is not {Count:>=1 and <=30} || r.BundleItems.Any(x=>x is null || string.IsNullOrWhiteSpace(x.Sku)||x.Sku.Length>100||x.Quantity is <1 or >50) || r.BundleItems.Select(x=>Text(x.Sku)).Distinct().Count()!=r.BundleItems.Count) errors["bundleItems"]=["پک باید ۱ تا ۳۰ SKU یکتا با تعداد ۱ تا ۵۰ داشته باشد."];
            if(r.BundlePrice is null or <0 or >1000000000000m || r.BundlePrice!=decimal.Round(r.BundlePrice??0,2)) errors["bundlePrice"]=["قیمت نهایی پک معتبر نیست."];
            if(r.Skus is {Count:>0} || r.Categories is {Count:>0}) errors["bundleScope"]=["دامنهٔ کالای پک فقط با اقلام خود پک تعیین می‌شود."];
        }
    }
    public static PromotionQuote Calculate(PromotionInput r,IReadOnlyCollection<CheckoutLine> lines,CommerceQuote q,PromotionContext? context=null)
    {
        context ??= new();
        var subtotal=lines.Sum(l=>l.LineTotal);
        bool Eligible(CheckoutLine l) => (r.Skus is not {Count:>0} || r.Skus.Contains(l.Sku,StringComparer.OrdinalIgnoreCase)) &&
            (r.Categories is not {Count:>0} || context.Categories is not null && context.Categories.TryGetValue(l.Sku,out var category) && r.Categories.Any(x=>Text(x)==Text(category)));
        var eligible=lines.Where(Eligible).ToArray();
        var eligibleTotal=eligible.Sum(l=>l.LineTotal);
        decimal discount=r.Kind=="Fixed"?Math.Min(r.Value,eligibleTotal):r.Kind=="Percent"?eligibleTotal*r.Value/100m:0;
        string? error=subtotal<r.MinSubtotal?"مبلغ سبد به حداقل این تخفیف نرسیده است.":null;
        if(r.Kind=="Bundle")
        {
            var items=r.BundleItems??[];
            var groups=items.Count==0?0:items.Min(i=>lines.FirstOrDefault(l=>l.Sku.Equals(i.Sku,StringComparison.OrdinalIgnoreCase))?.Quantity/i.Quantity??0);
            groups=Math.Min(groups,r.MaxApplications??1500);
            var original=items.Sum(i=>(lines.FirstOrDefault(l=>l.Sku.Equals(i.Sku,StringComparison.OrdinalIgnoreCase))?.UnitPrice??0)*i.Quantity);
            discount=groups*Math.Max(0,original-(r.BundlePrice??0));
            if(groups==0 || discount<=0)error="همهٔ اقلام و تعداد پک را به سبد اضافه کنید؛ قیمت پک باید از جمع آن کمتر باشد.";
        }
        else if(r.Kind=="BuyGet")
        {
            var rewards=lines.Where(l=>r.RewardSkus is {Count:>0}?r.RewardSkus.Contains(l.Sku,StringComparer.OrdinalIgnoreCase):Eligible(l))
                .SelectMany(l=>Enumerable.Repeat((l.UnitPrice,Qualifies:Eligible(l)),l.Quantity)).OrderBy(x=>x.UnitPrice).ToArray();
            var buyCount=eligible.Sum(l=>l.Quantity);
            var max=Math.Min(Math.Min(buyCount/Math.Max(1,r.BuyQuantity),rewards.Length/Math.Max(1,r.GetQuantity)),r.MaxApplications??1500);
            for(var groups=max;groups>0;groups--)
            {
                var overlap=buyCount-groups*r.BuyQuantity;var needed=groups*r.GetQuantity;decimal candidate=0;
                foreach(var reward in rewards){if(needed==0)break;if(reward.Qualifies && overlap==0)continue;if(reward.Qualifies)overlap--;candidate+=reward.UnitPrice;needed--;}
                if(needed==0){discount=candidate;break;}
            }
            if(discount<=0)error="تعداد کالای خرید و هدیه در سبد برای این پیشنهاد کافی نیست.";
        }
        else if(eligibleTotal<=0)error="این تخفیف برای کالاهای سبد شما قابل استفاده نیست.";
        if(r.MaxDiscount is decimal cap)discount=Math.Min(discount,cap);
        discount=decimal.Round(Math.Min(subtotal,Math.Max(0,discount)),2,MidpointRounding.AwayFromZero);
        var shipping=r.Kind=="FreeShipping"?Math.Max(0,q.Shipping-Math.Min(q.Shipping,r.MaxDiscount??q.Shipping)):q.Shipping;
        if(r.Cities is {Count:>0} && !r.Cities.Any(x=>Text(x)==Text(context.City)))error="این تخفیف برای اطلاعات تحویل یا مشتری فعلی قابل استفاده نیست.";
        var mobile=Mobile(context.Mobile);
        if((r.CustomerMobiles is {Count:>0} || r.FirstOrderOnly || r.MaxUsesPerCustomer is not null) && !ValidMobile(mobile))error="برای بررسی این تخفیف شماره موبایل معتبر لازم است.";
        if(r.CustomerMobiles is {Count:>0} && !r.CustomerMobiles.Any(x=>Mobile(x)==mobile))error="این تخفیف برای اطلاعات تحویل یا مشتری فعلی قابل استفاده نیست.";
        if(r.FirstOrderOnly && context.ExistingOrders>0 || r.MaxUsesPerCustomer is int limit && context.CustomerUses>=limit)error="این تخفیف برای اطلاعات تحویل یا مشتری فعلی قابل استفاده نیست.";
        var tax=decimal.Round((subtotal-discount)*q.TaxRatePercent/100m,2,MidpointRounding.AwayFromZero);
        var cost=lines.Sum(l=>l.Quantity*(l.CostPrice+l.PackagingCost+l.AdditionalCost));
        return new(subtotal,discount,shipping,q.ShippingExpense,tax,subtotal-discount+shipping+tax,cost,subtotal-discount+shipping-cost-q.ShippingExpense,error);
    }
}
