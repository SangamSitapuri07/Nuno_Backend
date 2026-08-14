import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Typography tokens. Display/heading uses a rounded geometric face for the
/// playful game feel; body uses a highly legible UI face.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _display(double size, FontWeight weight,
      {Color? color, double? spacing, double? height}) {
    return GoogleFonts.baloo2(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.textPrimary,
      letterSpacing: spacing,
      height: height,
    );
  }

  static TextStyle _body(double size, FontWeight weight,
      {Color? color, double? spacing, double? height}) {
    return GoogleFonts.inter(
      fontSize: size,
      fontWeight: weight,
      color: color ?? AppColors.textPrimary,
      letterSpacing: spacing,
      height: height,
    );
  }

  // Display / headings
  static TextStyle get logo =>
      _display(48, FontWeight.w800, spacing: 2, height: 1.05);
  static TextStyle get h1 => _display(30, FontWeight.w800, height: 1.15);
  static TextStyle get h2 => _display(24, FontWeight.w700, height: 1.2);
  static TextStyle get h3 => _display(20, FontWeight.w700, height: 1.25);
  static TextStyle get h4 => _display(17, FontWeight.w600, height: 1.3);

  // Body
  static TextStyle get bodyLg => _body(16, FontWeight.w500, height: 1.45);
  static TextStyle get body => _body(14, FontWeight.w500, height: 1.45);
  static TextStyle get bodySm =>
      _body(13, FontWeight.w400, color: AppColors.textSecondary, height: 1.4);
  static TextStyle get caption =>
      _body(11, FontWeight.w500, color: AppColors.textMuted, spacing: 0.3);

  // Emphasis
  static TextStyle get button =>
      _display(15, FontWeight.w700, spacing: 0.6);

  /// Centered uppercase title on a panel header strip.
  static TextStyle get panelTitle =>
      _body(12, FontWeight.w800, spacing: 1.4);
  static TextStyle get label => _body(12, FontWeight.w700,
      color: AppColors.textSecondary, spacing: 1.1);
  static TextStyle get numeric =>
      _display(20, FontWeight.w800, spacing: 0.4);

  // Card face glyph
  static TextStyle cardGlyph(double size) => GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: FontWeight.w800,
        color: Colors.white,
        height: 1,
      );
}
