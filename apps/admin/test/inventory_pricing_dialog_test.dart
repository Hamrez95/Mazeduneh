import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/auth_api.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/inventory_pricing_dialog.dart';
import 'package:mazeduneh_admin/order_api.dart';

const product = Product(id: '1', title: 'پسته', slug: 'pistachio', category: 'nuts', origin: 'IR', unitType: 'Weight',
  isPublished: true, variants: [ProductVariant(sku: 'PI-250', quantity: 250, displayLabel: '۲۵۰ گرم', price: 5000, availablePackages: 12)]);
const batch = {'id':'receipt-1','batchCode':'LOT-1','costPrice':4000,'packagingCost':500,'additionalCost':100};
const quote = {'purchaseCost':4000,'packagingCost':1000,'additionalCost':300,'totalCost':5300,'sellingPrice':6630,'profit':1330,'marginPercent':20.06};
Finder input(String label) => find.byWidgetPredicate((w) => w is TextField && w.decoration?.labelText == label);
Widget app(OrderApiClient client, {double scale = 1, AuthApiClient? auth}) => MaterialApp(builder: (context, child) => MediaQuery(
  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
  home: Directionality(textDirection: TextDirection.rtl, child: Scaffold(body: Builder(builder: (context) => TextButton(
    onPressed: () => showDialog<bool>(context: context, builder: (_) => InventoryPricingDialog(products: const [product], orders: client, auth: auth)), child: const Text('باز کردن'))))));

void main() {
  setUp(() => OwnerSession.instance.establish(accessToken: 'pricing-test', expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)), email: 'owner@example.test'));
  tearDown(OwnerSession.instance.clear);
  for (final width in [360.0,768.0,1280.0]) {
    testWidgets('preview invalidation and confirmed apply at $width', (tester) async {
      tester.view.physicalSize = Size(width,1100); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      Map<String,dynamic>? applied;
      String? stepUpHeader;
      final client = OrderApiClient(baseUrl: 'https://api.test', client: MockClient((request) async {
        if (request.url.path.endsWith('/apply')) {
          applied = jsonDecode(request.body) as Map<String,dynamic>;
          stepUpHeader = request.headers['x-admin-step-up'];
        }
        return http.Response(jsonEncode(request.method == 'GET' ? {'sku':'PI-250','currentPrice':5000,'recipe':null,'batches':[batch]} : quote),200);
      }));
      final auth = AuthApiClient(baseUrl: 'https://api.test', client: MockClient((request) async {
        expect(request.url.path, '/api/v1/admin/auth/step-up');
        expect(request.headers['authorization'], 'Bearer pricing-test');
        final password = (jsonDecode(request.body) as Map<String, dynamic>)['password'];
        if (password == 'wrong-password') {
          return http.Response.bytes(utf8.encode(jsonEncode({'message': 'رمز عبور تأیید نشد.'})), 403,
            headers: {'content-type': 'application/json; charset=utf-8'});
        }
        expect(password, 'secret');
        return http.Response(jsonEncode({'stepUpToken': 'short-lived-step-up'}), 200);
      }));
      await tester.pumpWidget(app(client, auth: auth, scale: width == 360 ? 2 : 1));
      await tester.tap(find.text('باز کردن')); await tester.pumpAndSettle();
      for (final entry in {'ضریب بسته‌بندی':'۱٫۲','درصد بسته‌بندی از خرید':'۱۰','درصد جانبی از خرید':'۵','درصد سود روی بهای تمام‌شده':'۲۵'}.entries) {
        await tester.ensureVisible(input(entry.key)); await tester.pumpAndSettle(); await tester.enterText(input(entry.key),entry.value);
      }
      await tester.tap(find.text('پیش‌نمایش قیمت')); await tester.pumpAndSettle();
      expect(find.textContaining('قیمت پیشنهادی: ۶۶۳ تومان'), findsOneWidget);
      await tester.ensureVisible(input('درصد سود روی بهای تمام‌شده')); await tester.pumpAndSettle();
      await tester.enterText(input('درصد سود روی بهای تمام‌شده'),'۳۰'); await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,'اعمال قیمت فروش')).onPressed,isNull);
      await tester.enterText(input('درصد سود روی بهای تمام‌شده'),'۲۵');
      await tester.tap(find.text('پیش‌نمایش قیمت')); await tester.pumpAndSettle();
      await tester.tap(find.text('اعمال قیمت فروش')); await tester.pumpAndSettle();
      expect(find.text('تأیید قیمت فروش'),findsOneWidget);
      await tester.tap(find.text('تأیید اعمال قیمت')); await tester.pumpAndSettle();
      expect(find.text('تأیید دوبارهٔ هویت'), findsOneWidget);
      await tester.enterText(input('رمز عبور فعلی'), 'wrong-password');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'تأیید هویت')); await tester.pumpAndSettle();
      expect(find.text('رمز عبور تأیید نشد.'), findsOneWidget);
      expect(find.textContaining('قیمت پیشنهادی: ۶۶۳ تومان'), findsOneWidget);
      await tester.enterText(input('رمز عبور فعلی'), 'secret');
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'تأیید هویت')); await tester.pumpAndSettle();
      expect(applied?['expectedPrice'],5000);
      expect(stepUpHeader, 'short-lived-step-up');
      final recipe = applied?['recipe'] as Map<String,dynamic>;
      expect(recipe['markupPercent'],25); expect(recipe['packagingMultiplier'],1.2); expect(recipe['packagingCost'],500);
      expect(find.byType(InventoryPricingDialog),findsNothing); expect(tester.takeException(),isNull);
    });
  }
  testWidgets('empty history points back to receiving', (tester) async {
    final client = OrderApiClient(baseUrl:'https://api.test',client:MockClient((r) async => http.Response(jsonEncode({'currentPrice':5000,'recipe':null,'batches':[]}),200)));
    await tester.pumpWidget(app(client)); await tester.tap(find.text('باز کردن')); await tester.pumpAndSettle();
    expect(find.textContaining('هنوز خریدی'),findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton,'پیش‌نمایش قیمت')).onPressed,isNull);
  });
  for (final status in [403,503]) {
    testWidgets('pricing error $status has refresh action', (tester) async {
      final client = OrderApiClient(baseUrl:'https://api.test',client:MockClient((r) async => http.Response('{"message":"دسترسی یا اتصال را بررسی کنید"}',status)));
      await tester.pumpWidget(app(client)); await tester.tap(find.text('باز کردن')); await tester.pumpAndSettle();
      expect(find.textContaining('دوباره تازه‌سازی کنید'),findsOneWidget);
      expect(find.text('تازه‌سازی'),findsOneWidget);
    });
  }
}
