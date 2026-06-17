import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/services/receipt_printer_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/pos_layout.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/order_models.dart';
import '../../../data/providers/app_providers.dart';
import '../../../shared/widgets/status_chip.dart';

part '../widgets/today_sales_summary.dart';
part '../widgets/today_sales_table.dart';
part '../widgets/sale_details_modal.dart';

class TodaySalesScreen extends ConsumerStatefulWidget {
  const TodaySalesScreen({super.key});

  @override
  ConsumerState<TodaySalesScreen> createState() => _TodaySalesScreenState();
}

class _TodaySalesScreenState extends ConsumerState<TodaySalesScreen> {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(ordersProvider.notifier).refreshIfStale(
            maxAge: const Duration(seconds: 8),
            showLoading: ref.read(ordersProvider).asData == null,
          );
      _refreshTimer = Timer.periodic(const Duration(seconds: 5), (_) {
        if (!mounted) return;
        ref.read(ordersProvider.notifier).refreshIfStale(
              maxAge: const Duration(seconds: 10),
              showLoading: false,
            );
      });
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final ordersAsync = ref.watch(ordersProvider);

    return ordersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(child: Text('Error loading today sales')),
      data: (orders) {
        final validated =
            orders.where((o) => o.status == OrderStatus.validated).toList();
        final cancelled =
            orders.where((o) => o.status == OrderStatus.cancelled).toList();

        final cashTotal = validated
            .where((o) => o.paymentType == PaymentType.cash)
            .fold<double>(0, (s, o) => s + o.total);
        final cardTotal = validated
            .where((o) => o.paymentType == PaymentType.card)
            .fold<double>(0, (s, o) => s + o.total);
        final glovoTotal = validated
            .where((o) => o.paymentType == PaymentType.glovo)
            .fold<double>(0, (s, o) => s + o.total);
        final otherTotal = validated
            .where((o) =>
                o.paymentType != PaymentType.cash &&
                o.paymentType != PaymentType.card &&
                o.paymentType != PaymentType.glovo)
            .fold<double>(0, (s, o) => s + o.total);
        final totalRevenue = validated.fold<double>(0, (s, o) => s + o.total);

        return Column(
          children: [
            // Summary cards
            Container(
              padding: EdgeInsets.all(layout.pagePadding),
              color: AppColors.surfaceFor(context),
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _SummaryCard(
                    label: 'Revenue',
                    value: '${totalRevenue.toStringAsFixed(3)} DT',
                    icon: Icons.trending_up_rounded,
                    color: AppColors.blue,
                  ),
                  _SummaryCard(
                    label: 'Cash',
                    value: '${cashTotal.toStringAsFixed(3)} DT',
                    icon: Icons.payments_rounded,
                    color: AppColors.success,
                  ),
                  _SummaryCard(
                    label: 'Card',
                    value: '${cardTotal.toStringAsFixed(3)} DT',
                    icon: Icons.credit_card_rounded,
                    color: AppColors.info,
                  ),
                  _SummaryCard(
                    label: 'Glovo',
                    value: '${glovoTotal.toStringAsFixed(3)} DT',
                    icon: Icons.delivery_dining_rounded,
                    color: AppColors.blue,
                  ),
                  _SummaryCard(
                    label: 'Other',
                    value: '${otherTotal.toStringAsFixed(3)} DT',
                    icon: Icons.more_horiz_rounded,
                    color: AppColors.neutral600,
                  ),
                  _SummaryCard(
                    label: 'Tickets',
                    value: '${validated.length}',
                    icon: Icons.receipt_long_rounded,
                    color: AppColors.blue,
                  ),
                  _SummaryCard(
                    label: 'Cancelled',
                    value: '${cancelled.length}',
                    icon: Icons.cancel_rounded,
                    color: AppColors.error,
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppColors.borderFor(context)),
            // Orders table
            Expanded(
              child:
                  orders.isEmpty ? _EmptyState() : _OrdersTable(orders: orders),
            ),
          ],
        );
      },
    );
  }
}

class _TodaySalesTableMetrics {
  const _TodaySalesTableMetrics({
    required this.compact,
    required this.horizontalPadding,
    required this.columnGap,
    required this.dateWidth,
    required this.ticketWidth,
    required this.itemsWidth,
    required this.amountWidth,
    required this.paymentWidth,
    required this.statusWidth,
    required this.actionsWidth,
  });

  final bool compact;
  final double horizontalPadding;
  final double columnGap;
  final double dateWidth;
  final double ticketWidth;
  final double itemsWidth;
  final double amountWidth;
  final double paymentWidth;
  final double statusWidth;
  final double actionsWidth;

  double get headerVerticalPadding => compact ? 14 : 18;
  double get rowVerticalPadding => compact ? 14 : 22;

  factory _TodaySalesTableMetrics.forWidth(double availableWidth) {
    final compact = availableWidth < 1100;
    final veryCompact = availableWidth < 760;

    final horizontalPadding = veryCompact
        ? 8.0
        : compact
            ? 12.0
            : 24.0;
    final columnGap = veryCompact
        ? 4.0
        : compact
            ? 8.0
            : 12.0;
    final dateWidth = veryCompact
        ? 88.0
        : compact
            ? 106.0
            : 116.0;
    final ticketWidth = veryCompact
        ? 48.0
        : compact
            ? 60.0
            : 76.0;
    final amountWidth = veryCompact
        ? 82.0
        : compact
            ? 90.0
            : 96.0;
    final paymentWidth = veryCompact
        ? 84.0
        : compact
            ? 102.0
            : 126.0;
    final statusWidth = veryCompact
        ? 92.0
        : compact
            ? 112.0
            : 126.0;
    final actionsWidth = veryCompact
        ? 112.0
        : compact
            ? 124.0
            : 136.0;

    final fixedWidth = (horizontalPadding * 2) +
        (columnGap * 6) +
        dateWidth +
        ticketWidth +
        amountWidth +
        paymentWidth +
        statusWidth +
        actionsWidth;
    final minItemsWidth = veryCompact
        ? 150.0
        : compact
            ? 180.0
            : 220.0;
    final remainingItemsWidth = availableWidth - fixedWidth;
    final itemsWidth = remainingItemsWidth < minItemsWidth
        ? minItemsWidth
        : remainingItemsWidth;

    return _TodaySalesTableMetrics(
      compact: compact,
      horizontalPadding: horizontalPadding,
      columnGap: columnGap,
      dateWidth: dateWidth,
      ticketWidth: ticketWidth,
      itemsWidth: itemsWidth,
      amountWidth: amountWidth,
      paymentWidth: paymentWidth,
      statusWidth: statusWidth,
      actionsWidth: actionsWidth,
    );
  }
}
