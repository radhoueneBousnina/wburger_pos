part of '../screens/sales_screen.dart';

class _CartPanel extends ConsumerWidget {
  final VoidCallback onCheckout;
  const _CartPanel({required this.onCheckout});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = context.posLayout;
    final cart = ref.watch(cartProvider);
    final isTraining = AppColors.isTraining(context);

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
                      color: AppColors.blue,
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
                    if (cart.items.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: layout.isCompact ? 12 : 14,
                          vertical: layout.isCompact ? 6 : 8,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.blue,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          '${cart.itemCount}',
                          style: AppTextStyles.titleSm
                              .copyWith(color: AppColors.white),
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
                      color: AppColors.blueSurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.blue.withValues(alpha: 0.18),
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
                              color: AppColors.blue,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          '${cart.orderType == OrderType.dineIn ? 'Dine In' : 'Takeaway'} • ${_salesPaymentLabel(cart.paymentType)}',
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
                              color: AppColors.blue,
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
                      Text(cart.isQrOrder ? 'Total' : 'Subtotal',
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondaryFor(context),
                          )),
                      Text('${cart.subtotal.toStringAsFixed(3)} DT',
                          style: AppTextStyles.title
                              .copyWith(color: AppColors.blue, fontSize: 18)),
                    ],
                  ),
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
}
