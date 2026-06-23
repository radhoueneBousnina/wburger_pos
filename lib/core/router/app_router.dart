import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/app_providers.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/sales/screens/sales_screen.dart';
import '../../features/today_sales/screens/today_sales_screen.dart';
import '../../features/stock/screens/stock_screen.dart';
import '../../features/purchases/screens/purchases_screen.dart';
import '../../features/purchases/screens/create_purchase_screen.dart';
import '../../features/closures/screens/session_closure_screen.dart';
import '../../features/diagnostics/screens/diagnostics_screen.dart';
import '../../shared/widgets/app_shell.dart';

// Route names
class AppRoutes {
  static const login = '/login';
  static const sales = '/sales';
  static const todaySales = '/today-sales';
  static const stock = '/stock';
  static const purchases = '/purchases';
  static const createPurchase = '/purchases/create';
  static const sessionClosure = '/session_closure';
  static const diagnostics = '/diagnostics';
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.login,
    redirect: (context, state) {
      final isAuth = auth.isAuthenticated;
      final onLogin = state.uri.path == AppRoutes.login;

      if (!isAuth && !onLogin) return AppRoutes.login;
      if (isAuth && onLogin) return AppRoutes.sales;
      if (isAuth && !_canAccessRoute(auth, state.uri.path)) {
        return AppRoutes.sales;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.login,
        builder: (ctx, state) => const LoginScreen(),
      ),
      ShellRoute(
        navigatorKey: _shellNavigatorKey,
        builder: (ctx, state, child) => AppShell(
          lockNavigation: state.uri.path == AppRoutes.sessionClosure &&
              state.uri.queryParameters['forced'] == '1',
          child: child,
        ),
        routes: [
          GoRoute(
            path: AppRoutes.sales,
            builder: (ctx, state) => const SalesScreen(),
          ),
          GoRoute(
            path: AppRoutes.todaySales,
            builder: (ctx, state) => const TodaySalesScreen(),
          ),
          GoRoute(
            path: AppRoutes.stock,
            builder: (ctx, state) => const StockScreen(),
          ),
          GoRoute(
            path: AppRoutes.purchases,
            builder: (ctx, state) => const PurchasesScreen(),
          ),
          GoRoute(
            path: AppRoutes.createPurchase,
            builder: (ctx, state) => const CreatePurchaseScreen(),
          ),
          GoRoute(
            path: AppRoutes.sessionClosure,
            builder: (ctx, state) => const SessionClosureScreen(),
          ),
          GoRoute(
            path: AppRoutes.diagnostics,
            builder: (ctx, state) => const DiagnosticsScreen(),
          ),
        ],
      ),
    ],
  );
});

bool _canAccessRoute(AuthState auth, String path) {
  if (path == AppRoutes.stock) {
    return auth.permissions['can_access_stock'] == true;
  }
  if (path == AppRoutes.purchases || path == AppRoutes.createPurchase) {
    return auth.permissions['can_access_purchases'] == true;
  }
  if (path == AppRoutes.todaySales) {
    return auth.permissions['can_view_daily_stats'] == true;
  }
  if (path == AppRoutes.sessionClosure) {
    return auth.permissions['can_close_session'] == true;
  }
  if (path == AppRoutes.diagnostics) {
    return false;
  }
  return true;
}
