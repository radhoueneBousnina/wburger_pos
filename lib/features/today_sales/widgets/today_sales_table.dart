part of '../screens/today_sales_screen.dart';

class _OrdersTable extends ConsumerWidget {
  final List<Order> orders;
  const _OrdersTable({required this.orders});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spec = _TodaySalesTableSpec();
        final tableWidth = constraints.maxWidth > spec.minWidth
            ? constraints.maxWidth
            : spec.minWidth;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: tableWidth,
            height: constraints.maxHeight,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _TodaySalesTableSpec.horizontalPadding,
                    vertical: 18,
                  ),
                  color: AppColors.tableHeaderFor(context),
                  child: Row(
                    children: [
                      _Cell(
                          width: _TodaySalesTableSpec.dateWidth,
                          child: _HeaderCell('Date')),
                      Spacer(flex: 1),
                      _Cell(
                          width: _TodaySalesTableSpec.ticketWidth,
                          child: _HeaderCell('Ticket #')),
                      Spacer(flex: 1),
                      _Cell(
                          width: _TodaySalesTableSpec.itemsWidth,
                          child: _HeaderCell('Items')),
                      Spacer(flex: 1),
                      _Cell(
                          width: _TodaySalesTableSpec.amountWidth,
                          child: _HeaderCell('Amount', align: TextAlign.right)),
                      Spacer(flex: 1),
                      _Cell(
                          width: _TodaySalesTableSpec.paymentWidth,
                          child:
                              _HeaderCell('Payment', align: TextAlign.center)),
                      Spacer(flex: 1),
                      _Cell(
                          width: _TodaySalesTableSpec.statusWidth,
                          child: _HeaderCell('Status')),
                      Spacer(flex: 1),
                      _Cell(
                          width: _TodaySalesTableSpec.actionsWidth,
                          child:
                              _HeaderCell('Actions', align: TextAlign.center)),
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
                    itemBuilder: (ctx, i) => _OrderRow(order: orders[i]),
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

class _HeaderCell extends StatelessWidget {
  final String label;
  final TextAlign align;

  const _HeaderCell(this.label, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: AppTextStyles.label.copyWith(
        color: AppColors.textSecondaryFor(context),
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _OrderRow extends ConsumerWidget {
  final Order order;
  const _OrderRow({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = context.posLayout;
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
          horizontal: _TodaySalesTableSpec.horizontalPadding,
          vertical: layout.isCompact ? 16 : 22,
        ),
        child: Row(
          children: [
            _Cell(
              width: _TodaySalesTableSpec.dateWidth,
              child: Text(
                DateFormat('dd/MM HH:mm').format(order.createdAt),
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondaryFor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Spacer(flex: 1),
            _Cell(
              width: _TodaySalesTableSpec.ticketWidth,
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
            const Spacer(flex: 1),
            _Cell(
              width: _TodaySalesTableSpec.itemsWidth,
              child: _OrderItemsSummary(items: order.items),
            ),
            const Spacer(flex: 1),
            _Cell(
              width: _TodaySalesTableSpec.amountWidth,
              child: Text(
                '${order.total.toStringAsFixed(3)} DT',
                textAlign: TextAlign.right,
                style: AppTextStyles.price.copyWith(
                  color: isCancelled ? AppColors.textDisabled : AppColors.blue,
                  decoration: isCancelled ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.error,
                  decorationThickness: 2,
                ),
              ),
            ),
            const Spacer(flex: 1),
            _Cell(
              width: _TodaySalesTableSpec.paymentWidth,
              child: Align(
                alignment: Alignment.center,
                child: PaymentTypeChip(type: order.paymentType),
              ),
            ),
            const Spacer(flex: 1),
            _Cell(
              width: _TodaySalesTableSpec.statusWidth,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusChip(status: order.status),
              ),
            ),
            const Spacer(flex: 1),
            _Cell(
              width: _TodaySalesTableSpec.actionsWidth,
              child: Align(
                alignment: Alignment.center,
                child: order.status == OrderStatus.validated && canCancelOrder
                    ? ElevatedButton(
                        onPressed: () => _showCancelDialog(context, ref),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          foregroundColor: AppColors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel'),
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
    if (items.isEmpty) {
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

    if (items.length <= 1) {
      final item = items.first;
      return Text(
        '${item.quantity}x ${item.product.name}',
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${items.first.quantity}x ${items.first.product.name} ...',
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
            '+ ${items.length - 1} more items',
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
