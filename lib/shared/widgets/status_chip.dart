import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/pos_layout.dart';
import '../../core/theme/app_text_styles.dart';
import '../../data/models/order_models.dart';

class StatusChip extends StatelessWidget {
  final OrderStatus status;

  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    Color bg;
    Color text;
    String label;
    IconData icon;

    switch (status) {
      case OrderStatus.validated:
        bg = AppColors.successSurfaceFor(context);
        text = AppColors.semanticTextFor(context, AppColors.success);
        label = 'Validated';
        icon = Icons.check_circle_rounded;
      case OrderStatus.cancelled:
        bg = AppColors.errorSurfaceFor(context);
        text = AppColors.semanticTextFor(context, AppColors.error);
        label = 'Cancelled';
        icon = Icons.cancel_rounded;
      case OrderStatus.pending:
        bg = AppColors.warningSurfaceFor(context);
        text = AppColors.semanticTextFor(context, AppColors.warning);
        label = 'Pending';
        icon = Icons.pending_rounded;
    }

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.isCompact ? 10 : 12,
        vertical: layout.isCompact ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: layout.isCompact ? 13 : 14, color: text),
          const SizedBox(width: 5),
          Text(label, style: AppTextStyles.labelSm.copyWith(color: text)),
        ],
      ),
    );
  }
}

class PaymentTypeChip extends StatelessWidget {
  final PaymentType? type;

  const PaymentTypeChip({super.key, this.type});

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    if (type == null) return const SizedBox.shrink();

    final (label, icon, color) = switch (type!) {
      PaymentType.cash => ('Cash', Icons.payments_rounded, AppColors.success),
      PaymentType.card => ('Card', Icons.credit_card_rounded, AppColors.blue),
      PaymentType.glovo => (
          'Glovo',
          Icons.delivery_dining_rounded,
          AppColors.blue
        ),
      PaymentType.staff => ('Staff', Icons.badge_rounded, AppColors.warning),
      PaymentType.gift => (
          'Gift',
          Icons.card_giftcard_rounded,
          AppColors.success
        ),
      PaymentType.other => (
          'Other',
          Icons.more_horiz_rounded,
          AppColors.neutral600
        ),
      PaymentType.points => ('Points', Icons.star_rounded, AppColors.blue),
      PaymentType.deal => (
          'Deal',
          Icons.local_offer_rounded,
          AppColors.success
        ),
    };
    final chipColor = AppColors.isTraining(context)
        ? color == AppColors.blue
            ? AppColors.yellow
            : color == AppColors.neutral600
                ? AppColors.neutral300
                : AppColors.semanticTextFor(context, color)
        : color;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: layout.isCompact ? 8 : 10,
        vertical: layout.isCompact ? 5 : 7,
      ),
      decoration: BoxDecoration(
        color: chipColor.withValues(
            alpha: AppColors.isTraining(context) ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: layout.isCompact ? 12 : 13, color: chipColor),
          const SizedBox(width: 4),
          Text(label, style: AppTextStyles.labelSm.copyWith(color: chipColor)),
        ],
      ),
    );
  }
}
