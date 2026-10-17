import 'package:flutter_test/flutter_test.dart';
import 'package:dailykit_app/main.dart';

void main() {
  testWidgets('AU APP smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DailyKitSosApp());
    expect(find.text('AU APP'), findsWidgets);
    expect(find.text('AU SOS'), findsOneWidget);
  });
}
