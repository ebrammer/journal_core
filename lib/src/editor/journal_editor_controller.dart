// lib/src/editor/journal_editor_controller.dart

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';
import 'dart:convert';

/// Controller for the journal editor, managing editor state and toolbar interactions.
/// - Synchronizes toolbar state with editor selection for consistent UI updates.
/// - Provides methods to retrieve document content and ensure valid selections.
/// - Includes debug logs with 🔍 prefix for state changes and operations.
/// - Compatible with AppFlowy 4.0.0 and single-editor drag-and-drop approach.
class JournalEditorController {
  final EditorState editorState;
  final ToolbarState toolbarState;

  JournalEditorController({
    required this.editorState,
    required this.toolbarState,
  });

  /// Ensures a valid selection exists in the editor, setting a default if none is present.
  /// - Sets selection to the first non-metadata node's path if no selection exists and document is non-empty.
  void ensureValidSelection() {
    if (editorState.selection == null &&
        editorState.document.root.children.isNotEmpty) {
      // Skip metadata_block for selection
      final firstNonMetadataNode = editorState.document.root.children
          .asMap()
          .entries
          .firstWhere(
            (entry) => entry.value.type != 'metadata_block',
            orElse: () => MapEntry(0, editorState.document.root.children.first),
          )
          .value;
      editorState.selection =
          Selection.collapsed(Position(path: firstNonMetadataNode.path));
      Log.info('🔍 Set default selection: ${editorState.selection}');
    }
  }

  /// Synchronizes the toolbar state with the current editor selection.
  /// - Updates block type, text styles, and visibility based on the selected node.
  /// - Preserves drag mode state during updates.
  void syncToolbarWithSelection() {
    try {
      final selection = editorState.selection;
      bool isVisible = selection != null;
      bool showTextStyles = selection != null && !selection.isCollapsed;
      List<int>? selectionPath = selection?.start.path;
      String? previousSiblingType;

      String currentBlockType = 'paragraph';
      int? headingLevel;
      bool isStyleBold = false;
      bool isStyleItalic = false;
      bool isStyleUnderline = false;
      bool isStyleStrikethrough = false;

      if (selection != null) {
        final node = editorState.getNodeAtPath(selection.start.path);
        if (node != null && node.type != 'metadata_block') {
          currentBlockType = node.type;
          if (currentBlockType == 'heading') {
            headingLevel = node.attributes[HeadingBlockKeys.level] as int? ?? 2;
          }

          // Check text styles if selection is not collapsed
          if (!selection.isCollapsed) {
            final attributes = node.attributes;
            final delta = attributes['delta'] as List? ?? [];
            if (delta.isNotEmpty) {
              final startOffset = selection.start.offset;
              final endOffset = selection.end.offset;
              var currentOffset = 0;
              for (final op in delta) {
                final opText = op['insert'] as String;
                final opLength = opText.length;
                final opAttributes =
                    op['attributes'] as Map<String, dynamic>? ?? {};
                if (currentOffset + opLength > startOffset &&
                    currentOffset < endOffset) {
                  isStyleBold |= opAttributes['bold'] == true;
                  isStyleItalic |= opAttributes['italic'] == true;
                  isStyleUnderline |= opAttributes['underline'] == true;
                  isStyleStrikethrough |= opAttributes['strikethrough'] == true;
                }
                currentOffset += opLength;
              }
            }
          }

          // Get previous sibling type
          if (selection.start.path.isNotEmpty) {
            final parentPath = selection.start.path.length > 1
                ? selection.start.path
                    .sublist(0, selection.start.path.length - 1)
                : null;
            final index = selection.start.path.last;
            if (index > 0) {
              final siblingPath = [...?parentPath, index - 1];
              final siblingNode = editorState.getNodeAtPath(siblingPath);
              previousSiblingType = siblingNode?.type;
            }
          }
        }
      }

      toolbarState.setSelectionInfo(
        isVisible: isVisible,
        showTextStyles: showTextStyles,
        isDragMode: toolbarState.isDragMode,
        selectionPath: selectionPath,
        previousSiblingType: previousSiblingType,
      );

      toolbarState.setBlockType(currentBlockType, headingLevel: headingLevel);

      toolbarState.setTextStyles(
        bold: isStyleBold,
        italic: isStyleItalic,
        underline: isStyleUnderline,
        strikethrough: isStyleStrikethrough,
      );

      Log.info(
          '🔍 Synced toolbar: blockType=$currentBlockType, headingLevel=$headingLevel, '
          'isVisible=$isVisible, showTextStyles=$showTextStyles, '
          'styles=[bold:$isStyleBold, italic:$isStyleItalic, underline:$isStyleUnderline, strikethrough:$isStyleStrikethrough]');
    } catch (e, stackTrace) {
      Log.error('🔍 Failed to sync toolbar with selection: $e');
      Log.error('🔍 Stack trace: $stackTrace');
    }
  }

  /// Retrieves the current document content as a JSON string, excluding metadata_block.
  /// - Serializes the editor's document for saving or external use.
  String getDocumentContent() {
    try {
      final json = editorState.document.toJson();
      final documentMap = json['document'] as Map<String, dynamic>? ?? {};
      final children = documentMap['children'] as List<dynamic>? ?? [];
      final filteredChildren =
          children.where((node) => node['type'] != 'metadata_block').toList();
      final filteredJson = {
        'document': {
          'type': documentMap['type'] as String? ?? 'page',
          'children': filteredChildren,
        }
      };
      final content = jsonEncode(filteredJson);
      Log.info(
          '🔍 Retrieved document content (excluded metadata_block): $content');
      return content;
    } catch (e, stackTrace) {
      Log.error('🔍 Failed to get document content: $e');
      Log.error('🔍 Stack trace: $stackTrace');
      return '{}';
    }
  }

  /// Disposes of resources held by the controller.
  void dispose() {
    editorState.dispose();
    Log.info('🔍 JournalEditorController disposed');
  }
}
