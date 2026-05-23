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
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.isSuccess
                ? result.message
                : 'Could not re-print ticket: ${result.message}',
          ),
          backgroundColor:
              result.isSuccess ? AppColors.success : AppColors.warning,
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
            color: AppColors.white,
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
      color: AppColors.blue,
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
                      icon: order.orderType == OrderType.dineIn
                          ? Icons.restaurant_rounded
                          : Icons.shopping_bag_rounded,
                      label: order.orderType == OrderType.dineIn
                          ? 'Dine In'
                          : 'Takeaway',
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
        value:
            '${order.items.fold<int>(0, (sum, item) => sum + item.quantity)}',
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
        color: AppColors.neutral50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
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
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${order.total.toStringAsFixed(3)} DT',
                      style: AppTextStyles.h1.copyWith(
                        color: AppColors.blue,
                        fontSize: compact ? 28 : 34,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '#${order.displayTicketNumber}',
                style: AppTextStyles.title.copyWith(
                  color: AppColors.textSecondary,
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
      color: AppColors.blue,
      background: AppColors.blueSurface,
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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
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
                const Icon(
                  Icons.fastfood_rounded,
                  color: AppColors.blue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text('Ordered items', style: AppTextStyles.titleLg),
                const Spacer(),
                Text(
                  '${order.items.length} line${order.items.length == 1 ? '' : 's'}',
                  style: AppTextStyles.label.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          if (order.items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(18),
              child: Text(
                'No item details available for this order.',
                style: AppTextStyles.body.copyWith(
                  color: AppColors.textSecondary,
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
              border: const TableBorder(
                horizontalInside: BorderSide(color: AppColors.border),
                bottom: BorderSide(color: AppColors.border),
                top: BorderSide(color: AppColors.border),
              ),
              defaultVerticalAlignment: TableCellVerticalAlignment.middle,
              children: [
                TableRow(
                  decoration: const BoxDecoration(color: AppColors.neutral50),
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
                for (final item in order.items)
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
                              color: AppColors.yellowSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color:
                                      AppColors.yellow.withValues(alpha: 0.5)),
                            ),
                            child: Text(
                              'x${item.quantity}',
                              style: AppTextStyles.title.copyWith(
                                color: AppColors.blue,
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
                              item.product.name,
                              style: AppTextStyles.title
                                  .copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${item.unitPrice.toStringAsFixed(3)} DT each',
                              style: AppTextStyles.bodySm.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (item.note?.trim().isNotEmpty == true) ...[
                              const SizedBox(height: 4),
                              Text(
                                item.note!.trim(),
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.textSecondary,
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
                            '${item.total.toStringAsFixed(3)} DT',
                            style: AppTextStyles.price
                                .copyWith(fontSize: compact ? 16 : 18),
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
      decoration: const BoxDecoration(
        color: AppColors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          Text(
            'Total',
            style: AppTextStyles.h3.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '${order.total.toStringAsFixed(3)} DT',
              textAlign: TextAlign.right,
              style: AppTextStyles.h2.copyWith(
                color: AppColors.blue,
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
                backgroundColor: AppColors.blue,
                foregroundColor: AppColors.white,
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.22)),
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
                    color: AppColors.textPrimary,
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
      shadowColor: AppColors.neutral300.withValues(alpha: 0.5),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      color: AppColors.white,
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(data.icon, color: AppColors.blue, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.label,
                    style: AppTextStyles.label.copyWith(
                      color: AppColors.textSecondary,
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
                color: AppColors.textPrimary,
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
        color: AppColors.textSecondary,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
