using System.Text.Json;
using System.Text.RegularExpressions;
using Npgsql;

public sealed record PromotionInput(string Name, string Kind, decimal Value, bool Active,
    DateTimeOffset StartsAt, DateTimeOffset EndsAt, decimal MinSubtotal = 0,
    decimal? MaxDiscount = null, int? MaxUses = null, IReadOnlyList<string>? Skus = null, bool AllowLoss = false,
    IReadOnlyList<string>? Categories = null, IReadOnlyList<string>? CustomerMobiles = null, IReadOnlyList<string>? Cities = null,
    bool FirstOrderOnly = false, int? MaxUsesPerCustomer = null, int BuyQuantity = 1, int GetQuantity = 1,
    IReadOnlyList<string>? RewardSkus = null, IReadOnlyList<PromotionBundleItem>? BundleItems = null, decimal? BundlePrice = null,
    int? MaxApplications = null, bool Automatic = false, int Priority = 0, string CombinationPolicy = "Exclusive");
public sealed record PromotionDefinition(string Code, PromotionInput Rule, string UpdatedBy, DateTimeOffset UpdatedAt, string? LossApprovedBy);
public sealed record PromotionSummary(string Code, PromotionInput Rule, int Uses, decimal DiscountTotal, string? LossApprovedBy, int PaidOrders = 0, decimal Revenue = 0, bool CustomerScopeHidden = false);
public sealed class PromotionScopePermissionException : Exception;
public sealed record PromotionPreviewRequest(PromotionInput Rule, IReadOnlyCollection<CheckoutItemRequest> Lines, string ShippingMethod = "post", string Mobile = "", string City = "");
public sealed record CouponPreviewRequest(string Code, IReadOnlyCollection<CheckoutItemRequest> Lines, string ShippingMethod = "post", string Mobile = "", string City = "");
public sealed record PromotionQuote(decimal Subtotal, decimal Discount, decimal Shipping, decimal ShippingExpense,
    decimal Tax, decimal Payable, decimal Cost, decimal NetProfit, string? Error = null);

public static class PromotionRules
{
    public static string NormalizeCode(string? code) => (code ?? "").Trim().ToUpperInvariant();
    public static Dictionary<string, string[]> Validate(string code, PromotionInput r)
    {
        var errors = new Dictionary<string, string[]>();
        if (!Regex.IsMatch(code, "^[A-Z0-9][A-Z0-9_-]{2,39}$", RegexOptions.CultureInvariant)) errors["code"] = ["کد باید ۳ تا ۴۰ حرف انگلیسی یا عدد، خط تیره یا زیرخط باشد."];
        if (string.IsNullOrWhiteSpace(r.Name) || r.Name.Length > 120) errors["name"] = ["نام تخفیف الزامی و حداکثر ۱۲۰ نویسه است."];
        if (r.Kind is not ("Percent" or "Fixed" or "FreeShipping" or "BuyGet" or "Bundle")) errors["kind"] = ["نوع تخفیف معتبر نیست."];
        if (r.Value < 0 || r.Value > 1000000000000m || (r.Kind is "Percent" or "Fixed" && r.Value <= 0) || (r.Kind == "Percent" && r.Value > 100) || r.Value != decimal.Round(r.Value, 2)) errors["value"] = ["مقدار تخفیف معتبر نیست؛ درصد حداکثر ۱۰۰ است."];
        if (r.EndsAt <= r.StartsAt) errors["endsAt"] = ["پایان باید بعد از شروع باشد."];
        if (r.MinSubtotal < 0 || r.MinSubtotal > 1000000000000m || r.MaxDiscount is <= 0 or > 1000000000000m || r.MaxUses is <= 0 or > 10000000) errors["limits"] = ["حداقل سبد و سقف مبلغ/مصرف معتبر نیستند."];
        if (r.Skus is {Count: > 30} || r.Skus?.Any(s => string.IsNullOrWhiteSpace(s) || s.Length > 100) == true) errors["skus"] = ["دامنهٔ SKU حداکثر ۳۰ قلم معتبر است."];
        AdvancedPromotionRules.Validate(r,errors);
        return errors;
    }
    public static PromotionQuote Calculate(PromotionInput rule, IReadOnlyCollection<CheckoutLine> lines, CommerceQuote quote, PromotionContext? context = null)
        => AdvancedPromotionRules.Calculate(rule,lines,quote,context);

}

public sealed class PromotionDatabase(IConfiguration configuration)
{
    private readonly string? connectionString = configuration.GetConnectionString("Catalog");
    public bool IsConfigured => !string.IsNullOrWhiteSpace(connectionString);
    public async Task ApplyMigrationsAsync(CancellationToken ct)
    {
        await using var c = new NpgsqlConnection(connectionString); await c.OpenAsync(ct);
        await DatabaseMigrationRunner.ApplyAsync(c, "promotions", "001-coupons", """
            create table if not exists promotions (
                code varchar(40) primary key, rules jsonb not null, updated_by varchar(180) not null,
                updated_at timestamptz not null, loss_approved_by varchar(180)
            );
            alter table checkout_orders add column if not exists coupon_code varchar(40);
            create table if not exists promotion_redemptions (
                order_id uuid primary key references checkout_orders(id) on delete cascade,
                code varchar(40) not null references promotions(code),
                discount numeric(18,2) not null check(discount>=0),
                shipping_discount numeric(18,2) not null check(shipping_discount>=0),
                created_at timestamptz not null default now()
            );
            create index if not exists ix_promotion_redemptions_code on promotion_redemptions(code);
            """, ct);
        await DatabaseMigrationRunner.ApplyAsync(c,"promotions","002-rule-snapshots", """
            alter table promotion_redemptions add column if not exists rule_snapshot jsonb;
            """,ct);
    }
    public async Task<PromotionDefinition?> FindAsync(NpgsqlConnection c, NpgsqlTransaction? tx, string code, bool locked, CancellationToken ct)
    {
        await using var cmd = new NpgsqlCommand("select code,rules::text,updated_by,updated_at,loss_approved_by from promotions where code=@code" + (locked ? " for update" : ""), c, tx);
        cmd.Parameters.AddWithValue("code", PromotionRules.NormalizeCode(code));
        await using var r=await cmd.ExecuteReaderAsync(ct);
        return await r.ReadAsync(ct) ? new(r.GetString(0),JsonSerializer.Deserialize<PromotionInput>(r.GetString(1))!,r.GetString(2),r.GetFieldValue<DateTimeOffset>(3),r.IsDBNull(4)?null:r.GetString(4)) : null;
    }
    public async Task<int> UsesAsync(NpgsqlConnection c,NpgsqlTransaction? tx,string code,CancellationToken ct)
    {
        await using var cmd=new NpgsqlCommand("select count(*)::int from promotion_redemptions r join checkout_orders o on o.id=r.order_id where r.code=@code and o.state not in ('Cancelled','Expired')",c,tx);
        cmd.Parameters.AddWithValue("code",code);return (int)(await cmd.ExecuteScalarAsync(ct))!;
    }
    public async Task<(PromotionDefinition? Promotion, PromotionQuote? Quote, string? Error)> EvaluateAsync(NpgsqlConnection c,NpgsqlTransaction? tx,string code,IReadOnlyCollection<CheckoutLine> lines,CommerceQuote quote,bool locked,CancellationToken ct,PromotionContext? context=null)
    {
        var p=await FindAsync(c,tx,code,locked,ct);
        var now=DateTimeOffset.UtcNow;
        if(p is null || !p.Rule.Active || now<p.Rule.StartsAt || now>=p.Rule.EndsAt) return (null,null,"کد تخفیف معتبر یا فعال نیست.");
        if(p.Rule.MaxUses is int limit && await UsesAsync(c,tx,p.Code,ct)>=limit) return(null,null,"سقف مصرف این کد تخفیف تمام شده است.");
        context ??= new();
        if(p.Rule.MaxUsesPerCustomer is not null && AdvancedPromotionRules.ValidMobile(context.Mobile))
        {
            await using var uses=new NpgsqlCommand("select count(*)::int from promotion_redemptions r join checkout_orders o on o.id=r.order_id join customers cu on cu.id=o.customer_id where r.code=@code and cu.mobile_normalized=@mobile and o.state not in ('Cancelled','Expired')",c,tx);
            uses.Parameters.AddWithValue("code",p.Code);uses.Parameters.AddWithValue("mobile",AdvancedPromotionRules.Mobile(context.Mobile));
            context=context with {CustomerUses=(int)(await uses.ExecuteScalarAsync(ct))!};
        }
        var result=PromotionRules.Calculate(p.Rule,lines,quote,context);
        if(result.Error is not null)return(null,null,result.Error);
        if(result.NetProfit<0 && (p.LossApprovedBy is null || !p.Rule.AllowLoss))return(null,null,"این تخفیف برای سبد فعلی قابل اعمال نیست؛ با فروشگاه تماس بگیرید.");
        return(p,result,null);
    }
    public async Task RecordAsync(NpgsqlConnection c,NpgsqlTransaction tx,Guid orderId,string code,PromotionQuote quote,decimal originalShipping,CancellationToken ct)
    {
        await using var cmd=new NpgsqlCommand("insert into promotion_redemptions(order_id,code,discount,shipping_discount,rule_snapshot) select @order,code,@discount,@shipping,rules from promotions where code=@code",c,tx);
        cmd.Parameters.AddWithValue("order",orderId);cmd.Parameters.AddWithValue("code",code);cmd.Parameters.AddWithValue("discount",quote.Discount);cmd.Parameters.AddWithValue("shipping",originalShipping-quote.Shipping);await cmd.ExecuteNonQueryAsync(ct);
    }
    public async Task<IReadOnlyList<PromotionSummary>> ListAsync(CancellationToken ct)
    {
        if(!IsConfigured)return [];
        await using var c=new NpgsqlConnection(connectionString);await c.OpenAsync(ct);
        await using var cmd=new NpgsqlCommand("""
            select p.code,p.rules::text,p.loss_approved_by,
                count(o.id) filter(where o.state not in ('Cancelled','Expired'))::int,
                coalesce(sum(r.discount+r.shipping_discount) filter(where o.state in ('Paid','Preparing','Shipped','Delivered')),0), count(o.id) filter(where o.state in ('Paid','Preparing','Shipped','Delivered'))::int, coalesce(sum(o.payable) filter(where o.state in ('Paid','Preparing','Shipped','Delivered')),0)
            from promotions p left join promotion_redemptions r on r.code=p.code
            left join checkout_orders o on o.id=r.order_id group by p.code order by p.updated_at desc limit 250
            """,c);
        var result=new List<PromotionSummary>();await using var r=await cmd.ExecuteReaderAsync(ct);
        while(await r.ReadAsync(ct)) result.Add(new(r.GetString(0),JsonSerializer.Deserialize<PromotionInput>(r.GetString(1))!,r.GetInt32(3),r.GetDecimal(4),r.IsDBNull(2)?null:r.GetString(2),r.GetInt32(5),r.GetDecimal(6)));
        return result;
    }
    public async Task<PromotionDefinition> SaveAsync(string code,PromotionInput input,string actor,AdminAuditLogDatabase audit,string requestId,CancellationToken ct,bool canReadCustomers=false)
    {
        await using var c=new NpgsqlConnection(connectionString);await c.OpenAsync(ct);await using var tx=await c.BeginTransactionAsync(ct);
        await using(var codeLock=new NpgsqlCommand("select pg_advisory_xact_lock(hashtextextended(@code,0))",c,tx))
        {codeLock.Parameters.AddWithValue("code","promotion-edit:"+code);await codeLock.ExecuteNonQueryAsync(ct);}
        var before=await FindAsync(c,tx,code,true,ct);
        if(!canReadCustomers && (input.CustomerMobiles is {Count:>0} || before?.Rule.CustomerMobiles is {Count:>0}))throw new PromotionScopePermissionException();
        var normalized=input with {Name=input.Name.Trim(),StartsAt=input.StartsAt.ToUniversalTime(),EndsAt=input.EndsAt.ToUniversalTime(),Skus=input.Skus?.Select(s=>s.Trim().ToUpperInvariant()).Distinct().ToArray(),
            Categories=input.Categories?.Select(AdvancedPromotionRules.Text).Distinct().ToArray(), Cities=input.Cities?.Select(AdvancedPromotionRules.Text).Distinct().ToArray(),
            CustomerMobiles=input.CustomerMobiles?.Select(AdvancedPromotionRules.Mobile).Distinct().ToArray(),RewardSkus=input.RewardSkus?.Select(x=>x.Trim().ToUpperInvariant()).Distinct().ToArray(),
            BundleItems=input.BundleItems?.Select(x=>x with {Sku=x.Sku.Trim().ToUpperInvariant()}).ToArray()};
        var now=DateTimeOffset.UtcNow;
        await using var cmd=new NpgsqlCommand("""
            insert into promotions(code,rules,updated_by,updated_at,loss_approved_by) values(@code,@rules::jsonb,@actor,@at,@approval)
            on conflict(code) do update set rules=excluded.rules,updated_by=excluded.updated_by,updated_at=excluded.updated_at,loss_approved_by=excluded.loss_approved_by
            """,c,tx);
        cmd.Parameters.AddWithValue("code",code);cmd.Parameters.AddWithValue("rules",JsonSerializer.Serialize(normalized));cmd.Parameters.AddWithValue("actor",actor);cmd.Parameters.AddWithValue("at",now);cmd.Parameters.AddWithValue("approval",(object?)(input.AllowLoss?actor:null)??DBNull.Value);
        await cmd.ExecuteNonQueryAsync(ct);
        var after=new PromotionDefinition(code,normalized,actor,now,input.AllowLoss?actor:null);
        await audit.RecordAsync(c,tx,actor,"promotion.save","Promotion",code,before,after,"ثبت قوانین کوپن",requestId,ct);
        await tx.CommitAsync(ct);return after;
    }
    public async Task<PromotionContext> ContextAsync(NpgsqlConnection c,NpgsqlTransaction? tx,string? mobile,string? city,IReadOnlyCollection<CheckoutLine> lines,CancellationToken ct)
    {
        var categories=new Dictionary<string,string>(StringComparer.OrdinalIgnoreCase);
        await using(var cmd=new NpgsqlCommand("select v.sku,p.category from product_variants v join products p on p.id=v.product_id where upper(v.sku)=any(@skus)",c,tx))
        {
            cmd.Parameters.AddWithValue("skus",lines.Select(l=>l.Sku.ToUpperInvariant()).ToArray());
            await using var reader=await cmd.ExecuteReaderAsync(ct);while(await reader.ReadAsync(ct))categories[reader.GetString(0)]=reader.GetString(1);
        }
        var normalized=AdvancedPromotionRules.Mobile(mobile);var orders=0;
        if(AdvancedPromotionRules.ValidMobile(normalized))
        {
            await using var cmd=new NpgsqlCommand("select count(*)::int from checkout_orders o join customers cu on cu.id=o.customer_id where cu.mobile_normalized=@mobile and o.state not in ('Cancelled','Expired')",c,tx);
            cmd.Parameters.AddWithValue("mobile",normalized);orders=(int)(await cmd.ExecuteScalarAsync(ct))!;
        }
        return new(normalized,city??"",categories,orders);
    }
    public async Task<(PromotionDefinition? Promotion,PromotionQuote? Quote,string? Error)> SelectAsync(NpgsqlConnection c,NpgsqlTransaction? tx,string? code,IReadOnlyCollection<CheckoutLine> lines,CommerceQuote quote,bool locked,string? mobile,string? city,CancellationToken ct)
    {
        var context=await ContextAsync(c,tx,mobile,city,lines,ct);
        if(!string.IsNullOrWhiteSpace(code))return await EvaluateAsync(c,tx,code,lines,quote,locked,ct,context);
        var codes=new List<string>();
        await using(var cmd=new NpgsqlCommand("select code from promotions where coalesce((rules->>'Automatic')::boolean,false)=true order by code"+(locked?" for update":""),c,tx))
        {await using var reader=await cmd.ExecuteReaderAsync(ct);while(await reader.ReadAsync(ct))codes.Add(reader.GetString(0));}
        var candidates=new List<(PromotionDefinition Promotion,PromotionQuote Quote)>();
        foreach(var candidate in codes){var evaluated=await EvaluateAsync(c,tx,candidate,lines,quote,false,ct,context);if(evaluated.Promotion is not null && evaluated.Quote is not null && evaluated.Quote.Discount+quote.Shipping-evaluated.Quote.Shipping>0)candidates.Add((evaluated.Promotion,evaluated.Quote));}
        var winner=candidates.OrderByDescending(x=>x.Promotion.Rule.Priority).ThenByDescending(x=>x.Quote.Discount+quote.Shipping-x.Quote.Shipping).ThenBy(x=>x.Promotion.Code,StringComparer.Ordinal).FirstOrDefault();
        return(winner.Promotion,winner.Quote,null);
    }
    public NpgsqlConnection OpenConnection() => new(connectionString);
}

public static class PromotionModule
{
    public static IEndpointRouteBuilder MapPromotions(this IEndpointRouteBuilder app)
    {
        app.MapGet("/api/v1/admin/promotions",async(PromotionDatabase db,HttpContext context,CancellationToken ct)=>Results.Ok((await db.ListAsync(ct)).Select(p=>CustomerPrivacy.CanReadPii(context)?p:p with {Rule=p.Rule with {CustomerMobiles=null},CustomerScopeHidden=p.Rule.CustomerMobiles is {Count:>0}})))
            .AddEndpointFilter<OwnerAuthorizationFilter>();
        app.MapPut("/api/v1/admin/promotions/{code}",async Task<IResult>(string code,PromotionInput input,PromotionDatabase db,AdminAuditLogDatabase audit,HttpContext context,CancellationToken ct)=>{
            code=PromotionRules.NormalizeCode(code);var errors=PromotionRules.Validate(code,input);if(errors.Count>0)return Results.ValidationProblem(errors);
            if(!db.IsConfigured)return Results.Problem(statusCode:503,title:"دیتابیس آماده نیست.");
            var principal=(AdminPrincipal)context.Items["AdminPrincipal"]!;
            if(input.AllowLoss && !string.Equals(principal.Role,"Owner",StringComparison.OrdinalIgnoreCase))return Results.Json(new{message="تأیید احتمال سود منفی فقط با مدیر اصلی است."},statusCode:403);
            try{return Results.Ok(await db.SaveAsync(code,input,principal.Email,audit,context.TraceIdentifier,ct,CustomerPrivacy.CanReadPii(context)));}
            catch(PromotionScopePermissionException){return Results.Json(new{message="مدیریت دامنهٔ مشتری به مجوز اطلاعات مشتری نیاز دارد."},statusCode:403);}
        }).AddEndpointFilter<OwnerAuthorizationFilter>().AddEndpointFilter<StepUpAuthorizationFilter>().WithMetadata(new StepUpPermissionRequirement(AdminPermissionCatalog.PricingWrite));
        app.MapPost("/api/v1/admin/promotions/preview",async Task<IResult>(PromotionPreviewRequest request,PromotionDatabase db,CommercePricingDatabase pricing,HttpContext http,CancellationToken ct)=>{
            if(request.Rule is null)return Results.BadRequest(new{message="قوانین تخفیف الزامی است."});
            if(!CustomerPrivacy.CanReadPii(http) && (!string.IsNullOrWhiteSpace(request.Mobile) || request.Rule.CustomerMobiles is {Count:>0}))return Results.StatusCode(403);
            var errors=PromotionRules.Validate("PREVIEW",request.Rule);if(errors.Count>0)return Results.ValidationProblem(errors);
            if(!db.IsConfigured)return Results.Problem(statusCode:503,title:"دیتابیس آماده نیست.");
            var lines=await BuildLinesAsync(db,request.Lines,ct);if(lines is null)return Results.BadRequest(new{message="کالاها یا تعداد سبد نمونه معتبر نیستند."});
            var quote=await pricing.QuoteAsync(lines.Sum(l=>l.LineTotal),request.ShippingMethod,ct);if(quote.Quote is null)return Results.BadRequest(new{message=quote.Error});
            await using var c=db.OpenConnection();await c.OpenAsync(ct);
            var context=await db.ContextAsync(c,null,request.Mobile,request.City,lines,ct);
            return Results.Ok(PromotionRules.Calculate(request.Rule,lines,quote.Quote,context));
        }).AddEndpointFilter<OwnerAuthorizationFilter>();
        app.MapPost("/api/v1/checkout/coupon-preview",async Task<IResult>(CouponPreviewRequest request,PromotionDatabase db,CommercePricingDatabase pricing,HttpContext context,CancellationToken ct)=>{
            context.Response.Headers.CacheControl="no-store";
            if(!db.IsConfigured)return Results.Problem(statusCode:503,title:"دیتابیس آماده نیست.");
            if(request.Code is {Length:>40} || request.Mobile?.Length>30 || request.City?.Length>120)return Results.BadRequest(new{message="کد تخفیف معتبر نیست."});
            var lines=await BuildLinesAsync(db,request.Lines,ct);if(lines is null)return Results.BadRequest(new{message="سبد معتبر نیست."});
            var quote=await pricing.QuoteAsync(lines.Sum(l=>l.LineTotal),request.ShippingMethod,ct);if(quote.Quote is null)return Results.BadRequest(new{message=quote.Error});
            await using var c=db.OpenConnection();await c.OpenAsync(ct);
            var result=await db.SelectAsync(c,null,request.Code,lines,quote.Quote,false,request.Mobile,request.City,ct);
            if(result.Error is not null)return Results.BadRequest(new{message=result.Error});
            var final=result.Quote??new PromotionQuote(lines.Sum(l=>l.LineTotal),0,quote.Quote.Shipping,quote.Quote.ShippingExpense,quote.Quote.Tax,quote.Quote.Payable,0,0);
            return Results.Ok(new{code=result.Promotion?.Code,name=result.Promotion?.Rule.Name,automatic=result.Promotion?.Rule.Automatic??false,final.Subtotal,final.Discount,final.Shipping,final.Tax,final.Payable});
        }).RequireRateLimiting("coupon-preview");
        return app;
    }
    private static async Task<IReadOnlyCollection<CheckoutLine>?> BuildLinesAsync(PromotionDatabase db,IReadOnlyCollection<CheckoutItemRequest>? requests,CancellationToken ct)
    {
        if(requests is null || requests.Count is <1 or >30 || requests.Any(r=>r is null || string.IsNullOrWhiteSpace(r.Sku)||r.Quantity is <1 or >50) || requests.Select(r=>r.Sku.Trim().ToUpperInvariant()).Distinct().Count()!=requests.Count)return null;
        await using var c=db.OpenConnection();await c.OpenAsync(ct);
        // Read a consistent, non-reserving view. Checkout repeats this under stock locks.
        await using var tx=await c.BeginTransactionAsync(System.Data.IsolationLevel.RepeatableRead,ct);
        var lines=new List<CheckoutLine>();
        foreach(var item in requests)
        {
            await using var cmd=new NpgsqlCommand("select p.title,v.sku,v.display_label,v.price,v.available_packages,v.cost_price,v.packaging_cost,v.additional_cost from product_variants v join products p on p.id=v.product_id where upper(v.sku)=upper(@sku) and p.is_published=true",c,tx);
            cmd.Parameters.AddWithValue("sku",item.Sku.Trim());
            string title,sku,label;decimal price,cost,pack,extra;int available;
            await using(var reader=await cmd.ExecuteReaderAsync(ct))
            {
                if(!await reader.ReadAsync(ct))return null;
                title=reader.GetString(0);sku=reader.GetString(1);label=reader.GetString(2);price=reader.GetDecimal(3);available=reader.GetInt32(4);cost=reader.GetDecimal(5);pack=reader.GetDecimal(6);extra=reader.GetDecimal(7);
            }
            await using var batches=new NpgsqlCommand("select remaining_packages,cost_price,packaging_cost,additional_cost,expires_at from inventory_batches where upper(sku)=upper(@sku) and remaining_packages>0 order by expires_at,created_at",c,tx);
            batches.Parameters.AddWithValue("sku",sku);
            var hasBatches=false;var remaining=item.Quantity;decimal totalCost=0,totalPack=0,totalExtra=0;
            await using(var reader=await batches.ExecuteReaderAsync(ct))
            {
                while(await reader.ReadAsync(ct))
                {
                    hasBatches=true;
                    if(reader.GetFieldValue<DateTimeOffset>(4)<=DateTimeOffset.UtcNow)continue;
                    var quantity=Math.Min(remaining,reader.GetInt32(0));remaining-=quantity;
                    totalCost+=quantity*reader.GetDecimal(1);totalPack+=quantity*reader.GetDecimal(2);totalExtra+=quantity*reader.GetDecimal(3);
                }
            }
            if(hasBatches){if(remaining>0)return null;cost=totalCost/item.Quantity;pack=totalPack/item.Quantity;extra=totalExtra/item.Quantity;}
            else if(available<item.Quantity)return null;
            lines.Add(new(title,sku,label,item.Quantity,price,price*item.Quantity,cost,pack,extra));
        }
        await tx.CommitAsync(ct);return lines;
    }
}
