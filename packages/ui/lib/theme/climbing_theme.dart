import 'package:flutter/material.dart';
import 'climbing_colors.dart';
import 'climbing_typography.dart';

class ClimbingTheme {
  ClimbingTheme._();

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ClimbingColors.cliffOrange,
        brightness: Brightness.light,
      ).copyWith(
        primary: ClimbingColors.cliffOrange,
        secondary: ClimbingColors.skyBlue,
        error: ClimbingColors.errorRed,
        surface: ClimbingColors.white,
        background: ClimbingColors.lightGray,
      ),
      textTheme: ClimbingTypography.textTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: ClimbingColors.darkGray,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: ClimbingColors.white,
          backgroundColor: ClimbingColors.cliffOrange,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: ClimbingColors.cliffOrange,
        brightness: Brightness.dark,
      ).copyWith(
        primary: ClimbingColors.cliffOrange,
        secondary: ClimbingColors.skyBlue,
        error: ClimbingColors.errorRed,
        surface: ClimbingColors.darkGray,
        background: ClimbingColors.black,
      ),
      textTheme: ClimbingTypography.textTheme,
      appBarTheme: const AppBarTheme(
        elevation: 0,
        centerTitle: true,
        backgroundColor: Colors.transparent,
        foregroundColor: ClimbingColors.white,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: ClimbingColors.white,
          backgroundColor: ClimbingColors.cliffOrange,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}