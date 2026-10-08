import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mazeduneh_admin/auth_session.dart';
import 'package:mazeduneh_admin/order_api.dart';

void main() {
  setUp(() {
    OwnerSession.instance.establish(
      accessToken: 'order-test-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'owner@example.com',
    );
  });
  tearDown(OwnerSession.instance.clear);

  test('stock adjustment and waste send their stable idempotency key', () async {
    final captured = <http.Request>[];
    final client = MockClient((request) async {
      captured.add(request);
      return http.Response(jsonEncode({'isSuccess': true, 'sku': 'PI-250', 'balanceAfter': 3}), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final api = OrderApiClient(client: client, baseUrl: 'https://api.test');
    await api.adjustStock('PI-250', -1, 'شکسته', operationKey: 'stable-adjustment-01');
    await api.writeOffStock('PI-250', 'LOT-1', 1, 'شکسته', operationKey: 'stable-waste-0001');
    expect(captured[0].headers['idempotency-key'], 'stable-adjustment-01');
    expect(captured[1].headers['idempotency-key'], 'stable-waste-0001');
    expect(captured.map((request) => request.url.path), [
      '/api/v1/admin/inventory/adjust', '/api/v1/admin/inventory/waste',
    ]);
  });

  test('fetchOrders sends Bearer token and parses payment data', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode([
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'customerName': 'Mina',
          'mobile': '09120000000',
          'province': 'Tehran',
          'city': 'Tehran',
          'payable': 2450000,
          'currency': 'IRR',
          'state': 'Paid',
          'createdAt': '2026-07-31T08:00:00Z',
          'reservationExpiresAt': '2026-07-31T08:20:00Z',
          'lineCount': 1,
          'paymentReference': 'SANDBOX-1',
          'paymentState': 'Succeeded'
        }
      ]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

    final orders = await OrderApiClient(client: client, baseUrl: 'https://api.test').fetchOrders(state: 'Paid', query: 'Mina');
    expect(captured.headers['authorization'], 'Bearer order-test-token');
    expect(captured.url.path, '/api/v1/admin/orders');
    expect(captured.url.queryParameters['state'], 'Paid');
    expect(captured.url.queryParameters['q'], 'Mina');
    expect(orders.single.nextState, 'Preparing');
    expect(orders.single.paymentReference, 'SANDBOX-1');
  });

  test('exportOrdersCsv preserves active filters and authenticated download contract', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response.bytes([0xEF, 0xBB, 0xBF, 0xD8, 0xB3], 200, headers: {'content-type': 'text/csv; charset=utf-8'});
    });
    final bytes = await OrderApiClient(client: client, baseUrl: 'https://api.test').exportOrdersCsv(state: 'Paid', query: 'Mina', limit: 500);
    expect(captured.url.path, '/api/v1/admin/orders/export.csv');
    expect(captured.url.queryParameters['state'], 'Paid');
    expect(captured.url.queryParameters['q'], 'Mina');
    expect(captured.url.queryParameters['limit'], '500');
    expect(captured.headers['authorization'], 'Bearer order-test-token');
    expect(bytes.take(3), [0xEF, 0xBB, 0xBF]);
  });

  test('transition sends PATCH state and reason', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({
        'id': '11111111-1111-1111-1111-111111111111',
        'customerName': 'Mina',
        'mobile': '09120000000',
        'province': 'Tehran',
        'city': 'Tehran',
        'payable': 2450000,
        'currency': 'IRR',
        'state': 'Preparing',
        'createdAt': '2026-07-31T08:00:00Z',
        'reservationExpiresAt': '2026-07-31T08:20:00Z',
        'lineCount': 1,
        'paymentReference': 'SANDBOX-1',
        'paymentState': 'Succeeded'
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

    await OrderApiClient(client: client, baseUrl: 'https://api.test')
        .transition('11111111-1111-1111-1111-111111111111', 'Preparing', reason: 'ready');
    expect(captured.method, 'PATCH');
    expect(captured.headers['authorization'], 'Bearer order-test-token');
    expect(jsonDecode(captured.body), {'state': 'Preparing', 'reason': 'ready'});
  });

  test('bulkTransition posts bounded order ids and returns update counts', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response.bytes(utf8.encode(jsonEncode({'updated': [{'id': '1'}], 'failed': [{'id': '2', 'message': 'مسیر نامعتبر'}]})), 200);
    });
    final result = await OrderApiClient(client: client, baseUrl: 'https://api.test')
        .bulkTransition(['1', '2'], 'Preparing', reason: 'آماده‌سازی گروهی');
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/admin/orders/bulk-state');
    expect(captured.headers['authorization'], 'Bearer order-test-token');
    expect(jsonDecode(captured.body), {'orderIds': ['1', '2'], 'state': 'Preparing', 'reason': 'آماده‌سازی گروهی'});
    expect(result.$1, 1);
    expect(result.$2, 1);
  });

  test('fetchOrderDetail requests the authenticated order detail contract', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({
        'id': '11111111-1111-1111-1111-111111111111',
        'customerName': 'Mina', 'mobile': '09120000000', 'province': 'Tehran', 'city': 'Tehran',
        'payable': 2450000, 'currency': 'IRR', 'state': 'Paid',
        'createdAt': '2026-07-31T08:00:00Z', 'reservationExpiresAt': '2026-07-31T08:20:00Z',
        'lineCount': 1, 'paymentReference': 'SANDBOX-1', 'paymentState': 'Succeeded',
        'address': 'خیابان ولیعصر', 'postalCode': '1111111111', 'subtotal': 2400000,
        'shipping': 50000, 'shippingExpense': 30000, 'discount': 0, 'tax': 0,
        'taxRatePercent': 0, 'shippingMethod': 'post', 'shippingCarrier': 'پست', 'trackingCode': 'TR-1', 'shippedAt': '2026-07-31T08:03:00Z',
        'lines': [{'productTitle': 'آجیل', 'sku': 'AJ-1', 'variantLabel': '۵۰۰ گرم', 'quantity': 1, 'unitPrice': 2400000, 'lineTotal': 2400000}],
        'transitions': [{'state': 'AwaitingPayment', 'actor': 'customer', 'occurredAt': '2026-07-31T08:00:00Z', 'reason': 'checkout-created'}],
        'notes': [{'id': 'note-1', 'note': 'با مشتری تماس گرفته شد.', 'actor': 'owner@example.com', 'createdAt': '2026-07-31T08:02:00Z'}],
        'payment': {'provider': 'sandbox', 'amount': 2450000, 'currency': 'IRR', 'state': 'Succeeded', 'reference': 'SANDBOX-1', 'createdAt': '2026-07-31T08:01:00Z', 'completedAt': '2026-07-31T08:01:10Z'},
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });

    final detail = await OrderApiClient(client: client, baseUrl: 'https://api.test').fetchOrderDetail('11111111-1111-1111-1111-111111111111');
    expect(captured.method, 'GET');
    expect(captured.url.path, '/api/v1/admin/orders/11111111-1111-1111-1111-111111111111');
    expect(captured.headers['authorization'], 'Bearer order-test-token');
    expect(detail.lines.single.sku, 'AJ-1');
    expect(detail.transitions.single.actor, 'customer');
    expect(detail.notes.single.actor, 'owner@example.com');
    expect(detail.payment?.reference, 'SANDBOX-1');
  });

  test('addOrderNote posts the internal note contract', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'id': 'note-1', 'note': 'پیگیری شد.', 'actor': 'owner@example.com', 'createdAt': '2026-07-31T08:02:00Z'}), 201, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final note = await OrderApiClient(client: client, baseUrl: 'https://api.test').addOrderNote('11111111-1111-1111-1111-111111111111', 'پیگیری شد.');
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/admin/orders/11111111-1111-1111-1111-111111111111/notes');
    expect(jsonDecode(captured.body), {'note': 'پیگیری شد.'});
    expect(note.note, 'پیگیری شد.');
  });

  test('fetchInvoiceHtml uses the authenticated admin invoice endpoint', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('<html dir="rtl">فاکتور</html>', 200, headers: {'content-type': 'text/html; charset=utf-8'});
    });
    final html = await OrderApiClient(client: client, baseUrl: 'https://api.test').fetchInvoiceHtml('11111111-1111-1111-1111-111111111111');
    expect(captured.url.path, '/api/v1/admin/orders/11111111-1111-1111-1111-111111111111/invoice');
    expect(captured.headers['authorization'], 'Bearer order-test-token');
    expect(html, contains('فاکتور'));
  });

  test('fetchPackingSlipHtml uses the authenticated packing slip endpoint', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response('<html dir="rtl">برگه بسته‌بندی</html>', 200, headers: {'content-type': 'text/html; charset=utf-8'});
    });
    final html = await OrderApiClient(client: client, baseUrl: 'https://api.test').fetchPackingSlipHtml('11111111-1111-1111-1111-111111111111');
    expect(captured.url.path, '/api/v1/admin/orders/11111111-1111-1111-1111-111111111111/packing-slip');
    expect(captured.headers['authorization'], 'Bearer order-test-token');
    expect(html, contains('برگه بسته‌بندی'));
  });

  test('fetchInventoryBatches requests the warning window and parses expiry state', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode([
        {
          'id': 'batch-1', 'sku': 'AJ-1', 'productTitle': 'آجیل', 'variantLabel': '۵۰۰ گرم', 'batchCode': 'LOT-1',
          'receivedPackages': 10, 'remainingPackages': 6, 'producedAt': '2026-07-01T08:00:00Z', 'expiresAt': '2026-07-20T08:00:00Z',
          'costPrice': 100, 'packagingCost': 2, 'additionalCost': 1, 'isExpired': false, 'isExpiringSoon': true,
        }
      ]), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final batches = await OrderApiClient(client: client, baseUrl: 'https://api.test').fetchInventoryBatches(expiryWarningDays: 14, limit: 25);
    expect(captured.url.path, '/api/v1/admin/inventory/batches');
    expect(captured.url.queryParameters['expiryWarningDays'], '14');
    expect(captured.url.queryParameters['limit'], '25');
    expect(batches.single.isExpiringSoon, isTrue);
  });

  test('updateShipping sends tracking and actual expense', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({
        'id': '11111111-1111-1111-1111-111111111111', 'customerName': 'Mina', 'mobile': '09120000000', 'province': 'Tehran', 'city': 'Tehran',
        'payable': 2450000, 'currency': 'IRR', 'state': 'Shipped', 'createdAt': '2026-07-31T08:00:00Z', 'reservationExpiresAt': '2026-07-31T08:20:00Z',
        'lineCount': 1, 'paymentReference': null, 'paymentState': null, 'address': 'خیابان ولیعصر', 'postalCode': '1111111111', 'subtotal': 2400000,
        'shipping': 50000, 'shippingExpense': 45000, 'discount': 0, 'tax': 0, 'taxRatePercent': 0, 'shippingMethod': 'post', 'shippingCarrier': 'پست',
        'trackingCode': 'TR-2', 'shippedAt': '2026-07-31T08:03:00Z', 'lines': [], 'transitions': [], 'notes': [], 'payment': null,
      }), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    });
    final detail = await OrderApiClient(client: client, baseUrl: 'https://api.test').updateShipping('11111111-1111-1111-1111-111111111111', carrier: 'پست', trackingCode: 'TR-2', actualShippingCost: 45000, reason: 'اصلاح کد رهگیری');
    expect(captured.method, 'PATCH');
    expect(captured.url.path, '/api/v1/admin/orders/11111111-1111-1111-1111-111111111111/shipping');
    expect(jsonDecode(captured.body), {'carrier': 'پست', 'trackingCode': 'TR-2', 'actualShippingCost': 45000, 'reason': 'اصلاح کد رهگیری'});
    expect(detail.trackingCode, 'TR-2');
  });

  test('writeOffStock uses the explicit inventory waste endpoint', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'isSuccess': true, 'sku': 'PI-AKB-250', 'balanceAfter': 2}), 200);
    });
    final result = await OrderApiClient(client: client, baseUrl: 'https://api.test').writeOffStock('PI-AKB-250', 'LOT-1', 1, 'بسته آسیب‌دیده', operationKey: 'test-writeoff-0001');
    expect(captured.method, 'POST');
    expect(captured.url.path, '/api/v1/admin/inventory/waste');
    expect(jsonDecode(captured.body), {'sku': 'PI-AKB-250', 'batchCode': 'LOT-1', 'quantity': 1, 'reason': 'بسته آسیب‌دیده'});
    expect(result.balanceAfter, 2);
  });

  test('fetchOverdueShipments sends the delay window and parses tracking context', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode([
        {
          'id': '11111111-1111-1111-1111-111111111111',
          'customerName': 'مشتری تست',
          'mobile': '09120000000',
          'province': 'تهران',
          'city': 'تهران',
          'payable': 120000,
          'currency': 'IRR',
          'state': 'Shipped',
          'createdAt': '2026-09-20T10:00:00Z',
          'reservationExpiresAt': '2026-09-20T10:20:00Z',
          'lineCount': 2,
          'shippingCarrier': 'پست',
          'trackingCode': 'TR-42',
          'shippedAt': '2026-09-21T10:00:00Z',
          'daysOverdue': 5,
        },
      ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final shipments = await OrderApiClient(client: client, baseUrl: 'https://api.test').fetchOverdueShipments(days: 5);
    expect(captured.url.path, '/api/v1/admin/shipping/overdue');
    expect(captured.url.queryParameters['days'], '5');
    expect(shipments.single.trackingCode, 'TR-42');
    expect(shipments.single.daysOverdue, 5);
  });

  test('401 clears owner session', () async {
    final client = MockClient((request) async => http.Response('', 401));
    final api = OrderApiClient(client: client, baseUrl: 'https://api.test');
    await expectLater(api.fetchDashboard(), throwsA(isA<OrderApiException>()));
    expect(OwnerSession.instance.isAuthenticated, isFalse);
  });

  test('fetchProductProfitability sends the selected period and parses margin rows', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(
        jsonEncode([
          {
            'productTitle': 'پسته اکبری',
            'sku': 'PI-AKB-250',
            'variantLabel': '۲۵۰ گرم',
            'unitsSold': 4,
            'revenue': 9800000,
            'cost': 5600000,
            'grossProfit': 4200000,
          },
        ]),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    });
    final rows = await OrderApiClient(client: client, baseUrl: 'https://api.test').fetchProductProfitability(days: 90);
    expect(captured.url.path, '/api/v1/admin/analytics/products');
    expect(captured.url.queryParameters['days'], '90');
    expect(rows.single.sku, 'PI-AKB-250');
    expect(rows.single.grossProfit, 4200000);
  });

  test('fetchDashboard sends the selected sales period', () async {
    late http.Request captured;
    final client = MockClient((request) async {
      captured = request;
      return http.Response(jsonEncode({'awaitingPayment': 0, 'processing': 0, 'shipped': 0, 'delivered': 0, 'paidRevenue': 0, 'todayRevenue': 0, 'lowStock': [], 'periodDays': 7, 'periodOrderCount': 3, 'periodRevenue': 900000, 'averageOrderValue': 300000}), 200);
    });
    final dashboard = await OrderApiClient(client: client, baseUrl: 'https://api.test').fetchDashboard(days: 7);
    expect(captured.url.queryParameters['days'], '7');
    expect(dashboard.periodOrderCount, 3);
    expect(dashboard.averageOrderValue, 300000);
  });
}
