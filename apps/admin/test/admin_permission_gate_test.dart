import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/admin_permissions.dart';
import 'package:mazeduneh_admin/admin_state.dart';
import 'package:mazeduneh_admin/auth_session.dart';

void main() {
  tearDown(OwnerSession.instance.clear);

  testWidgets('hides a restricted page behind a clear forbidden state', (tester) async {
    OwnerSession.instance.establish(
      accessToken: 'readonly-token',
      expiresAt: DateTime.now().toUtc().add(const Duration(minutes: 10)),
      email: 'analyst@example.com',
      role: 'ReadOnlyAnalyst',
      permissions: const [AdminPermissions.dashboardRead],
    );
    await tester.pumpWidget(const MaterialApp(home: AdminPermissionGate(permission: AdminPermissions.productsRead, child: Text('محصولات'))));
    await tester.pump();
    expect(find.text('دسترسی به این بخش محدود است.'), findsOneWidget);
    expect(find.text('محصولات'), findsNothing);
  });

  testWidgets('keeps the page available before authentication resolves', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: AdminPermissionGate(permission: AdminPermissions.productsRead, child: Text('محصولات'))));
    expect(find.text('محصولات'), findsOneWidget);
  });
}
