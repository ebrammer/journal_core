// src/editor/journal_editor_controller.dart

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';

class JournalEditorController {
  final EditorState editorState;
  final ToolbarState toolbarState;

  JournalEditorController({required this.editorState})
      : toolbarState = ToolbarState() {
    editorState.selectionNotifier.addListener(syncToolbarWithSelection);
  }

  void dispose() {
    editorState.selectionNotifier.removeListener(syncToolbarWithSelection);
  }

  String getDocumentContent() {
    try {
      return editorState.document.toJson().toString();
    } catch (_) {
      return '';
    }
  }

  Node? get selectedNode {
    final selection = editorState.selection;
    return selection != null
        ? editorState.getNodeAtPath(selection.start.path)
        : null;
  }

  void syncToolbarWithSelection() {
    Log.info(
        '🔄 syncToolbarWithSelection triggered with selection: ${editorState.selection}');
    final selection = editorState.selection;
    final node = selection != null
        ? editorState.getNodeAtPath(selection.start.path)
        : null;

    if (selection == null || node == null) {
      toolbarState.setSelectionInfo(
        isVisible: false,
        showTextStyles: false,
        selectionPath: null,
        previousSiblingType: null,
      );
      return;
    }

    // Update block type directly with node.type
    final blockType = node.type;
    Log.info(
        '🔢 Node type at cursor: $blockType, path: ${selection.start.path}');
    final headingLevel =
        blockType == 'heading' ? node.attributes['level'] as int? ?? 2 : null;
    toolbarState.setBlockType(blockType, headingLevel: headingLevel);

    // Update text styles
    bool isBold = false;
    bool isItalic = false;
    bool isUnderline = false;
    bool isStrikethrough = false;

    final delta = node.attributes['delta'] as List? ?? [];
    if (delta.isNotEmpty) {
      if (selection.isCollapsed) {
        var currentOffset = 0;
        final cursorOffset = selection.start.offset;
        for (final op in delta) {
          final text = op['insert'] as String;
          final len = text.length;
          final attrs = op['attributes'] as Map<String, dynamic>? ?? {};
          if (currentOffset <= cursorOffset &&
              cursorOffset <= currentOffset + len) {
            isBold = attrs['bold'] == true;
            isItalic = attrs['italic'] == true;
            isUnderline = attrs['underline'] == true;
            isStrikethrough = attrs['strikethrough'] == true;
            break;
          }
          currentOffset += len;
        }
      } else {
        final startOffset = selection.start.offset;
        final endOffset = selection.end.offset;
        var currentOffset = 0;
        for (final op in delta) {
          final text = op['insert'] as String;
          final len = text.length;
          final attrs = op['attributes'] as Map<String, dynamic>? ?? {};
          if (currentOffset + len > startOffset && currentOffset < endOffset) {
            isBold |= attrs['bold'] == true;
            isItalic |= attrs['italic'] == true;
            isUnderline |= attrs['underline'] == true;
            isStrikethrough |= attrs['strikethrough'] == true;
          }
          currentOffset += len;
        }
      }
    }

    toolbarState.setTextStyles(
      bold: isBold,
      italic: isItalic,
      underline: isUnderline,
      strikethrough: isStrikethrough,
    );

    toolbarState.setSelectionInfo(
      isVisible: true,
      showTextStyles: !selection.isCollapsed,
      selectionPath: selection.start.path,
      previousSiblingType: _getPreviousSiblingType(selection),
    );
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
