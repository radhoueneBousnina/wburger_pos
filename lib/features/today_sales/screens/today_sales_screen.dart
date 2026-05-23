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
        final otherTotal = validated
            .where((o) =>
                o.paymentType != PaymentType.cash &&
                o.paymentType != PaymentType.card)
            .fold<double>(0, (s, o) => s + o.total);
        final totalRevenue = validated.fold<double>(0, (s, o) => s + o.total);

        return Column(
          children: [
            // Summary cards
            Container(
              padding: EdgeInsets.all(layout.pagePadding),
              color: AppColors.white,
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
            const Divider(height: 1),
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

class _TodaySalesTableSpec {
  const _TodaySalesTableSpec();

  static const double horizontalPadding = 24;
  static const double dateWidth = 100;
  static const double ticketWidth = 80;
  static const double itemsWidth = 320;
  static const double amountWidth = 90;
  static const double paymentWidth = 120;
  static const double statusWidth = 120;
  static const double actionsWidth = 120;

  double get minWidth =>
      (horizontalPadding * 2) +
      dateWidth +
      ticketWidth +
      itemsWidth +
      amountWidth +
      paymentWidth +
      statusWidth +
      actionsWidth +
      (16 * 7);
}
