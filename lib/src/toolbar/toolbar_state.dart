// lib/src/toolbar/toolbar_state.dart

import 'package:flutter/foundation.dart';
import 'package:journal_core/journal_core.dart';

class ToolbarState extends ChangeNotifier {
  bool isVisible = false;
  bool showTextStyles = false;
  bool isDragMode = false;
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

  void setBlockType(BlockType type, {int? headingLevel}) {
    currentBlockType = type.name;
    this.headingLevel = headingLevel;
    notifyListeners();
  }

  void setTextStyles({
    required bool bold,
    required bool italic,
    required bool underline,
    required bool strikethrough,
  }) {
    isStyleBold = bold;
    isStyleItalic = italic;
    isStyleUnderline = underline;
    isStyleStrikethrough = strikethrough;
    notifyListeners();
  }

  void setSelectionInfo({
    required bool isVisible,
    required bool showTextStyles,
    required List<int>? selectionPath,
    required String? previousSiblingType,
  }) {
    this.isVisible = isVisible;
    this.showTextStyles = showTextStyles;
    currentSelectionPath = selectionPath;
    this.previousSiblingType = previousSiblingType;
    notifyListeners();
  }
}
