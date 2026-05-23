import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/pos_layout.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/router/app_router.dart';
import '../../data/providers/app_providers.dart';

class SidebarNav extends ConsumerWidget {
  final bool closeOnNavigate;

  const SidebarNav({
    super.key,
    this.closeOnNavigate = true,
  });

  static const _items = [
    _NavItem(
        icon: Icons.point_of_sale_rounded,
        label: 'Sales',
        route: AppRoutes.sales),
    _NavItem(
        icon: Icons.receipt_long_rounded,
        label: "Today's Sales",
        route: AppRoutes.todaySales,
        permission: 'can_view_daily_stats'),
    _NavItem(
        icon: Icons.inventory_2_rounded,
        label: 'Stock',
        route: AppRoutes.stock,
        permission: 'can_access_stock'),
    _NavItem(
        icon: Icons.shopping_cart_rounded,
        label: 'Purchases',
        route: AppRoutes.purchases,
        permission: 'can_access_purchases'),
    _NavItem(
        icon: Icons.lock_clock_rounded,
        label: 'Session Closure',
        route: AppRoutes.sessionClosure,
        permission: 'can_close_session'),
    _NavItem(
        icon: Icons.health_and_safety_rounded,
        label: 'Diagnostics',
        route: AppRoutes.diagnostics),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = context.posLayout;
    final location = GoRouterState.of(context).uri.path;
    final auth = ref.watch(authProvider);

    return ClipRRect(
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Blue background
          Positioned.fill(child: Container(color: AppColors.blue)),
          // Blob decoration — top right
          Positioned(
            top: -40,
            right: -60,
            child: CustomPaint(
              size: const Size(180, 180),
              painter: _SidebarBlobPainter(),
            ),
          ),
          // Checkerboard at bottom
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: SizedBox(
              height: 56,
              child: CustomPaint(
                painter: _SidebarCheckerPainter(),
              ),
            ),
          ),
          // Content
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // HEADER — big logo
              Container(
                padding: EdgeInsets.fromLTRB(
                  layout.isCompact ? 16 : 20,
                  layout.isCompact ? 24 : 32,
                  layout.isCompact ? 16 : 20,
                  layout.isCompact ? 12 : 16,
                ),
                child: Column(
                  children: [
                    Image.asset(
                      'assets/logos/logo_yellow.png',
                      height: layout.isCompact ? 64 : 80,
                      cacheHeight: ((layout.isCompact ? 64 : 80) *
                              MediaQuery.devicePixelRatioOf(context))
                          .round(),
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const Text(
                        'W',
                        style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w900,
                            color: AppColors.yellow),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'POS Terminal',
                      style: AppTextStyles.bodySm.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        letterSpacing: 2.0,
                        fontSize: layout.isCompact ? 10 : 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: layout.isCompact ? 20 : 24),
                    Container(
                        height: 1, color: Colors.white.withValues(alpha: 0.12)),
                  ],
                ),
              ),
              // Nav items
              Expanded(
                child: ListView(
                  padding: EdgeInsets.symmetric(
                    horizontal: layout.isCompact ? 10 : 12,
                    vertical: 8,
                  ),
                  children: _items.where((item) {
                    final permission = item.permission;
                    return permission == null ||
                        auth.permissions[permission] == true;
                  }).map((item) {
                    // Match active state — handle createPurchase sub-route
                    final active = location == item.route ||
                        (item.route == AppRoutes.purchases &&
                            location == AppRoutes.createPurchase);
                    return _NavTile(
                      item: item,
                      active: active,
                      closeOnNavigate: closeOnNavigate,
                    );
                  }).toList(),
                ),
              ),
              const _TestModeControl(),
              // User info + logout
              Padding(
                padding: EdgeInsets.fromLTRB(
                  layout.isCompact ? 10 : 12,
                  0,
                  layout.isCompact ? 10 : 12,
                  layout.isCompact ? 16 : 24,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () async {
                      await ref.read(authProvider.notifier).logout();
                      if (context.mounted) {
                        context.go(AppRoutes.login);
                        if (closeOnNavigate && Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      }
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: EdgeInsets.all(layout.isCompact ? 14 : 16),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: const BoxDecoration(
                                color: AppColors.yellow,
                                shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: Text(
                              (auth.username?.isNotEmpty == true
                                      ? auth.username![0]
                                      : 'A')
                                  .toUpperCase(),
                              style: AppTextStyles.title.copyWith(
                                  color: AppColors.blue,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(auth.username ?? 'Staff',
                                    style: AppTextStyles.titleSm
                                        .copyWith(color: Colors.white)),
                                Text(
                                  (auth.role ?? 'Staff').toUpperCase(),
                                  style: AppTextStyles.bodySm.copyWith(
                                    color:
                                        AppColors.yellow.withValues(alpha: 0.8),
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.logout_rounded,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'EXIT',
                                  style: AppTextStyles.label.copyWith(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TestModeControl extends ConsumerWidget {
  const _TestModeControl();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = context.posLayout;
    final state = ref.watch(testModeProvider);
    final notifier = ref.read(testModeProvider.notifier);
    final active = state.isActive;
    final pending = state.isPending;
    final busy = state.requesting || state.loading;

    final Color borderColor = active
        ? AppColors.yellow.withValues(alpha: 0.7)
        : pending
            ? AppColors.warning.withValues(alpha: 0.7)
            : Colors.white.withValues(alpha: 0.2);
    final Color bgColor = active
        ? AppColors.yellow.withValues(alpha: 0.16)
        : pending
            ? AppColors.warning.withValues(alpha: 0.16)
            : Colors.white.withValues(alpha: 0.08);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: layout.isCompact ? 10 : 12,
        vertical: 8,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: busy
              ? null
              : active
                  ? notifier.stopTestMode
                  : pending
                      ? () => notifier.refreshCurrent()
                      : notifier.requestTestMode,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: EdgeInsets.all(layout.isCompact ? 12 : 14),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                Icon(
                  active
                      ? Icons.science_rounded
                      : pending
                          ? Icons.hourglass_top_rounded
                          : Icons.school_rounded,
                  color: active || pending ? AppColors.yellow : Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        active
                            ? 'Training Active'
                            : pending
                                ? 'Request Pending'
                                : 'Test Mode',
                        style: AppTextStyles.titleSm.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        active
                            ? 'Tap to stop'
                            : pending
                                ? 'Waiting admin approval'
                                : 'Ask admin to approve',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySm.copyWith(
                          color: Colors.white.withValues(alpha: 0.68),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
                if (busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.yellow,
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

class _NavTile extends StatelessWidget {
  final _NavItem item;
  final bool active;
  final bool closeOnNavigate;

  const _NavTile({
    required this.item,
    required this.active,
    required this.closeOnNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {
            context.go(item.route);
            if (closeOnNavigate && Navigator.canPop(context)) {
              Navigator.pop(context);
            }
          },
          borderRadius: BorderRadius.circular(16),
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            constraints: BoxConstraints(minHeight: layout.sidebarItemHeight),
            padding: EdgeInsets.symmetric(
              horizontal: layout.isCompact ? 16 : 18,
              vertical: layout.isCompact ? 14 : 16,
            ),
            decoration: BoxDecoration(
              color: active ? AppColors.yellow : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(item.icon,
                    size: layout.isCompact ? 24 : 26,
                    color: active
                        ? AppColors.blue
                        : Colors.white.withValues(alpha: 0.85)),
                const SizedBox(width: 14),
                Text(
                  item.label,
                  style: AppTextStyles.title.copyWith(
                    color: active
                        ? AppColors.blue
                        : Colors.white.withValues(alpha: 0.85),
                    fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                    fontSize: layout.isCompact ? 14 : 15,
                  ),
                ),
                if (active) ...[
                  const Spacer(),
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: AppColors.blue, shape: BoxShape.circle),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final String route;
  final String? permission;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.route,
    this.permission,
  });
}

// ---- Painters ----
class _SidebarBlobPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppColors.yellow.withValues(alpha: 0.15);
    final path = Path();
    final w = size.width;
    final h = size.height;
    path.moveTo(w * 0.5, 0);
    path.cubicTo(w * 0.9, 0, w, h * 0.3, w * 0.95, h * 0.6);
    path.cubicTo(w * 0.9, h * 0.9, w * 0.7, h, w * 0.4, h * 0.9);
    path.cubicTo(w * 0.1, h * 0.8, 0, h * 0.6, 0.05 * w, h * 0.35);
    path.cubicTo(0.1 * w, h * 0.1, w * 0.1, 0, w * 0.5, 0);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SidebarCheckerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const tileSize = 18.0;
    final yellowPaint = Paint()
      ..color = AppColors.yellow.withValues(alpha: 0.6);
    final whitePaint = Paint()..color = Colors.white.withValues(alpha: 0.2);

    int col = 0;
    for (double x = 0; x < size.width + tileSize; x += tileSize) {
      int row = 0;
      for (double y = 0; y < size.height; y += tileSize) {
        final paint = ((col + row) % 2 == 0) ? yellowPaint : whitePaint;
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x + 1.5, y + 1.5, tileSize - 3, tileSize - 3),
          const Radius.circular(3),
        );
        canvas.drawRRect(rect, paint);
        row++;
      }
      col++;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
