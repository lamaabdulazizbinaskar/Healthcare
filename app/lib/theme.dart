import 'package:flutter/material.dart';

/// Bundled font (see pubspec.yaml). Explicit TextStyles that replace (not merge) the default
/// style — app bar, buttons, tabs — must name it, or Arabic falls back to a font without glyphs.
const kFont = 'Tajawal';

/// Global text scale applied in main.dart (all font sizes in the code are multiplied by it).
const kTextScale = 0.85;

/// Design tokens. Warm, calm palette with high-contrast text for older eyes.
class AppColors {
  static const primary = Color(0xFF0F6B5A); // deep teal-green
  static const primaryDark = Color(0xFF0A4F43);
  static const primaryLight = Color(0xFFE3F1EC);
  static const accent = Color(0xFFF2B544); // warm sand-gold, used sparingly
  static const ink = Color(0xFF14211D);
  static const muted = Color(0xFF3E4A45); // dark enough to read easily
  static const bg = Color(0xFFF6F3EE); // warm off-white
  static const card = Colors.white;
  static const border = Color(0xFFE2DDD3);
  static const danger = Color(0xFFC62828);
  static const dangerBg = Color(0xFFFDECEC);
  static const warn = Color(0xFFB25E00);
  static const warnBg = Color(0xFFFFF3E0);
  static const ok = Color(0xFF2E7D32);
  static const okBg = Color(0xFFE8F5EA);
  // Dark "health dashboard" cards (charts, progress) with glowing accents.
  static const navy = Color(0xFF0B1E33);
  static const navyCard = Color(0xFF12304D);
  static const glow = Color(0xFF2FE0C3); // teal glow
  static const glowBlue = Color(0xFF4FC3F7);
  static const glowRed = Color(0xFFFF6B81);
  static const water = Color(0xFF2E9BEA);
}

/// 3D illustration asset path (Microsoft Fluent Emoji, MIT).
String img3d(String name) => 'assets/3d/$name.png';

const kDashboardGradient = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF0B1E33), Color(0xFF0F3A4A)],
);

/// One colour, icon and 3D illustration per goal category so the checklist scans at a glance.
class CategoryStyle {
  const CategoryStyle(this.color, this.icon, this.image);
  final Color color;
  final IconData icon;
  final String image; // name in assets/3d

  static const _map = {
    'diet': CategoryStyle(Color(0xFFD9772B), Icons.restaurant_rounded, 'salad'),
    'activity': CategoryStyle(
      Color(0xFF2F6FDB),
      Icons.directions_walk_rounded,
      'walking',
    ),
    'medication': CategoryStyle(
      Color(0xFF7B4FD0),
      Icons.medication_rounded,
      'pill',
    ),
    'monitoring': CategoryStyle(
      Color(0xFFD0445A),
      Icons.monitor_heart_rounded,
      'stethoscope',
    ),
    'weight': CategoryStyle(
      Color(0xFF2E9E6A),
      Icons.monitor_weight_rounded,
      'scale',
    ),
    'lifestyle': CategoryStyle(
      Color(0xFF5F6B73),
      Icons.smoke_free_rounded,
      'no_smoking',
    ),
    'selfcare': CategoryStyle(
      Color(0xFF0E8C8C),
      Icons.health_and_safety_rounded,
      'leg',
    ),
  };

  static CategoryStyle of(String? category) =>
      _map[category] ??
      const CategoryStyle(AppColors.primary, Icons.flag_rounded, 'target');
}

const kRadius = 18.0;
const kShadow = [
  BoxShadow(color: Color(0x12000000), blurRadius: 18, offset: Offset(0, 6)),
];

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: kFont,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.bg,
      error: AppColors.danger,
    ),
    scaffoldBackgroundColor: AppColors.bg,
  );
  final text = base.textTheme.apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );
  OutlineInputBorder border(Color c, double w) => OutlineInputBorder(
    borderRadius: BorderRadius.circular(16),
    borderSide: BorderSide(color: c, width: w),
  );
  return base.copyWith(
    textTheme: text.copyWith(
      headlineMedium: text.headlineMedium?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w900,
      ),
      headlineSmall: text.headlineSmall?.copyWith(
        fontSize: 26,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: text.titleLarge?.copyWith(
        fontSize: 22,
        fontWeight: FontWeight.w800,
      ),
      titleMedium: text.titleMedium?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: text.bodyLarge?.copyWith(fontSize: 20, height: 1.45),
      bodyMedium: text.bodyMedium?.copyWith(fontSize: 18, height: 1.45),
      labelLarge: text.labelLarge?.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        fontFamily: kFont,
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.ink,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        textStyle: const TextStyle(
          fontFamily: kFont,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 54),
        foregroundColor: AppColors.primary,
        backgroundColor: Colors.white,
        side: const BorderSide(color: AppColors.primary, width: 2),
        textStyle: const TextStyle(
          fontFamily: kFont,
          fontSize: 21,
          fontWeight: FontWeight.w800,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      indicatorColor: AppColors.primaryLight,
      indicatorShape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => TextStyle(
          fontFamily: kFont,
          fontSize: 16,
          fontWeight: states.contains(WidgetState.selected)
              ? FontWeight.w900
              : FontWeight.w600,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 30,
          color: states.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.muted,
        ),
      ),
    ),
    chipTheme: base.chipTheme.copyWith(
      labelStyle: const TextStyle(
        fontFamily: kFont,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.ink,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      side: const BorderSide(color: AppColors.border, width: 1.5),
      selectedColor: AppColors.dangerBg,
      checkmarkColor: AppColors.danger,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: AppColors.bg,
      showDragHandle: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.ink,
      contentTextStyle: TextStyle(
        fontFamily: kFont,
        fontSize: 18,
        color: Colors.white,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.all(18),
      labelStyle: const TextStyle(
        fontFamily: kFont,
        fontSize: 19,
        color: AppColors.muted,
      ),
      border: border(AppColors.border, 1.5),
      enabledBorder: border(AppColors.border, 1.5),
      focusedBorder: border(AppColors.primary, 2.5),
    ),
  );
}
