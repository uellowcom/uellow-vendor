import 'package:flutter/material.dart';

class UC {
  UC._();
  static const yellow      = Color(0xFFF5C320);
  static const yellowSoft  = Color(0xFFFFE066);
  static const yellowFaint = Color(0xFFFFF6D9);
  static const brown       = Color(0xFF412402);
  static const brownSoft   = Color(0xFF5B3C00);
  static const bg          = Color(0xFFF4F2EE);
  static const card        = Colors.white;
  static const border      = Color(0xFFE7E3D9);
  static const text        = Color(0xFF3A3A40);
  static const ink         = Color(0xFF1B1B1F);
  static const muted       = Color(0xFF8B8B92);
  static const success     = Color(0xFF10B981);
  static const successBg   = Color(0xFFD1FAE5);
  static const successDk   = Color(0xFF047857);
  static const danger      = Color(0xFFEF4444);
  static const dangerBg    = Color(0xFFFEE2E2);
  static const dangerDk    = Color(0xFFB91C1C);
  static const warn        = Color(0xFFF59E0B);
  static const warnBg      = Color(0xFFFEF3C7);
  static const info        = Color(0xFF0EA5E9);
  static const infoBg      = Color(0xFFDBEAFE);
}

class UT {
  UT._();
  static const h1 = TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: UC.ink);
  static const h2 = TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: UC.ink);
  static const h3 = TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: UC.ink);
  static const body = TextStyle(fontSize: 13, color: UC.text);
  static const small = TextStyle(fontSize: 11, color: UC.muted);
  static const tiny = TextStyle(fontSize: 10, color: UC.muted, fontWeight: FontWeight.w700);
}

ThemeData uellowVendorTheme() {
  return ThemeData(
    useMaterial3: true,
    fontFamily: 'Tajawal',
    scaffoldBackgroundColor: UC.bg,
    colorScheme: ColorScheme.fromSeed(
      seedColor: UC.yellow, primary: UC.yellow,
      secondary: UC.brown, surface: UC.card, brightness: Brightness.light,
    ).copyWith(onPrimary: UC.brown),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white, foregroundColor: UC.ink,
      elevation: 0, scrolledUnderElevation: 0.5,
      titleTextStyle: TextStyle(color: UC.ink, fontSize: 17, fontWeight: FontWeight.w900, fontFamily: 'Tajawal'),
      iconTheme: IconThemeData(color: UC.brown),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true, fillColor: UC.bg, isDense: true,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: UC.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11),
          borderSide: const BorderSide(color: UC.yellow, width: 2)),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(style: ElevatedButton.styleFrom(
      backgroundColor: UC.yellow, foregroundColor: UC.brown,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      textStyle: const TextStyle(fontWeight: FontWeight.w900, fontSize: 14, fontFamily: 'Tajawal'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    )),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(
      foregroundColor: UC.brown, side: const BorderSide(color: UC.border, width: 1.5),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, fontFamily: 'Tajawal'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    )),
    cardTheme: CardThemeData(color: Colors.white, surfaceTintColor: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

class UPill extends StatelessWidget {
  const UPill({super.key, required this.text, this.bg = UC.bg, this.fg = UC.muted, this.icon, this.live = false});
  final String text;
  final Color bg, fg;
  final IconData? icon;
  final bool live;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (live) Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 5),
          decoration: BoxDecoration(color: fg, shape: BoxShape.circle)),
        if (icon != null) Padding(padding: const EdgeInsets.only(right: 3),
          child: Icon(icon, size: 11, color: fg)),
        Text(text, style: TextStyle(color: fg, fontWeight: FontWeight.w900, fontSize: 10.5)),
      ]),
    );
  }
}

class USpinner extends StatelessWidget {
  const USpinner({super.key, this.size = 24});
  final double size;
  @override
  Widget build(BuildContext context) => Center(
    child: SizedBox(width: size, height: size,
      child: const CircularProgressIndicator(color: UC.brown, strokeWidth: 2.5)));
}
