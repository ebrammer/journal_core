import 'package:flutter/material.dart';
import 'package:journal_core/src/theme/journal_theme.dart';

/// Constants and theme-related code for the color picker
class ColorPickerConstants {
  // Theme-aware color pairs (light, dark)
  static const List<(Color, Color)> textColorPairs = [
    (Colors.black, Colors.white), // black/white
    (Color(0xFFF5B40B), Color(0xFFF5B40B)), // yellow
    (Color(0xFF79CE0A), Color(0xFF79CE0A)), // green
    (Color(0xFF317FFF), Color(0xFF317FFF)), // blue
    (Color(0xFF9D68FF), Color(0xFF9D68FF)), // purple
    (Color(0xFFEF4444), Color(0xFFEF4444)), // red
  ];

  // Theme-aware background color pairs (light, dark)
  static const List<(Color, Color)> bgColorPairs = [
    (Color(0xFFFBE28F), Color(0xFFF5B40B)), // yellow
    (Color(0xFFB8EA8C), Color(0xFF79CE0A)), // green
    (Color(0xFFAED6FF), Color(0xFF317FFF)), // blue
    (Color(0xFFD9BFFF), Color(0xFF9D68FF)), // purple
    (Color(0xFFF9A3A3), Color(0xFFEF4444)), // red
  ];

  // Theme-aware underline color pairs (light, dark)
  static const List<(Color, Color)> underlineColorPairs = [
    (Color(0xFFF5B40B), Color(0xFFF5B40B)), // yellow
    (Color(0xFF79CE0A), Color(0xFF79CE0A)), // green
    (Color(0xFF317FFF), Color(0xFF317FFF)), // blue
    (Color(0xFF9D68FF), Color(0xFF9D68FF)), // purple
    (Color(0xFFEF4444), Color(0xFFEF4444)), // red
  ];

  /// Get a theme-aware color based on the color index and theme mode
  static Color getThemeAwareColor(int colorIndex, bool isDarkMode) {
    // Get the theme colors from JournalTheme
    final theme = isDarkMode ? JournalTheme.dark() : JournalTheme.light();

    // Define color mappings based on theme colors
    final colors = [
      theme.secondaryBackground, // Light/dark background
      theme.toolbarBackground, // Toolbar background
      theme.dividerColor, // Divider color
      theme.metadataText, // Metadata text
      theme.secondaryText, // Secondary text
      theme.link, // Link color
      theme.error, // Error color
      theme.cursor, // Cursor color
    ];

    // Ensure the color index is within bounds
    final index = colorIndex % colors.length;
    return colors[index];
  }

  /// Get the current theme-aware colors based on the theme mode
  static (List<Color>, List<Color>, List<Color>) getCurrentThemeColors(
      bool isDarkMode) {
    final currentTextColors =
        textColorPairs.map((pair) => isDarkMode ? pair.$2 : pair.$1).toList();
    final currentBgColors =
        bgColorPairs.map((pair) => isDarkMode ? pair.$2 : pair.$1).toList();
    final currentUnderlineColors = underlineColorPairs
        .map((pair) => isDarkMode ? pair.$2 : pair.$1)
        .toList();

    return (currentTextColors, currentBgColors, currentUnderlineColors);
  }
}
