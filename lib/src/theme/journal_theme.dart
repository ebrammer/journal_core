import 'package:flutter/material.dart';

/// A theme for the journal editor that defines all the colors and styles used in the editor.
class JournalTheme {
  final Color primaryBackground;
  final Color secondaryBackground;
  final Color primaryText;
  final Color secondaryText;
  final Color dividerColor;
  final Color dividerSelectedBackground;
  final Color metadataText;
  final Color metadataCursor;
  final Color toolbarBackground;
  final Color toolbarBorder;
  final Color toolbarIcon;
  final Color doneButtonText;
  final Color error;
  final Color link;
  final Color cursor;
  final Color selectionBorder;

  const JournalTheme({
    required this.primaryBackground,
    required this.secondaryBackground,
    required this.primaryText,
    required this.secondaryText,
    required this.dividerColor,
    required this.dividerSelectedBackground,
    required this.metadataText,
    required this.metadataCursor,
    required this.toolbarBackground,
    required this.toolbarBorder,
    required this.toolbarIcon,
    required this.doneButtonText,
    required this.error,
    required this.link,
    required this.cursor,
    required this.selectionBorder,
  });

  /// Light theme
  static JournalTheme light() => const JournalTheme(
        primaryBackground: Colors.white,
        secondaryBackground: const Color(0xFFF5F5F5),
        primaryText: Colors.black,
        secondaryText: const Color(0xFF666666),
        dividerColor: const Color(0xFFE0E0E0),
        dividerSelectedBackground: const Color(0xFFF0F0F0),
        metadataText: const Color(0xFF666666),
        metadataCursor: const Color(0xFF2196F3),
        toolbarBackground: Colors.white,
        toolbarBorder: const Color(0xFFE0E0E0),
        toolbarIcon: const Color(0xFF666666),
        doneButtonText: Colors.black,
        error: const Color(0xFFE53935),
        link: const Color(0xFF2196F3),
        cursor: const Color(0xFF2196F3),
        selectionBorder: const Color(0xFF2196F3),
      );

  /// Dark theme
  static JournalTheme dark() => const JournalTheme(
        primaryBackground: const Color(0xFF1E1E1E),
        secondaryBackground: const Color(0xFF2D2D2D),
        primaryText: Colors.white,
        secondaryText: const Color(0xFFB0B0B0),
        dividerColor: const Color(0xFF404040),
        dividerSelectedBackground: const Color(0xFF353535),
        metadataText: const Color(0xFFB0B0B0),
        metadataCursor: const Color(0xFF2196F3),
        toolbarBackground: const Color(0xFF1E1E1E),
        toolbarBorder: const Color(0xFF404040),
        toolbarIcon: const Color(0xFFB0B0B0),
        doneButtonText: Colors.white,
        error: const Color(0xFFE53935),
        link: const Color(0xFF2196F3),
        cursor: const Color(0xFF2196F3),
        selectionBorder: const Color(0xFF2196F3),
      );

  /// Get theme from brightness
  static JournalTheme fromBrightness(Brightness brightness) {
    return brightness == Brightness.light ? light() : dark();
  }
}
