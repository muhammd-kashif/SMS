import 'package:flutter/material.dart';

class CollegePalette {
  const CollegePalette(this.id, this.name, this.primary, this.secondary, this.accent, this.sidebar, this.header);

  final String id;
  final String name;
  final String primary;
  final String secondary;
  final String accent;
  final String sidebar;
  final String header;
}

const collegePalettes = <CollegePalette>[
  CollegePalette('navy', 'College navy', '#1B4F9C', '#F39200', '#F5A623', '#0E2A4A', '#FFFDF8'),
  CollegePalette('emerald', 'Emerald', '#0F766E', '#D97706', '#14B8A6', '#042F2E', '#F0FDFA'),
  CollegePalette('royal', 'Royal', '#5B21B6', '#DB2777', '#A78BFA', '#2E1065', '#FAF5FF'),
  CollegePalette('ocean', 'Ocean', '#0369A1', '#0284C7', '#38BDF8', '#0C4A6E', '#F0F9FF'),
  CollegePalette('crimson', 'Crimson', '#9F1239', '#E11D48', '#FB7185', '#4C0519', '#FFF1F2'),
  CollegePalette('slate', 'Slate', '#334155', '#0F766E', '#64748B', '#0F172A', '#F8FAFC'),
  CollegePalette('sunset', 'Sunset', '#C2410C', '#F59E0B', '#FB923C', '#431407', '#FFF7ED'),
  CollegePalette('forest', 'Forest', '#166534', '#CA8A04', '#4ADE80', '#052E16', '#F0FDF4'),
];

class CollegeColors {
  static Color sidebar = const Color(0xFF0F172A);
  static Color sidebarTop = const Color(0xFF1E3A8A);
  static Color primary = const Color(0xFF1B4F9C);
  static Color secondary = const Color(0xFFF39200);
  static Color paper = const Color(0xFFF1F5F9);
  static Color line = const Color(0xFFE2E8F0);
  static Color ink = const Color(0xFF1C1917);
  static Color muted = const Color(0xFF78716C);
  static Color ok = const Color(0xFF166534);
  static Color okBg = const Color(0xFFE8F6EE);
  static Color warn = const Color(0xFFA16207);
  static Color warnBg = const Color(0xFFFEF3C7);
  static Color danger = const Color(0xFF9F1239);
  static Color dangerBg = const Color(0xFFFFE4E6);
  static Color header = const Color(0xFFFFFDF8);
  static Color blueBg = const Color(0xFFE8F0FB);
  static Color teal = const Color(0xFF0F766E);
  static Color tealDeep = const Color(0xFF0E2A4A);
  static Color amber = const Color(0xFFF39200);
  static Color accent = const Color(0xFFF5A623);
  static Color onPrimary = Colors.white;
  static double radius = 12;
  static bool dark = false;
  static String schoolName = 'Smart College';
  static String shortName = 'SMS';
  static String buttonStyle = 'rounded';

  static void apply(Map brand) {
    final name = brand['name']?.toString().trim() ?? brand['college_name']?.toString().trim() ?? '';
    final short = brand['short_name']?.toString().trim() ?? '';
    if (name.isNotEmpty) schoolName = name;
    if (short.isNotEmpty) shortName = short;
    primary = parse(brand['primary_color'], primary);
    secondary = parse(brand['secondary_color'], secondary);
    accent = parse(brand['accent_color'], accent);
    sidebar = parse(brand['sidebar_color'], sidebar);
    sidebarTop = Color.lerp(sidebar, Colors.white, 0.22) ?? sidebar;
    header = parse(brand['header_color'], header);
    teal = accent;
    tealDeep = sidebar;
    amber = secondary;
    blueBg = primary.withValues(alpha: 0.12);
    onPrimary = _readable(primary);
    final style = brand['button_style']?.toString();
    if (style == 'square' || style == 'pill' || style == 'rounded') buttonStyle = style!;
    radius = switch (buttonStyle) {
      'square' => 4,
      'pill' => 999,
      _ => 12,
    };
    dark = brand['theme'] == 'dark';
    if (dark) {
      paper = const Color(0xFF0A0F1C);
      ink = const Color(0xFFF8FAFC);
      muted = const Color(0xFF94A3B8);
      line = const Color(0xFF1F2937);
    } else {
      paper = const Color(0xFFF1F5F9);
      ink = const Color(0xFF0F172A);
      muted = const Color(0xFF64748B);
      line = const Color(0xFFE2E8F0);
    }
  }

  static Color parse(dynamic value, Color fallback) {
    final hex = value?.toString().replaceAll('#', '') ?? '';
    if (hex.length != 6) return fallback;
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) return fallback;
    return Color(0xFF000000 | parsed);
  }

  static Color _readable(Color color) {
    final red = (color.r * 255).round();
    final green = (color.g * 255).round();
    final blue = (color.b * 255).round();
    return (red * 299 + green * 587 + blue * 114) / 1000 > 160 ? const Color(0xFF1C1917) : Colors.white;
  }

  static String toHex(Color color) {
    final r = (color.r * 255).round().toRadixString(16).padLeft(2, '0');
    final g = (color.g * 255).round().toRadixString(16).padLeft(2, '0');
    final b = (color.b * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${(r + g + b).toUpperCase()}';
  }
}

EdgeInsets pagePadding(BuildContext context) {
  final width = MediaQuery.sizeOf(context).width;
  final inset = width >= 1100 ? 32.0 : width >= 720 ? 20.0 : 14.0;
  return EdgeInsets.fromLTRB(inset, inset, inset, inset + 16);
}

bool isWideLayout(BuildContext context) => MediaQuery.sizeOf(context).width >= 900;

ThemeData collegeTheme() {
  final base = ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: CollegeColors.paper,
    brightness: CollegeColors.dark ? Brightness.dark : Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: CollegeColors.primary,
      brightness: CollegeColors.dark ? Brightness.dark : Brightness.light,
      primary: CollegeColors.primary,
      secondary: CollegeColors.secondary,
      surface: CollegeColors.dark ? const Color(0xFF111827) : Colors.white,
    ),
    dividerColor: CollegeColors.line,
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? CollegeColors.primary : Colors.transparent),
      checkColor: const WidgetStatePropertyAll(Colors.white),
      side: BorderSide(color: CollegeColors.line, width: 1.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: CollegeColors.dark ? const Color(0xFF111827) : Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CollegeColors.radius.clamp(6, 16).toDouble())),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: CollegeColors.dark ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
      contentTextStyle: const TextStyle(color: Colors.white, fontFamily: 'Roboto'),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: CollegeColors.dark ? const Color(0xFF1E293B) : const Color(0xFF0F172A), borderRadius: BorderRadius.circular(6)),
      textStyle: const TextStyle(color: Colors.white, fontSize: 12),
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: CollegeColors.ink, displayColor: CollegeColors.ink),
    cardTheme: CardThemeData(
      color: CollegeColors.dark ? const Color(0xFF111827) : Colors.white,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: CollegeColors.line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: CollegeColors.primary,
        foregroundColor: CollegeColors.onPrimary,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CollegeColors.radius)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: CollegeColors.primary,
        side: const BorderSide(color: Color(0xFFD5E2F2)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(CollegeColors.radius)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CollegeColors.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: CollegeColors.line)),
    ),
  );
}
