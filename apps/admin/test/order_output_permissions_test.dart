import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/main.dart';
import 'package:mazeduneh_admin/order_api.dart';

void main() {
  tearDown(OwnerSession.instance.clear);
  for (final permissions in [<String>['orders.read'], <String>['orders.read','orders.export','orders.documents.read','customers.pii.read']]) {
    testWidgets('order outputs respect permissions $permissions', (tester) async {
      OwnerSession.instance.establish(accessToken: 'test-token', expiresAt: DateTime.now().toUtc().add(const Duration(hours: 1)), email: 'analyst@example.test', role: 'ReadOnlyAnalyst', permissions: permissions);
      tester.view.physicalSize = const Size(1280,1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final order = {'id':'11111111-1111-1111-1111-111111111111','customerName':'مشتری ناشناس','mobile':'مخفی بر اساس نقش','province':'مخفی','city':'مخفی','payable':10000,'currency':'IRR','state':'Paid','createdAt':'2026-10-01T10:00:00Z','reservationExpiresAt':'2026-10-01T11:00:00Z','lineCount':1};
      final client = MockClient((request) async => http.Response(jsonEncode(request.url.path.endsWith('/orders') ? [order] : request.url.path.contains('/orders/') ? {...order,'address':'مخفی','postalCode':'مخفی','subtotal':10000,'shipping':0,'shippingExpense':0,'discount':0,'tax':0,'taxRatePercent':0,'shippingMethod':'post','lines':[],'transitions':[],'notes':[]} : []),200,headers:{'content-type':'application/json; charset=utf-8'}));
      await tester.pumpWidget(MaterialApp(home: Scaffold(body: OrdersPage(api: OrderApiClient(client: client)))));
      await tester.pumpAndSettle();
      expect(find.text('خروجی CSV'), permissions.contains('orders.export') ? findsOneWidget : findsNothing);
      await tester.tap(find.text('مشتری ناشناس').first);
      await tester.pumpAndSettle();
      expect(find.text('برگه بسته‌بندی'), permissions.contains('orders.documents.read') ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
