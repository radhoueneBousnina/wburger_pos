part of '../screens/sales_screen.dart';

class _SuccessOverlay extends StatelessWidget {
  final String ticketNumber;
  const _SuccessOverlay({required this.ticketNumber});

  @override
  Widget build(BuildContext context) {
    final displayTicketNumber = displayTicketNumberFrom(ticketNumber);
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
            ],
          ),
        ),
      ),
    );
  }
}
