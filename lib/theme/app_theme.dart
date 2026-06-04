import 'package:flutter/material.dart';

import 'app_dimens.dart';

/// App-specific semantic colours — adapt to light/dark theme.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color valueColor;
  final Color previousValueColor;
  final Color unavailableValueColor;
  final Color exceptionValueColor;
  final Color typeColor;
  final Color txColor;
  final Color rxColor;
  final Color qualityGood;
  final Color warningColor;
  final Color connectedColor;
  final Color disconnectedColor;
  final Color openLogColor;
  final Color writeActionColor;
  final Color brandGreen;

  /// Bright "live/good/connected" green — sampled from the logo's vivid tile.
  /// Kept distinct from the deep brand green used for chrome so status reads as
  /// a lively state, not as another piece of UI. For fills/dots/icons; small
  /// status text stays on the more legible [connectedColor]/[valueColor].
  final Color liveColor;

  const AppColors({
    required this.valueColor,
    required this.previousValueColor,
    required this.unavailableValueColor,
    required this.exceptionValueColor,
    required this.typeColor,
    required this.txColor,
    required this.rxColor,
    required this.qualityGood,
    required this.warningColor,
    required this.connectedColor,
    required this.disconnectedColor,
    required this.openLogColor,
    required this.writeActionColor,
    required this.brandGreen,
    required this.liveColor,
  });

  static const dark = AppColors(
    valueColor: Color(0xFF66BB6A),
    previousValueColor: Color(0xFF90A4AE),
    unavailableValueColor: Color(0xFF6B6B6B),
    exceptionValueColor: Color(0xFFFF9800),
    typeColor: Color(0xFF64B5F6),
    txColor: Color(0xFF64B5F6),
    rxColor: Color(0xFF66BB6A),
    qualityGood: Color(0xFF66BB6A),
    warningColor: Color(0xFFFF9800),
    connectedColor: Color(0xFF66BB6A),
    disconnectedColor: Color(0xFFEF5350),
    openLogColor: Color(0xFFCE93D8),
    writeActionColor: Color(0xFF66BB6A),
    brandGreen: Color(0xFF3DDC3D),
    liveColor: Color(0xFF35D15A),
  );

  static const light = AppColors(
    valueColor: Color(0xFF2E7D32),
    previousValueColor: Color(0xFF607D8B),
    unavailableValueColor: Color(0xFFB0B0B0),
    exceptionValueColor: Color(0xFFE65100),
    typeColor: Color(0xFF1565C0),
    txColor: Color(0xFF1565C0),
    rxColor: Color(0xFF2E7D32),
    qualityGood: Color(0xFF2E7D32),
    warningColor: Color(0xFFE65100),
    connectedColor: Color(0xFF2E7D32),
    disconnectedColor: Color(0xFFD32F2F),
    openLogColor: Color(0xFF7B1FA2),
    writeActionColor: Color(0xFF2E7D32),
    brandGreen: Color(0xFF259025),
    liveColor: Color(0xFF22C55E),
  );

  @override
  AppColors copyWith({
    Color? valueColor,
    Color? previousValueColor,
    Color? unavailableValueColor,
    Color? exceptionValueColor,
    Color? typeColor,
    Color? txColor,
    Color? rxColor,
    Color? qualityGood,
    Color? warningColor,
    Color? connectedColor,
    Color? disconnectedColor,
    Color? openLogColor,
    Color? writeActionColor,
    Color? brandGreen,
    Color? liveColor,
  }) => AppColors(
    valueColor: valueColor ?? this.valueColor,
    previousValueColor: previousValueColor ?? this.previousValueColor,
    unavailableValueColor: unavailableValueColor ?? this.unavailableValueColor,
    exceptionValueColor: exceptionValueColor ?? this.exceptionValueColor,
    typeColor: typeColor ?? this.typeColor,
    txColor: txColor ?? this.txColor,
    rxColor: rxColor ?? this.rxColor,
    qualityGood: qualityGood ?? this.qualityGood,
    warningColor: warningColor ?? this.warningColor,
    connectedColor: connectedColor ?? this.connectedColor,
    disconnectedColor: disconnectedColor ?? this.disconnectedColor,
    openLogColor: openLogColor ?? this.openLogColor,
    writeActionColor: writeActionColor ?? this.writeActionColor,
    brandGreen: brandGreen ?? this.brandGreen,
    liveColor: liveColor ?? this.liveColor,
  );

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      valueColor: Color.lerp(valueColor, other.valueColor, t)!,
      previousValueColor: Color.lerp(
        previousValueColor,
        other.previousValueColor,
        t,
      )!,
      unavailableValueColor: Color.lerp(
        unavailableValueColor,
        other.unavailableValueColor,
        t,
      )!,
      exceptionValueColor: Color.lerp(
        exceptionValueColor,
        other.exceptionValueColor,
        t,
      )!,
      typeColor: Color.lerp(typeColor, other.typeColor, t)!,
      txColor: Color.lerp(txColor, other.txColor, t)!,
      rxColor: Color.lerp(rxColor, other.rxColor, t)!,
      qualityGood: Color.lerp(qualityGood, other.qualityGood, t)!,
      warningColor: Color.lerp(warningColor, other.warningColor, t)!,
      connectedColor: Color.lerp(connectedColor, other.connectedColor, t)!,
      disconnectedColor: Color.lerp(
        disconnectedColor,
        other.disconnectedColor,
        t,
      )!,
      openLogColor: Color.lerp(openLogColor, other.openLogColor, t)!,
      writeActionColor: Color.lerp(
        writeActionColor,
        other.writeActionColor,
        t,
      )!,
      brandGreen: Color.lerp(brandGreen, other.brandGreen, t)!,
      liveColor: Color.lerp(liveColor, other.liveColor, t)!,
    );
  }
}

class AppTheme {
  static const _primary = Color(0xFF1E8E3E);

  static const TextTheme textTheme = TextTheme(
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
    titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
    titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
    titleSmall: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
    labelLarge: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
    bodyLarge: TextStyle(fontSize: 14),
    bodyMedium: TextStyle(fontSize: 13),
    bodySmall: TextStyle(fontSize: 12),
    labelSmall: TextStyle(fontSize: 11),
  );

  static InputDecorationTheme _inputDecorationTheme({
    required Color fillColor,
    required Color hintColor,
    required Color primary,
    required Color error,
  }) {
    OutlineInputBorder border(Color color, double width) => OutlineInputBorder(
      borderRadius: AppRadii.mdAll,
      borderSide: width == 0
          ? BorderSide.none
          : BorderSide(color: color, width: width),
    );
    return InputDecorationTheme(
      filled: true,
      fillColor: fillColor,
      hintStyle: TextStyle(color: hintColor),
      border: border(primary, 0),
      enabledBorder: border(primary, 0),
      focusedBorder: border(primary, 1.4),
      errorBorder: border(error, 1),
      focusedErrorBorder: border(error, 1.4),
    );
  }

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
      onPrimary: Colors.white,
      error: Color(0xFFEF5350),
      surface: Color(0xFF1E1E1E),
      surfaceContainer: Color(0xFF1A1A1A),
      surfaceContainerHighest: Color(0xFF252525),
      onSurfaceVariant: Colors.grey,
      outline: Color(0xFF3A3A3A),
    ),
    cardTheme: CardThemeData(
      color: const Color(0xFF1E1E1E),
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.lgAll,
        side: BorderSide(color: const Color(0xFF3A3A3A).withValues(alpha: 0.7)),
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
    inputDecorationTheme: _inputDecorationTheme(
      fillColor: const Color(0xFF252525),
      hintColor: Colors.grey,
      primary: _primary,
      error: const Color(0xFFEF5350),
    ),
    switchTheme: _switchTheme,
    snackBarTheme: const SnackBarThemeData(actionTextColor: _primary),
    extensions: const [AppColors.dark],
  );

  static ThemeData get lightTheme => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: const Color(0xFFF2F2F7),
    textTheme: textTheme,
    colorScheme: const ColorScheme.light(
      primary: _primary,
      onPrimary: Colors.white,
      error: Color(0xFFD32F2F),
      surface: Colors.white,
      surfaceContainer: Color(0xFFEAEAF0),
      surfaceContainerHighest: Color(0xFFF0F0F5),
      onSurfaceVariant: Color(0xFF757575),
      outline: Color(0xFFE0E0E0),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 1,
      shadowColor: Colors.black.withValues(alpha: 0.03),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadii.lgAll,
        side: BorderSide(
          color: const Color(0xFFE0E0E0).withValues(alpha: 0.28),
        ),
      ),
      margin: EdgeInsets.zero,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: const Color(0xFFF2F2F7),
      elevation: 0,
      centerTitle: true,
      iconTheme: const IconThemeData(color: Color(0xFF1C1C1E)),
      titleTextStyle: textTheme.titleMedium!.copyWith(
        color: const Color(0xFF1C1C1E),
      ),
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
    inputDecorationTheme: _inputDecorationTheme(
      fillColor: const Color(0xFFF0F0F5),
      hintColor: const Color(0xFF757575),
      primary: _primary,
      error: const Color(0xFFD32F2F),
    ),
    switchTheme: _switchTheme,
    snackBarTheme: const SnackBarThemeData(actionTextColor: Colors.white),
    extensions: const [AppColors.light],
  );
}
