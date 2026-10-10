import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/catalog_api.dart';
import 'package:mazeduneh_admin/inventory_page.dart' show InventoryPage;
import 'package:mazeduneh_admin/order_api.dart';

Map<String,dynamic> batch(String id) => {'id':id,'sku':'PI-250','productTitle':'پسته','variantLabel':'۲۵۰ گرم',
  'batchCode':id,'receivedPackages':12,'remainingPackages':12,'producedAt':'2025-01-01T00:00:00Z',
  'expiresAt':'2030-01-01T00:00:00Z','purchasedAt':'2026-01-01T00:00:00Z','supplier':'تأمین تهران',
  'costPrice':4000,'packagingCost':500,'additionalCost':100,'isExpired':false};
void main() {
  setUp(() => OwnerSession.instance.establish(accessToken:'history-test',expiresAt:DateTime.now().toUtc().add(const Duration(minutes:10)),email:'owner@example.test'));
  tearDown(OwnerSession.instance.clear);
  testWidgets('an older refresh failure cannot replace the newest purchase page', (tester) async {
    tester.view.physicalSize=const Size(1280,1100);tester.view.devicePixelRatio=1;
    addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
    final old=Completer<http.Response>();var purchaseCalls=0;
    final client=MockClient((r) async {
      if(r.url.path.endsWith('/purchases')) {
        purchaseCalls++;
        if(purchaseCalls==1) return old.future;
        return http.Response(jsonEncode({'items':[batch('صفحه تازه')],'nextCursor':null}),200,headers:{'content-type':'application/json; charset=utf-8'});
      }
      return http.Response('[]',200);
    });
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:InventoryPage(catalog:CatalogApiClient(client:client,baseUrl:'https://api.test'),orders:OrderApiClient(client:client,baseUrl:'https://api.test')))));
    await tester.pump();
    await tester.tap(find.byTooltip('بارگذاری مجدد'));await tester.pumpAndSettle();
    expect(find.textContaining('پسته · صفحه تازه'),findsOneWidget);
    old.complete(http.Response('{"message":"پاسخ قدیمی"}',503,headers:{'content-type':'application/json; charset=utf-8'}));await tester.pumpAndSettle();
    expect(find.textContaining('پسته · صفحه تازه'),findsOneWidget);
    expect(find.textContaining('پاسخ قدیمی'),findsNothing);expect(tester.takeException(),isNull);
  });
  for (final width in [360.0,768.0,1280.0]) {
    testWidgets('older purchases keep current page on error and retry at $width', (tester) async {
      tester.view.physicalSize=Size(width,1100);tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
      var olderCalls=0;
      final requestedSkus=<String?>[];
      final client=MockClient((r) async {
        Object body=[];
        if (r.url.path.endsWith('/products/admin')) body=[{'id':'1','slug':'pistachio','title':'پسته','category':'nuts','origin':'IR','unitType':'Weight','isPublished':true,
          'variants':[{'sku':'PI-250','quantity':250,'displayLabel':'۲۵۰ گرم','price':5000,'availablePackages':12}]}];
        if (r.url.path.endsWith('/purchases')) {
          requestedSkus.add(r.url.queryParameters['sku']);
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
      // Move the outer section grid; a drag at its center can scroll a nested receipt/product list instead.
      final sections=tester.state<ScrollableState>(gridScroll).position;
      sections.jumpTo(sections.maxScrollExtent); await tester.pumpAndSettle();
      final purchaseScroll=find.descendant(of:find.byKey(const ValueKey('inventory-purchases')),matching:find.byType(Scrollable)).first;
      tester.state<ScrollableState>(purchaseScroll).position.jumpTo(tester.state<ScrollableState>(purchaseScroll).position.maxScrollExtent);await tester.pumpAndSettle();
      expect(more,findsOneWidget);
      await tester.ensureVisible(more); await tester.pumpAndSettle();
      Focus.of(tester.element(more)).requestFocus(); await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter); await tester.pumpAndSettle();
      expect(olderCalls,1);expect(find.textContaining('خریدهای قدیمی دریافت نشد'),findsOneWidget);
      tester.state<ScrollableState>(purchaseScroll).position.jumpTo(0);await tester.pumpAndSettle();
      expect(find.textContaining('پسته · خرید جدید'),findsOneWidget);
      tester.state<ScrollableState>(purchaseScroll).position.jumpTo(tester.state<ScrollableState>(purchaseScroll).position.maxScrollExtent);await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('تلاش دوباره'));await tester.pumpAndSettle();
      await tester.tap(find.text('تلاش دوباره'));await tester.pumpAndSettle();
      expect(olderCalls,2);expect(find.textContaining('خریدهای قدیمی دریافت نشد'),findsNothing);
      expect(find.text('مشاهده خریدهای قدیمی‌تر'),findsNothing);
      expect(requestedSkus.every((sku)=>sku==null),isTrue);
      await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String>));await tester.pumpAndSettle();
      await tester.tap(find.text('پسته · ۲۵۰ گرم · PI-250').last);await tester.pumpAndSettle();
      final filteredSections=tester.state<ScrollableState>(gridScroll).position;
      filteredSections.jumpTo(filteredSections.maxScrollExtent);await tester.pumpAndSettle();
      tester.state<ScrollableState>(purchaseScroll).position.jumpTo(tester.state<ScrollableState>(purchaseScroll).position.maxScrollExtent);await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('مشاهده خریدهای قدیمی‌تر'));await tester.pumpAndSettle();
      await tester.tap(find.text('مشاهده خریدهای قدیمی‌تر'));await tester.pumpAndSettle();
      expect(requestedSkus.sublist(requestedSkus.length-2),['PI-250','PI-250']);
      expect(tester.takeException(),isNull);
    });
  }
}
