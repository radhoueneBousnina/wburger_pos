part of '../screens/stock_screen.dart';

class _StockTable extends StatelessWidget {
  final List<StockItem> stocks;

  const _StockTable({required this.stocks});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spec = _StockTableSpec();
        // tableWidth should at least be minWidth to avoid squishing
        final tableWidth = constraints.maxWidth > spec.minWidth
            ? constraints.maxWidth
            : spec.minWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _StockTableSpec.horizontalPadding,
                    vertical: 14,
                  ),
                  color: AppColors.tableHeaderFor(context),
                  child: Row(
                    children: [
                      _Cell(
                          width: _StockTableSpec.productWidth,
                          child: _StockHeaderCell('Product')),
                      Spacer(flex: 4),
                      _Cell(
                          width: _StockTableSpec.unitWidth,
                          child: _StockHeaderCell('Unit')),
                      Spacer(flex: 1),
                      _Cell(
                        width: _StockTableSpec.qtyWidth,
                        child: _StockHeaderCell('Stock',
                            align: TextAlign.right,
                            rightPadding: _StockTableSpec.cellRightPadding),
                      ),
                      Spacer(flex: 1),
                      _Cell(
                          width: _StockTableSpec.thresholdWidth,
                          child:
                              _StockHeaderCell('Min', align: TextAlign.right)),
                      Spacer(flex: 1),
                      _Cell(
                          width: _StockTableSpec.statusWidth,
                          child: _StockHeaderCell('Status')),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.borderFor(context)),
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: stocks.length,
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppColors.borderFor(context)),
                    itemBuilder: (ctx, i) => _StockRow(item: stocks[i]),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  final double width;
  final Widget child;

  const _Cell({required this.width, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(width: width, child: child);
  }
}

class _StockHeaderCell extends StatelessWidget {
  final String label;
  final TextAlign align;
  final double rightPadding;

  const _StockHeaderCell(this.label,
      {this.align = TextAlign.left, this.rightPadding = 0});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(right: rightPadding),
      child: Text(
        label,
        textAlign: align,
        style: AppTextStyles.label.copyWith(
          color: AppColors.textSecondaryFor(context),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _StockRow extends StatelessWidget {
  final StockItem item;
  const _StockRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    Color rowBg = AppColors.surfaceFor(context);
    if (item.isCritical) {
      rowBg = AppColors.errorLight
          .withValues(alpha: AppColors.isTraining(context) ? 0.12 : 0.25);
    } else if (item.isLowStock) {
      rowBg = AppColors.warningLight
          .withValues(alpha: AppColors.isTraining(context) ? 0.12 : 0.3);
    }

    return InkWell(
      onTap: () {},
      overlayColor: WidgetStateProperty.all(rowBg.withValues(alpha: 0.1)),
      child: Container(
        color: rowBg,
        padding: EdgeInsets.symmetric(
          horizontal: _StockTableSpec.horizontalPadding,
          vertical: layout.isCompact ? 16 : 20,
        ),
        child: Row(
          children: [
            _Cell(
              width: _StockTableSpec.productWidth,
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: item.isCritical
                          ? AppColors.errorLight.withValues(
                              alpha: AppColors.isTraining(context) ? 0.18 : 1)
                          : item.isLowStock
                              ? AppColors.warningLight.withValues(
                                  alpha:
                                      AppColors.isTraining(context) ? 0.18 : 1)
                              : AppColors.blueSurface.withValues(
                                  alpha:
                                      AppColors.isTraining(context) ? 0.18 : 1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.inventory_2_rounded,
                      size: 20,
                      color: item.isCritical
                          ? AppColors.error
                          : item.isLowStock
                              ? AppColors.warning
                              : AppColors.blue,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      item.name,
                      style: AppTextStyles.titleLg.copyWith(
                        color: AppColors.textPrimaryFor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 4),
            _Cell(
              width: _StockTableSpec.unitWidth,
              child: Text(
                item.unit,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondaryFor(context)),
              ),
            ),
            const Spacer(flex: 1),
            _Cell(
              width: _StockTableSpec.qtyWidth,
              child: Padding(
                padding:
                    EdgeInsets.only(right: _StockTableSpec.cellRightPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      item.quantity.toStringAsFixed(item.unit == 'pcs' ? 0 : 1),
                      style: AppTextStyles.h4.copyWith(
                        color: item.isCritical
                            ? AppColors.error
                            : item.isLowStock
                                ? AppColors.warning
                                : AppColors.textPrimaryFor(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _StockLevelIndicator(item: item),
                  ],
                ),
              ),
            ),
            const Spacer(flex: 1),
            _Cell(
              width: _StockTableSpec.thresholdWidth,
              child: Text(
                '${item.minThreshold}',
                textAlign: TextAlign.right,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondaryFor(context)),
              ),
            ),
            const Spacer(flex: 1),
            _Cell(
              width: _StockTableSpec.statusWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: _StatusBadge(item: item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final StockItem item;
  const _StatusBadge({required this.item});

  @override
  Widget build(BuildContext context) {
    Color color = AppColors.success;
    String label = 'OK';
    IconData icon = Icons.check_circle_rounded;

    if (item.isCritical) {
      color = AppColors.error;
      label = 'CRITICAL';
      icon = Icons.error_rounded;
    } else if (item.isLowStock) {
      color = AppColors.warning;
      label = 'LOW STOCK';
      icon = Icons.warning_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _StockLevelIndicator extends StatelessWidget {
  final StockItem item;
  const _StockLevelIndicator({required this.item});

  @override
  Widget build(BuildContext context) {
    // Calculate percentage: quantity / (threshold * 2) capped at 1.0
    // If threshold is 0, we can't show a bar easily, so we just show a full bar if > 0
    double percent = 1.0;
    if (item.minThreshold > 0) {
      percent = (item.quantity / (item.minThreshold * 2)).clamp(0.0, 1.0);
    } else if (item.quantity == 0) {
      percent = 0.0;
    }

    Color color = AppColors.success;
    if (item.isCritical) {
      color = AppColors.error;
    } else if (item.isLowStock) {
      color = AppColors.warning;
    }

    return Container(
      width: 60,
      height: 4,
      decoration: BoxDecoration(
        color: AppColors.neutral200,
        borderRadius: BorderRadius.circular(2),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerRight,
        widthFactor: percent,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}
