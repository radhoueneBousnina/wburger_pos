part of '../screens/sales_screen.dart';

class _CartItemTile extends ConsumerWidget {
  final int index;
  final CartItem item;
  final List<CartItem> components;
  final bool readonly;
  final String? importedOrderNote;

  const _CartItemTile({
    required this.index,
    required this.item,
    this.components = const [],
    this.readonly = false,
    this.importedOrderNote,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = context.posLayout;
    final cart = ref.read(cartProvider.notifier);
    final canApplyDiscount =
        ref.watch(authProvider).permissions['can_apply_discount'] == true;
    final effectiveNote = item.note?.trim().isNotEmpty == true
        ? item.note!.trim()
        : (importedOrderNote?.isNotEmpty == true ? importedOrderNote : null);
    final hasComponents = components.isNotEmpty;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: layout.isCompact ? 12 : 16,
        vertical: layout.isCompact ? 10 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (readonly && hasComponents)
                SizedBox(width: layout.isCompact ? 42 : 46)
              else if (!readonly)
                _QtyBtn(
                  icon: Icons.remove_rounded,
                  onTap: () => cart.updateQuantity(index, item.quantity - 1),
                )
              else
                _ReadonlyQtyBadge(quantity: item.quantity),
              if (!readonly)
                Container(
                  width: layout.isCompact ? 30 : 34,
                  alignment: Alignment.center,
                  child: Text(
                    '${item.quantity}',
                    style: AppTextStyles.title.copyWith(
                      fontSize: layout.isCompact ? 16 : 18,
                      color: AppColors.textPrimaryFor(context),
                    ),
                  ),
                ),
              if (!readonly)
                _QtyBtn(
                  icon: Icons.add_rounded,
                  onTap: () => cart.updateQuantity(index, item.quantity + 1),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.displayName,
                        style: AppTextStyles.titleSm.copyWith(
                          color: AppColors.textPrimaryFor(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),
                    if (item.isMealUpgrade)
                      Text(
                        'Includes ${item.mealSodaProduct?.name ?? 'soda'} • +${item.mealAddOnPrice.toStringAsFixed(3)} DT',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondaryFor(context),
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (hasComponents)
                      for (final component in components)
                        _DealComponentLine(component: component),
                    if (effectiveNote != null)
                      Text(
                        effectiveNote,
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.textSecondaryFor(context),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (item.discountPercent != null)
                      Text('🏷 -${item.discountPercent!.toStringAsFixed(0)}%',
                          style: AppTextStyles.bodySm
                              .copyWith(color: AppColors.success)),
                  ],
                ),
              ),
              Text(
                item.total.toStringAsFixed(1),
                style: AppTextStyles.priceSm
                    .copyWith(fontSize: layout.isCompact ? 16 : 18),
              ),
              if (!readonly) ...[
                const SizedBox(width: 4),
                SizedBox(
                  width: layout.isCompact ? 34 : 38,
                  child: PopupMenuButton<String>(
                    padding: EdgeInsets.zero,
                    tooltip: 'Options',
                    child: SizedBox(
                      height: layout.isCompact ? 42 : 46,
                      child: Icon(
                        Icons.more_vert_rounded,
                        size: layout.isCompact ? 24 : 26,
                        color: AppColors.textSecondaryFor(context),
                      ),
                    ),
                    onSelected: (val) {
                      if (val == 'note') {
                        _showNoteDialog(context, ref, index, item.note);
                      }
                      if (val == 'discount') {
                        if (canApplyDiscount) {
                          _showDiscountDialog(
                              context, ref, index, item.discountPercent);
                        }
                      }
                      if (val == 'remove') cart.removeItem(index);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'note',
                        child: Row(children: [
                          Icon(Icons.note_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Add Note')
                        ]),
                      ),
                      if (canApplyDiscount)
                        const PopupMenuItem(
                          value: 'discount',
                          child: Row(children: [
                            Icon(Icons.local_offer_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Discount')
                          ]),
                        ),
                      const PopupMenuItem(
                        value: 'remove',
                        child: Row(children: [
                          Icon(Icons.delete_rounded,
                              size: 18, color: AppColors.error),
                          SizedBox(width: 10),
                          Text('Remove',
                              style: TextStyle(color: AppColors.error))
                        ]),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          if (item.sauces.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _SauceLines(lines: item.sauceDisplayLines),
            ),
        ],
      ),
    );
  }

  void _showNoteDialog(
      BuildContext context, WidgetRef ref, int index, String? current) {
    final ctrl = TextEditingController(text: current);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Item Note'),
        content: SizedBox(
          width: context.posLayout.dialogWidth,
          child: TextField(
            controller: ctrl,
            decoration: const InputDecoration(
              hintText: 'e.g. no salad, extra sauce...',
            ),
            maxLines: 3,
            autofocus: true,
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              ref.read(cartProvider.notifier).updateNote(
                    index,
                    ctrl.text.trim().isEmpty ? null : ctrl.text.trim(),
                  );
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showDiscountDialog(
      BuildContext context, WidgetRef ref, int index, double? current) {
    double value = current ?? 0;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('Apply Discount'),
          content: SizedBox(
            width: context.posLayout.dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${value.toStringAsFixed(0)}%',
                    style: AppTextStyles.priceLg),
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
                child: const Text('Cancel')),
            if (current != null)
              TextButton(
                onPressed: () {
                  ref.read(cartProvider.notifier).updateDiscount(index, null);
                  Navigator.pop(ctx);
                },
                child: const Text('Remove',
                    style: TextStyle(color: AppColors.error)),
              ),
            ElevatedButton(
              onPressed: () {
                ref.read(cartProvider.notifier).updateDiscount(
                      index,
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

class _DealComponentLine extends StatelessWidget {
  final CartItem component;

  const _DealComponentLine({required this.component});

  @override
  Widget build(BuildContext context) {
    final note = component.note?.trim();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '- ${component.quantity}x ${component.displayName}',
            style: AppTextStyles.bodySm.copyWith(
              color: AppColors.textPrimaryFor(context),
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (note != null && note.isNotEmpty)
            Text(
              '  $note',
              style: AppTextStyles.bodySm.copyWith(
                color: AppColors.textSecondaryFor(context),
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (component.sauces.isNotEmpty)
            _SauceLines(lines: component.sauceDisplayLines, indent: '  '),
        ],
      ),
    );
  }
}

class _SauceLines extends StatelessWidget {
  final List<String> lines;
  final String indent;

  const _SauceLines({
    required this.lines,
    this.indent = '',
  });

  @override
  Widget build(BuildContext context) {
    final isTraining = AppColors.isTraining(context);

    return Padding(
      padding: EdgeInsets.only(
        top: 6,
        left: indent.isEmpty ? 0 : 12,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppColors.yellow.withValues(
                    alpha: isTraining ? 0.18 : 0.24,
                  ),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: AppColors.yellow.withValues(alpha: 0.72),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.restaurant_menu_rounded,
                      size: 15,
                      color: AppColors.blue,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Sauce: $line',
                        style: AppTextStyles.bodySm.copyWith(
                          color: AppColors.blue,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ReadonlyQtyBadge extends StatelessWidget {
  final int quantity;

  const _ReadonlyQtyBadge({required this.quantity});

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final size = layout.isCompact ? 42.0 : 46.0;

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.elevatedSurfaceFor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'x$quantity',
        style: AppTextStyles.title.copyWith(
          fontSize: layout.isCompact ? 14 : 16,
          color: AppColors.textPrimaryFor(context),
        ),
      ),
    );
  }
}

class _QtyBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _QtyBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final size = layout.isCompact ? 42.0 : 46.0;

    return Material(
      color: AppColors.elevatedSurfaceFor(context),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.elevatedSurfaceFor(context),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon,
              size: layout.isCompact ? 22 : 24, color: AppColors.blue),
        ),
      ),
    );
  }
}
