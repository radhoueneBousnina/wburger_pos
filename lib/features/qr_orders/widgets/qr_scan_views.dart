part of '../screens/qr_scan_screen.dart';

class _ScanningView extends StatelessWidget {
  final Function(String) onSimulate;
  const _ScanningView({required this.onSimulate});

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QR Order Scan', style: AppTextStyles.h3),
        Text(
            'Scan a customer QR code from the W Burger mobile app to import their order.',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        Expanded(
          child: layout.stackPanels
              ? Column(
                  children: [
                    Expanded(child: _ScannerArea(cornerBuilder: _buildCorners)),
                    SizedBox(height: layout.sectionGap),
                    _DemoPanel(onSimulate: onSimulate),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: _ScannerArea(cornerBuilder: _buildCorners),
                    ),
                    SizedBox(width: layout.sectionGap),
                    SizedBox(
                      width: layout.isCompact ? 260 : 300,
                      child: _DemoPanel(onSimulate: onSimulate),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  List<Widget> _buildCorners() {
    const size = 20.0;
    const thickness = 3.0;
    const color = AppColors.yellow;
    return [
      Positioned(
          top: 0,
          left: 0,
          child: Container(width: size, height: thickness, color: color)),
      Positioned(
          top: 0,
          left: 0,
          child: Container(width: thickness, height: size, color: color)),
      Positioned(
          top: 0,
          right: 0,
          child: Container(width: size, height: thickness, color: color)),
      Positioned(
          top: 0,
          right: 0,
          child: Container(width: thickness, height: size, color: color)),
      Positioned(
          bottom: 0,
          left: 0,
          child: Container(width: size, height: thickness, color: color)),
      Positioned(
          bottom: 0,
          left: 0,
          child: Container(width: thickness, height: size, color: color)),
      Positioned(
          bottom: 0,
          right: 0,
          child: Container(width: size, height: thickness, color: color)),
      Positioned(
          bottom: 0,
          right: 0,
          child: Container(width: thickness, height: size, color: color)),
    ];
  }
}

class _ScanPulse extends StatefulWidget {
  @override
  State<_ScanPulse> createState() => _ScanPulseState();
}

class _ScanPulseState extends State<_ScanPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<Color?> _colorAnim;

  @override
  void initState() {
    super.initState();
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
    _colorAnim = ColorTween(
      begin: AppColors.yellow,
      end: AppColors.yellow.withValues(alpha: 0.3),
    ).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: 8,
        height: 8,
        decoration:
            BoxDecoration(color: _colorAnim.value, shape: BoxShape.circle),
      ),
    );
  }
}

class _ScannerArea extends StatelessWidget {
  final List<Widget> Function() cornerBuilder;

  const _ScannerArea({required this.cornerBuilder});

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.neutral900,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.blue, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            children: [
              Container(
                width: layout.isCompact ? 220 : 260,
                height: layout.isCompact ? 220 : 260,
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.yellow, width: 3),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Icon(
                    Icons.qr_code_scanner_rounded,
                    color: AppColors.yellow.withValues(alpha: 0.4),
                    size: layout.isCompact ? 124 : 144,
                  ),
                ),
              ),
              ...cornerBuilder(),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'Point camera at customer QR code',
            style: AppTextStyles.bodyLg.copyWith(color: AppColors.white),
          ),
          const SizedBox(height: 10),
          _ScanPulse(),
        ],
      ),
    );
  }
}

class _DemoPanel extends StatelessWidget {
  final Function(String) onSimulate;

  const _DemoPanel({required this.onSimulate});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.yellowSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.yellow),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AppColors.warning, size: 18),
                  const SizedBox(width: 8),
                  Text('Demo Mode',
                      style: AppTextStyles.title
                          .copyWith(color: AppColors.warning)),
                ],
              ),
              const SizedBox(height: 8),
              Text('Simulate QR scan result:', style: AppTextStyles.body),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SimBtn(
          label: '✅ Valid QR Order',
          subtitle: '3 items - Ahmed B.',
          color: AppColors.success,
          onTap: () => onSimulate('valid'),
        ),
        const SizedBox(height: 12),
        _SimBtn(
          label: '⏰ Expired QR',
          subtitle: 'Older than 5 minutes',
          color: AppColors.warning,
          onTap: () => onSimulate('expired'),
        ),
        const SizedBox(height: 12),
        _SimBtn(
          label: '❌ Invalid QR',
          subtitle: 'Not recognized',
          color: AppColors.error,
          onTap: () => onSimulate('invalid'),
        ),
      ],
    );
  }
}

class _SimBtn extends StatelessWidget {
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _SimBtn(
      {required this.label,
      required this.subtitle,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;

    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          constraints: BoxConstraints(minHeight: layout.touchTarget + 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.title.copyWith(color: color)),
              Text(subtitle, style: AppTextStyles.bodySm),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewingView extends StatelessWidget {
  final String customer;
  final String qrCode;
  final List<Map<String, dynamic>> items;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const _ReviewingView({
    required this.customer,
    required this.qrCode,
    required this.items,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final total = items.fold<double>(
        0, (s, i) => s + (i['qty'] as int) * (i['price'] as double));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                  color: AppColors.successLight,
                  borderRadius: BorderRadius.circular(8)),
              child:
                  const Icon(Icons.qr_code_rounded, color: AppColors.success),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('QR Order Imported',
                    style: AppTextStyles.h4.copyWith(color: AppColors.success)),
                Text('Code: $qrCode', style: AppTextStyles.bodySm),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
        // Order review card
        Expanded(
          child: Container(
            padding: EdgeInsets.all(layout.pagePadding),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.person_rounded,
                        color: AppColors.blue, size: 18),
                    const SizedBox(width: 8),
                    Text('Customer: $customer',
                        style: AppTextStyles.title
                            .copyWith(color: AppColors.blue)),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.yellowSurface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.yellow),
                      ),
                      child: Text('QR Order',
                          style: AppTextStyles.labelSm
                              .copyWith(color: AppColors.yellowDark)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 12),
                Text('Order Items', style: AppTextStyles.label),
                const SizedBox(height: 10),
                ...items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                                color: AppColors.blueSurface,
                                borderRadius: BorderRadius.circular(6)),
                            alignment: Alignment.center,
                            child: Text('${item['qty']}x',
                                style: AppTextStyles.labelSm
                                    .copyWith(color: AppColors.blue)),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                              child: Text(item['name'] as String,
                                  style: AppTextStyles.body)),
                          Text(
                              '${((item['qty'] as int) * (item['price'] as double)).toStringAsFixed(3)} DT',
                              style: AppTextStyles.priceSm),
                        ],
                      ),
                    )),
                const Spacer(),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Total', style: AppTextStyles.h4),
                    Text('${total.toStringAsFixed(3)} DT',
                        style: AppTextStyles.priceLg),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onCancel,
                icon: const Icon(Icons.close_rounded, size: 18),
                label: const Text('Cancel'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.error,
                  side: const BorderSide(color: AppColors.error),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: onConfirm,
                icon: const Icon(Icons.payment_rounded, size: 18),
                label: const Text('Continue to Payment'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: AppTextStyles.buttonLg,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatusView extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color bgColor;
  final String title;
  final String message;
  final VoidCallback onRetry;
  final String retryLabel;

  const _StatusView({
    required this.icon,
    required this.iconColor,
    required this.bgColor,
    required this.title,
    required this.message,
    required this.onRetry,
    this.retryLabel = 'Scan Again',
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;

    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: layout.dialogWidth),
        padding: EdgeInsets.all(layout.isCompact ? 28 : 40),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.05), blurRadius: 20)
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
              child: Icon(icon, color: iconColor, size: 44),
            ),
            const SizedBox(height: 20),
            Text(title,
                style: AppTextStyles.h3.copyWith(color: iconColor),
                textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text(message,
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                label: Text(retryLabel),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
