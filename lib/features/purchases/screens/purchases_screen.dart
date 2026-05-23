import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/pos_layout.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/stock_models.dart';
import '../../../data/providers/app_providers.dart';
import '../../../shared/widgets/app_image.dart';

part '../widgets/purchases_table.dart';
part '../widgets/purchase_details_widgets.dart';

class PurchasesScreen extends ConsumerWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = context.posLayout;
    final purchasesAsync = ref.watch(purchasesProvider);
    final testMode = ref.watch(testModeProvider);

    return purchasesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) =>
          Center(child: Text('Error loading purchases $err')),
      data: (purchases) => Column(
        children: [
          // Header actions
          Container(
            padding: EdgeInsets.symmetric(
                horizontal: layout.pagePadding, vertical: 12),
            color:
                testMode.isActive ? const Color(0xFF151827) : AppColors.white,
            child: Row(
              children: [
                Text(
                  testMode.isActive
                      ? 'Training Purchase History'
                      : 'Purchase History',
                  style: AppTextStyles.h4.copyWith(
                    color: testMode.isActive
                        ? AppColors.white
                        : AppColors.textPrimary,
                  ),
                ),
                const Spacer(),
                ElevatedButton.icon(
                  onPressed: () => context.go(AppRoutes.createPurchase),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Purchase'),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // List
          Expanded(
            child: purchases.isEmpty
                ? _EmptyPurchases()
                : _PurchasesTable(purchases: purchases),
          ),
        ],
      ),
    );
  }
}
