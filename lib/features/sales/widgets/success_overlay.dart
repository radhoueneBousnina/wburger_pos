part of '../screens/sales_screen.dart';

class _SuccessOverlay extends StatelessWidget {
  final String ticketNumber;
  final CustomerDisplayBackendResult? customerDisplayResult;

  const _SuccessOverlay({
    required this.ticketNumber,
    this.customerDisplayResult,
  });

  @override
  Widget build(BuildContext context) {
    final displayTicketNumber = displayTicketNumberFrom(ticketNumber);
    final displayMessage = _customerDisplayMessage(customerDisplayResult);
    return Container(
      color: Colors.black.withValues(alpha: 0.6),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(48),
          decoration: BoxDecoration(
              color: AppColors.white, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(
                    color: AppColors.yellow, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.blue, size: 52),
              ),
              const SizedBox(height: 20),
              Text('Payment Confirmed!',
                  style: AppTextStyles.h3.copyWith(color: AppColors.blue)),
              const SizedBox(height: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.yellowSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.yellow)),
                child: Text('Ticket $displayTicketNumber',
                    style: AppTextStyles.h4.copyWith(color: AppColors.blue)),
              ),
              const SizedBox(height: 12),
              Text('Order sent to kitchen • Printing ticket...',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
              if (displayMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  displayMessage,
                  style: AppTextStyles.bodySm.copyWith(
                    color: customerDisplayResult?.success == true
                        ? AppColors.success
                        : AppColors.warning,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String? _customerDisplayMessage(CustomerDisplayBackendResult? result) {
    if (result == null) return 'Customer display: detecting...';
    if (!result.configured) return null;
    if (result.success) {
      final source = result.source?.trim();
      return source == null || source.isEmpty
          ? 'Customer display: updated'
          : 'Customer display: $source';
    }
    return 'Customer display: not detected';
  }
}
