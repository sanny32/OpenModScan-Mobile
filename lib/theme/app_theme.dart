import 'package:flutter/material.dart';

class AppTheme {
  static const Color background = Color(0xFF121212);
  static const Color surface = Color(0xFF1E1E1E);
  static const Color surfaceVariant = Color(0xFF252525);
  static const Color valueColor = Color(0xFF4CAF50);
  static const Color typeColor = Color(0xFF64B5F6);
  static const Color txColor = Color(0xFF64B5F6);
  static const Color rxColor = Color(0xFF4CAF50);
  static const Color errorColor = Color(0xFFEF5350);
  static const Color qualityGood = Color(0xFF4CAF50);

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF1976D2),
          surface: surface,
        ),
        cardTheme: const CardThemeData(
          color: surface,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          elevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: Colors.white),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: surface,
          selectedItemColor: Color(0xFF1976D2),
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: Color(0xFF1976D2),
          unselectedLabelColor: Colors.grey,
          indicatorColor: Color(0xFF1976D2),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2A2A2A),
          thickness: 1,
          space: 1,
        ),
        switchTheme: SwitchThemeData(
          thumbColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF1976D2);
            }
            return Colors.grey;
          }),
          trackColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) {
              return const Color(0xFF1976D2).withAlpha(128);
            }
            return Colors.grey.withAlpha(77);
          }),
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.grey),
        ),
      );
}
