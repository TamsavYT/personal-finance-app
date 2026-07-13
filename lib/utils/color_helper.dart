import 'package:flutter/material.dart';

class ColorHelper {
  static const Color _fallback = Colors.grey;

  static Color hexToColor(String? hex, {Color fallback = _fallback}) {
    if (hex == null || hex.isEmpty) return fallback;
    final parsed = int.tryParse(hex.replaceFirst('#', '0xFF'));
    return parsed != null ? Color(parsed) : fallback;
  }
}
