import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/pos_layout.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/payment_modal.dart';

part '../widgets/qr_scan_views.dart';

enum QrState { scanning, reviewing, invalid, expired, success }

class QrScanScreen extends ConsumerStatefulWidget {
  const QrScanScreen({super.key});

  @override
  ConsumerState<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends ConsumerState<QrScanScreen> {
  QrState _state = QrState.scanning;
  // Mock imported order data
  final _mockImportedItems = <Map<String, dynamic>>[
    {'name': 'W Classic Burger', 'qty': 1, 'price': 12.5},
    {'name': 'Classic Fries', 'qty': 2, 'price': 4.5},
    {'name': 'Coca-Cola', 'qty': 1, 'price': 2.5},
  ];
  final String _mockCustomer = 'Ahmed B.';
  final String _mockQrCode = 'QR-${DateTime.now().year}-00123';

  void _simulateScan(String result) {
    if (result == 'expired') {
      setState(() => _state = QrState.expired);
    } else if (result == 'invalid') {
      setState(() => _state = QrState.invalid);
    } else {
      setState(() => _state = QrState.reviewing);
    }
  }

  void _reset() => setState(() => _state = QrState.scanning);

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;

    return Padding(
      padding: EdgeInsets.all(layout.pagePadding),
      child: switch (_state) {
        QrState.scanning => _ScanningView(onSimulate: _simulateScan),
        QrState.reviewing => _ReviewingView(
            customer: _mockCustomer,
            qrCode: _mockQrCode,
            items: _mockImportedItems,
            onCancel: _reset,
            onConfirm: () {
              final total = _mockImportedItems.fold<double>(
                  0, (s, i) => s + (i['qty'] as int) * (i['price'] as double));
              PaymentModal.show(
                context,
                total: total,
                onConfirm: (pType, oType,
                    {double? amountGiven,
                    double? changeReturned,
                    String? giftRecipient,
                    String? glovoOrderId,
                    String? staffId,
                    double? payableTotal,
                    double? discountAmount,
                    double? staffDiscountPercent}) async {
                  setState(() => _state = QrState.success);
                  Future.delayed(const Duration(seconds: 3), _reset);
                },
              );
            },
          ),
        QrState.invalid => _StatusView(
            icon: Icons.qr_code_2_rounded,
            iconColor: AppColors.semanticTextFor(context, AppColors.error),
            bgColor: AppColors.errorSurfaceFor(context),
            title: 'Invalid QR Code',
            message:
                'This QR code is not recognized by the system. Please ask the customer to try again.',
            onRetry: _reset,
          ),
        QrState.expired => _StatusView(
            icon: Icons.timer_off_rounded,
            iconColor: AppColors.semanticTextFor(context, AppColors.warning),
            bgColor: AppColors.warningSurfaceFor(context),
            title: 'QR Code Expired',
            message:
                'This QR code has expired (validity: 5 minutes). The order was not validated. Ask the customer to generate a new QR.',
            onRetry: _reset,
          ),
        QrState.success => _StatusView(
            icon: Icons.check_circle_rounded,
            iconColor: AppColors.semanticTextFor(context, AppColors.success),
            bgColor: AppColors.successSurfaceFor(context),
            title: 'Order Confirmed!',
            message:
                'QR order validated and sent to kitchen. Payment recorded successfully.',
            onRetry: _reset,
            retryLabel: 'Scan Another',
          ),
      },
    );
  }
}
