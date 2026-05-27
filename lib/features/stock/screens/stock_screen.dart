import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/pos_layout.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/stock_models.dart';
import '../../../data/providers/app_providers.dart';

part '../widgets/stock_table.dart';
part '../widgets/stock_alert.dart';

class StockScreen extends ConsumerWidget {
  const StockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = context.posLayout;
    final stocksAsync = ref.watch(stockProvider);

    return stocksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading stock')),
      data: (stocks) {
        final lowStockItems = stocks.where((s) => s.isLowStock).length;
        final criticalItems = stocks.where((s) => s.isCritical).length;

        return Column(
          children: [
            // Top bar
            Container(
              padding: EdgeInsets.fromLTRB(
                  layout.pagePadding, 16, layout.pagePadding, 12),
              color: AppColors.surfaceFor(context),
              child: Row(
                children: [
                  if (lowStockItems > 0)
                    _StockAlert(
                      label: '$lowStockItems Low Stock',
                      color: AppColors.warning,
                      icon: Icons.warning_rounded,
                    ),
                  if (criticalItems > 0) ...[
                    const SizedBox(width: 10),
                    _StockAlert(
                      label: '$criticalItems Critical',
                      color: AppColors.error,
                      icon: Icons.error_rounded,
                    ),
                  ],
                  const Spacer(),
                  Text('${stocks.length} items',
                      style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondaryFor(context))),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.borderFor(context)),
            // Table items
            Expanded(
              child: _StockTable(stocks: stocks),
            ),
          ],
        );
      },
    );
  }
}

class _StockTableSpec {
  const _StockTableSpec();

  static const double horizontalPadding = 24;
  static const double unitWidth = 80;
  static const double qtyWidth = 120;
  static const double thresholdWidth = 100;
  static const double statusWidth = 140; // Increased for badge
  static const double columnGap = 16;
  static const double productWidth = 350;
  static const double cellRightPadding = 16;

  double get minWidth =>
      (horizontalPadding * 2) +
      unitWidth +
      qtyWidth +
      thresholdWidth +
      statusWidth +
      productWidth +
      (columnGap * 5); // Base minimum gaps if needed
}
