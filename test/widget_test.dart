import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/main.dart';

void main() {
  testWidgets('App starts without crash', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: WBurgerPosApp()));
    await tester.pump();
    // Basic smoke test - app renders
    expect(find.byType(ProviderScope), findsOneWidget);
    expect(find.text('Test Printer & Drawer'), findsOneWidget);
  });
}
