import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/pos_layout.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/router/app_router.dart';
import '../../data/providers/app_providers.dart';
import '../../data/models/order_models.dart';
import 'brand_patterns.dart';

class TopBar extends ConsumerStatefulWidget {
  final bool showMenuButton;

  const TopBar({
    super.key,
    this.showMenuButton = true,
  });

  @override
  ConsumerState<TopBar> createState() => _TopBarState();
}

class _TopBarState extends ConsumerState<TopBar> {
  late DateTime _now;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    Future.delayed(const Duration(minutes: 1), _updateTime);
  }

  void _updateTime() {
    if (mounted) {
      setState(() => _now = DateTime.now());
      Future.delayed(const Duration(minutes: 1), _updateTime);
    }
  }

  String _getTitle(String path) {
    switch (path) {
      case AppRoutes.sales:
        return 'Point of Sale';
      case AppRoutes.todaySales:
        return "Today's Sales";
      case AppRoutes.stock:
        return 'Stock';
      case AppRoutes.purchases:
        return "Today's Purchases";
      case AppRoutes.createPurchase:
        return 'New Purchase';
      case AppRoutes.sessionClosure:
        return 'Session Closure';
      default:
        return 'W Burger - POS';
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final location = GoRouterState.of(context).uri.path;
    final title = _getTitle(location);
    final testMode = ref.watch(testModeProvider);

    return Container(
      height: layout.topBarHeight,
      decoration: BoxDecoration(
        color: testMode.isActive ? const Color(0xFF151827) : AppColors.white,
        border: Border(
          bottom: BorderSide(
            color: testMode.isActive
                ? Colors.white.withValues(alpha: 0.12)
                : AppColors.border,
          ),
        ),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000), blurRadius: 6, offset: Offset(0, 2)),
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: layout.pagePadding),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: BrandCheckerPainter(
                  color1:
                      (testMode.isActive ? AppColors.yellow : AppColors.blue)
                          .withValues(alpha: testMode.isActive ? 0.04 : 0.06),
                  color2:
                      (testMode.isActive ? AppColors.yellow : AppColors.blue)
                          .withValues(alpha: 0.02),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Row(
              children: [
                if (widget.showMenuButton) ...[
                  Builder(
                    builder: (buttonContext) => Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => Scaffold.of(buttonContext).openDrawer(),
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: layout.iconTouchTarget,
                          height: layout.iconTouchTarget,
                          child: Center(
                            child: Icon(
                              Icons.menu_rounded,
                              color: testMode.isActive
                                  ? AppColors.yellow
                                  : AppColors.blue,
                              size: 28,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                SizedBox(
                  width: layout.isCompact ? 36 : 42,
                  height: layout.isCompact ? 36 : 42,
                  child: Image.asset(
                    'assets/logos/logo_yellow.png',
                    cacheHeight: ((layout.isCompact ? 36 : 42) *
                            MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.fastfood_rounded,
                      color: AppColors.blue,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                if (!layout.isCompact) ...[
                  Container(
                    width: 1,
                    height: 24,
                    color: testMode.isActive
                        ? Colors.white.withValues(alpha: 0.12)
                        : AppColors.border,
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      title,
                      style: AppTextStyles.h4.copyWith(
                        color: testMode.isActive
                            ? AppColors.white
                            : AppColors.textPrimary,
                        fontSize: layout.isCompact ? 18 : 20,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                SizedBox(width: layout.isCompact ? 10 : 16),
                Flexible(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _CashDrawerButton(),
                          SizedBox(width: layout.isCompact ? 12 : 18),
                          Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(DateFormat('EEE, dd MMM').format(_now),
                                  style: AppTextStyles.bodySm.copyWith(
                                      color: testMode.isActive
                                          ? AppColors.neutral300
                                          : AppColors.textSecondary,
                                      fontSize: layout.isCompact ? 11 : 12)),
                              Text(
                                DateFormat('HH:mm').format(_now),
                                style: AppTextStyles.title.copyWith(
                                  color: testMode.isActive
                                      ? AppColors.yellow
                                      : AppColors.blue,
                                  fontWeight: FontWeight.w800,
                                  fontSize: layout.isCompact ? 15 : 18,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
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

class _CashDrawerButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = context.posLayout;
    final canOpenDrawer =
        ref.watch(authProvider).permissions['can_open_cash_drawer'] == true;
    final testMode = ref.watch(testModeProvider);

    return OutlinedButton.icon(
      onPressed:
          canOpenDrawer ? () => _showCashDrawerDialog(context, ref) : null,
      icon: Icon(Icons.storefront_rounded,
          color: testMode.isActive ? AppColors.yellow : AppColors.blue,
          size: layout.isCompact ? 20 : 22),
      label: Text('Cash Drawer',
          style: AppTextStyles.title.copyWith(
              color: testMode.isActive ? AppColors.yellow : AppColors.blue)),
      style: OutlinedButton.styleFrom(
        foregroundColor: testMode.isActive ? AppColors.yellow : AppColors.blue,
        backgroundColor:
            testMode.isActive ? const Color(0xFF1D2235) : AppColors.white,
        side: BorderSide(
            color: (testMode.isActive ? AppColors.yellow : AppColors.blue)
                .withValues(alpha: 0.5),
            width: 1.5),
        padding: EdgeInsets.symmetric(
          horizontal: layout.isCompact ? 18 : 20,
          vertical: layout.isCompact ? 14 : 16,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
    );
  }

  void _showCashDrawerDialog(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.read(ordersProvider);
    final orders = ordersAsync.value ?? [];
    final openingFund = ref
            .read(activeSessionStatusProvider)
            .valueOrNull
            ?.activeSessionOpeningFund ??
        0.0;
    final validated = orders.where((o) => o.status == OrderStatus.validated);
    final cash = validated
        .where((o) => o.paymentType == PaymentType.cash)
        .fold<double>(0, (s, o) => s + o.total);
    final other = validated
        .where((o) =>
            o.paymentType != PaymentType.cash &&
            o.paymentType != PaymentType.card)
        .fold<double>(0, (s, o) => s + o.total);
    final reasonCtrl = TextEditingController();
    var isOpening = false;
    String? selectedReason;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.storefront_rounded, color: AppColors.blue),
              const SizedBox(width: 8),
              const Text('Open Cash Drawer'),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: isOpening ? null : () => Navigator.pop(ctx),
              ),
            ],
          ),
          content: SizedBox(
            width: context.posLayout.dialogWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.yellowSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.yellow),
                  ),
                  child: Column(
                    children: [
                      _DrawerRow('Total Cash',
                          '${(cash + openingFund).toStringAsFixed(3)} DT',
                          bold: true),
                      const Divider(height: 16),
                      _DrawerRow('Cash', '${cash.toStringAsFixed(3)} DT'),
                      const SizedBox(height: 4),
                      _DrawerRow('Other', '${other.toStringAsFixed(3)} DT'),
                      const SizedBox(height: 4),
                      _DrawerRow(
                        'Cash Fund',
                        '${openingFund.toStringAsFixed(3)} DT',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text('Reason *', style: AppTextStyles.label),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _ReasonButton(
                        icon: Icons.fact_check_rounded,
                        label: 'Checking',
                        isSelected: selectedReason == 'Checking',
                        onTap: isOpening
                            ? null
                            : () => setDialogState(
                                () => selectedReason = 'Checking'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _ReasonButton(
                        icon: Icons.payments_rounded,
                        label: 'Payment',
                        isSelected: selectedReason == 'Payment',
                        onTap: isOpening
                            ? null
                            : () => setDialogState(
                                () => selectedReason = 'Payment'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                    controller: reasonCtrl,
                    enabled: !isOpening,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        hintText: 'Additional details or custom reason...')),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: isOpening ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel')),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: isOpening
                        ? null
                        : () async {
                            final customReason = reasonCtrl.text.trim();
                            final finalReason = [
                              if (selectedReason != null) selectedReason,
                              if (customReason.isNotEmpty) customReason,
                            ].join(' - ');

                            if (finalReason.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Please select or enter a reason'),
                                      backgroundColor: AppColors.error));
                              return;
                            }

                            setDialogState(() => isOpening = true);
                            final result = await ref
                                .read(ordersProvider.notifier)
                                .openCashDrawer(finalReason);

                            if (!context.mounted) return;
                            if (dialogContext.mounted &&
                                Navigator.canPop(dialogContext)) {
                              Navigator.pop(dialogContext);
                            }
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.message),
                                backgroundColor: result.isSuccess
                                    ? AppColors.success
                                    : AppColors.error,
                                duration: const Duration(seconds: 6),
                              ),
                            );
                          },
                    icon: isOpening
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.lock_open_rounded, size: 16),
                    label: Text(isOpening ? 'Opening...' : 'Open Drawer'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _DrawerRow(this.label, this.value, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: bold
              ? AppTextStyles.title.copyWith(fontWeight: FontWeight.w800)
              : AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: bold
              ? AppTextStyles.title.copyWith(fontWeight: FontWeight.w900)
              : AppTextStyles.body.copyWith(fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _ReasonButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  const _ReasonButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? AppColors.blue : AppColors.neutral50,
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? AppColors.blue : AppColors.border,
              width: 1.5,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected ? AppColors.white : AppColors.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                label,
                style: AppTextStyles.title.copyWith(
                  color: isSelected ? AppColors.white : AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
