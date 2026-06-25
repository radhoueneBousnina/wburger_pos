part of '../screens/purchases_screen.dart';

class _PurchasesTable extends ConsumerStatefulWidget {
  final List<Purchase> purchases;

  const _PurchasesTable({required this.purchases});

  @override
  ConsumerState<_PurchasesTable> createState() => _PurchasesTableState();
}

class _PurchasesTableState extends ConsumerState<_PurchasesTable> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(purchasesProvider.notifier).fetchPurchases(loadMore: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = ref.watch(purchasesProvider.notifier);
    final isLoadingMore = notifier.isLoadingMore;

    return LayoutBuilder(
      builder: (context, constraints) {
        const spec = _PurchasesTableSpec();
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _PurchasesTableSpec.horizontalPadding,
                    vertical: 14,
                  ),
                  color: AppColors.tableHeaderFor(context),
                  child: Row(
                    children: [
                      _Cell(
                          width: _PurchasesTableSpec.dateWidth,
                          child: _HeaderCell('Date')),
                      Spacer(flex: 1),
                      _Cell(
                          width: _PurchasesTableSpec.itemsWidth,
                          child: _HeaderCell('Items')),
                      Spacer(flex: 1),
                      _Cell(
                          width: _PurchasesTableSpec.totalWidth,
                          child: _HeaderCell('Total', align: TextAlign.right)),
                      Spacer(flex: 1),
                      _Cell(
                          width: _PurchasesTableSpec.invoiceWidth,
                          child:
                              _HeaderCell('Invoice', align: TextAlign.center)),
                      Spacer(flex: 1),
                      _Cell(
                          width: _PurchasesTableSpec.statusWidth,
                          child:
                              _HeaderCell('Status', align: TextAlign.center)),
                    ],
                  ),
                ),
                Divider(height: 1, color: AppColors.borderFor(context)),
                Expanded(
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: EdgeInsets.zero,
                    itemCount:
                        widget.purchases.length + (isLoadingMore ? 1 : 0),
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, color: AppColors.borderFor(context)),
                    itemBuilder: (ctx, i) {
                      if (i == widget.purchases.length) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }
                      return _PurchaseRow(purchase: widget.purchases[i]);
                    },
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

class _PurchasesTableSpec {
  const _PurchasesTableSpec();

  static const double horizontalPadding = 24;
  static const double dateWidth = 120;
  static const double itemsWidth = 320;
  static const double totalWidth = 110;
  static const double invoiceWidth = 120;
  static const double statusWidth = 120;

  double get minWidth =>
      (horizontalPadding * 2) +
      dateWidth +
      itemsWidth +
      totalWidth +
      invoiceWidth +
      statusWidth +
      (16 * 4); // Accounting for all spacers
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

class _PurchaseRow extends StatelessWidget {
  final Purchase purchase;
  const _PurchaseRow({required this.purchase});

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;

    return InkWell(
      onTap: () => _showPurchaseDetails(context),
      overlayColor:
          WidgetStateProperty.all(AppColors.blueSurface.withValues(alpha: 0.1)),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: _PurchasesTableSpec.horizontalPadding,
          vertical: layout.isCompact ? 16 : 22,
        ),
        color: AppColors.surfaceFor(context),
        child: Row(
          children: [
            _Cell(
              width: _PurchasesTableSpec.dateWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateFormat('dd MMM yyyy').format(purchase.createdAt),
                    style: AppTextStyles.title.copyWith(
                      color: AppColors.textPrimaryFor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.access_time_rounded,
                          size: 12, color: AppColors.textSecondaryFor(context)),
                      const SizedBox(width: 4),
                      Text(DateFormat('HH:mm').format(purchase.createdAt),
                          style: AppTextStyles.bodySm.copyWith(
                            color: AppColors.textSecondaryFor(context),
                          )),
                    ],
                  ),
                ],
              ),
            ),
            const Spacer(flex: 1),
            _Cell(
              width: _PurchasesTableSpec.itemsWidth,
              child: _PurchaseItems(lines: purchase.lines),
            ),
            const Spacer(flex: 1),
            _Cell(
              width: _PurchasesTableSpec.totalWidth,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${purchase.total.toStringAsFixed(3)} DT',
                    textAlign: TextAlign.right,
                    style: AppTextStyles.price.copyWith(
                      color: AppColors.accentFor(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${purchase.lines.length} item(s)',
                    style: AppTextStyles.labelSm
                        .copyWith(color: AppColors.textSecondaryFor(context)),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 1),
            _Cell(
              width: _PurchasesTableSpec.invoiceWidth,
              child: Align(
                alignment: Alignment.center,
                child: _InvoiceThumb(
                  imageUrl: purchase.invoiceImagePath,
                  compact: true,
                ),
              ),
            ),
            const Spacer(flex: 1),
            _Cell(
              width: _PurchasesTableSpec.statusWidth,
              child: Align(
                alignment: Alignment.center,
                child: _StatusBadge(status: purchase.status),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPurchaseDetails(BuildContext context) {
    final layout = context.posLayout;

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: EdgeInsets.all(layout.pagePadding),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: layout.stackPanels ? 680 : 860,
            maxHeight: layout.height * 0.86,
          ),
          child: Padding(
            padding: EdgeInsets.all(layout.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Purchase Details', style: AppTextStyles.h3),
                          const SizedBox(height: 4),
                          Text(
                            DateFormat('EEEE, dd MMM yyyy • HH:mm')
                                .format(purchase.createdAt),
                            style: AppTextStyles.body
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: purchase.status),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _PurchaseStatCard(
                      label: 'Total',
                      value: '${purchase.total.toStringAsFixed(3)} DT',
                      icon: Icons.payments_rounded,
                      color: AppColors.blue,
                    ),
                    _PurchaseStatCard(
                      label: 'Lines',
                      value: '${purchase.lines.length}',
                      icon: Icons.receipt_long_rounded,
                      color: AppColors.warning,
                    ),
                    if (purchase.validatedBy != null &&
                        purchase.validatedBy!.isNotEmpty)
                      _PurchaseStatCard(
                        label: 'Recorded By',
                        value: purchase.validatedBy!,
                        icon: Icons.person_rounded,
                        color: AppColors.success,
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: layout.stackPanels
                      ? ListView(
                          children: [
                            _PurchaseLinesCard(purchase: purchase),
                            const SizedBox(height: 16),
                            _InvoiceDetailsCard(purchase: purchase),
                          ],
                        )
                      : Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: _PurchaseLinesCard(purchase: purchase),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 2,
                              child: _InvoiceDetailsCard(purchase: purchase),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PurchaseItems extends StatelessWidget {
  final List<PurchaseLine> lines;
  const _PurchaseItems({required this.lines});

  @override
  Widget build(BuildContext context) {
    if (lines.isEmpty) {
      return Text('No items',
          style: AppTextStyles.body.copyWith(color: AppColors.textDisabled));
    }

    if (lines.length == 1) {
      final line = lines.first;
      return Text(
        '${line.stockItem.name} (${line.quantity} ${line.stockItem.unit})',
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${lines.first.stockItem.name} ...',
          style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w500),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.neutral100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            '+ ${lines.length - 1} other items',
            style:
                AppTextStyles.labelSm.copyWith(color: AppColors.textSecondary),
          ),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final PurchaseStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final isValidated = status == PurchaseStatus.validated;
    final color = isValidated ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        isValidated ? 'Validated' : 'Pending',
        style: AppTextStyles.label.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _EmptyPurchases extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 64,
            color: AppColors.isTraining(context)
                ? AppColors.neutral500
                : AppColors.neutral300,
          ),
          const SizedBox(height: 16),
          Text('No purchases recorded',
              style: AppTextStyles.h4
                  .copyWith(color: AppColors.textSecondaryFor(context))),
          const SizedBox(height: 8),
          Text('Tap "New Purchase" to record a stock purchase.',
              style: AppTextStyles.body
                  .copyWith(color: AppColors.textSecondaryFor(context))),
        ],
      ),
    );
  }
}
