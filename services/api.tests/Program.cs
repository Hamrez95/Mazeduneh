static void Check(bool condition, string message) { if (!condition) throw new Exception(message); }
var now = DateTimeOffset.UtcNow;
var valid = new InventoryBatchRequest("SKU", "receipt", 2, now.AddDays(-2), now.AddDays(100), 100, 20, 5, now.AddDays(-1), "supplier");
Check(valid.Validate().Count == 0, "Valid receipt rejected");
Check((valid with { PurchasedAt = now.AddDays(1) }).Validate().ContainsKey("PurchasedAt"), "Future purchase accepted");
Check((valid with { ReceivedPackages = 0 }).Validate().ContainsKey("ReceivedPackages"), "Zero quantity accepted");
Check((valid with { CostPrice = -1 }).Validate().ContainsKey("CostPrice"), "Negative cost accepted");
Check((valid with { Supplier = new string('x', 201) }).Validate().ContainsKey("Supplier"), "Long supplier accepted");
Check((valid with { ExpiresAt = valid.ProducedAt }).Validate().ContainsKey("ExpiresAt"), "Invalid expiry accepted");
Check((valid with { PurchasedAt = null, Supplier = null }).Validate().ContainsKey("Supplier"), "New receipt without supplier accepted");
Console.WriteLine("Receipt validation unit checks passed");

var recipe = new InventoryPriceRecipe(Guid.NewGuid(), 500, 1.2m, 10, 100, 5, 25, 10);
var quote = InventoryPriceCalculator.Calculate(4000, recipe);
Check(quote.PackagingCost == 1000 && quote.AdditionalCost == 300, "Cost components incorrect");
Check(quote.TotalCost == 5300 && quote.SellingPrice == 6630, "Markup/upward rounding incorrect");
Check(quote.Profit == 1330 && quote.MarginPercent == 20.06m, "Profit/margin incorrect");
Check(InventoryPriceCalculator.Calculate(0, recipe).SellingPrice == 880, "Zero purchase with positive fees incorrect");
Check((recipe with { PackagingMultiplier = -1 }).Validate().Count > 0, "Invalid multiplier accepted");
Check((recipe with { RoundingStep = 0 }).Validate().Count > 0, "Zero rounding step accepted");
Check((recipe with { MarkupPercent = 1001 }).Validate().Count > 0, "Unbounded markup accepted");
Console.WriteLine("Server cost pricing arithmetic and validation unit checks passed");

var cursor = new InventoryPurchaseCursor(now, Guid.NewGuid());
Check(InventoryPurchaseCursor.TryDecode(InventoryPurchaseCursor.Encode(cursor), out var decoded) && decoded == cursor, "Cursor roundtrip failed");
Check(!InventoryPurchaseCursor.TryDecode("invalid", out _), "Malformed cursor accepted");
Check(!InventoryPurchaseCursor.TryDecode(Convert.ToBase64String("null"u8.ToArray()), out _), "Null cursor accepted");
Check(!InventoryPurchaseCursor.TryDecode(new string('x',513), out _), "Unbounded cursor accepted");
Console.WriteLine("Purchase pagination cursor unit checks passed");
