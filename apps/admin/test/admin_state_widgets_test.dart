import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/admin_state.dart';

void main() {
  testWidgets('shared empty state exposes an educational next action', (tester) async {
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      home: AdminEmptyState(
        icon: Icons.inventory_2_outlined,
        title: 'موجودی خالی است',
        detail: 'برای شروع، اولین دریافت کالا را ثبت کنید.',
        actionLabel: 'ثبت دریافت',
        onAction: () => pressed = true,
      ),
    ));

    expect(find.text('موجودی خالی است'), findsOneWidget);
    expect(find.text('برای شروع، اولین دریافت کالا را ثبت کنید.'), findsOneWidget);
    await tester.tap(find.text('ثبت دریافت'));
    expect(pressed, isTrue);
  });

  testWidgets('shared stale banner explains refresh without hiding the data context', (tester) async {
    var retried = false;
    await tester.pumpWidget(MaterialApp(
      home: AdminStaleBanner(detail: 'داده‌ها ممکن است تازه نباشند.', onRetry: () => retried = true),
    ));

    expect(find.text('داده‌ها ممکن است تازه نباشند.'), findsOneWidget);
    await tester.tap(find.text('تلاش دوباره'));
    expect(retried, isTrue);
  });
}
