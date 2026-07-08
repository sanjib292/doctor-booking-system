import 'package:flutter/material.dart';

abstract final class AppTheme {
  static const _primary = Color(0xFF1A73E8);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: _primary,
    brightness: Brightness.light,
    fontFamily: 'Poppins',
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    colorSchemeSeed: _primary,
    brightness: Brightness.dark,
    fontFamily: 'Poppins',
  );
}
