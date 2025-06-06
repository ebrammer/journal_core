// lib/src/blocks/metadata_block.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:intl/intl.dart';
import 'package:journal_core/journal_core.dart';
import 'package:provider/provider.dart';
import '../theme/journal_theme.dart';

/// Metadata block builder to display title and created date
class MetadataBlockBuilder extends BlockComponentBuilder {
  MetadataBlockBuilder({
    required this.titleController,
    required this.createdAt,
    required this.onTitleChanged,
    this.titleFocusNode,
    this.onTitleEditingComplete,
    this.onTitleSubmitted,
    this.readOnly = false,
    this.editorFocusNode,
  });

  final TextEditingController titleController;
  final int createdAt;
  final ValueChanged<String> onTitleChanged;
  final FocusNode? titleFocusNode;
  final VoidCallback? onTitleEditingComplete;
  final ValueChanged<String>? onTitleSubmitted;
  final bool readOnly;
  final FocusNode? editorFocusNode;

  @override
  String get blockType => 'metadata_block';

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    return MetadataBlockWidget(
      key: context.node.key,
      node: context.node,
      titleController: titleController,
      createdAt: createdAt,
      onTitleChanged: onTitleChanged,
      titleFocusNode: titleFocusNode,
      onTitleEditingComplete: onTitleEditingComplete,
      onTitleSubmitted: onTitleSubmitted,
      readOnly: readOnly,
      editorFocusNode: editorFocusNode,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (Node node) => node.type == 'metadata_block';
}

class MetadataBlockWidget extends StatelessWidget
    implements BlockComponentWidget {
  const MetadataBlockWidget({
    super.key,
    required this.node,
    required this.titleController,
    required this.createdAt,
    required this.onTitleChanged,
    this.titleFocusNode,
    this.onTitleEditingComplete,
    this.onTitleSubmitted,
    this.readOnly = false,
    this.editorFocusNode,
  });

  @override
  final Node node;
  final TextEditingController titleController;
  final int createdAt;
  final ValueChanged<String> onTitleChanged;
  final FocusNode? titleFocusNode;
  final VoidCallback? onTitleEditingComplete;
  final ValueChanged<String>? onTitleSubmitted;
  final bool readOnly;
  final FocusNode? editorFocusNode;

  @override
  BlockComponentConfiguration get configuration =>
      const BlockComponentConfiguration();

  @override
  BlockComponentActionBuilder? get actionBuilder => null;

  BlockComponentActionBuilder? get actionTrailingBuilder => null;

  @override
  bool get showActions => false;

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMMM d, yyyy')
        .format(DateTime.fromMillisecondsSinceEpoch(createdAt));

    // Get the toolbar state to check if we're in reorder mode
    final toolbarState = context.watch<ToolbarState>();
    final isReorderMode = toolbarState.isDragMode;
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);

    return Container(
      // In reorder mode: Add horizontal padding (16.0) to align with reorderable blocks
      // In edit mode: No horizontal padding (0.0) to align with content
      // Vertical padding (8.0) remains consistent in both modes
      padding: EdgeInsets.symmetric(
        horizontal: isReorderMode ? 14.0 : 0.0,
        vertical: isReorderMode ? 0 : 12.0,
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (readOnly)
            Text(
              titleController.text,
              style: TextStyle(
                fontSize: 32.0,
                fontWeight: FontWeight.w700,
                color: theme.primaryText,
                height: 1.5,
              ),
            )
          else
            TextField(
              controller: titleController,
              focusNode: titleFocusNode,
              decoration: InputDecoration(
                hintText: 'Title',
                border: InputBorder.none,
                hintStyle: TextStyle(
                  color: theme.secondaryText,
                  fontSize: 32.0,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
              style: TextStyle(
                fontSize: 32.0,
                fontWeight: FontWeight.w700,
                color: theme.primaryText,
                height: 1.5,
              ),
              maxLines: null,
              minLines: 1,
              textInputAction: TextInputAction.done,
              onChanged: onTitleChanged,
              onEditingComplete: onTitleEditingComplete,
              onSubmitted: (value) {
                // Find the first content block (after metadata)
                final editorState =
                    Provider.of<EditorState>(context, listen: false);
                int firstContentIndex = 0;
                for (int i = 0;
                    i < editorState.document.root.children.length;
                    i++) {
                  if (editorState.document.root.children[i].type !=
                          BlockTypeConstants.metadata &&
                      editorState.document.root.children[i].type !=
                          BlockTypeConstants.spacer) {
                    firstContentIndex = i;
                    break;
                  }
                }

                // Set selection to the first content block
                editorState.selection = Selection.collapsed(
                  Position(path: [firstContentIndex], offset: 0),
                );

                // Request focus for the editor
                editorFocusNode?.requestFocus();

                // Call the original onSubmitted callback
                onTitleSubmitted?.call(value);
              },
              cursorColor: theme.primaryText,
              cursorWidth: 2.0,
              cursorRadius: const Radius.circular(1.0),
              onTap: () {
                // Clear any selection in the editor when title gets focus
                final editorState =
                    Provider.of<EditorState>(context, listen: false);
                editorState.selection = null;
              },
            ),
          const SizedBox(height: 4.0),
          Text(
            '$formattedDate',
            style: TextStyle(
              fontSize: 14.0,
              color: theme.secondaryText,
              height: 1.5,
            ),
          ),
          isReorderMode
              ? const SizedBox(height: 12.0)
              : const SizedBox.shrink(),
        ],
      ),
    );
  }
}
