// lib/src/toolbar/toolbar_state.dart

import 'package:flutter/foundation.dart';
import 'package:journal_core/journal_core.dart';
import '../models/block_type_constants.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

class ToolbarState extends ChangeNotifier {
  bool isVisible = false;
  bool showTextStyles = false;
  bool isDragMode = false; // Added drag mode flag
  bool showInsertMenu = false;
  bool showLayoutMenu = false;
  bool showActionsMenu = false; // Added for actions submenu
  bool showColorPicker = false; // Added for color picker column
  Widget? colorPickerWidget; // Added for color picker widget
  String currentBlockType = BlockTypeConstants.paragraph;
  int? headingLevel;
  bool isStyleBold = false;
  bool isStyleItalic = false;
  bool isStyleUnderline = false;
  bool isStyleStrikethrough = false;
  bool isStyleBackgroundColor = false;
  bool isStyleTextColor = false;
  bool hasClipboardContent = false;
  List<int>? currentSelectionPath;
  String? previousSiblingType;
  Selection? visualSelection; // Added to track selection state

  ToolbarState();

  void setBlockType(String type, {int? headingLevel}) {
    if (currentBlockType != type || this.headingLevel != headingLevel) {
      Log.info('🔢 Block type changed to: $type, headingLevel: $headingLevel');
      currentBlockType = type;
      this.headingLevel = headingLevel;
      notifyListeners();
    }
  }

  void setTextStyles({
    required bool bold,
    required bool italic,
    required bool underline,
    required bool strikethrough,
    bool? backgroundColor,
    bool? textColor,
  }) {
    if (isStyleBold != bold ||
        isStyleItalic != italic ||
        isStyleUnderline != underline ||
        isStyleStrikethrough != strikethrough ||
        (backgroundColor != null &&
            isStyleBackgroundColor != backgroundColor) ||
        (textColor != null && isStyleTextColor != textColor)) {
      isStyleBold = bold;
      isStyleItalic = italic;
      isStyleUnderline = underline;
      isStyleStrikethrough = strikethrough;
      if (backgroundColor != null) {
        isStyleBackgroundColor = backgroundColor;
      }
      if (textColor != null) {
        isStyleTextColor = textColor;
      }
      notifyListeners();
    }
  }

  void setSelectionInfo({
    required bool isVisible,
    required bool showTextStyles,
    required bool isDragMode,
    required List<int>? selectionPath,
    required String? previousSiblingType,
  }) {
    this.isVisible = isVisible;
    this.showTextStyles = showTextStyles;
    this.isDragMode = isDragMode;
    currentSelectionPath = selectionPath;
    this.previousSiblingType = previousSiblingType;
    notifyListeners();
  }

  void setVisualSelection(Selection? selection) {
    visualSelection = selection;
    // Only update showTextStyles if color picker is not open
    if (!showColorPicker) {
      showTextStyles = selection != null;
    }
    notifyListeners();
  }
}
