import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/admin_form_drafts.dart';

void main() {
  test('draft sanitization removes sensitive keys recursively', () {
    final safe = sanitizeAdminFormDraft({
      'title': 'Cookie box',
      'price': 250000,
      'customerMobile': '09120000000',
      'customerEmails': ['person@example.test'],
      'items': [
        {
          'sku': 'KOO-250',
          'quantity': 2,
          'paymentToken': 'secret-token',
          'recipientAddress': 'private address',
        },
      ],
      'password': 'must-not-persist',
    });

    expect(safe, {
      'title': 'Cookie box',
      'price': 250000,
      'items': [
        {'sku': 'KOO-250', 'quantity': 2},
      ],
    });
  });

  test('draft sanitization replaces unsupported values with null', () {
    final safe = sanitizeAdminFormDraft({
      'title': 'Draft',
      'controller': Object(),
    });

    expect(safe, {'title': 'Draft', 'controller': null});
  });
}
