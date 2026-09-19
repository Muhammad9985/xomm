import 'package:flutter_test/flutter_test.dart';
import 'package:xomm/main.dart';

void main() {
  testWidgets('Xomm smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const XommApp());
    // Settle all micro-animations
    await tester.pumpAndSettle(const Duration(milliseconds: 500));

    expect(find.text('XOMM'), findsOneWidget);
    expect(find.text('Generate Meeting'), findsOneWidget);
    expect(find.text('Join a Meeting'), findsOneWidget);
  });
}
