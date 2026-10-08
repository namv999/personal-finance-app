import 'package:flutter/material.dart';

/// Central color palette. Keep all raw color values here so the rest of
/// the app never hardcodes a Color(...) literal.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFF2E7D6B); // teal-green, "money growing"
  static const Color primaryDark = Color(0xFF1E5548);
  static const Color secondary = Color(0xFFF2A65A); // warm accent
  static const Color background = Color(0xFFF7F8FA);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color income = Color(0xFF2E9E5B);
  static const Color expense = Color(0xFFE0554F);
  static const Color transfer = Color(0xFF4C7DF0);

  static const Color textPrimary = Color(0xFF1B1E23);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color divider = Color(0xFFE5E7EB);
  static const Color danger = Color(0xFFE0554F);
  static const Color warning = Color(0xFFF2A65A);

  /// Default palette offered when a user picks a color for a wallet/category.
  static const List<Color> pickerPalette = [
    Color(0xFF2E7D6B),
    Color(0xFF4C7DF0),
    Color(0xFFF2A65A),
    Color(0xFFE0554F),
    Color(0xFF9B59B6),
    Color(0xFF16A085),
    Color(0xFFE67E22),
    Color(0xFF34495E),
  ];
}
