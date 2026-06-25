part of '../screens/sales_screen.dart';

class _CartPanel extends ConsumerWidget {
  final VoidCallback onCheckout;
  const _CartPanel({required this.onCheckout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = context.posLayout;
    final cart = ref.watch(cartProvider);
    final isTraining = AppColors.isTraining(context);
    final canApplyDiscount =
        ref.watch(authProvider).permissions['can_apply_discount'] == true;
    final hasDiscount = cart.discountAmount > 0.001;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceFor(context),
        border: Border(left: BorderSide(color: AppColors.borderFor(context))),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: EdgeInsets.fromLTRB(
              layout.pagePadding,
              layout.pagePadding,
              layout.pagePadding,
              cart.isQrOrder
                  ? 10
                  : layout.isCompact
                      ? 14
                      : 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.surfaceFor(context),
              border: Border(
                  bottom: BorderSide(color: AppColors.borderFor(context))),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.shopping_basket_rounded,
                      color: AppColors.accentFor(context),
                      size: layout.isCompact ? 24 : 26,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      cart.isQrOrder ? 'Mobile Order' : 'Order',
                      style: AppTextStyles.h4.copyWith(
                        fontSize: layout.isCompact ? 20 : 22,
                        color: AppColors.textPrimaryFor(context),
                      ),
                    ),
                    const Spacer(),
                    if (canApplyDiscount &&
                        !cart.isLockedForQr &&
                        cart.items.isNotEmpty) ...[
                      _OrderDiscountHeaderButton(
                        percent: cart.orderDiscountPercent,
                        onPressed: () => _showOrderDiscountDialog(
                          context,
                          ref,
                          cart.orderDiscountPercent,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    if (cart.items.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.isCompact ? 12 : 14,
                          vertical: layout.isCompact ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.selectedSurfaceFor(context),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${cart.itemCount}',
                          style: AppTextStyles.titleSm.copyWith(
                              color: AppColors.selectedTextFor(context)),
                        ),
                      ),
                  ],
                ),
                if (cart.isQrOrder) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.accentSurfaceFor(context),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.accentFor(context)
                            .withValues(alpha: 0.22),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (cart.customerName != null &&
                            cart.customerName!.isNotEmpty)
                          Text(
                            cart.customerName!,
                            style: AppTextStyles.title.copyWith(
                              color: AppColors.accentFor(context),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${_salesOrderTypeLabel(cart.orderType)} • ${_salesPaymentLabel(cart.paymentType)}',
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondaryFor(context),
                          ),
                        ),
                        if (cart.ticketNumber != null &&
                            cart.ticketNumber!.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Ticket ${displayTicketNumberFrom(cart.ticketNumber!)}',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.accentFor(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          // Items
          Expanded(
            child: cart.items.isEmpty
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: BrandCheckerPainter(
                            color1: AppColors.subtlePatternFor(
                              context,
                              isTraining ? AppColors.yellow : AppColors.blue,
                            ),
                            color2: Colors.transparent,
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.shopping_basket_outlined,
                              size: 52,
                              color: isTraining
                                  ? AppColors.neutral500
                                  : AppColors.neutral300,
                            ),
                            const SizedBox(height: 12),
                            Text('Cart is empty',
                                style: AppTextStyles.body.copyWith(
                                    color:
                                        AppColors.textSecondaryFor(context))),
                            const SizedBox(height: 4),
                            Text('Tap a product or scan a customer QR',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.textSecondaryFor(context),
                                )),
                          ],
                        ),
                      ),
                    ],
                  )
                : Builder(builder: (context) {
                    final itemGroups = groupCartItemsForDisplay(cart.items);
                    return ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      itemCount: itemGroups.length,
                      separatorBuilder: (_, __) => Divider(
                          height: 1,
                          indent: 14,
                          endIndent: 14,
                          color: AppColors.borderFor(context)),
                      itemBuilder: (ctx, i) {
                        final group = itemGroups[i];
                        return _CartItemTile(
                          index: group.itemIndex,
                          item: group.item,
                          components: group.components,
                          readonly: cart.isLockedForQr,
                          importedOrderNote: cart.isQrOrder && i == 0
                              ? cart.customerNote?.trim()
                              : null,
                        );
                      },
                    );
                  }),
          ),
          // Footer
          if (cart.items.isNotEmpty)
            Container(
              padding: EdgeInsets.all(layout.pagePadding),
              decoration: BoxDecoration(
                color: AppColors.surfaceFor(context),
                border: Border(
                    top: BorderSide(color: AppColors.borderFor(context))),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(hasDiscount ? 'Subtotal' : 'Total',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondaryFor(context),
                          )),
                      Text(
                          '${(hasDiscount ? cart.originalSubtotal : cart.subtotal).toStringAsFixed(3)} DT',
                          style: AppTextStyles.title.copyWith(
                            color: AppColors.accentFor(context),
                            fontSize: 18,
                          )),
                    ],
                  ),
                  if (cart.itemDiscountAmount > 0.001) ...[
                    const SizedBox(height: 6),
                    _CartSummaryLine(
                      label: 'Item discounts',
                      value:
                          '-${cart.itemDiscountAmount.toStringAsFixed(3)} DT',
                      color: AppColors.success,
                    ),
                  ],
                  if (cart.orderDiscountAmount > 0.001) ...[
                    const SizedBox(height: 6),
                    _CartSummaryLine(
                      label:
                          'Order discount ${cart.orderDiscountPercent!.toStringAsFixed(0)}%',
                      value:
                          '-${cart.orderDiscountAmount.toStringAsFixed(3)} DT',
                      color: AppColors.success,
                    ),
                  ],
                  if (hasDiscount) ...[
                    const SizedBox(height: 8),
                    _CartSummaryLine(
                      label: 'Total',
                      value: '${cart.subtotal.toStringAsFixed(3)} DT',
                      color: AppColors.accentFor(context),
                      isStrong: true,
                    ),
                  ],
                  const SizedBox(height: 12),
                  // Clear
                  SizedBox(
                    width: double.infinity,
                    height: layout.touchTarget,
                    child: OutlinedButton.icon(
                      onPressed: () => ref.read(cartProvider.notifier).clear(),
                      icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                      label: Text(cart.isQrOrder
                          ? 'Clear Imported Order'
                          : 'Clear Order'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // YELLOW checkout — big touch target
                  SizedBox(
                    width: double.infinity,
                    height: layout.touchTarget + 4,
                    child: ElevatedButton(
                      onPressed: onCheckout,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.yellow,
                        foregroundColor: AppColors.blue,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        elevation: 0,
                        textStyle: AppTextStyles.buttonLg.copyWith(
                          fontSize: layout.isCompact ? 18 : 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            cart.isQrOrder
                                ? Icons.check_circle_rounded
                                : Icons.payment_rounded,
                            size: layout.isCompact ? 22 : 24,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            cart.isQrOrder
                                ? 'Confirm ${cart.subtotal.toStringAsFixed(3)} DT'
                                : 'Pay ${cart.subtotal.toStringAsFixed(3)} DT',
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  void _showOrderDiscountDialog(
    BuildContext context,
    WidgetRef ref,
    double? current,
  ) {
    double value = current ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Apply Order Discount'),
          content: SizedBox(
            width: context.posLayout.dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${value.toStringAsFixed(0)}%',
                    style: AppTextStyles.priceLg.copyWith(
                      color: AppColors.accentFor(ctx),
                    )),
                Slider(
                  value: value,
                  min: 0,
                  max: 30,
                  divisions: 30,
                  activeColor: AppColors.yellow,
                  onChanged: (v) => setState(() => value = v),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [5, 10, 15, 20, 25, 30]
                      .map(
                        (p) => ActionChip(
                          label: Text('$p%'),
                          onPressed: () => setState(() => value = p.toDouble()),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            if (current != null)
              TextButton(
                onPressed: () {
                  ref.read(cartProvider.notifier).updateOrderDiscount(null);
                  Navigator.pop(ctx);
                },
                child: const Text(
                  'Remove',
                  style: TextStyle(color: AppColors.error),
                ),
              ),
            ElevatedButton(
              onPressed: () {
                ref.read(cartProvider.notifier).updateOrderDiscount(
                      value > 0 ? value : null,
                    );
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}

class _OrderDiscountHeaderButton extends StatelessWidget {
  final double? percent;
  final VoidCallback onPressed;

  const _OrderDiscountHeaderButton({
    required this.percent,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final active = percent != null && percent! > 0;
    final showText = active || !layout.isCompact;
    final color = active ? AppColors.success : AppColors.accentFor(context);
    final radius = BorderRadius.circular(14);

    return Tooltip(
      message: active
          ? 'Order discount ${percent!.toStringAsFixed(0)}%'
          : 'Apply order discount',
      child: Material(
        color: (active ? AppColors.success : AppColors.accentFor(context))
            .withValues(alpha: active ? 0.12 : 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(
            color: color.withValues(alpha: active ? 0.55 : 0.25),
          ),
        ),
        child: InkWell(
          onTap: onPressed,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: layout.isCompact ? 38 : 40,
              minWidth: layout.isCompact ? 40 : 44,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: showText ? 10 : 0),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.local_offer_rounded, size: 18, color: color),
                  if (showText) ...[
                    const SizedBox(width: 6),
                    Text(
                      active ? '${percent!.toStringAsFixed(0)}%' : 'Discount',
                      style: AppTextStyles.label.copyWith(
                        color: color,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CartSummaryLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final bool isStrong;

  const _CartSummaryLine({
    required this.label,
    required this.value,
    required this.color,
    this.isStrong = false,
  });

  @override
  Widget build(BuildContext context) {
    final textStyle = isStrong ? AppTextStyles.title : AppTextStyles.bodySm;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: textStyle.copyWith(
            color: isStrong ? AppColors.textPrimaryFor(context) : color,
          ),
        ),
        Text(
          value,
          style: textStyle.copyWith(
            color: color,
            fontWeight: isStrong ? FontWeight.w900 : FontWeight.w800,
          ),
        ),
      ],
    );
  }
}
