import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/core/theme/app_theme.dart';
import 'package:wburger_pos/data/models/order_models.dart';
import 'package:wburger_pos/data/providers/app_providers.dart';
import 'package:wburger_pos/shared/widgets/payment_modal.dart';

class _StaticPosSettingsNotifier extends PosSettingsNotifier {
  _StaticPosSettingsNotifier() : super(autoFetch: false) {
    state = const AsyncValue.data(PosSettings(staffDiscountPercent: 40));
  }

  @override
  Future<void> fetchSettings({
    bool silent = false,
    bool force = false,
  }) async {
    state = const AsyncValue.data(PosSettings(staffDiscountPercent: 40));
  }
}

class _StaticStaffListNotifier extends StaffListNotifier {
  _StaticStaffListNotifier() : super() {
    state = const AsyncValue.data(_staff);
  }

  static const _staff = [
    StaffMember(
      id: '7',
      username: 'staff7',
      firstName: 'Staff',
      lastName: 'Member',
      role: 'staff',
    ),
  ];

  @override
  Future<void> fetchStaff({
    bool silent = false,
    bool force = false,
  }) async {
    state = const AsyncValue.data(_staff);
  }
}

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
              onConfirm: (
                _,
                __, {
                amountGiven,
                changeReturned,
                staffId,
                glovoOrderId,
                giftRecipient,
                payableTotal,
                discountAmount,
                staffDiscountPercent,
              }) {},
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

  testWidgets('staff payment displays configured discounted total',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          posSettingsProvider.overrideWith(
            (_) => _StaticPosSettingsNotifier(),
          ),
          staffListProvider.overrideWith(
            (_) => _StaticStaffListNotifier(),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PaymentModal(
              total: 20,
              staffDiscountBaseTotal: 20,
              initialPaymentType: PaymentType.staff,
              onConfirm: (
                _,
                __, {
                amountGiven,
                changeReturned,
                staffId,
                glovoOrderId,
                giftRecipient,
                payableTotal,
                discountAmount,
                staffDiscountPercent,
              }) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Staff total: 12.000 DT'), findsOneWidget);
    expect(find.text('Discount 40.00%: -8.000 DT'), findsOneWidget);
  });

  testWidgets('cash validation is shown inside the payment modal',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var confirmed = false;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PaymentModal(
              total: 20,
              initialPaymentType: PaymentType.cash,
              onConfirm: (
                _,
                __, {
                amountGiven,
                changeReturned,
                staffId,
                glovoOrderId,
                giftRecipient,
                payableTotal,
                discountAmount,
                staffDiscountPercent,
              }) {
                confirmed = true;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Confirm Payment'));
    await tester.pumpAndSettle();

    expect(confirmed, isFalse);
    expect(find.text('Enter enough cash before confirming.'), findsOneWidget);
    expect(find.text('Amount received must cover the total.'), findsOneWidget);
  });

  testWidgets('gift payment requires a recipient and reports zero total',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? receivedGiftRecipient;
    double? receivedPayableTotal;
    double? receivedDiscountAmount;

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: PaymentModal(
              total: 20,
              staffDiscountBaseTotal: 20,
              initialPaymentType: PaymentType.gift,
              onConfirm: (
                _,
                __, {
                amountGiven,
                changeReturned,
                staffId,
                glovoOrderId,
                giftRecipient,
                payableTotal,
                discountAmount,
                staffDiscountPercent,
              }) {
                receivedGiftRecipient = giftRecipient;
                receivedPayableTotal = payableTotal;
                receivedDiscountAmount = discountAmount;
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Gift total: 0.000 DT'), findsOneWidget);
    expect(find.text('Gift discount: -20.000 DT'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Sami');
    await tester.tap(find.text('Confirm Payment'));
    await tester.pumpAndSettle();

    expect(receivedGiftRecipient, 'Sami');
    expect(receivedPayableTotal, 0);
    expect(receivedDiscountAmount, 20);
  });
}
