import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Brand Colours ───────────────────────────────────────────────────────────
const _teal = Color(0xFF14B8A6);
const _darkSlate = Color(0xFF1E293B);
const _midnight = Color(0xFF0F172A);

// ─── Light Theme ─────────────────────────────────────────────────────────────
final ThemeData broLightTheme = ThemeData(
  brightness: Brightness.light,
  useMaterial3: true,
  scaffoldBackgroundColor: const Color(0xFFF8FAFC),
  primaryColor: _teal,
  canvasColor: Colors.white,
  dividerColor: const Color(0xFFE2E8F0),
  textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme).copyWith(
    displayLarge: const TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w900, color: _darkSlate),
    titleLarge:   const TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w800, color: _darkSlate),
    bodyMedium:   const TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF64748B)),
  ),
  colorScheme: const ColorScheme.light(
    primary:    _teal,
    onPrimary:  Colors.white,
    secondary:  Color(0xFF4F46E5),
    surface:    Colors.white,
    onSurface:  _darkSlate,
    surfaceVariant: Color(0xFFF1F5F9),
    onSurfaceVariant: Color(0xFF64748B),
    outline:    Color(0xFFE2E8F0),
    background: Color(0xFFF8FAFC),
    onBackground: _darkSlate,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: _darkSlate),
    titleTextStyle: TextStyle(fontFamily: '.SF Pro Display', fontSize: 18, fontWeight: FontWeight.w800, color: _darkSlate),
  ),
  cardTheme: CardThemeData(
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Colors.white,
    selectedItemColor: _teal,
    unselectedItemColor: Color(0xFF94A3B8),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? _teal : Colors.white),
    trackColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? _teal.withOpacity(0.4) : const Color(0xFFE2E8F0)),
  ),
);

// ─── Dark Theme ──────────────────────────────────────────────────────────────
final ThemeData broDarkTheme = ThemeData(
  brightness: Brightness.dark,
  useMaterial3: true,
  scaffoldBackgroundColor: _midnight,
  primaryColor: _teal,
  canvasColor: const Color(0xFF1E293B),
  dividerColor: const Color(0xFF334155),
  textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
    displayLarge: const TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w900, color: Colors.white),
    titleLarge:   const TextStyle(fontFamily: '.SF Pro Display', fontWeight: FontWeight.w800, color: Colors.white),
    bodyMedium:   const TextStyle(fontFamily: '.SF Pro Display', color: Color(0xFF94A3B8)),
  ),
  colorScheme: const ColorScheme.dark(
    primary:    _teal,
    onPrimary:  Colors.white,
    secondary:  Color(0xFF4F46E5),
    surface:    Color(0xFF1E293B),
    onSurface:  Colors.white,
    surfaceVariant: Color(0xFF0F172A),
    onSurfaceVariant: Color(0xFF94A3B8),
    outline:    Color(0xFF334155),
    background: _midnight,
    onBackground: Colors.white,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: Color(0xFF1E293B),
    elevation: 0,
    centerTitle: false,
    iconTheme: IconThemeData(color: Colors.white),
    titleTextStyle: TextStyle(fontFamily: '.SF Pro Display', fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
  ),
  cardTheme: CardThemeData(
    color: const Color(0xFF1E293B),
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: Color(0xFF1E293B),
    selectedItemColor: _teal,
    unselectedItemColor: Color(0xFF64748B),
  ),
  switchTheme: SwitchThemeData(
    thumbColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? _teal : const Color(0xFF64748B)),
    trackColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? _teal.withOpacity(0.4) : const Color(0xFF334155)),
  ),
);

// ─── Helper Extension ────────────────────────────────────────────────────────
// Usage: context.broColors.bg, context.broColors.card, etc.
extension BroThemeX on BuildContext {
  BroColors get broColors => Theme.of(this).brightness == Brightness.dark
      ? BroColors.dark()
      : BroColors.light();
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

class BroColors {
  final Color bg;
  final Color card;
  final Color surface;
  final Color text;
  final Color subtext;
  final Color border;
  final Color inputFill;
  final Color iconBg;

  const BroColors._({
    required this.bg,
    required this.card,
    required this.surface,
    required this.text,
    required this.subtext,
    required this.border,
    required this.inputFill,
    required this.iconBg,
  });

  factory BroColors.light() => const BroColors._(
    bg:        Color(0xFFF8FAFC),
    card:      Colors.white,
    surface:   Colors.white,
    text:      Color(0xFF1E293B),
    subtext:   Color(0xFF64748B),
    border:    Color(0xFFE2E8F0),
    inputFill: Color(0xFFF1F5F9),
    iconBg:    Colors.white,
  );

  factory BroColors.dark() => const BroColors._(
    bg:        Color(0xFF0F172A),
    card:      Color(0xFF1E293B),
    surface:   Color(0xFF1E293B),
    text:      Colors.white,
    subtext:   Color(0xFF94A3B8),
    border:    Color(0xFF334155),
    inputFill: Color(0xFF0F172A),
    iconBg:    Color(0xFF334155),
  );
}
