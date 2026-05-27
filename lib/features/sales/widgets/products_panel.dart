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
                    prefixIcon: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Icon(
                        Icons.search_rounded,
                        color: AppColors.blue,
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
        onTap: () {
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
          ref.read(cartProvider.notifier).addProduct(product);
        },
        borderRadius: BorderRadius.circular(layout.cardRadius),
        splashColor: AppColors.yellowSurface,
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
                            style: AppTextStyles.price
                                .copyWith(fontSize: layout.isCompact ? 18 : 20),
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
