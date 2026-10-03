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
    final detail = await OrderApiClient(client: client, baseUrl: 'https://api.test').updateShipping('11111111-1111-1111-1111-111111111111', carrier: 'پست', trackingCode: 'TR-2', actualShippingCost: 45000);
    expect(captured.method, 'PATCH');
    expect(captured.url.path, '/api/v1/admin/orders/11111111-1111-1111-1111-111111111111/shipping');
    expect(jsonDecode(captured.body), {'carrier': 'پست', 'trackingCode': 'TR-2', 'actualShippingCost': 45000});
    expect(detail.trackingCode, 'TR-2');
  });

  test('401 clears owner session', () async {
    final client = MockClient((request) async => http.Response('', 401));
    final api = OrderApiClient(client: client, baseUrl: 'https://api.test');
    await expectLater(api.fetchDashboard(), throwsA(isA<OrderApiException>()));
    expect(OwnerSession.instance.isAuthenticated, isFalse);
  });
}
