import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/core/theme/app_theme.dart';
import 'package:wburger_pos/data/models/order_models.dart';
import 'package:wburger_pos/shared/widgets/payment_modal.dart';

void main() {
  testWidgets('cash keypad appends when the amount field is selected',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PaymentModal(
              total: 12,
              initialPaymentType: PaymentType.cash,
              onConfirm: (_, __, {amountGiven, changeReturned, staffId}) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.ensureVisible(find.text('1'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('1'));
    await tester.pump();

    final editableText = tester.widget<EditableText>(find.byType(EditableText));
    editableText.controller.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 1,
    );

    await tester.tap(find.text('2'));
    await tester.pump();

    expect(editableText.controller.text, '12');
  });
}
