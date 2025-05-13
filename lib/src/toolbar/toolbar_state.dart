// lib/src/toolbar/toolbar_state.dart

import 'package:flutter/foundation.dart';
import 'package:journal_core/journal_core.dart';

class ToolbarState extends ChangeNotifier {
  bool isVisible = false;
  bool showTextStyles = false;
  bool isDragMode = false; // Added drag mode flag
  bool showInsertMenu = false;
  bool showLayoutMenu = false;
  String currentBlockType = 'paragraph';
  int? headingLevel;
  bool isStyleBold = false;
  bool isStyleItalic = false;
  bool isStyleUnderline = false;
  bool isStyleStrikethrough = false;
  bool hasClipboardContent = false;
  List<int>? currentSelectionPath;
  String? previousSiblingType;

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
  }) {
    if (isStyleBold != bold ||
        isStyleItalic != italic ||
        isStyleUnderline != underline ||
        isStyleStrikethrough != strikethrough) {
      isStyleBold = bold;
      isStyleItalic = italic;
      isStyleUnderline = underline;
      isStyleStrikethrough = strikethrough;
      notifyListeners();
    }
  }

  void setSelectionInfo({
    required bool isVisible,
    required bool showTextStyles,
    required bool isDragMode, // Added parameter
    required List<int>? selectionPath,
    required String? previousSiblingType,
  }) {
    this.isVisible = isVisible;
    this.showTextStyles = showTextStyles;
    this.isDragMode = isDragMode; // Update drag mode
    currentSelectionPath = selectionPath;
    this.previousSiblingType = previousSiblingType;
    notifyListeners();
  }
}
