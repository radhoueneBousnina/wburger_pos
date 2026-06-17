import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wburger_pos/core/services/windows_fullscreen_shortcuts.dart';

void main() {
  const escapeDown = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.escape,
    logicalKey: LogicalKeyboardKey.escape,
    timeStamp: Duration.zero,
  );
  const escapeUp = KeyUpEvent(
    physicalKey: PhysicalKeyboardKey.escape,
    logicalKey: LogicalKeyboardKey.escape,
    timeStamp: Duration.zero,
  );
  const f11Down = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.f11,
    logicalKey: LogicalKeyboardKey.f11,
    timeStamp: Duration.zero,
  );

  testWidgets('holding Escape exits fullscreen', (tester) async {
    final fullscreenStates = <bool>[];
    final shortcuts = WindowsFullscreenShortcuts(
      setFullScreen: (enabled) async => fullscreenStates.add(enabled),
    );
    addTearDown(shortcuts.dispose);

    expect(shortcuts.handleKey(escapeDown), isTrue);
    await tester.pump(const Duration(milliseconds: 699));
    expect(fullscreenStates, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(fullscreenStates, [false]);
  });

  testWidgets('releasing Escape early keeps fullscreen', (tester) async {
    final fullscreenStates = <bool>[];
    final shortcuts = WindowsFullscreenShortcuts(
      setFullScreen: (enabled) async => fullscreenStates.add(enabled),
    );
    addTearDown(shortcuts.dispose);

    expect(shortcuts.handleKey(escapeDown), isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    expect(shortcuts.handleKey(escapeUp), isTrue);
    await tester.pump(const Duration(seconds: 1));

    expect(fullscreenStates, isEmpty);
  });

  test('F11 enters fullscreen', () async {
    final fullscreenStates = <bool>[];
    final shortcuts = WindowsFullscreenShortcuts(
      setFullScreen: (enabled) async => fullscreenStates.add(enabled),
    );
    addTearDown(shortcuts.dispose);

    expect(shortcuts.handleKey(f11Down), isTrue);
    await Future<void>.delayed(Duration.zero);

    expect(fullscreenStates, [true]);
  });
}
