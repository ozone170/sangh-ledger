import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static const String fontFamily = 'NotoSansKannada';

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.primaryNavy,
      onPrimary: Colors.white,
      primaryContainer: AppColors.primaryNavyLight,
      onPrimaryContainer: Colors.white,
      secondary: AppColors.financialTeal,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.financialTealLight.withValues(alpha: 0.2),
      onSecondaryContainer: AppColors.financialTealDark,
      error: AppColors.errorCrimson,
      onError: Colors.white,
      surface: AppColors.surfaceNeutral,
      onSurface: AppColors.textPrimary,
      surfaceContainerLowest: AppColors.cardWhite,
      outline: AppColors.borderSubtle,
    );

    final baseTextTheme = Typography.material2021().black;
    const tabularFigureFeatures = [FontFeature.tabularFigures()];

    final textTheme = baseTextTheme.copyWith(
      displayLarge: baseTextTheme.displayLarge?.copyWith(
        fontFamily: fontFamily,
        fontFeatures: tabularFigureFeatures,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      displayMedium: baseTextTheme.displayMedium?.copyWith(
        fontFamily: fontFamily,
        fontFeatures: tabularFigureFeatures,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w700,
      ),
      headlineMedium: baseTextTheme.headlineMedium?.copyWith(
        fontFamily: fontFamily,
        fontFeatures: tabularFigureFeatures,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: baseTextTheme.titleLarge?.copyWith(
        fontFamily: fontFamily,
        fontFeatures: tabularFigureFeatures,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: baseTextTheme.titleMedium?.copyWith(
        fontFamily: fontFamily,
        fontFeatures: tabularFigureFeatures,
        color: AppColors.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      bodyLarge: baseTextTheme.bodyLarge?.copyWith(
        fontFamily: fontFamily,
        fontFeatures: tabularFigureFeatures,
        color: AppColors.textPrimary,
      ),
      bodyMedium: baseTextTheme.bodyMedium?.copyWith(
        fontFamily: fontFamily,
        fontFeatures: tabularFigureFeatures,
        color: AppColors.textSecondary,
      ),
      bodySmall: baseTextTheme.bodySmall?.copyWith(
        fontFamily: fontFamily,
        fontFeatures: tabularFigureFeatures,
        color: AppColors.textMuted,
      ),
      labelLarge: baseTextTheme.labelLarge?.copyWith(
        fontFamily: fontFamily,
        fontFeatures: tabularFigureFeatures,
        fontWeight: FontWeight.w600,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontFamily,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surfaceNeutral,
      textTheme: textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaryNavy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardWhite,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.borderSubtle, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryNavy,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryNavy,
          side: const BorderSide(color: AppColors.primaryNavy, width: 1.5),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontFamily: fontFamily,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.borderSubtle),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryNavy, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.errorCrimson),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary, fontFamily: fontFamily),
        hintStyle: const TextStyle(color: AppColors.textMuted, fontFamily: fontFamily),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primaryNavy,
        unselectedItemColor: AppColors.textMuted,
        selectedLabelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }
}

