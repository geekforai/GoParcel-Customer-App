import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTypography {
  /// When true, primary UI font is Noto Sans Devanagari so Hindi renders.
  static bool hindi = false;

  static TextStyle _font({
    required double fontSize,
    required FontWeight fontWeight,
    required Color color,
    double height = 1.4,
    double? letterSpacing,
  }) {
    final style = hindi
        ? GoogleFonts.notoSansDevanagari(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            height: height,
            letterSpacing: letterSpacing,
          )
        : GoogleFonts.plusJakartaSans(
            fontSize: fontSize,
            fontWeight: fontWeight,
            color: color,
            height: height,
            letterSpacing: letterSpacing,
          );
    final hindiFamily = GoogleFonts.notoSansDevanagari().fontFamily;
    return style.copyWith(
      fontFamilyFallback: [
        ?hindiFamily,
        'Noto Sans Devanagari',
        'NotoSansDevanagari',
      ],
    );
  }

  static TextTheme get textTheme => TextTheme(
        displayLarge: _font(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        displayMedium: _font(
          fontSize: 28,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.2,
        ),
        headlineLarge: _font(
          fontSize: 24,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.3,
        ),
        headlineMedium: _font(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          height: 1.3,
        ),
        headlineSmall: _font(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.3,
        ),
        titleLarge: _font(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleMedium: _font(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        titleSmall: _font(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        bodyLarge: _font(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: AppColors.textPrimary,
          height: 1.5,
        ),
        bodyMedium: _font(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        bodySmall: _font(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
        labelLarge: _font(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        labelMedium: _font(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
        labelSmall: _font(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          color: AppColors.textTertiary,
        ),
      );

  static TextStyle get brandLogo => _font(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: AppColors.brandNavy,
        letterSpacing: -0.5,
      );

  static TextStyle get brandLogoAccent => _font(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: AppColors.brandGreen,
        letterSpacing: -0.5,
      );
}
