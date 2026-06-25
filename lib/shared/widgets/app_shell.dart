import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/pos_layout.dart';
import '../../core/router/app_router.dart';
import '../../data/providers/app_providers.dart';
import 'sidebar_nav.dart';
import 'top_bar.dart';
import 'brand_patterns.dart';

class AppShell extends ConsumerStatefulWidget {
  final Widget child;
  final bool lockNavigation;

  const AppShell({
    super.key,
    required this.child,
    this.lockNavigation = false,
  });

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> {
  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final showSidebar = !widget.lockNavigation && layout.width >= 1700;
    final sessionStatus = ref.watch(activeSessionStatusProvider);
    final testMode = ref.watch(testModeProvider);
    final connectionState = ref.watch(posConnectionProvider);
    ref.watch(cashDrawerKeyMonitorProvider);
    final path = GoRouterState.of(context).uri.path;
    final isSalesPage = path == AppRoutes.sales;
    final canCloseSession =
        ref.watch(authProvider).permissions['can_close_session'] == true;

    ref.listen<PosConnectionState>(posConnectionProvider, (previous, next) {
      final wasOffline = previous?.isOffline ?? false;
      if (next.isOffline && !wasOffline) {
        _showConnectionSnack(
          message: 'Internet connection lost. POS is offline.',
          backgroundColor: AppColors.error,
          icon: Icons.wifi_off_rounded,
        );
      } else if (!next.isOffline && wasOffline) {
        _showConnectionSnack(
          message: 'Internet connection restored.',
          backgroundColor: AppColors.success,
          icon: Icons.wifi_rounded,
        );
      }
    });

    sessionStatus.whenData((status) {
      if (status != null &&
          !testMode.isActive &&
          canCloseSession &&
          status.activeSessionDateDiffDays >= 2 &&
          path != AppRoutes.sessionClosure) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            final previousDate =
                Uri.encodeComponent(status.activeSessionDate ?? '');
            context.go(
              '${AppRoutes.sessionClosure}?forced=1&previous_date=$previousDate',
            );
          }
        });
      }
    });

    final body = Scaffold(
      backgroundColor: testMode.isActive
          ? AppColors.trainingBackground
          : AppColors.neutral50,
      drawer: showSidebar || widget.lockNavigation ? null : const _AppDrawer(),
      body: Stack(
        children: [
          if (!testMode.isActive) ...[
            Positioned(
              top: -100,
              right: -100,
              child: CustomPaint(
                size: const Size(400, 400),
                painter: BrandBlobPainter(
                    color: AppColors.yellow.withValues(alpha: 0.1)),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -50,
              child: CustomPaint(
                size: const Size(300, 300),
                painter: BrandBlobPainter(
                    color: AppColors.blue.withValues(alpha: 0.06)),
              ),
            ),
          ],
          Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    if (showSidebar)
                      SizedBox(
                        width: layout.drawerWidth,
                        child: const SidebarNav(closeOnNavigate: false),
                      ),
                    Expanded(
                      child: Column(
                        children: [
                          if (!isSalesPage)
                            TopBar(
                                showMenuButton:
                                    !showSidebar && !widget.lockNavigation),
                          if (testMode.isActive) const _TrainingModeBanner(),
                          if (connectionState.isOffline)
                            _ConnectionLostBanner(
                              onRetry: () => ref
                                  .read(posConnectionProvider.notifier)
                                  .checkNow(),
                            ),
                          Expanded(child: widget.child),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (!testMode.isActive) return body;
    return Theme(
      data: AppTheme.trainingTheme,
      child: body,
    );
  }

  void _showConnectionSnack({
    required String message,
    required Color backgroundColor,
    required IconData icon,
  }) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          backgroundColor: backgroundColor,
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Icon(icon, color: AppColors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    });
  }
}

class _TrainingModeBanner extends ConsumerWidget {
  const _TrainingModeBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final testMode = ref.watch(testModeProvider);
    final layout = context.posLayout;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF0D1020),
        border: Border(
          bottom: BorderSide(color: Color(0x33FFD500)),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_rounded, color: AppColors.yellow, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'TRAINING MODE - sales, purchases, and stock movements are temporary',
              style: AppTextStyles.label.copyWith(
                color: AppColors.yellow,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          TextButton.icon(
            onPressed: testMode.loading
                ? null
                : () => ref.read(testModeProvider.notifier).stopTestMode(),
            icon: const Icon(Icons.stop_circle_rounded, size: 18),
            label: const Text('Stop'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.yellow,
              minimumSize: Size(112, layout.touchTarget - 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionLostBanner extends StatelessWidget {
  final VoidCallback onRetry;

  const _ConnectionLostBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;
    final errorColor = AppColors.semanticTextFor(context, AppColors.error);
    final compact = layout.isCompact;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 12 : 18,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: AppColors.errorSurfaceFor(context),
        border: Border(
          bottom: BorderSide(color: errorColor.withValues(alpha: 0.45)),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.wifi_off_rounded, color: errorColor, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Internet connection lost - POS is offline. Some actions may fail until the connection returns.',
              maxLines: compact ? 2 : 1,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleSm.copyWith(
                color: errorColor,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry'),
            style: TextButton.styleFrom(
              foregroundColor: errorColor,
              minimumSize: Size(104, layout.touchTarget - 10),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
        ],
      ),
    );
  }
}

/// Wraps the SidebarNav inside a styled Drawer with smooth animation
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    final layout = context.posLayout;

    return Drawer(
      width: layout.drawerWidth,
      elevation: 24,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(0),
          bottomRight: Radius.circular(0),
        ),
      ),
      child: const SidebarNav(closeOnNavigate: true),
    );
  }
}
