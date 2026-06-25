import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand Primary
  static const Color blue = Color(0xFF2814B8);
  static const Color yellow = Color(0xFFFFD500);
  static const Color white = Color(0xFFFFFFFF);

  // Blue Shades
  static const Color blueLight = Color(0xFF3A25D8);
  static const Color blueDark = Color(0xFF1A0B7D);
  static const Color blueSurface = Color(0xFFECE9FF);
  static const Color blueBorder = Color(0xFFC7BFFF);

  // Yellow Shades
  static const Color yellowLight = Color(0xFFFFE04D);
  static const Color yellowDark = Color(0xFFCCAA00);
  static const Color yellowSurface = Color(0xFFFFFBE6);

  // Neutrals
  static const Color neutral50 = Color(0xFFF8F9FA);
  static const Color neutral100 = Color(0xFFF1F3F5);
  static const Color neutral200 = Color(0xFFE9ECEF);
  static const Color neutral300 = Color(0xFFDEE2E6);
  static const Color neutral400 = Color(0xFFCED4DA);
  static const Color neutral500 = Color(0xFFADB5BD);
  static const Color neutral600 = Color(0xFF6C757D);
  static const Color neutral700 = Color(0xFF495057);
  static const Color neutral800 = Color(0xFF343A40);
  static const Color neutral900 = Color(0xFF212529);

  // Semantic
  static const Color success = Color(0xFF28A745);
  static const Color successLight = Color(0xFFD4EDDA);
  static const Color warning = Color(0xFFFF8C00);
  static const Color warningLight = Color(0xFFFFF3CD);
  static const Color error = Color(0xFFDC3545);
  static const Color errorLight = Color(0xFFF8D7DA);
  static const Color info = Color(0xFF17A2B8);
  static const Color infoLight = Color(0xFFD1ECF1);

  // Sidebar
  static const Color sidebarBg = Color(0xFF2814B8);
  static const Color sidebarSelected = Color(0xFF3A25D8);
  static const Color sidebarText = Color(0xFFFFFFFF);
  static const Color sidebarIcon = Color(0xFFC7BFFF);

  // Surface
  static const Color background = Color(0xFFFFFFFF);
  static const Color surface = Color(0xFFF8F9FA);
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE9ECEF);

  // Text
  static const Color textPrimary = Color(0xFF212529);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textDisabled = Color(0xFFADB5BD);
  static const Color textOnBlue = Color(0xFFFFFFFF);
  static const Color textOnYellow = Color(0xFF2814B8);

  // Training mode surfaces
  static const Color trainingBackground = Color(0xFF10131F);
  static const Color trainingSurface = Color(0xFF151827);
  static const Color trainingPanel = Color(0xFF191D2E);
  static const Color trainingElevated = Color(0xFF1D2235);
  static const Color trainingBorder = Color(0x33FFFFFF);
  static const Color trainingTextSecondary = Color(0xFF9AA3B8);
  static const Color trainingAccentSurface = Color(0xFF222842);

  static bool isTraining(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  static Color pageBackgroundFor(BuildContext context) =>
      isTraining(context) ? trainingBackground : neutral50;

  static Color shellBackgroundFor(BuildContext context) =>
      isTraining(context) ? trainingBackground : background;

  static Color surfaceFor(BuildContext context) =>
      isTraining(context) ? trainingSurface : white;

  static Color panelFor(BuildContext context) =>
      isTraining(context) ? trainingPanel : white;

  static Color elevatedSurfaceFor(BuildContext context) =>
      isTraining(context) ? trainingElevated : neutral50;

  static Color inputFillFor(BuildContext context) =>
      isTraining(context) ? const Color(0xFF22283C) : neutral50;

  static Color modalHeaderFor(BuildContext context) =>
      isTraining(context) ? const Color(0xFF20263A) : blue;

  static Color accentFor(BuildContext context) =>
      isTraining(context) ? yellow : blue;

  static Color onAccentFor(BuildContext context) =>
      isTraining(context) ? blueDark : white;

  static Color accentSurfaceFor(BuildContext context) =>
      isTraining(context) ? trainingAccentSurface : yellowSurface;

  static Color selectedSurfaceFor(BuildContext context) =>
      isTraining(context) ? yellow : blue;

  static Color selectedTextFor(BuildContext context) =>
      isTraining(context) ? blueDark : white;

  static Color tableHeaderFor(BuildContext context) =>
      isTraining(context) ? trainingSurface : neutral50;

  static Color borderFor(BuildContext context) =>
      isTraining(context) ? trainingBorder : border;

  static Color textPrimaryFor(BuildContext context) =>
      isTraining(context) ? white : textPrimary;

  static Color textSecondaryFor(BuildContext context) =>
      isTraining(context) ? trainingTextSecondary : textSecondary;

  static Color semanticTextFor(BuildContext context, Color color) {
    if (!isTraining(context)) return color;
    return semanticTextForDark(color);
  }

  static Color semanticTextForDark(Color color) {
    if (color == success) return const Color(0xFF7FE6A2);
    if (color == error) return const Color(0xFFFF8FA0);
    if (color == warning) return const Color(0xFFFFC766);
    if (color == info) return const Color(0xFF7DD8E8);
    return color;
  }

  static Color errorSurfaceFor(BuildContext context) =>
      isTraining(context) ? const Color(0xFF3A1D29) : errorLight;

  static Color warningSurfaceFor(BuildContext context) =>
      isTraining(context) ? const Color(0xFF3A2D14) : warningLight;

  static Color successSurfaceFor(BuildContext context) =>
      isTraining(context) ? const Color(0xFF173322) : successLight;

  static Color infoSurfaceFor(BuildContext context) =>
      isTraining(context) ? const Color(0xFF15313A) : infoLight;

  static Color subtlePatternFor(BuildContext context, Color color) =>
      isTraining(context)
          ? color.withValues(alpha: 0.05)
          : color.withValues(alpha: 0.03);
}
