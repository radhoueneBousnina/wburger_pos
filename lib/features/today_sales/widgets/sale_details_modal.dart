part of '../screens/today_sales_screen.dart';

class _SaleDetailsModal extends ConsumerWidget {
  final Order order;
  const _SaleDetailsModal({required this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screen = MediaQuery.sizeOf(context);
    final layout = context.posLayout;
    final compact = screen.width < 820 || layout.isCompact;
    final modalWidth = (screen.width - (compact ? 24 : 72)).clamp(360.0, 780.0);
    final modalHeight = (screen.height - (compact ? 24 : 56)).clamp(
      560.0,
      screen.height * 0.92,
    );
    final contentPadding = compact ? 16.0 : 22.0;
    final contentWidth = modalWidth - (contentPadding * 2);

    Future<void> reprintReceipt() async {
      final messenger = ScaffoldMessenger.of(context);
      final navigator = Navigator.of(context);
      final receiptData = ReceiptData.fromOrder(
        order,
        cashierName: ref.read(authProvider).username,
        isReprint: true,
      );
      final result =
          await ReceiptPrinterService.instance.printReceipt(receiptData);
      if (!context.mounted) return;
      navigator.pop();
      if (result.isSuccess) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not re-print ticket: ${result.message}'),
          backgroundColor: AppColors.warning,
        ),
      );
    }

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 36,
        vertical: compact ? 12 : 28,
      ),
      backgroundColor: Colors.transparent,
      child: SizedBox(
        width: modalWidth,
        height: modalHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(compact ? 20 : 28),
          child: Material(
            color: AppColors.panelFor(context),
            child: Column(
              children: [
                _OrderDetailsHeader(order: order, compact: compact),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      contentPadding,
                      compact ? 14 : 18,
                      contentPadding,
                      compact ? 10 : 14,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        width: contentWidth,
                        child: _OrderDetailsContent(
                          order: order,
                          compact: compact,
                        ),
                      ),
                    ),
                  ),
                ),
                _OrderDetailsFooter(
                  order: order,
                  compact: compact,
                  onReprint: reprintReceipt,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderDetailsHeader extends StatelessWidget {
  final Order order;
  final bool compact;

  const _OrderDetailsHeader({
    required this.order,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 24,
        compact ? 16 : 22,
        compact ? 10 : 16,
        compact ? 16 : 22,
      ),
      color: AppColors.modalHeaderFor(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: compact ? 44 : 52,
            height: compact ? 44 : 52,
            decoration: BoxDecoration(
              color: AppColors.yellow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.receipt_long_rounded,
              color: AppColors.blue,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Order ${order.displayTicketNumber}',
                  style: AppTextStyles.h2.copyWith(
                    color: AppColors.white,
                    fontSize: compact ? 22 : 26,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  DateFormat('EEEE, dd MMM yyyy - HH:mm')
                      .format(order.createdAt),
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.white.withValues(alpha: 0.75),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    StatusChip(status: order.status),
                    PaymentTypeChip(type: order.paymentType),
                    _SoftChip(
                      icon: order.isQrOrder
                          ? Icons.qr_code_2_rounded
                          : Icons.point_of_sale_rounded,
                      label: order.isQrOrder ? 'Mobile QR' : 'POS Sale',
                    ),
                    _SoftChip(
                      icon: _todaySaleOrderTypeIcon(order.orderType),
                      label: _todaySaleOrderTypeLabel(order.orderType),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close_rounded),
            color: AppColors.white,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.white.withValues(alpha: 0.12),
              padding: EdgeInsets.all(compact ? 10 : 12),
            ),
          ),
        ],
      ),
    );
  }
}

String _todaySaleOrderTypeLabel(OrderType type) {
  switch (type) {
    case OrderType.dineIn:
      return 'Dine In';
    case OrderType.takeaway:
      return 'Takeaway';
    case OrderType.glovo:
      return 'Glovo';
  }
}

IconData _todaySaleOrderTypeIcon(OrderType type) {
  switch (type) {
    case OrderType.dineIn:
      return Icons.restaurant_rounded;
    case OrderType.takeaway:
      return Icons.shopping_bag_rounded;
    case OrderType.glovo:
      return Icons.delivery_dining_rounded;
  }
}

class _OrderDetailsContent extends StatelessWidget {
  final Order order;
  final bool compact;

  const _OrderDetailsContent({
    required this.order,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final cancelledReason = order.cancellationReason?.trim();
    final giftRecipient = order.giftRecipient?.trim();
    final hasCustomerInfo = order.customerName?.trim().isNotEmpty == true ||
        order.customerPhone?.trim().isNotEmpty == true ||
        order.customerNote?.trim().isNotEmpty == true;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _OrderTotalsPanel(order: order, compact: compact),
        if (order.status == OrderStatus.cancelled &&
            cancelledReason != null &&
            cancelledReason.isNotEmpty) ...[
          const SizedBox(height: 12),
          _NoticePanel(
            icon: Icons.cancel_rounded,
            title: 'Cancelled order',
            message: cancelledReason,
            color: AppColors.error,
            background: AppColors.errorLight,
          ),
        ],
        if (hasCustomerInfo) ...[
          const SizedBox(height: 12),
          _CustomerPanel(order: order),
        ],
        if (order.paymentType == PaymentType.gift &&
            giftRecipient != null &&
            giftRecipient.isNotEmpty) ...[
          const SizedBox(height: 12),
          _NoticePanel(
            icon: Icons.card_giftcard_rounded,
            title: 'Gift order',
            message: giftRecipient,
            color: AppColors.success,
            background: AppColors.successLight,
          ),
        ],
        const SizedBox(height: 14),
        _ItemsSection(order: order, compact: compact),
      ],
    );
  }
}

class _OrderTotalsPanel extends StatelessWidget {
  final Order order;
  final bool compact;

  const _OrderTotalsPanel({
    required this.order,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final infoCards = [
      _InfoTileData(
        icon: Icons.shopping_cart_checkout_rounded,
        label: 'Items',
        value: '${displayQuantityForCartItems(order.items)}',
      ),
      _InfoTileData(
        icon: Icons.discount_rounded,
        label: 'Discount',
        value: '${order.discountAmount.toStringAsFixed(3)} DT',
      ),
      _InfoTileData(
        icon: Icons.payments_rounded,
        label: 'Paid',
        value: order.amountGiven > 0
            ? '${order.amountGiven.toStringAsFixed(3)} DT'
            : '-',
      ),
      _InfoTileData(
        icon: Icons.keyboard_return_rounded,
        label: 'Change',
        value: order.changeReturned > 0
            ? '${order.changeReturned.toStringAsFixed(3)} DT'
            : '-',
      ),
    ];

    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.elevatedSurfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total amount',
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textSecondaryFor(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.total.toStringAsFixed(3)} DT',
                      style: AppTextStyles.h1.copyWith(
                        color: AppColors.accentFor(context),
                        fontSize: compact ? 28 : 34,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '#${order.displayTicketNumber}',
                style: AppTextStyles.title.copyWith(
                  color: AppColors.textSecondaryFor(context),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (var i = 0; i < infoCards.length; i++) ...[
                Expanded(child: _InfoTile(data: infoCards[i])),
                if (i != infoCards.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CustomerPanel extends StatelessWidget {
  final Order order;

  const _CustomerPanel({required this.order});

  @override
  Widget build(BuildContext context) {
    return _NoticePanel(
      icon: Icons.person_rounded,
      title: [
        order.customerName?.trim(),
        order.customerPhone?.trim(),
      ].where((part) => part != null && part.isNotEmpty).join(' - '),
      message: order.customerNote?.trim().isNotEmpty == true
          ? order.customerNote!.trim()
          : 'Mobile customer information attached to this order.',
      color: AppColors.accentFor(context),
      background: AppColors.accentSurfaceFor(context),
    );
  }
}

class _ItemsSection extends StatelessWidget {
  final Order order;
  final bool compact;

  const _ItemsSection({
    required this.order,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final itemGroups = groupCartItemsForDisplay(order.items);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.panelFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 14 : 18,
              compact ? 12 : 14,
              compact ? 14 : 18,
              compact ? 8 : 10,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.fastfood_rounded,
                  color: AppColors.accentFor(context),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Ordered items',
                  style: AppTextStyles.titleLg.copyWith(
                    color: AppColors.textPrimaryFor(context),
                  ),
                ),
                const Spacer(),
                Text(
                  '${itemGroups.length} line${itemGroups.length == 1 ? '' : 's'}',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondaryFor(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (itemGroups.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'No item details available for this order.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondaryFor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            Table(
              columnWidths: const {
                0: FixedColumnWidth(70),
                1: FlexColumnWidth(1),
                2: FixedColumnWidth(120),
              },
              border: TableBorder(
                horizontalInside:
                    BorderSide(color: AppColors.borderFor(context)),
                bottom: BorderSide(color: AppColors.borderFor(context)),
                top: BorderSide(color: AppColors.borderFor(context)),
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration:
                      BoxDecoration(color: AppColors.tableHeaderFor(context)),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: _ItemsHeader('Qty'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: _ItemsHeader('Item'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      child: _ItemsHeader('Total', align: TextAlign.right),
                    ),
                  ],
                ),
                for (final group in itemGroups)
                  TableRow(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 14,
                            vertical: compact ? 8 : 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Container(
                            width: 44,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.accentSurfaceFor(context),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.accentFor(context)
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                            child: Text(
                              group.components.isEmpty
                                  ? 'x${group.item.quantity}'
                                  : '',
                              style: AppTextStyles.title.copyWith(
                                color: AppColors.accentFor(context),
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 14,
                            vertical: compact ? 8 : 12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              group.item.product.name,
                              style: AppTextStyles.title.copyWith(
                                color: AppColors.textPrimaryFor(context),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${group.item.unitPrice.toStringAsFixed(3)} DT each',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.textSecondaryFor(context),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            for (final component in group.components) ...[
                              const SizedBox(height: 4),
                              Text(
                                '- ${component.quantity}x ${component.product.name}',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.textPrimaryFor(context),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              if (component.note?.trim().isNotEmpty ==
                                  true) ...[
                                const SizedBox(height: 2),
                                Text(
                                  '  ${component.note!.trim()}',
                                  style: AppTextStyles.bodySm.copyWith(
                                    color: AppColors.textSecondaryFor(context),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                            if (group.item.note?.trim().isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                group.item.note!.trim(),
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.textSecondaryFor(context),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: compact ? 10 : 14,
                            vertical: compact ? 8 : 12),
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: Text(
                            '${group.item.total.toStringAsFixed(3)} DT',
                            style: AppTextStyles.price.copyWith(
                              color: AppColors.accentFor(context),
                              fontSize: compact ? 16 : 18,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _OrderDetailsFooter extends StatelessWidget {
  final Order order;
  final bool compact;
  final VoidCallback onReprint;

  const _OrderDetailsFooter({
    required this.order,
    required this.compact,
    required this.onReprint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 18),
      decoration: BoxDecoration(
        color: AppColors.panelFor(context),
        border: Border(
          top: BorderSide(color: AppColors.borderFor(context)),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Total',
            style: AppTextStyles.h3.copyWith(
              color: AppColors.textSecondaryFor(context),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${order.total.toStringAsFixed(3)} DT',
              textAlign: TextAlign.right,
              style: AppTextStyles.h2.copyWith(
                color: AppColors.accentFor(context),
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: compact ? 180 : 220,
            height: context.posLayout.touchTarget,
            child: ElevatedButton.icon(
              onPressed: onReprint,
              icon: const Icon(Icons.print_rounded),
              label: const Text('Re-print Ticket'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentFor(context),
                foregroundColor: AppColors.onAccentFor(context),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final Color color;
  final Color background;

  const _NoticePanel({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final isTraining = AppColors.isTraining(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isTraining
            ? color.withValues(alpha: 0.14)
            : background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty ? 'Customer details' : title,
                  style: AppTextStyles.title.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textPrimaryFor(context),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SoftChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _SoftChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: AppColors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.white),
          const SizedBox(width: 5),
          Text(
            label,
            style: AppTextStyles.labelSm.copyWith(
              color: AppColors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTileData {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTileData({
    required this.icon,
    required this.label,
    required this.value,
  });
}

class _InfoTile extends StatelessWidget {
  final _InfoTileData data;

  const _InfoTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shadowColor: AppColors.isTraining(context)
          ? Colors.black.withValues(alpha: 0.28)
          : AppColors.neutral300.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: AppColors.borderFor(context)),
      ),
      color: AppColors.panelFor(context),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(data.icon, color: AppColors.accentFor(context), size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.label,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondaryFor(context),
                      fontWeight: FontWeight.w800,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              data.value,
              style: AppTextStyles.h3.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimaryFor(context),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class _ItemsHeader extends StatelessWidget {
  final String label;
  final TextAlign align;

  const _ItemsHeader(this.label, {this.align = TextAlign.left});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: AppTextStyles.label.copyWith(
        color: AppColors.textSecondaryFor(context),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
