import 'package:flutter/material.dart';

class AppTheme {
  static CardThemeData _lightCardTheme() => CardThemeData(
    elevation: 0.5, // Reduced shadow for light theme
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );

  static CardThemeData _darkCardTheme() => CardThemeData(
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  );

  static ElevatedButtonThemeData _elevatedButtonTheme() =>
      ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.light,
    ),
    appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
    cardTheme: _lightCardTheme(),
    elevatedButtonTheme: _elevatedButtonTheme(),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: Colors.blue,
      brightness: Brightness.dark,
    ),
    appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
    cardTheme: _darkCardTheme(),
    elevatedButtonTheme: _elevatedButtonTheme(),
  );
}
