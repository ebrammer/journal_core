// src/editor/journal_editor_controller.dart

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/src/toolbar/toolbar_state.dart';

/// Controller that manages document-level actions and state during editing.
class JournalEditorController {
  final EditorState editorState;
  final toolbarState = ToolbarState();

  JournalEditorController({required this.editorState});

  void dispose() {
    // Add cleanup if needed in future
  }

  /// Gets the current document as JSON string
  String getDocumentContent() {
    try {
      return editorState.document.toJson().toString();
    } catch (_) {
      return '';
    }
  }

  /// Returns the currently selected block node
  Node? get selectedNode {
    final selection = editorState.selection;
    return selection != null
        ? editorState.getNodeAtPath(selection.start.path)
        : null;
  }

  void syncToolbarWithSelection() {
    final selection = editorState.selection;
    final node = selection != null
        ? editorState.getNodeAtPath(selection.start.path)
        : null;

    toolbarState
      ..isVisible = selection != null
      ..showTextStyles = selection != null && !selection.isCollapsed
      ..currentBlockType = node?.type ?? 'paragraph'
      ..headingLevel = node?.attributes['level'] as int?
      ..currentSelectionPath = selection?.start.path
      ..previousSiblingType = _getPreviousSiblingType(selection)
      ..isStyleBold = _isStyleActive('bold')
      ..isStyleItalic = _isStyleActive('italic')
      ..isStyleUnderline = _isStyleActive('underline')
      ..isStyleStrikethrough = _isStyleActive('strikethrough');

    toolbarState.notifyListeners();
  }

  bool _isStyleActive(String style) {
    final selection = editorState.selection;
    if (selection == null || selection.isCollapsed) return false;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return false;
    final delta = node.attributes['delta'] as List?;
    if (delta == null || delta.isEmpty) return false;

    final startOffset = selection.start.offset;
    final endOffset = selection.end.offset;
    var currentOffset = 0;

    for (final op in delta) {
      final text = op['insert'] as String;
      final len = text.length;
      final attrs = op['attributes'] as Map<String, dynamic>?;

      if (currentOffset + len > startOffset && currentOffset < endOffset) {
        if (attrs?[style] == true) return true;
      }

      currentOffset += len;
    }

    return false;
  }

  String? _getPreviousSiblingType(Selection? selection) {
    if (selection == null || selection.start.path.isEmpty) return null;
    final index = selection.start.path.last;
    if (index > 0) {
      final siblingPath = [
        ...selection.start.path.sublist(0, selection.start.path.length - 1),
        index - 1
      ];
      final siblingNode = editorState.getNodeAtPath(siblingPath);
      return siblingNode?.type;
    }
    return null;
  }
}
