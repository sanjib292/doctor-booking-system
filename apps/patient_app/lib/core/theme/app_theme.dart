import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

abstract final class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final isLight = brightness == Brightness.light;

    final colorScheme = isLight
        ? const ColorScheme.light(
            primary: AppColors.primary,
            onPrimary: AppColors.onPrimary,
            primaryContainer: AppColors.primaryContainer,
            onPrimaryContainer: AppColors.onPrimaryContainer,
            secondary: AppColors.secondary,
            tertiary: AppColors.accent,
            error: AppColors.error,
            surface: AppColors.surfaceLight,
            onSurface: AppColors.textPrimaryLight,
            onSurfaceVariant: AppColors.textSecondaryLight,
            outline: AppColors.outlineLight,
            surfaceContainerHighest: AppColors.surfaceVariantLight,
          )
        : const ColorScheme.dark(
            primary: AppColors.primaryLight,
            onPrimary: AppColors.onPrimaryContainer,
            primaryContainer: AppColors.primaryDark,
            secondary: AppColors.secondary,
            tertiary: AppColors.accent,
            error: AppColors.error,
            surface: AppColors.surfaceDark,
            onSurface: AppColors.textPrimaryDark,
            onSurfaceVariant: AppColors.textSecondaryDark,
            outline: AppColors.outlineDark,
            surfaceContainerHighest: AppColors.surfaceVariantDark,
          );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: 'Poppins',
      textTheme: isLight ? AppTextStyles.lightTextTheme : AppTextStyles.darkTextTheme,
      scaffoldBackgroundColor:
          isLight ? AppColors.backgroundLight : AppColors.backgroundDark,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor:
            isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        foregroundColor:
            isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        centerTitle: false,
        titleTextStyle: AppTextStyles.titleLarge.copyWith(
          color: isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        ),
        systemOverlayStyle: isLight
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: AppTextStyles.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight ? AppColors.surfaceVariantLight : AppColors.surfaceVariantDark,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor:
            isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        selectedItemColor: AppColors.primary,
        unselectedItemColor:
            isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showSelectedLabels: true,
        showUnselectedLabels: true,
        selectedLabelStyle: AppTextStyles.labelSmall.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTextStyles.labelSmall,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isLight ? AppColors.surfaceVariantLight : AppColors.surfaceVariantDark,
        selectedColor: AppColors.primaryContainer,
        labelStyle: AppTextStyles.labelMedium.copyWith(
          color: isLight ? AppColors.textPrimaryLight : AppColors.textPrimaryDark,
        ),
        secondaryLabelStyle: AppTextStyles.labelMedium.copyWith(
          color: AppColors.primary,
        ),
        iconTheme: IconThemeData(
          color: isLight ? AppColors.textSecondaryLight : AppColors.textSecondaryDark,
          size: 18,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: BorderSide.none,
      ),
      dividerTheme: DividerThemeData(
        color: isLight ? AppColors.outlineLight : AppColors.outlineDark,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
