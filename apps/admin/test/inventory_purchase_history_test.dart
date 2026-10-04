import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/main.dart' show InventoryPage;
import 'package:mazeduneh_admin/order_api.dart';

Map<String,dynamic> batch(String id) => {'id':id,'sku':'PI-250','productTitle':'پسته','variantLabel':'۲۵۰ گرم',
  'batchCode':id,'receivedPackages':12,'remainingPackages':12,'producedAt':'2025-01-01T00:00:00Z',
  'expiresAt':'2030-01-01T00:00:00Z','purchasedAt':'2026-01-01T00:00:00Z','supplier':'تأمین تهران',
  'costPrice':4000,'packagingCost':500,'additionalCost':100,'isExpired':false};
void main() {
  setUp(() => OwnerSession.instance.establish(accessToken:'history-test',expiresAt:DateTime.now().toUtc().add(const Duration(minutes:10)),email:'owner@example.test'));
  tearDown(OwnerSession.instance.clear);
  for (final width in [360.0,768.0,1280.0]) {
    testWidgets('older purchases keep current page on error and retry at $width', (tester) async {
      tester.view.physicalSize=Size(width,1100);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      var olderCalls=0;
      final client=MockClient((r) async {
        Object body=[];
        if (r.url.path.endsWith('/products/admin')) body=[{'id':'1','slug':'pistachio','title':'پسته','category':'nuts','origin':'IR','unitType':'Weight','isPublished':true,
          'variants':[{'sku':'PI-250','quantity':250,'displayLabel':'۲۵۰ گرم','price':5000,'availablePackages':12}]}];
        if (r.url.path.endsWith('/purchases')) {
          if (r.url.queryParameters.containsKey('cursor')) {
            olderCalls++;
            if (olderCalls==1) return http.Response('{"message":"قطع اتصال"}',503,headers:{'content-type':'application/json; charset=utf-8'});
            body={'items':[batch('خرید قدیمی')],'nextCursor':null};
          } else {body={'items':[batch('خرید جدید')],'nextCursor':'next-cursor'};}
        }
        return http.Response(jsonEncode(body),200,headers:{'content-type':'application/json; charset=utf-8'});
      });
      await tester.pumpWidget(MaterialApp(builder:(context,child)=>MediaQuery(data:MediaQuery.of(context).copyWith(textScaler:TextScaler.linear(width==360?2:1)),child:child!),
        home:Directionality(textDirection:TextDirection.rtl,child:Scaffold(body:InventoryPage(catalog:CatalogApiClient(client:client,baseUrl:'https://api.test'),orders:OrderApiClient(client:client,baseUrl:'https://api.test'))))));
      await tester.pumpAndSettle();
      final more=find.text('مشاهده خریدهای قدیمی‌تر');
      final gridScroll=find.descendant(of:find.byKey(const ValueKey('inventory-sections')),matching:find.byType(Scrollable)).first;
      await tester.scrollUntilVisible(more,250,scrollable:gridScroll); await tester.pumpAndSettle();
      Focus.of(tester.element(more)).requestFocus(); await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); await tester.pumpAndSettle();
      expect(olderCalls,1);expect(find.textContaining('خریدهای قدیمی دریافت نشد'),findsOneWidget);
      expect(find.textContaining('پسته · خرید جدید'),findsOneWidget);
      await tester.ensureVisible(find.text('تلاش دوباره'));await tester.pumpAndSettle();
      await tester.tap(find.text('تلاش دوباره'));await tester.pumpAndSettle();
      expect(olderCalls,2);expect(find.textContaining('خریدهای قدیمی دریافت نشد'),findsNothing);
      expect(find.text('مشاهده خریدهای قدیمی‌تر'),findsNothing);expect(tester.takeException(),isNull);
    });
  }
}
