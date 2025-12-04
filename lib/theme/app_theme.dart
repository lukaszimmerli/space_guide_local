import 'package:flutter/material.dart';

class AppTheme {
  static CardThemeData _lightCardTheme() => CardThemeData(
    elevation: 0.5, // Reduced shadow for light theme
    color: const Color(0xFFF2F2F2), // Darker card background
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

  static const Color primaryColorLight = Color.fromARGB(255, 13, 110, 237);
  static const Color primaryColorDark = Color.fromARGB(255, 125, 179, 255);

  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'IBMPlexSans',
    textTheme: ThemeData.light().textTheme.copyWith(
      displayLarge: ThemeData.light().textTheme.displayLarge?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize:
            (ThemeData.light().textTheme.displayLarge?.fontSize ?? 57) + 2,
      ),
      displayMedium: ThemeData.light().textTheme.displayMedium?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize:
            (ThemeData.light().textTheme.displayMedium?.fontSize ?? 45) + 2,
      ),
      displaySmall: ThemeData.light().textTheme.displaySmall?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize:
            (ThemeData.light().textTheme.displaySmall?.fontSize ?? 36) + 2,
      ),
      headlineLarge: ThemeData.light().textTheme.headlineLarge?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize:
            (ThemeData.light().textTheme.headlineLarge?.fontSize ?? 32) + 2,
      ),
      headlineMedium: ThemeData.light().textTheme.headlineMedium?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize:
            (ThemeData.light().textTheme.headlineMedium?.fontSize ?? 28) + 2,
      ),
      headlineSmall: ThemeData.light().textTheme.headlineSmall?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize:
            (ThemeData.light().textTheme.headlineSmall?.fontSize ?? 24) + 2,
      ),
      titleLarge: ThemeData.light().textTheme.titleLarge?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.light().textTheme.titleLarge?.fontSize ?? 22) + 2,
      ),
      titleMedium: ThemeData.light().textTheme.titleMedium?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.light().textTheme.titleMedium?.fontSize ?? 16) + 2,
      ),
      titleSmall: ThemeData.light().textTheme.titleSmall?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.light().textTheme.titleSmall?.fontSize ?? 14) + 2,
      ),
      bodyLarge: ThemeData.light().textTheme.bodyLarge?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.light().textTheme.bodyLarge?.fontSize ?? 16) + 2,
      ),
      bodyMedium: ThemeData.light().textTheme.bodyMedium?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.light().textTheme.bodyMedium?.fontSize ?? 14) + 2,
      ),
      bodySmall: ThemeData.light().textTheme.bodySmall?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.light().textTheme.bodySmall?.fontSize ?? 12) + 2,
      ),
      labelLarge: ThemeData.light().textTheme.labelLarge?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.light().textTheme.labelLarge?.fontSize ?? 14) + 2,
      ),
      labelMedium: ThemeData.light().textTheme.labelMedium?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.light().textTheme.labelMedium?.fontSize ?? 12) + 2,
      ),
      labelSmall: ThemeData.light().textTheme.labelSmall?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.light().textTheme.labelSmall?.fontSize ?? 11) + 2,
      ),
    ),
    colorScheme: ColorScheme.light(
      primary: primaryColorLight,
      secondary: primaryColorLight, // Use same color for secondary elements
      primaryContainer: const Color(0xFFF2F2F2), // Same as card background
    ),
    scaffoldBackgroundColor: Colors.white, // Keep background white
    cardColor: Colors.green, // Test color to verify it's working
    appBarTheme: const AppBarTheme(elevation: 0, centerTitle: false),
    cardTheme: _lightCardTheme(),
    elevatedButtonTheme: _elevatedButtonTheme(),
  );

  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    fontFamily: 'IBMPlexSans',
    textTheme: ThemeData.dark().textTheme.copyWith(
      displayLarge: ThemeData.dark().textTheme.displayLarge?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.dark().textTheme.displayLarge?.fontSize ?? 57) + 2,
      ),
      displayMedium: ThemeData.dark().textTheme.displayMedium?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize:
            (ThemeData.dark().textTheme.displayMedium?.fontSize ?? 45) + 2,
      ),
      displaySmall: ThemeData.dark().textTheme.displaySmall?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.dark().textTheme.displaySmall?.fontSize ?? 36) + 2,
      ),
      headlineLarge: ThemeData.dark().textTheme.headlineLarge?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize:
            (ThemeData.dark().textTheme.headlineLarge?.fontSize ?? 32) + 2,
      ),
      headlineMedium: ThemeData.dark().textTheme.headlineMedium?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize:
            (ThemeData.dark().textTheme.headlineMedium?.fontSize ?? 28) + 2,
      ),
      headlineSmall: ThemeData.dark().textTheme.headlineSmall?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize:
            (ThemeData.dark().textTheme.headlineSmall?.fontSize ?? 24) + 2,
      ),
      titleLarge: ThemeData.dark().textTheme.titleLarge?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.dark().textTheme.titleLarge?.fontSize ?? 22) + 2,
      ),
      titleMedium: ThemeData.dark().textTheme.titleMedium?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.dark().textTheme.titleMedium?.fontSize ?? 16) + 2,
      ),
      titleSmall: ThemeData.dark().textTheme.titleSmall?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.dark().textTheme.titleSmall?.fontSize ?? 14) + 2,
      ),
      bodyLarge: ThemeData.dark().textTheme.bodyLarge?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.dark().textTheme.bodyLarge?.fontSize ?? 16) + 2,
      ),
      bodyMedium: ThemeData.dark().textTheme.bodyMedium?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.dark().textTheme.bodyMedium?.fontSize ?? 14) + 2,
      ),
      bodySmall: ThemeData.dark().textTheme.bodySmall?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.dark().textTheme.bodySmall?.fontSize ?? 12) + 2,
      ),
      labelLarge: ThemeData.dark().textTheme.labelLarge?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.dark().textTheme.labelLarge?.fontSize ?? 14) + 2,
      ),
      labelMedium: ThemeData.dark().textTheme.labelMedium?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.dark().textTheme.labelMedium?.fontSize ?? 12) + 2,
      ),
      labelSmall: ThemeData.dark().textTheme.labelSmall?.copyWith(
        fontFamily: 'IBMPlexSans',
        fontSize: (ThemeData.dark().textTheme.labelSmall?.fontSize ?? 11) + 2,
      ),
    ),
    colorScheme: ColorScheme.dark(
      primary: primaryColorDark,
      secondary: primaryColorDark, // Use same color for secondary elements
      primaryContainer: const Color(0xFF1C1C1C), // Same as card background
      surface: const Color(0xFF1E1E1E), // Base dark surface
      surfaceContainerLowest: const Color(0xFF141414), // Darkest
      surfaceContainerLow: const Color(0xFF161616), // Lower
      surfaceContainer: const Color(0xFF181818), // Normal
      surfaceContainerHigh: const Color(0xFF1A1A1A), // Higher
      surfaceContainerHighest: const Color(
        0xFF1C1C1C,
      ), // Highest - cards use this (extremely subtle)
      onSurface: const Color(0xFFE6E6E6), // Text on surfaces
      onSurfaceVariant: const Color(0xFFB8B8B8), // Secondary text
      tertiary: const Color.fromARGB(255, 218, 125, 3), // Accent color
    ),
    scaffoldBackgroundColor: const Color(0xFF121212), // App background
    appBarTheme: const AppBarTheme(
      elevation: 0,
      centerTitle: false,
      backgroundColor: Color(0xFF121212), // Match scaffold background
    ),
    cardTheme: _darkCardTheme(),
    elevatedButtonTheme: _elevatedButtonTheme(),
  );
}
