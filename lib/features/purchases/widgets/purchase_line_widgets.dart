part of '../screens/create_purchase_screen.dart';

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: AppTextStyles.body
                .copyWith(color: AppColors.textSecondaryFor(context))),
        Text(
          value,
          style: AppTextStyles.titleSm.copyWith(
            color: AppColors.textPrimaryFor(context),
          ),
        ),
      ],
    );
  }
}

class _PurchaseLineRow extends StatelessWidget {
  final _PurchaseLineEntry entry;
  final List<StockItem> stocks;
  final VoidCallback onRemove;
  final VoidCallback onChanged;
  final Function(StockItem) onStockChanged;

  const _PurchaseLineRow({
    required this.entry,
    required this.stocks,
    required this.onRemove,
    required this.onChanged,
    required this.onStockChanged,
  });

  double get _lineTotal {
    final qty = double.tryParse(entry.quantityCtrl.text) ?? 0;
    final price = double.tryParse(entry.priceCtrl.text) ?? 0;
    return qty * price;
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final textColor = AppColors.textPrimaryFor(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(layout.isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.panelFor(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Row(
        children: [
          // Stock Selection (Searchable)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stock Item',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.textSecondaryFor(context),
                    )),
                const SizedBox(height: 4),
                _StockPickerButton(
                  stock: entry.stockItem,
                  stocks: stocks,
                  onSelected: onStockChanged,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Quantity
          SizedBox(
            width: 120,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Qty',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.textSecondaryFor(context),
                    )),
                const SizedBox(height: 4),
                TextField(
                  controller: entry.quantityCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                  style: AppTextStyles.titleSm.copyWith(color: textColor),
                  decoration: InputDecoration(
                    fillColor: AppColors.elevatedSurfaceFor(context),
                    filled: true,
                    suffixText: entry.stockItem.unit,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Price
          SizedBox(
            width: 140,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Unit Price',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.textSecondaryFor(context),
                    )),
                const SizedBox(height: 4),
                TextField(
                  controller: entry.priceCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                  style: AppTextStyles.titleSm.copyWith(color: textColor),
                  decoration: InputDecoration(
                    fillColor: AppColors.elevatedSurfaceFor(context),
                    filled: true,
                    suffixText: 'DT',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Line Total
          SizedBox(
            width: 110,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('Total',
                    style: AppTextStyles.labelSm.copyWith(
                      color: AppColors.textSecondaryFor(context),
                    )),
                const SizedBox(height: 10),
                Text(
                  '${_lineTotal.toStringAsFixed(3)} DT',
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.accentFor(context),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: AppColors.error, size: 24),
            onPressed: onRemove,
            tooltip: 'Remove item',
          ),
        ],
      ),
    );
  }
}

class _StockPickerButton extends StatelessWidget {
  final StockItem stock;
  final List<StockItem> stocks;
  final Function(StockItem) onSelected;

  const _StockPickerButton({
    required this.stock,
    required this.stocks,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.elevatedSurfaceFor(context),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: () async {
          final selected = await _showStockItemPicker(
            context,
            stocks,
            initialStock: stock,
          );
          if (selected != null) onSelected(selected);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          constraints: BoxConstraints(
            minHeight: context.posLayout.touchTarget,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.borderFor(context)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  stock.name,
                  style: AppTextStyles.titleSm.copyWith(
                    color: AppColors.textPrimaryFor(context),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.touch_app_rounded,
                size: 18,
                color: AppColors.accentFor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<StockItem?> _showStockItemPicker(
  BuildContext context,
  List<StockItem> stocks, {
  StockItem? initialStock,
}) {
  return showDialog<StockItem>(
    context: context,
    builder: (context) => _StockItemPickerDialog(
      stocks: stocks,
      initialStock: initialStock,
    ),
  );
}

class _StockItemPickerDialog extends StatefulWidget {
  final List<StockItem> stocks;
  final StockItem? initialStock;

  const _StockItemPickerDialog({
    required this.stocks,
    this.initialStock,
  });

  @override
  State<_StockItemPickerDialog> createState() => _StockItemPickerDialogState();
}

class _StockItemPickerDialogState extends State<_StockItemPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final query = _searchCtrl.text.trim().toLowerCase();
    final filtered = query.isEmpty
        ? widget.stocks
        : widget.stocks
            .where((stock) =>
                stock.name.toLowerCase().contains(query) ||
                stock.unit.toLowerCase().contains(query))
            .toList();

    return Dialog(
      insetPadding: EdgeInsets.all(layout.pagePadding),
      backgroundColor: AppColors.panelFor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 760,
          maxHeight: MediaQuery.sizeOf(context).height -
              (layout.pagePadding * 2).clamp(24.0, 56.0),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_rounded,
                    color: AppColors.accentFor(context),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Choose Stock Item',
                      style: AppTextStyles.h4.copyWith(
                        color: AppColors.textPrimaryFor(context),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
              child: TextField(
                controller: _searchCtrl,
                autofocus: false,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Search stock item...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.close_rounded),
                          tooltip: 'Clear search',
                        ),
                ),
              ),
            ),
            Divider(height: 1, color: AppColors.borderFor(context)),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No matching stock item',
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondaryFor(context),
                        ),
                      ),
                    )
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth >= 560 ? 2 : 1;
                        return GridView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: columns,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                            mainAxisExtent: 92,
                          ),
                          itemBuilder: (context, index) {
                            final stock = filtered[index];
                            final selected =
                                widget.initialStock?.id == stock.id;
                            return _StockPickerCard(
                              stock: stock,
                              selected: selected,
                              onTap: () => Navigator.pop(context, stock),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StockPickerCard extends StatelessWidget {
  final StockItem stock;
  final bool selected;
  final VoidCallback onTap;

  const _StockPickerCard({
    required this.stock,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppColors.accentSurfaceFor(context)
          : AppColors.elevatedSurfaceFor(context),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? AppColors.accentFor(context)
                  : AppColors.borderFor(context),
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accentFor(context).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.inventory_2_rounded,
                  color: AppColors.accentFor(context),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      stock.name,
                      style: AppTextStyles.titleSm.copyWith(
                        color: AppColors.textPrimaryFor(context),
                        fontWeight: FontWeight.w900,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${stock.unit} - ${stock.purchasePrice.toStringAsFixed(3)} DT',
                      style: AppTextStyles.bodySm.copyWith(
                        color: AppColors.textSecondaryFor(context),
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondaryFor(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget? trailing;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.h4.copyWith(
                  color: AppColors.textPrimaryFor(context),
                ),
              ),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondaryFor(context),
                  )),
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _PurchaseLineEntry {
  StockItem stockItem;
  TextEditingController quantityCtrl;
  TextEditingController priceCtrl;

  _PurchaseLineEntry({
    required this.stockItem,
    required this.quantityCtrl,
    required this.priceCtrl,
  });
}
