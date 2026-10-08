using Npgsql;
using Microsoft.AspNetCore.Http;
using System.Text.Json;
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

if (args.Length == 0 || InventoryExpiryFixture.IsCommand(args))
    await InventoryExpiryFixture.RunAsync(args);

var privacyContext = new DefaultHttpContext();
privacyContext.Items["AdminPrincipal"] = new AdminPrincipal("analyst@example.test", now.AddHours(1), "ReadOnlyAnalyst", [AdminPermissionCatalog.OrdersRead], Guid.NewGuid(), null, "default");
var summary = new AdminOrderSummary(Guid.NewGuid(), "PII name", "09120000199", "PII province", "PII city", 100, "IRR", OrderState.Shipped, now, now.AddHours(1), 1, "PII reference", "Paid");
var orderDetail = new AdminOrderDetail(summary, "PII address", "1234567890", 100, 0, 0, 0, 0, 0, "standard", "PII carrier", "PII tracking", now,
    [new AdminOrderLine("product", "SKU", "package", 1, 100, 100)],
    [new AdminOrderTransition(OrderState.Shipped, "PII actor", now, "PII reason")],
    [new AdminOrderNote(Guid.NewGuid(), "PII note", "PII actor", now)],
    new AdminPayment("sandbox", 100, "IRR", PaymentState.Succeeded, "PII reference", now, now));
var masked = OrderPrivacy.Project(orderDetail, privacyContext);
Check(!JsonSerializer.Serialize(masked).Contains("PII") && masked.Lines.Count == 1 && masked.State == OrderState.Shipped, "Order projection leaked PII or lost operational data");
var overdue = new AdminOverdueShipment(summary.Id, summary.CustomerName, summary.Mobile, summary.Province, summary.City, summary.Payable, summary.Currency, summary.State, now, now, 1, "PII carrier", "PII tracking", now, 3);
Check(!JsonSerializer.Serialize(OrderPrivacy.Project(overdue, privacyContext)).Contains("PII"), "Overdue projection leaked PII");
privacyContext.Request.Method = "GET";
privacyContext.Request.Path = "/api/v1/admin/orders/" + summary.Id + "/invoice";
Check(AdminPermissionCatalog.RequiredPermission(privacyContext) == AdminPermissionCatalog.OrdersDocumentsRead, "Invoice needs independent permission");
Check(!AdminPermissionCatalog.AllowsOrderOutput(privacyContext, (AdminPrincipal)privacyContext.Items["AdminPrincipal"]!), "PII-free role received document permission");
privacyContext.Items["AdminPrincipal"] = new AdminPrincipal("owner@example.test", now.AddHours(1), "Owner", [], Guid.NewGuid(), null, "default");
Check(OrderPrivacy.Project(orderDetail, privacyContext) == orderDetail, "Authorized projection changed customer details");
Console.WriteLine("Order contact privacy and output permission unit checks passed");

// Test-only fixture: backdate only the explicitly created privacy-test shipment.
if (args.Length == 2 && args[0] == "--backdate-privacy-shipment")
{
    Check(Environment.GetEnvironmentVariable("MAZEDUNEH_TEST_FIXTURES") == "true", "Fixture mutation disabled");
    Check(Guid.TryParse(args[1], out var fixtureOrderId), "Invalid fixture order id");
    await using var fixtureConnection = new NpgsqlConnection(Environment.GetEnvironmentVariable("ConnectionStrings__Catalog"));
    await fixtureConnection.OpenAsync();
    await using var fixtureCommand = new NpgsqlCommand("update checkout_orders set shipped_at=now()-interval '5 days' where id=@id and state='Shipped' and customer_name='PrivacyFixtureCustomer'", fixtureConnection);
    fixtureCommand.Parameters.AddWithValue("id", fixtureOrderId);
    Check(await fixtureCommand.ExecuteNonQueryAsync() == 1, "Expected exactly the privacy fixture shipment");
}
