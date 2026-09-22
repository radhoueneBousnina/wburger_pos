import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/core/theme/app_colors.dart';
import 'package:wburger_pos/core/theme/app_theme.dart';
import 'package:wburger_pos/data/models/order_models.dart';
import 'package:wburger_pos/data/providers/app_providers.dart';
import 'package:wburger_pos/shared/widgets/payment_modal.dart';

Future<void> _ignoreCustomerDisplay(double _) async {}

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
              customerDisplayWriter: _ignoreCustomerDisplay,
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

    const oneKey = ValueKey('cash-key-1');
    const twoKey = ValueKey('cash-key-2');
    const amountFieldKey = ValueKey('cash-amount-field');

    await tester.ensureVisible(find.byKey(oneKey));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(oneKey));
    await tester.pump();

    final amountField = tester.widget<TextField>(find.byKey(amountFieldKey));
    amountField.controller!.selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 1,
    );

    await tester.tap(find.byKey(twoKey));
    await tester.pump();

    expect(amountField.controller!.text, '12');
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
              customerDisplayWriter: _ignoreCustomerDisplay,
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
              customerDisplayWriter: _ignoreCustomerDisplay,
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

  testWidgets('cash amount field stays readable in training theme',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1200, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.trainingTheme,
          home: Scaffold(
            body: PaymentModal(
              total: 20,
              initialPaymentType: PaymentType.cash,
              customerDisplayWriter: _ignoreCustomerDisplay,
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

    final cashField = tester.widget<TextField>(find.byType(TextField).first);

    expect(cashField.style?.color, AppColors.white);
    expect(cashField.cursorColor, AppColors.yellow);
    expect(cashField.decoration?.suffixStyle?.color,
        AppColors.trainingTextSecondary);
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
              customerDisplayWriter: _ignoreCustomerDisplay,
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
