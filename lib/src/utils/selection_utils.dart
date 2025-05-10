// src/utils/selection_utils.dart

import 'package:appflowy_editor/appflowy_editor.dart';

/// Returns true if the selection is collapsed at the start of the node.
bool isSelectionAtStart(Selection? selection) {
  if (selection == null || !selection.isCollapsed) return false;
  return selection.start.offset == 0;
}

/// Returns true if the selection is collapsed at the end of the node.
bool isSelectionAtEnd(Selection? selection, Node node) {
  if (selection == null || !selection.isCollapsed) return false;
  final delta = node.attributes['delta'] as List?;
  final fullLength = delta?.fold<int>(
        0,
        (sum, op) => sum + (op['insert'] as String).length,
      ) ??
      0;
  return selection.start.offset == fullLength;
}

/// Returns the index of the currently selected node in the root
int? getSelectedNodeIndex(EditorState editorState) {
  final selection = editorState.selection;
  if (selection == null) return null;
  return selection.start.path.first;
}
