import 'dart:math' as math;

import 'package:flutter/material.dart';

class PosLayout {
  const PosLayout._({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  static PosLayout of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return PosLayout._(width: size.width, height: size.height);
  }

  bool get isCompact => width < 1280;
  bool get isMedium => width >= 1280 && width < 1600;
  bool get isLarge => width >= 1600;
  bool get stackPanels => width < 1180;
  bool get showWideLoginLayout {
    final landscapePosTerminal =
        width >= 800 && height >= 540 && width / height >= 1.2;
    return width >= 1120 || landscapePosTerminal;
  }

  double get pagePadding => isCompact ? 16 : 24;
  double get sectionGap => isCompact ? 16 : 24;
  double get cardRadius => isCompact ? 16 : 20;
  double get touchTarget => isCompact ? 64 : 72;
  double get iconTouchTarget => isCompact ? 60 : 68;
  double get topBarHeight => isCompact ? 72 : 80;
  double get drawerWidth => isCompact ? 284 : 320;
  double get sidebarItemHeight => isCompact ? 64 : 72;
  double get cartPanelWidth => isCompact ? 360 : 410;
  double get dialogWidth => math.min(width - (pagePadding * 2), 880);

  int gridColumns(double availableWidth) {
    final minCardWidth = isCompact ? 176.0 : 205.0;
    return math.max(2, (availableWidth / minCardWidth).floor());
  }

  double productCardAspectRatio(double availableWidth) {
    final columns = gridColumns(availableWidth);
    final totalSpacing = (columns - 1) * 8.0;
    final cardWidth = (availableWidth - totalSpacing) / columns;
    return isCompact ? cardWidth / 270 : cardWidth / 286;
  }
}

extension PosLayoutContext on BuildContext {
  PosLayout get posLayout => PosLayout.of(this);
}
