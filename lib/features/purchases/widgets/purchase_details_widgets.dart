part of '../screens/purchases_screen.dart';

class _PurchaseStatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _PurchaseStatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 180),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: AppTextStyles.label
                      .copyWith(color: AppColors.textSecondaryFor(context))),
              Text(value, style: AppTextStyles.title.copyWith(color: color)),
            ],
          ),
        ],
      ),
    );
  }
}

class _PurchaseLinesCard extends StatelessWidget {
  final Purchase purchase;

  const _PurchaseLinesCard({required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Purchase Lines',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textPrimaryFor(context),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: purchase.lines.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 18, color: AppColors.borderFor(context)),
              itemBuilder: (context, index) {
                final line = purchase.lines[index];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            line.stockItem.name,
                            style: AppTextStyles.title.copyWith(
                              color: AppColors.textPrimaryFor(context),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${line.quantity.toStringAsFixed(line.stockItem.unit == 'pcs' ? 0 : 3)} ${line.stockItem.unit} • ${line.purchasePrice.toStringAsFixed(3)} DT / unit',
                            style: AppTextStyles.bodySm.copyWith(
                              color: AppColors.textSecondaryFor(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${line.lineTotal.toStringAsFixed(3)} DT',
                      style: AppTextStyles.title.copyWith(
                        color: AppColors.accentFor(context),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoiceDetailsCard extends StatelessWidget {
  final Purchase purchase;

  const _InvoiceDetailsCard({required this.purchase});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.panelFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Invoice',
            style: AppTextStyles.h4.copyWith(
              color: AppColors.textPrimaryFor(context),
            ),
          ),
          const SizedBox(height: 12),
          if (purchase.invoiceImagePath != null &&
              purchase.invoiceImagePath!.isNotEmpty)
            GestureDetector(
              onTap: () =>
                  _showInvoiceViewer(context, purchase.invoiceImagePath!),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 4 / 3,
                      child: AppImage(
                        imageUrl: purchase.invoiceImagePath!,
                        fit: BoxFit.contain,
                        optimizedSize: 960,
                        fallbackWidget:
                            const _InvoiceImageFallback(height: 220),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Tap image to open zoomable viewer',
                    style: AppTextStyles.bodySm
                        .copyWith(color: AppColors.textSecondaryFor(context)),
                  ),
                ],
              ),
            )
          else
            const _InvoiceImageFallback(
                height: 220, message: 'No invoice image attached'),
        ],
      ),
    );
  }

  void _showInvoiceViewer(BuildContext context, String imageUrl) {
    final layout = context.posLayout;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.85),
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(layout.pagePadding),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(18),
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 5,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AppImage(
                    imageUrl: imageUrl,
                    fit: BoxFit.contain,
                    optimizedSize: 1600,
                    fallbackWidget: const _InvoiceImageFallback(height: 420),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                onPressed: () => Navigator.pop(ctx),
                icon: const Icon(Icons.close_rounded, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvoiceThumb extends StatelessWidget {
  final String? imageUrl;
  final bool compact;

  const _InvoiceThumb({
    required this.imageUrl,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.no_photography_outlined,
              size: 16, color: AppColors.neutral400),
          const SizedBox(width: 6),
          Text('No File',
              style:
                  AppTextStyles.bodySm.copyWith(color: AppColors.textDisabled)),
        ],
      );
    }

    final width = compact ? 68.0 : 88.0;
    final height = compact ? 48.0 : 64.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: AppImage(
            imageUrl: imageUrl!,
            width: width,
            height: height,
            fit: BoxFit.contain,
            optimizedSize: compact ? 192 : 320,
            fallbackWidget: _InvoiceImageFallback(height: height, width: width),
          ),
        ),
        const SizedBox(height: 6),
        Text('Preview',
            style: AppTextStyles.labelSm
                .copyWith(color: AppColors.textSecondaryFor(context))),
      ],
    );
  }
}

class _InvoiceImageFallback extends StatelessWidget {
  final double height;
  final double? width;
  final String message;

  const _InvoiceImageFallback({
    required this.height,
    this.width,
    this.message = 'Unable to load invoice image',
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: AppColors.elevatedSurfaceFor(context),
      alignment: Alignment.center,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Padding(
          padding: const EdgeInsets.all(4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.image_not_supported_rounded,
                  color: AppColors.textSecondaryFor(context)),
              const SizedBox(height: 8),
              Text(message,
                  style: AppTextStyles.bodySm.copyWith(
                    color: AppColors.textSecondaryFor(context),
                  ),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
