static void Check(bool condition, string message) { if (!condition) throw new Exception(message); }
var now = DateTimeOffset.UtcNow;
var valid = new InventoryBatchRequest("SKU", "receipt", 2, now.AddDays(-2), now.AddDays(100), 100, 20, 5, now.AddDays(-1), "supplier");
Check(valid.Validate().Count == 0, "Valid receipt rejected");
Check((valid with { PurchasedAt = now.AddDays(1) }).Validate().ContainsKey("PurchasedAt"), "Future purchase accepted");
Check((valid with { ReceivedPackages = 0 }).Validate().ContainsKey("ReceivedPackages"), "Zero quantity accepted");
Check((valid with { CostPrice = -1 }).Validate().ContainsKey("CostPrice"), "Negative cost accepted");
Check((valid with { Supplier = new string('x', 201) }).Validate().ContainsKey("Supplier"), "Long supplier accepted");
Check((valid with { ExpiresAt = valid.ProducedAt }).Validate().ContainsKey("ExpiresAt"), "Invalid expiry accepted");
Check((valid with { PurchasedAt = null, Supplier = null }).Validate().Count == 0, "Legacy receipt rejected");
Console.WriteLine("Receipt validation unit checks passed");
