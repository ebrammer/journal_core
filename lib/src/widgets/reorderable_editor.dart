// lib/src/widgets/reorderable_editor.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show lerpDouble;
import 'package:journal_core/src/blocks/divider_block.dart' as divider;
import '../theme/journal_theme.dart';
import '../models/journal.dart';

/// Custom block component builder for custom block renderers
class CustomBlockComponentBuilder extends BlockComponentBuilder {
  CustomBlockComponentBuilder({
    required this.builder,
    this.configuration = const BlockComponentConfiguration(),
  });

  final Widget Function(Node, int depth) builder;
  @override
  final BlockComponentConfiguration configuration;

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    return CustomBlockComponentWidget(
      key: context.node.key,
      node: context.node,
      configuration: configuration,
      builder: builder,
    );
  }

  @override
  BlockComponentValidate get validate => (Node node) => true;
}

/// Custom block component widget for custom block renderers
class CustomBlockComponentWidget extends StatelessWidget
    implements BlockComponentWidget {
  const CustomBlockComponentWidget({
    super.key,
    required this.node,
    required this.configuration,
    required this.builder,
  });

  @override
  final Node node;
  @override
  final BlockComponentConfiguration configuration;
  final Widget Function(Node, int depth) builder;

  @override
  BlockComponentActionBuilder? get actionBuilder => null;

  @override
  BlockComponentActionBuilder? get actionTrailingBuilder => null;

  @override
  bool get showActions => false;

  @override
  Widget build(BuildContext context) {
    return builder(node, 0);
  }
}

class ReorderableEditor extends StatefulWidget {
  const ReorderableEditor({
    super.key,
    required this.editorState,
    required this.selectedBlockPath,
    required this.onBlockSelected,
    this.customBlockRenderers,
    this.onDocumentChanged,
    this.scrollController,
    required this.journal,
    required this.onTitleChanged,
    this.focusNode,
    this.readOnly = true, // Default to read-only in reorder mode
  });

  final EditorState editorState;
  final List<int>? selectedBlockPath;
  final void Function(List<int> path) onBlockSelected;
  final Map<String, Widget Function(Node, int depth)>? customBlockRenderers;
  final void Function(List<int>?)? onDocumentChanged;
  final ScrollController? scrollController;
  final Journal journal;
  final ValueChanged<String> onTitleChanged;
  final FocusNode? focusNode;
  final bool readOnly;

  @override
  State<ReorderableEditor> createState() => ReorderableEditorState();
}

class ReorderableEditorState extends State<ReorderableEditor> {
  late final ScrollController _scrollController;
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  bool _isDragging = false;
  bool _showCollapsedTitle = false;
  double _lastScrollPosition = 0;

  @override
  void initState() {
    super.initState();
    _scrollController = widget.scrollController ?? ScrollController();
    _titleController = TextEditingController(text: widget.journal.title);
    _titleFocusNode = FocusNode();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _titleController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;

    final currentPosition = _scrollController.position.pixels;
    final isScrollingDown = currentPosition > _lastScrollPosition;
    _lastScrollPosition = currentPosition;

    if (isScrollingDown && !_showCollapsedTitle) {
      setState(() {
        _showCollapsedTitle = true;
      });
    } else if (!isScrollingDown && _showCollapsedTitle) {
      setState(() {
        _showCollapsedTitle = false;
      });
    }
  }

  void _onTitleChanged(String value) {
    widget.onTitleChanged(value);
  }

  void moveBlock(int currentIndex, int offset) {
    final children = widget.editorState.document.root.children;
    final newIndex = currentIndex + offset;

    if (newIndex >= 0 && newIndex < children.length) {
      final transaction = widget.editorState.transaction;
      final node = children[currentIndex];
      transaction.deleteNode(node);
      transaction.insertNode([newIndex], node);
      widget.editorState.apply(transaction);
      widget.onDocumentChanged?.call([newIndex]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    return Stack(
      children: [
        // Main editor
        AppFlowyEditor(
          editorState: widget.editorState,
          editorStyle: EditorStyle.mobile(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
            cursorColor: theme.cursor,
            selectionColor: theme.selectionBorder.withOpacity(0.1),
            textStyleConfiguration: TextStyleConfiguration(
              text: TextStyle(
                fontSize: 16,
                color: theme.primaryText,
                height: 1.5,
              ),
              bold: const TextStyle(fontWeight: FontWeight.bold),
              italic: const TextStyle(fontStyle: FontStyle.italic),
              underline: const TextStyle(decoration: TextDecoration.underline),
              strikethrough:
                  const TextStyle(decoration: TextDecoration.lineThrough),
              href: TextStyle(
                color: theme.link,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
          blockComponentBuilders: {
            ...standardBlockComponentBuilderMap,
            if (widget.customBlockRenderers != null)
              ...widget.customBlockRenderers!.map(
                (key, value) => MapEntry(
                  key,
                  CustomBlockComponentBuilder(
                    builder: value,
                  ),
                ),
              ),
            'metadata_block': MetadataBlockBuilder(
              titleController: _titleController,
              createdAt: widget.journal.createdAt,
              onTitleChanged: _onTitleChanged,
            ),
          },
          header: _showCollapsedTitle
              ? Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: theme.primaryBackground,
                    border: Border(
                      bottom: BorderSide(
                        color: theme.dividerColor,
                        width: 1,
                      ),
                    ),
                  ),
                  child: Text(
                    _titleController.text,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: theme.primaryText,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : null,
          footer: const SizedBox(height: 100),
          focusNode: widget.focusNode,
        ),
      ],
    );
  }
}
