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
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        Text(value, style: AppTextStyles.titleSm),
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

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(layout.isCompact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Stock Selection (Searchable)
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Stock Item', style: AppTextStyles.labelSm),
                const SizedBox(height: 4),
                _StockSearchPicker(
                  initialStock: entry.stockItem,
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
                Text('Qty', style: AppTextStyles.labelSm),
                const SizedBox(height: 4),
                TextField(
                  controller: entry.quantityCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                  style: AppTextStyles.titleSm,
                  decoration: InputDecoration(
                    fillColor: AppColors.neutral50,
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
                Text('Unit Price', style: AppTextStyles.labelSm),
                const SizedBox(height: 4),
                TextField(
                  controller: entry.priceCtrl,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => onChanged(),
                  style: AppTextStyles.titleSm,
                  decoration: InputDecoration(
                    fillColor: AppColors.neutral50,
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
                Text('Total', style: AppTextStyles.labelSm),
                const SizedBox(height: 10),
                Text(
                  '${_lineTotal.toStringAsFixed(3)} DT',
                  style: AppTextStyles.title.copyWith(color: AppColors.blue),
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

class _StockSearchPicker extends StatefulWidget {
  final StockItem initialStock;
  final List<StockItem> stocks;
  final Function(StockItem) onSelected;

  const _StockSearchPicker({
    required this.initialStock,
    required this.stocks,
    required this.onSelected,
  });

  @override
  State<_StockSearchPicker> createState() => _StockSearchPickerState();
}

class _StockSearchPickerState extends State<_StockSearchPicker> {
  final SearchController _controller = SearchController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.initialStock.name;
  }

  @override
  void didUpdateWidget(_StockSearchPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialStock.id != widget.initialStock.id) {
      _controller.text = widget.initialStock.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SearchAnchor(
      searchController: _controller,
      viewBackgroundColor: AppColors.white,
      viewSurfaceTintColor: AppColors.white,
      viewHintText: 'Search stock item...',
      builder: (context, controller) {
        return InkWell(
          onTap: () => controller.openView(),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.neutral50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.initialStock.name,
                    style: AppTextStyles.titleSm,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Icon(Icons.search_rounded,
                    size: 18, color: AppColors.neutral400),
              ],
            ),
          ),
        );
      },
      suggestionsBuilder: (context, controller) {
        final query = controller.text.toLowerCase();
        final filtered = widget.stocks.where((s) {
          return s.name.toLowerCase().contains(query);
        }).toList();

        if (filtered.isEmpty) {
          return [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('No matching items found',
                  textAlign: TextAlign.center, style: AppTextStyles.bodySm),
            )
          ];
        }

        return filtered.map((s) {
          return ListTile(
            title: Text(s.name, style: AppTextStyles.titleSm),
            subtitle: Text('Unit: ${s.unit} | Price: ${s.purchasePrice} DT',
                style: AppTextStyles.labelSm),
            onTap: () {
              controller.closeView(s.name);
              widget.onSelected(s);
            },
          );
        }).toList();
      },
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
              Text(title, style: AppTextStyles.h4),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.textSecondary)),
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
