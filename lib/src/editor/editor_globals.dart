// src/editor/editor_globals.dart

import 'package:flutter/widgets.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

/// Globally accessible editor state & focus for components that can't access context.
class EditorGlobals {
  static EditorState? editorState;
  static FocusNode? editorFocusNode;
  static const String titleBlockType = 'title';
  static const int titleBlockLevel = 1;
  static const String titlePlaceholder = 'Untitled';
}
