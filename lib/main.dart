import 'dart:async';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/network/api_client.dart';
import 'core/services/monitoring_service.dart';
import 'data/providers/app_providers.dart';

void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      unawaited(PosMonitoringService.instance.recordFlutterError(details));
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      unawaited(PosMonitoringService.instance.recordException(error, stack));
      return true;
    };

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.windows) {
      await windowManager.ensureInitialized();
      const windowOptions = WindowOptions(
        title: 'W Burger - POS',
        center: true,
        size: Size(1280, 720),
        fullScreen: true,
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.show();
        await windowManager.focus();
      });
    }

    // Force landscape mode for POS terminal
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);

    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
      ),
    );

    await PosMonitoringService.instance.init();

    // POS access must be explicit for each app launch. If the app is closed,
    // crashes, or the browser tab is reopened, do not restore the previous
    // staff session from persisted storage.
    await apiClient.clearAllTokens();

    runApp(
      ProviderScope(
        overrides: [
          initialAuthStateProvider.overrideWithValue(false),
        ],
        child: const WBurgerPosApp(),
      ),
    );
  }, (error, stack) {
    unawaited(PosMonitoringService.instance.recordException(error, stack));
  });
}

class WBurgerPosApp extends ConsumerWidget {
  const WBurgerPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'W Burger - POS',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
      builder: (context, child) => FocusTraversalGroup(
        // Flutter Web can ask reading-order traversal for widget geometry while
        // responsive pages are still laying out. Widget order keeps keyboard
        // navigation predictable without touching unlaid RenderBoxes.
        policy: WidgetOrderTraversalPolicy(),
        child: _DesktopShellShortcuts(
          child: child ?? const SizedBox.shrink(),
        ),
      ),
      scrollBehavior: const MaterialScrollBehavior().copyWith(
        dragDevices: {
          PointerDeviceKind.mouse,
          PointerDeviceKind.touch,
          PointerDeviceKind.stylus,
          PointerDeviceKind.trackpad,
        },
      ),
    );
  }
}

class _DesktopShellShortcuts extends StatefulWidget {
  final Widget child;

  const _DesktopShellShortcuts({required this.child});

  @override
  State<_DesktopShellShortcuts> createState() => _DesktopShellShortcutsState();
}

class _DesktopShellShortcutsState extends State<_DesktopShellShortcuts> {
  static const _escapeHoldDuration = Duration(milliseconds: 700);

  Timer? _escapeHoldTimer;

  bool get _isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    if (_isWindowsDesktop) {
      HardwareKeyboard.instance.addHandler(_handleKey);
    }
  }

  @override
  void dispose() {
    if (_isWindowsDesktop) {
      HardwareKeyboard.instance.removeHandler(_handleKey);
    }
    _escapeHoldTimer?.cancel();
    super.dispose();
  }

  bool _handleKey(KeyEvent event) {
    if (!_isWindowsDesktop) return false;

    if (event.logicalKey == LogicalKeyboardKey.f11 && event is KeyDownEvent) {
      unawaited(windowManager.setFullScreen(true));
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        _escapeHoldTimer ??= Timer(_escapeHoldDuration, () {
          _escapeHoldTimer = null;
          unawaited(windowManager.setFullScreen(false));
        });
      } else if (event is KeyUpEvent) {
        _escapeHoldTimer?.cancel();
        _escapeHoldTimer = null;
      }
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
