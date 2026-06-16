import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/core/theme/pos_layout.dart';

void main() {
  testWidgets('uses wide login layout on common POS landscape screens',
      (tester) async {
    expect(await _showWideLoginLayout(tester, const Size(1024, 768)), isTrue);
    expect(await _showWideLoginLayout(tester, const Size(1366, 768)), isTrue);
  });

  testWidgets('keeps stacked login layout on cramped landscape screens',
      (tester) async {
    expect(await _showWideLoginLayout(tester, const Size(800, 480)), isFalse);
  });
}

Future<bool> _showWideLoginLayout(WidgetTester tester, Size size) async {
  bool? result;

  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(size: size),
        child: Builder(
          builder: (context) {
            result = context.posLayout.showWideLoginLayout;
            return const SizedBox.shrink();
          },
        ),
      ),
    ),
  );

  return result!;
}
