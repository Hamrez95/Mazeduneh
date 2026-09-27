import 'package:flutter_test/flutter_test.dart';
import 'package:mazeduneh_admin/main.dart';

void main() {
  testWidgets('admin shell renders branded navigation while dashboard loads', (tester) async {
    await tester.pumpWidget(const MazedunehAdminApp());
    await tester.pump();

    expect(find.text('مدیریت مزه‌دونه'), findsOneWidget);
    expect(find.text('سفارش‌ها'), findsOneWidget);
    expect(find.text('محصولات'), findsOneWidget);
    expect(find.text('انبار'), findsOneWidget);
    expect(find.text('گزارش‌ها'), findsOneWidget);
  });
}
