part of '../screens/today_sales_screen.dart';

class _OrdersTable extends ConsumerWidget {
  final List<Order> orders;
  const _OrdersTable({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final metrics = _TodaySalesTableMetrics.forWidth(
          constraints.maxWidth,
        );

        return SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: metrics.horizontalPadding,
                  vertical: metrics.headerVerticalPadding,
                ),
                color: AppColors.tableHeaderFor(context),
                child: Row(
                  children: [
                    _Cell(width: metrics.dateWidth, child: _HeaderCell('Date')),
                    _TableGap(metrics),
                    _Cell(
                        width: metrics.ticketWidth,
                        child: _HeaderCell('Ticket #')),
                    _TableGap(metrics),
                    _Cell(
                        width: metrics.itemsWidth, child: _HeaderCell('Items')),
                    _TableGap(metrics),
                    _Cell(
                        width: metrics.amountWidth,
                        child: _HeaderCell('Amount', align: TextAlign.right)),
                    _TableGap(metrics),
                    _Cell(
                        width: metrics.paymentWidth,
                        child: _HeaderCell('Payment', align: TextAlign.center)),
                    _TableGap(metrics),
                    _Cell(
                        width: metrics.statusWidth,
                        child: _HeaderCell('Status', align: TextAlign.center)),
                    _TableGap(metrics),
                    _Cell(
                        width: metrics.actionsWidth,
                        child: _HeaderCell('Actions', align: TextAlign.center)),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.borderFor(context)),
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: orders.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: AppColors.borderFor(context)),
                  itemBuilder: (ctx, i) =>
                      _OrderRow(order: orders[i], metrics: metrics),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TableGap extends StatelessWidget {
  final _TodaySalesTableMetrics metrics;

  const _TableGap(this.metrics);

  @override
  Widget build(BuildContext context) => SizedBox(width: metrics.columnGap);
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

class _HeaderCell extends StatelessWidget {
  final String label;
  final TextAlign align;

  const _HeaderCell(this.label, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTextStyles.label.copyWith(
        color: AppColors.textSecondaryFor(context),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _OrderRow extends ConsumerWidget {
  final Order order;
  final _TodaySalesTableMetrics metrics;

  const _OrderRow({required this.order, required this.metrics});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCancelled = order.status == OrderStatus.cancelled;
    final rowColor = isCancelled
        ? AppColors.errorLight.withValues(
            alpha: AppColors.isTraining(context) ? 0.12 : 0.2,
          )
        : AppColors.surfaceFor(context);
    final canCancelOrder =
        ref.watch(authProvider).permissions['can_cancel_order'] == true;

    return InkWell(
      onTap: () => _showOrderDetails(context, order),
      child: Container(
        color: rowColor,
        padding: EdgeInsets.symmetric(
          horizontal: metrics.horizontalPadding,
          vertical: metrics.rowVerticalPadding,
        ),
        child: Row(
          children: [
            _Cell(
              width: metrics.dateWidth,
              child: Text(
                DateFormat('dd/MM HH:mm').format(order.createdAt),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondaryFor(context),
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            _TableGap(metrics),
            _Cell(
              width: metrics.ticketWidth,
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      order.displayTicketNumber,
                      style: AppTextStyles.h4.copyWith(
                          color: AppColors.blue, fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (order.isQrOrder) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.qr_code_2_rounded,
                        size: 14, color: AppColors.blue),
                  ],
                ],
              ),
            ),
            _TableGap(metrics),
            _Cell(
              width: metrics.itemsWidth,
              child: _OrderItemsSummary(items: order.items),
            ),
            _TableGap(metrics),
            _Cell(
              width: metrics.amountWidth,
              child: Align(
                alignment: Alignment.centerRight,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${order.total.toStringAsFixed(3)} DT',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.price.copyWith(
                      color:
                          isCancelled ? AppColors.textDisabled : AppColors.blue,
                      decoration:
                          isCancelled ? TextDecoration.lineThrough : null,
                      decorationColor: AppColors.error,
                      decorationThickness: 2,
                    ),
                  ),
                ),
              ),
            ),
            _TableGap(metrics),
            _Cell(
              width: metrics.paymentWidth,
              child: Align(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: PaymentTypeChip(type: order.paymentType),
                ),
              ),
            ),
            _TableGap(metrics),
            _Cell(
              width: metrics.statusWidth,
              child: Align(
                alignment: Alignment.center,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: StatusChip(status: order.status),
                ),
              ),
            ),
            _TableGap(metrics),
            _Cell(
              width: metrics.actionsWidth,
              child: Align(
                alignment: Alignment.center,
                child: order.status == OrderStatus.validated && canCancelOrder
                    ? ElevatedButton(
                        onPressed: () => _showCancelDialog(context, ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          minimumSize: const Size(104, 42),
                          tapTargetSize: MaterialTapTargetSize.padded,
                          padding: EdgeInsets.symmetric(
                            horizontal: metrics.compact ? 14 : 18,
                            vertical: metrics.compact ? 11 : 12,
                          ),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTextStyles.labelSm.copyWith(
                            color: AppColors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                    : order.cancellationReason != null
                        ? Tooltip(
                            message: 'Reason: ${order.cancellationReason}',
                            child: const Icon(Icons.info_outline_rounded,
                                size: 18, color: AppColors.neutral400),
                          )
                        : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showOrderDetails(BuildContext context, Order order) {
    showDialog(
      context: context,
      builder: (ctx) => _SaleDetailsModal(order: order),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.warning_rounded, color: AppColors.error),
            const SizedBox(width: 8),
            Text('Cancel Order ${order.displayTicketNumber}'),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Total: ${order.total.toStringAsFixed(3)} DT',
                  style: AppTextStyles.title.copyWith(color: AppColors.blue)),
              const SizedBox(height: 4),
              Text(
                  'This action cannot be reversed. Stock will not be affected.',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              Text('Cancellation Reason *', style: AppTextStyles.label),
              const SizedBox(height: 6),
              TextField(
                controller: ctrl,
                maxLines: 3,
                autofocus: true,
                decoration: const InputDecoration(
                    hintText: 'Enter the reason for cancellation...'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Keep Order')),
          ElevatedButton(
            onPressed: () {
              if (ctrl.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('Reason is required'),
                      backgroundColor: AppColors.error),
                );
                return;
              }
              ref
                  .read(ordersProvider.notifier)
                  .cancelOrder(order.id, ctrl.text.trim());
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content:
                        Text('Order ${order.displayTicketNumber} cancelled'),
                    backgroundColor: AppColors.warning),
              );
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Cancel Order'),
          ),
        ],
      ),
    );
  }
}

class _OrderItemsSummary extends StatelessWidget {
  final List<CartItem> items;
  const _OrderItemsSummary({required this.items});

  @override
  Widget build(BuildContext context) {
    final itemGroups = groupCartItemsForDisplay(items);
    if (itemGroups.isEmpty) {
      return Text(
        'No item details',
        style: AppTextStyles.body.copyWith(
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    if (itemGroups.length <= 1) {
      final group = itemGroups.first;
      final item = group.item;
      return Text(
        group.components.isEmpty
            ? '${item.quantity}x ${item.displayName}'
            : '${item.displayName} - ${group.components.map((component) => '${component.quantity}x ${component.displayName}').join(', ')}',
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          itemGroups.first.components.isEmpty
              ? '${itemGroups.first.item.quantity}x ${itemGroups.first.item.displayName} ...'
              : '${itemGroups.first.item.displayName} ...',
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.blueSurface,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '+ ${itemGroups.length - 1} more items',
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.blue, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long_rounded,
            size: 64,
            color: AppColors.isTraining(context)
                ? AppColors.neutral500
                : AppColors.neutral300,
          ),
          const SizedBox(height: 16),
          Text('No sales today yet',
              style: AppTextStyles.h4
                  .copyWith(color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
          Text('Orders will appear here once sales are processed.',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondaryFor(context))),
        ],
      ),
    );
  }
}
