import 'package:flutter_test/flutter_test.dart';
import 'package:guest_app_flutter/main.dart';

void main() {
  testWidgets('Guest app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const GuestApp());
    expect(find.text('⚡ CrisisSync'), findsOneWidget);
  });
}
