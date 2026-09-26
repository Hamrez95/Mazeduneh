import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/main.dart';

void main() {
  testWidgets('dashboard renders primary management metrics', (tester) async {
    await tester.pumpWidget(const MazedunehAdminApp());
    await tester.pumpAndSettle();

    expect(find.text('فروش امروز'), findsOneWidget);
    expect(find.text('سفارش جدید'), findsOneWidget);
    expect(find.text('کاتالوگ'), findsOneWidget);
    expect(find.text('متصل به API'), findsOneWidget);
    expect(find.text('وضعیت پرداخت'), findsOneWidget);
    expect(find.text('غیرفعال'), findsOneWidget);
  });
}
