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
import 'core/services/windows_fullscreen_shortcuts.dart';
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
        title: 'W Burger POS',
        center: true,
        size: Size(1280, 720),
        fullScreen: true,
      );
      await windowManager.waitUntilReadyToShow(windowOptions, () async {
        await windowManager.setFullScreen(true);
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
      title: 'W Burger POS',
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
  WindowsFullscreenShortcuts? _shortcuts;

  bool get _isWindowsDesktop =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    if (_isWindowsDesktop) {
      _shortcuts = WindowsFullscreenShortcuts(
        setFullScreen: windowManager.setFullScreen,
      );
      HardwareKeyboard.instance.addHandler(_shortcuts!.handleKey);
    }
  }

  @override
  void dispose() {
    final shortcuts = _shortcuts;
    if (shortcuts != null) {
      HardwareKeyboard.instance.removeHandler(shortcuts.handleKey);
      shortcuts.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
