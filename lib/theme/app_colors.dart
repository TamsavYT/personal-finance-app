import 'package:flutter/material.dart';

/// Centralized color definitions for the Expense Ledger app.
///
/// Includes semantic colors for transaction types, a vibrant category
/// palette, account-type colors, chart-friendly palettes, and gradients.
class AppColors {
  AppColors._();

  // ─── Primary ───────────────────────────────────────────────────────
  static const Color primary = Color(0xFF00897B);
  static const Color primaryLight = Color(0xFF4DB6AC);
  static const Color primaryDark = Color(0xFF00695C);

  // ─── Secondary ─────────────────────────────────────────────────────
  static const Color secondary = Color(0xFFFFB300);
  static const Color secondaryLight = Color(0xFFFFD54F);

  // ─── Transaction Type Colors ───────────────────────────────────────
  static const Color income = Color(0xFF43A047);
  static const Color expense = Color(0xFFE53935);
  static const Color transfer = Color(0xFF1E88E5);

  // ─── Category Palette (20 vibrant, distinct colors) ────────────────
  static const List<Color> categoryColors = [
    Color(0xFFE53935), // Red
    Color(0xFF1E88E5), // Blue
    Color(0xFF43A047), // Green
    Color(0xFFFFB300), // Amber
    Color(0xFF8E24AA), // Purple
    Color(0xFF00ACC1), // Cyan
    Color(0xFFFF7043), // Deep Orange
    Color(0xFF5C6BC0), // Indigo
    Color(0xFF00897B), // Teal
    Color(0xFFC0CA33), // Lime
    Color(0xFFF4511E), // Orange-Red
    Color(0xFF3949AB), // Deep Blue
    Color(0xFF7CB342), // Light Green
    Color(0xFFD81B60), // Pink
    Color(0xFF039BE5), // Light Blue
    Color(0xFFFDD835), // Yellow
    Color(0xFF6D4C41), // Brown
    Color(0xFF546E7A), // Blue Grey
    Color(0xFFAB47BC), // Light Purple
    Color(0xFF26A69A), // Medium Teal
  ];

  // ─── Account Type Colors ───────────────────────────────────────────
  static const Map<String, Color> accountColors = {
    'cash': Color(0xFF43A047),
    'bank': Color(0xFF1E88E5),
    'upi': Color(0xFF7C4DFF),
    'wallet': Color(0xFFFF7043),
    'other': Color(0xFF78909C),
  };

  // ─── Chart Palette (10 chart-friendly colors) ──────────────────────
  static const List<Color> chartColors = [
    Color(0xFF00897B), // Teal
    Color(0xFFE53935), // Red
    Color(0xFF1E88E5), // Blue
    Color(0xFFFFB300), // Amber
    Color(0xFF8E24AA), // Purple
    Color(0xFF43A047), // Green
    Color(0xFFFF7043), // Deep Orange
    Color(0xFF00ACC1), // Cyan
    Color(0xFF5C6BC0), // Indigo
    Color(0xFFD81B60), // Pink
  ];

  // ─── Gradients ─────────────────────────────────────────────────────
  static const LinearGradient incomeGradient = LinearGradient(
    colors: [Color(0xFF43A047), Color(0xFF66BB6A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient expenseGradient = LinearGradient(
    colors: [Color(0xFFE53935), Color(0xFFEF5350)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient transferGradient = LinearGradient(
    colors: [Color(0xFF1E88E5), Color(0xFF42A5F5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF00897B), Color(0xFF4DB6AC)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // ─── Background Colors ─────────────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF8F9FA);
  static const Color backgroundDark = Color(0xFF121212);

  // ─── Surface Colors ────────────────────────────────────────────────
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surfaceDark = Color(0xFF1E1E1E);
  static const Color cardSurfaceDark = Color(0xFF2C2C2C);
}
