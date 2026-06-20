part of '../screens/sales_screen.dart';

class _ProductsPanel extends ConsumerWidget {
  final TextEditingController searchCtrl;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<String?> onCategorySelected;

  const _ProductsPanel({
    required this.searchCtrl,
    required this.onSearch,
    required this.onSearchSubmitted,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = context.posLayout;
    final categoriesAsync = ref.watch(categoriesProvider);
    final selectedCat = ref.watch(selectedCategoryProvider);
    final productsAsync = ref.watch(filteredProductsProvider);
    final isTraining = AppColors.isTraining(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search bar
        Container(
          color: AppColors.surfaceFor(context),
          padding: EdgeInsets.fromLTRB(
            layout.pagePadding,
            6,
            layout.pagePadding,
            0,
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchCtrl,
                  onChanged: onSearch,
                  onSubmitted: onSearchSubmitted,
                  style: AppTextStyles.title.copyWith(
                    color: AppColors.textPrimaryFor(context),
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search products...',
                    hintStyle: AppTextStyles.body.copyWith(
                      color: AppColors.textSecondaryFor(context),
                    ),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Icon(
                        Icons.search_rounded,
                        color: AppColors.accentFor(context),
                        size: 22,
                      ),
                    ),
                    suffixIcon: searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              searchCtrl.clear();
                              onSearch('');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: AppColors.elevatedSurfaceFor(context),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 18,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide:
                          BorderSide(color: AppColors.borderFor(context)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        // Category chips — big touch targets
        Container(
          color: AppColors.surfaceFor(context),
          padding: EdgeInsets.fromLTRB(
            layout.pagePadding,
            6,
            layout.pagePadding,
            6,
          ),
          child: SizedBox(
            height: layout.touchTarget + 18,
            child: categoriesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              data: (categories) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _CategoryChip(
                      label: 'All',
                      iconEmoji: '🍽️',
                      selected: selectedCat == null,
                      onTap: () => onCategorySelected(null),
                    ),
                    ...categories.map((Category cat) {
                      final selected = selectedCat == cat.id;
                      return _CategoryChip(
                        label: cat.name,
                        iconEmoji: cat.iconEmoji ?? '🍔',
                        imageUrl: cat.imageUrl,
                        selected: selected,
                        onTap: () => onCategorySelected(cat.id),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
        Divider(height: 1, color: AppColors.borderFor(context)),
        // Products grid
        Expanded(
          child: productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Center(
                child: Text(
              'Error loading products: $err',
              style: TextStyle(color: AppColors.textPrimaryFor(context)),
            )),
            data: (products) => products.isEmpty
                ? Stack(
                    children: [
                      Positioned.fill(
                        child: CustomPaint(
                          painter: BrandCheckerPainter(
                            color1: isTraining
                                ? AppColors.yellow.withValues(alpha: 0.035)
                                : AppColors.yellow.withValues(alpha: 0.05),
                            color2: Colors.transparent,
                          ),
                        ),
                      ),
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search_off_rounded,
                              size: 56,
                              color: isTraining
                                  ? AppColors.neutral500
                                  : AppColors.neutral400,
                            ),
                            const SizedBox(height: 12),
                            Text('No products found',
                                style: AppTextStyles.body.copyWith(
                                    color:
                                        AppColors.textSecondaryFor(context))),
                          ],
                        ),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = layout.gridColumns(constraints.maxWidth);
                      return GridView.builder(
                        padding: EdgeInsets.fromLTRB(
                          layout.pagePadding,
                          10,
                          layout.pagePadding,
                          layout.pagePadding,
                        ),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: columns,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          childAspectRatio: layout
                              .productCardAspectRatio(constraints.maxWidth),
                        ),
                        itemCount: products.length,
                        itemBuilder: (ctx, i) =>
                            _ProductCard(product: products[i]),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String iconEmoji;
  final String? imageUrl;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.iconEmoji,
    required this.selected,
    required this.onTap,
    this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final isTraining = AppColors.isTraining(context);

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: BoxConstraints(minHeight: layout.touchTarget),
            padding: EdgeInsets.symmetric(
              horizontal: layout.isCompact ? 12 : 14,
              vertical: layout.isCompact ? 8 : 10,
            ),
            decoration: BoxDecoration(
              color: selected ? AppColors.yellow : AppColors.panelFor(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color:
                    selected ? AppColors.yellow : AppColors.borderFor(context),
                width: selected ? 2.5 : 1.5,
              ),
              boxShadow: [
                if (selected)
                  BoxShadow(
                    color: AppColors.yellow
                        .withValues(alpha: isTraining ? 0.18 : 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                if (!selected)
                  const BoxShadow(
                    color: Color(0x05000000),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (imageUrl != null && imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: AppImage(
                      imageUrl: imageUrl!,
                      width: 64,
                      height: 64,
                      fallbackWidget: Text(
                        iconEmoji,
                        style: const TextStyle(fontSize: 36),
                      ),
                    ),
                  )
                else
                  Text(iconEmoji, style: const TextStyle(fontSize: 36)),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: AppTextStyles.title.copyWith(
                    color: selected
                        ? AppColors.blue
                        : AppColors.textSecondaryFor(context),
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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

class _ProductCard extends ConsumerWidget {
  final Product product;
  const _ProductCard({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = context.posLayout;
    final isLockedForQr = ref.watch(
      cartProvider.select((cart) => cart.isLockedForQr),
    );
    final isTraining = AppColors.isTraining(context);

    return Material(
      color: AppColors.panelFor(context),
      borderRadius: BorderRadius.circular(layout.cardRadius),
      child: InkWell(
        onTap: () => _handleProductTap(context, ref, isLockedForQr),
        borderRadius: BorderRadius.circular(layout.cardRadius),
        splashColor: AppColors.accentSurfaceFor(context),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(layout.cardRadius),
            border: Border.all(color: AppColors.borderFor(context)),
            boxShadow: [
              BoxShadow(
                color: isTraining
                    ? Colors.black.withValues(alpha: 0.16)
                    : const Color(0x08000000),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image area
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(layout.cardRadius),
                    topRight: Radius.circular(layout.cardRadius),
                  ),
                  child: _ProductImage(imagePath: product.imageUrl),
                ),
              ),
              // Info area
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: layout.isCompact ? 12 : 14,
                  vertical: layout.isCompact ? 10 : 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.name,
                      style: AppTextStyles.title.copyWith(
                        fontSize: layout.isCompact ? 14 : 15,
                        color: AppColors.textPrimaryFor(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product.description,
                      style: AppTextStyles.bodySm.copyWith(
                        fontSize: layout.isCompact ? 12 : 13,
                        color: AppColors.textSecondaryFor(context),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            '${product.price.toStringAsFixed(1)} DT',
                            style: AppTextStyles.price.copyWith(
                              color: AppColors.accentFor(context),
                              fontSize: layout.isCompact ? 18 : 20,
                            ),
                            maxLines: 1,
                          ),
                        ),
                        // BIG add button
                        Container(
                          width: layout.isCompact ? 42 : 48,
                          height: layout.isCompact ? 42 : 48,
                          decoration: const BoxDecoration(
                            color: AppColors.yellow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.add_rounded,
                            color: AppColors.blue,
                            size: layout.isCompact ? 24 : 28,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleProductTap(
    BuildContext context,
    WidgetRef ref,
    bool isLockedForQr,
  ) async {
    if (isLockedForQr) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Imported mobile orders are read-only. Clear the order to start a manual sale.',
          ),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final stockNotifier = ref.read(stockProvider.notifier);
    await Future.wait([
      stockNotifier.fetchRecipes(),
      stockNotifier.refreshIfStale(maxAge: const Duration(minutes: 5)),
    ]);
    if (!context.mounted) return;

    final sauceGroups = _sauceGroupsForProduct(stockNotifier, product);
    if (sauceGroups.isEmpty) {
      ref.read(cartProvider.notifier).addProduct(product);
      return;
    }

    final selections = await _showSaucePicker(
      context,
      product: product,
      groups: sauceGroups,
    );
    if (selections == null || !context.mounted) return;

    ref.read(cartProvider.notifier).addProduct(
          product,
          sauces: selections,
        );
  }

  List<_SauceChoiceGroup> _sauceGroupsForProduct(
    StockNotifier stockNotifier,
    Product product,
  ) {
    if (product.isMeal) {
      return stockNotifier
          .saucyMealComponents(product)
          .map(
            (component) => _SauceChoiceGroup(
              productId: component.productId,
              title: component.quantity > 1
                  ? '${component.quantity}x ${component.name}'
                  : component.name,
              productName: component.name,
              quantity: component.quantity,
              options: component.sauceOptions,
            ),
          )
          .toList();
    }

    final options = stockNotifier.sauceOptionsForProduct(product);
    if (options.isEmpty) return const [];
    return [
      _SauceChoiceGroup(
        productId: product.id,
        title: product.name,
        productName: product.name,
        quantity: 1,
        options: options,
      ),
    ];
  }

  Future<List<CartSauceSelection>?> _showSaucePicker(
    BuildContext context, {
    required Product product,
    required List<_SauceChoiceGroup> groups,
  }) {
    final selectedKeys = <String>{};

    String optionKey(_SauceChoiceGroup group, ProductSauceOption option) {
      return '${group.productId}|${option.stockItemId}';
    }

    return showDialog<List<CartSauceSelection>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) {
          final layout = ctx.posLayout;
          final maxHeight = MediaQuery.sizeOf(ctx).height * 0.78;
          return Dialog(
            insetPadding: EdgeInsets.symmetric(
              horizontal: layout.isCompact ? 14 : 32,
              vertical: 22,
            ),
            backgroundColor: Colors.transparent,
            child: Container(
              width: layout.dialogWidth,
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: AppColors.panelFor(ctx),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.borderFor(ctx)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 30,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.fromLTRB(
                      layout.isCompact ? 18 : 22,
                      layout.isCompact ? 16 : 20,
                      layout.isCompact ? 10 : 14,
                      layout.isCompact ? 14 : 18,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurfaceFor(ctx),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                      border: Border(
                        bottom: BorderSide(color: AppColors.borderFor(ctx)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: layout.isCompact ? 42 : 48,
                          height: layout.isCompact ? 42 : 48,
                          decoration: const BoxDecoration(
                            color: AppColors.yellow,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.restaurant_menu_rounded,
                            color: AppColors.blue,
                            size: layout.isCompact ? 22 : 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                product.name,
                                style: AppTextStyles.title.copyWith(
                                  color: AppColors.textPrimaryFor(ctx),
                                  fontWeight: FontWeight.w900,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selectedKeys.isEmpty
                                    ? 'Choose sauces'
                                    : '${selectedKeys.length} sauce${selectedKeys.length == 1 ? '' : 's'} selected',
                                style: AppTextStyles.bodySm.copyWith(
                                  color: AppColors.textSecondaryFor(ctx),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Close',
                          onPressed: () => Navigator.pop(ctx),
                          icon: Icon(
                            Icons.close_rounded,
                            color: AppColors.textSecondaryFor(ctx),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: Scrollbar(
                      child: SingleChildScrollView(
                        padding: EdgeInsets.all(layout.isCompact ? 14 : 18),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (final group in groups) ...[
                              Container(
                                width: double.infinity,
                                padding: EdgeInsets.all(
                                  layout.isCompact ? 12 : 14,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceFor(ctx),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: AppColors.borderFor(ctx),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      group.title,
                                      style: AppTextStyles.titleSm.copyWith(
                                        color: AppColors.textPrimaryFor(ctx),
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Wrap(
                                      spacing: 10,
                                      runSpacing: 10,
                                      children: [
                                        for (final option in group.options)
                                          Builder(builder: (ctx) {
                                            final key = optionKey(
                                              group,
                                              option,
                                            );
                                            final selected =
                                                selectedKeys.contains(key);
                                            return Material(
                                              color: Colors.transparent,
                                              child: InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    if (selected) {
                                                      selectedKeys.remove(key);
                                                    } else {
                                                      selectedKeys.add(key);
                                                    }
                                                  });
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(14),
                                                child: AnimatedContainer(
                                                  duration: const Duration(
                                                    milliseconds: 140,
                                                  ),
                                                  constraints:
                                                      const BoxConstraints(
                                                    minHeight: 46,
                                                    maxWidth: 220,
                                                  ),
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 12,
                                                    vertical: 10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: selected
                                                        ? AppColors.yellow
                                                        : AppColors
                                                            .elevatedSurfaceFor(
                                                            ctx,
                                                          ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      14,
                                                    ),
                                                    border: Border.all(
                                                      color: selected
                                                          ? AppColors.yellow
                                                          : AppColors.borderFor(
                                                              ctx),
                                                      width: selected ? 2 : 1,
                                                    ),
                                                  ),
                                                  child: Row(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Icon(
                                                        selected
                                                            ? Icons
                                                                .check_circle_rounded
                                                            : Icons
                                                                .add_circle_outline_rounded,
                                                        size: 18,
                                                        color: selected
                                                            ? AppColors.blue
                                                            : AppColors
                                                                .accentFor(
                                                                ctx,
                                                              ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Flexible(
                                                        child: Text(
                                                          option.name,
                                                          style: AppTextStyles
                                                              .body
                                                              .copyWith(
                                                            color: selected
                                                                ? AppColors.blue
                                                                : AppColors
                                                                    .textPrimaryFor(
                                                                    ctx,
                                                                  ),
                                                            fontWeight:
                                                                FontWeight.w800,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (group != groups.last)
                                const SizedBox(height: 12),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(layout.isCompact ? 14 : 18),
                    decoration: BoxDecoration(
                      color: AppColors.elevatedSurfaceFor(ctx),
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(24),
                      ),
                      border: Border(
                        top: BorderSide(color: AppColors.borderFor(ctx)),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            selectedKeys.isEmpty
                                ? 'No sauce selected'
                                : '${selectedKeys.length} selected',
                            style: AppTextStyles.body.copyWith(
                              color: AppColors.textSecondaryFor(ctx),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 10),
                        SizedBox(
                          height: layout.touchTarget,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              final selections = <CartSauceSelection>[];
                              for (final group in groups) {
                                for (final option in group.options) {
                                  if (!selectedKeys.contains(
                                    optionKey(group, option),
                                  )) {
                                    continue;
                                  }
                                  selections.add(option.toSelection(
                                    productId: group.productId,
                                    productName: group.productName,
                                  ));
                                }
                              }
                              Navigator.pop(ctx, selections);
                            },
                            icon: const Icon(Icons.check_rounded),
                            label: const Text('Submit'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.yellow,
                              foregroundColor: AppColors.blue,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _SauceChoiceGroup {
  final String productId;
  final String title;
  final String productName;
  final int quantity;
  final List<ProductSauceOption> options;

  const _SauceChoiceGroup({
    required this.productId,
    required this.title,
    required this.productName,
    required this.quantity,
    required this.options,
  });
}

class _ProductImage extends StatelessWidget {
  final String? imagePath;
  const _ProductImage({this.imagePath});

  @override
  Widget build(BuildContext context) {
    return AppImage(
      imageUrl: imagePath,
      width: double.infinity,
      height: double.infinity,
      optimizedSize: 320,
      filterQuality: FilterQuality.low,
      fallbackAsset: 'assets/images/default_burger.jpg',
    );
  }
}
