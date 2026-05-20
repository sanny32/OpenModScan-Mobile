import 'package:flutter/material.dart';

/// App-specific semantic colours — adapt to light/dark theme.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color valueColor;
  final Color typeColor;
  final Color txColor;
  final Color rxColor;
  final Color qualityGood;
  final Color warningColor;
  final Color connectedColor;
  final Color disconnectedColor;
  final Color openLogColor;
  final Color writeActionColor;

  const AppColors({
    required this.valueColor,
    required this.typeColor,
    required this.txColor,
    required this.rxColor,
    required this.qualityGood,
    required this.warningColor,
    required this.connectedColor,
    required this.disconnectedColor,
    required this.openLogColor,
    required this.writeActionColor,
  });

  static const dark = AppColors(
    valueColor: Color(0xFF66BB6A),
    typeColor: Color(0xFF64B5F6),
    txColor: Color(0xFF64B5F6),
    rxColor: Color(0xFF66BB6A),
    qualityGood: Color(0xFF66BB6A),
    warningColor: Color(0xFFFF9800),
    connectedColor: Color(0xFF66BB6A),
    disconnectedColor: Color(0xFFEF5350),
    openLogColor: Color(0xFFCE93D8),
    writeActionColor: Color(0xFF66BB6A),
  );

  static const light = AppColors(
    valueColor: Color(0xFF2E7D32),
    typeColor: Color(0xFF1565C0),
    txColor: Color(0xFF1565C0),
    rxColor: Color(0xFF2E7D32),
    qualityGood: Color(0xFF2E7D32),
    warningColor: Color(0xFFE65100),
    connectedColor: Color(0xFF2E7D32),
    disconnectedColor: Color(0xFFD32F2F),
    openLogColor: Color(0xFF7B1FA2),
    writeActionColor: Color(0xFF2E7D32),
  );

  @override
  AppColors copyWith({
    Color? valueColor,
    Color? typeColor,
    Color? txColor,
    Color? rxColor,
    Color? qualityGood,
    Color? warningColor,
    Color? connectedColor,
    Color? disconnectedColor,
    Color? openLogColor,
    Color? writeActionColor,
  }) =>
      AppColors(
        valueColor: valueColor ?? this.valueColor,
        typeColor: typeColor ?? this.typeColor,
        txColor: txColor ?? this.txColor,
        rxColor: rxColor ?? this.rxColor,
        qualityGood: qualityGood ?? this.qualityGood,
        warningColor: warningColor ?? this.warningColor,
        connectedColor: connectedColor ?? this.connectedColor,
        disconnectedColor: disconnectedColor ?? this.disconnectedColor,
        openLogColor: openLogColor ?? this.openLogColor,
        writeActionColor: writeActionColor ?? this.writeActionColor,
      );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      valueColor: Color.lerp(valueColor, other.valueColor, t)!,
      typeColor: Color.lerp(typeColor, other.typeColor, t)!,
      txColor: Color.lerp(txColor, other.txColor, t)!,
      rxColor: Color.lerp(rxColor, other.rxColor, t)!,
      qualityGood: Color.lerp(qualityGood, other.qualityGood, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      connectedColor: Color.lerp(connectedColor, other.connectedColor, t)!,
      disconnectedColor:
          Color.lerp(disconnectedColor, other.disconnectedColor, t)!,
      openLogColor: Color.lerp(openLogColor, other.openLogColor, t)!,
      writeActionColor:
          Color.lerp(writeActionColor, other.writeActionColor, t)!,
    );
  }
}

class AppTheme {
  static const _primary = Color(0xFF1976D2);

  static const TextTheme textTheme = TextTheme(
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    titleLarge:     TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium:    TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    titleSmall:     TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    labelLarge:     TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    bodyLarge:      TextStyle(fontSize: 14),
    bodyMedium:     TextStyle(fontSize: 13),
    bodySmall:      TextStyle(fontSize: 12),
    labelSmall:     TextStyle(fontSize: 11),
  );

  static final SwitchThemeData _switchTheme = SwitchThemeData(
    thumbColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected) ? _primary : Colors.grey,
    ),
    trackColor: WidgetStateProperty.resolveWith(
      (s) => s.contains(WidgetState.selected)
          ? _primary.withAlpha(128)
          : Colors.grey.withAlpha(77),
    ),
  );

  static ThemeData get darkTheme => ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF121212),
        textTheme: textTheme,
        colorScheme: const ColorScheme.dark(
          primary: _primary,
          error: Color(0xFFEF5350),
          surface: Color(0xFF1E1E1E),
          surfaceContainer: Color(0xFF1A1A1A),
          surfaceContainerHighest: Color(0xFF252525),
          onSurfaceVariant: Colors.grey,
          outline: Color(0xFF3A3A3A),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFF1E1E1E),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF121212),
          elevation: 0,
          centerTitle: true,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Color(0xFF1E1E1E),
          selectedItemColor: _primary,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: _primary,
          unselectedLabelColor: Colors.grey,
          indicatorColor: _primary,
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFF2A2A2A),
          thickness: 1,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF252525),
          hintStyle: const TextStyle(color: Colors.grey),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        switchTheme: _switchTheme,
        extensions: const [AppColors.dark],
      );

  static ThemeData get lightTheme => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: const Color(0xFFF2F2F7),
        textTheme: textTheme,
        colorScheme: const ColorScheme.light(
          primary: _primary,
          error: Color(0xFFD32F2F),
          surface: Colors.white,
          surfaceContainer: Color(0xFFEAEAF0),
          surfaceContainerHighest: Color(0xFFF0F0F5),
          onSurfaceVariant: Color(0xFF757575),
          outline: Color(0xFFE0E0E0),
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          margin: EdgeInsets.zero,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: const Color(0xFFF2F2F7),
          elevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: Color(0xFF1C1C1E)),
          titleTextStyle: textTheme.titleMedium!
              .copyWith(color: const Color(0xFF1C1C1E)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: _primary,
          unselectedItemColor: Color(0xFF757575),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
        tabBarTheme: const TabBarThemeData(
          labelColor: _primary,
          unselectedLabelColor: Color(0xFF757575),
          indicatorColor: _primary,
          dividerColor: Color(0xFFE0E0E0),
        ),
        dividerTheme: const DividerThemeData(
          color: Color(0xFFE0E0E0),
          thickness: 1,
          space: 1,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFF0F0F5),
          hintStyle: const TextStyle(color: Color(0xFF757575)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide.none,
          ),
        ),
        switchTheme: _switchTheme,
        extensions: const [AppColors.light],
      );
}
