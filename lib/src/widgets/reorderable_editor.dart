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
  late List<_BlockEntry> _flattenedBlocks;
  late EditorState _editorState;
  late ScrollController _controller;
  late TextEditingController _titleController;
  bool _showCollapsedTitle = false;
  double _lastScrollPosition = 0;

  @override
  void initState() {
    super.initState();
    _flattenedBlocks = _flattenNodes(widget.editorState.document.root.children);
    _editorState = widget.editorState;
    _controller = widget.scrollController ?? ScrollController();
    _titleController = TextEditingController(text: widget.journal.title);
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _titleController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;

    final currentPosition = _controller.position.pixels;
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

  @override
  void didUpdateWidget(covariant ReorderableEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    _flattenedBlocks = _flattenNodes(widget.editorState.document.root.children);
    Log.info('🔁 ReorderableEditor: Rebuilt _flattenedBlocks on widget update');
  }

  List<_BlockEntry> _flattenNodes(List<Node?> nodes) {
    if (nodes.isEmpty) {
      return [];
    }
    final result = <_BlockEntry>[];
    int visualIndex = 0;
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node == null ||
          node.type == 'spacer_block' ||
          node.type == 'metadata_block') {
        continue; // Skip spacer_block and metadata_block
      }
      final path = [visualIndex]; // Visual index for reordering
      result
          .add(_BlockEntry(node: node, path: path, depth: 0, documentIndex: i));
      visualIndex++;
    }
    return result;
  }

  void _onReorderCustom(
      int oldIndex, int newIndex, List<_BlockEntry> currentValidBlocks,
      {bool isDrag = false}) {
    if (oldIndex < 0 ||
        oldIndex >= currentValidBlocks.length ||
        newIndex < 0 ||
        newIndex >= currentValidBlocks.length) {
      Log.error(
          'Invalid reorder indices: oldIndex=$oldIndex, newIndex=$newIndex');
      return;
    }

    final _BlockEntry movedEntry = currentValidBlocks[oldIndex];
    final Node nodeToMove = movedEntry.node;

    // Find the current document index of the node to move
    int? documentOldIndex;
    for (int i = 0; i < widget.editorState.document.root.children.length; i++) {
      final node = widget.editorState.document.root.children[i];
      if (node?.id == nodeToMove.id) {
        documentOldIndex = i;
        break;
      }
    }

    if (documentOldIndex == null) {
      Log.error('Node to move not found in document, id: ${nodeToMove.id}');
      return;
    }

    // For drag-down, adjust newIndex; for arrows, use newIndex directly
    final targetVisualIndex =
        isDrag && newIndex > oldIndex ? newIndex - 1 : newIndex;
    final newVisualPath = [targetVisualIndex];

    Log.info('🔍 _onReorderCustom: oldIndex=$oldIndex, newIndex=$newIndex, '
        'targetVisualIndex=$targetVisualIndex');

    // Calculate document insertion index
    int documentNewIndex = 1; // Start after metadata block
    int currentVisualIndex = 0;
    final documentChildren = widget.editorState.document.root.children;
    for (var i = 0;
        i < documentChildren.length && currentVisualIndex <= targetVisualIndex;
        i++) {
      final node = documentChildren[i];
      if (node == null ||
          node.type == 'spacer_block' ||
          node.type == 'metadata_block' ||
          node.id == nodeToMove.id) {
        continue; // Skip metadata, spacer, or the node being moved
      }
      if (currentVisualIndex == targetVisualIndex) {
        documentNewIndex = i; // Insert at this document index
        break;
      }
      currentVisualIndex++;
      documentNewIndex++;
    }

    // If targetVisualIndex is at the end, append after the last valid block
    if (currentVisualIndex < targetVisualIndex) {
      documentNewIndex = documentChildren.length;
      for (var i = documentChildren.length - 1; i >= 0; i--) {
        final node = documentChildren[i];
        if (node != null &&
            node.type != 'spacer_block' &&
            node.type != 'metadata_block' &&
            node.id != nodeToMove.id) {
          documentNewIndex = i + 1;
          break;
        }
      }
    }

    // Ensure documentNewIndex is valid
    final currentChildrenLength = documentChildren.length;
    final finalInsertionPath = [
      documentNewIndex.clamp(1, currentChildrenLength)
    ];

    Log.info('🔍 _onReorderCustom: documentOldIndex=$documentOldIndex, '
        'documentNewIndex=$documentNewIndex, finalInsertionPath=$finalInsertionPath');

    // Perform the transaction
    final Transaction transaction = widget.editorState.transaction;

    // Delete the node at its current document index
    final Node? nodeToDelete =
        widget.editorState.getNodeAtPath([documentOldIndex]);
    if (nodeToDelete == null || nodeToDelete.id != nodeToMove.id) {
      Log.error(
          'Node to delete not found at path [$documentOldIndex], id: ${nodeToMove.id}');
      return;
    }
    transaction.deleteNode(nodeToDelete);

    // Insert the node at the new document index
    transaction.insertNode(finalInsertionPath, nodeToMove);

    try {
      widget.editorState.apply(transaction);
      // Set selection to the new block immediately after transaction
      widget.editorState.selection = Selection.collapsed(
          Position(path: [targetVisualIndex + 1], offset: 0));
      setState(() {
        _flattenedBlocks =
            _flattenNodes(widget.editorState.document.root.children);
      });
      // Notify document change with the new visual path
      widget.onDocumentChanged?.call(newVisualPath);
      widget.focusNode?.requestFocus();
      Log.info(
          '🔍 Reordered block to visual path: $newVisualPath, document path: [${targetVisualIndex + 1}], focus requested');
    } catch (e, s) {
      Log.error(
          '[ReorderableEditor._onReorderCustom] Failed to apply transaction: $e\n$s');
      return;
    }
  }

  Widget _buildBlock(_BlockEntry entry) {
    final isSelected = entry.path.join() == widget.selectedBlockPath?.join();
    final indent = entry.depth * 16.0;
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);

    // Base style for fallback rendering
    final baseStyle = TextStyle(
      fontSize: 16,
      height: 1.5,
      color: theme.primaryText,
    );

    Widget child;

    // Handle spacer_block explicitly (fallback, should not occur due to filtering)
    if (entry.node.type == 'spacer_block') {
      final height =
          (entry.node.attributes['height'] as num?)?.toDouble() ?? 100.0;
      child = Container(
        height: height,
        margin: const EdgeInsets.symmetric(vertical: 2.0),
        padding: EdgeInsets.zero,
      );
    } else if (entry.node.type == divider.DividerBlockKeys.type) {
      child = divider.DividerBlockComponentWidget(
        node: entry.node,
        configuration: const BlockComponentConfiguration(),
      );
    } else if (widget.customBlockRenderers?.containsKey(entry.node.type) ??
        false) {
      child = widget.customBlockRenderers![entry.node.type]!(
          entry.node, entry.depth);
    } else {
      final builder = standardBlockComponentBuilderMap[entry.node.type];
      if (builder != null) {
        try {
          child = Provider<EditorState>.value(
            value: widget.editorState,
            child: builder.build(BlockComponentContext(context, entry.node)),
          );
        } catch (e, s) {
          Log.error(
              '[ReorderableEditor._buildBlock] Error building block type ${entry.node.type} at path ${entry.path}: $e\n$s');
          // Fallback to RichText for text-based blocks
          final delta = entry.node.delta ?? Delta();
          final textSpans = <TextSpan>[];
          for (final op in delta.toJson()) {
            final text = op['insert'] as String? ?? '';
            final attributes = op['attributes'] as Map<String, dynamic>? ?? {};
            TextStyle style = baseStyle;
            if (attributes['bold'] == true) {
              style = style.copyWith(fontWeight: FontWeight.bold);
            }
            if (attributes['italic'] == true) {
              style = style.copyWith(fontStyle: FontStyle.italic);
            }
            if (attributes['underline'] == true) {
              style = style.copyWith(decoration: TextDecoration.underline);
            }
            if (attributes['strikethrough'] == true) {
              style = style.copyWith(decoration: TextDecoration.lineThrough);
            }
            textSpans.add(TextSpan(text: text, style: style));
          }
          child = RichText(
            text: TextSpan(
              children: textSpans,
              style: baseStyle,
            ),
          );
        }
      } else {
        final text = entry.node.attributes['text'] as String? ??
            entry.node.attributes['content'] as String? ??
            '[${entry.node.type}]';
        TextStyle style = baseStyle;
        if (entry.node.type == 'scripture_block') {
          style = style.copyWith(fontStyle: FontStyle.italic);
        } else if (entry.node.type == 'title_block') {
          style = style.copyWith(fontSize: 18, fontWeight: FontWeight.bold);
        }
        child = Text(
          text,
          style: style,
        );
      }
    }

    // Skip GestureDetector for spacer_block to make it non-selectable
    if (entry.node.type == 'spacer_block') {
      return IntrinsicHeight(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          padding: EdgeInsets.fromLTRB(indent + 6, 8, 6, 4),
          child: child,
        ),
      );
    }

    // Wrap the block content in IgnorePointer to prevent editing in reorder mode
    final blockContent = IgnorePointer(
      child: Theme(
        data: Theme.of(context).copyWith(
          textTheme: Theme.of(context).textTheme.apply(
                bodyColor: theme.primaryText,
                displayColor: theme.primaryText,
              ),
        ),
        child: child,
      ),
    );

    return GestureDetector(
      key: ValueKey(
          'reorderable_block_${entry.path.join("_")}_${entry.node.id}'),
      onTap: () {
        if (entry.path.join() != widget.selectedBlockPath?.join()) {
          _onBlockSelected(entry.path);
        }
      },
      child: Container(
        padding: EdgeInsets.fromLTRB(indent + 14, 8, 16, 8),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.selectionBorder.withAlpha((0.05 * 255).round())
              : Colors.transparent,
          border: Border.all(
            color: isSelected ? theme.selectionBorder : Colors.transparent,
            width: isSelected ? 1 : 0,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(
            textSelectionTheme: TextSelectionThemeData(
              cursorColor: Colors.transparent,
              selectionColor: Colors.transparent,
              selectionHandleColor: Colors.transparent,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [blockContent],
          ),
        ),
      ),
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double scale = lerpDouble(1, 1, animValue)!;
        return Material(
          color: Colors.transparent,
          shadowColor: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(6),
          child: Transform.scale(
            scale: scale,
            child: Opacity(
              opacity: lerpDouble(1, 0.95, animValue)!,
              child: child,
            ),
          ),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final children = widget.editorState.document.root.children;
    final metadataBlock =
        children.isNotEmpty && children.first.type == 'metadata_block'
            ? children.first
            : null;
    final blocksToReorder =
        metadataBlock != null ? children.sublist(1) : children;

    return _buildScrollableList(metadataBlock, blocksToReorder);
  }

  Widget _buildScrollableList(Node? metadataBlock, List<Node?> nodes) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    return SingleChildScrollView(
      controller: _controller,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Render metadata block at the top, non-reorderable
          if (metadataBlock != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 20, 4, 0),
              child: MetadataBlockWidget(
                node: metadataBlock,
                titleController: _titleController,
                createdAt: widget.journal.createdAt,
                onTitleChanged: widget.onTitleChanged,
                readOnly: widget.readOnly,
              ),
            ),
          // Render reorderable blocks
          if (nodes.isNotEmpty)
            _buildReorderableList(nodes)
          else
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No blocks to reorder.',
                style: TextStyle(fontSize: 16, color: theme.secondaryText),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReorderableList(List<Node?> nodes) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final validFlattenedBlocks = _flattenNodes(nodes);
    if (validFlattenedBlocks.isEmpty) {
      return const SizedBox.shrink();
    }
    return ReorderableListView.builder(
      key: const PageStorageKey('reorderable_editor_list_view'),
      padding: const EdgeInsets.fromLTRB(4, 8, 4, 112),
      itemCount: validFlattenedBlocks.length,
      onReorder: (oldIndex, newIndex) {
        _onReorderCustom(oldIndex, newIndex, validFlattenedBlocks,
            isDrag: true);
      },
      proxyDecorator: _proxyDecorator,
      itemBuilder: (context, index) {
        if (index >= validFlattenedBlocks.length) {
          Log.error(
              '[ReorderableEditor.build] Index $index out of bounds for validFlattenedBlocks length ${validFlattenedBlocks.length}');
          return Container(
            key: ValueKey('block_$index'),
            child: Text(
              '[Error: Index out of bounds]',
              style: TextStyle(fontSize: 14, color: theme.error),
            ),
          );
        }
        return _buildBlock(validFlattenedBlocks[index]);
      },
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
    );
  }

  void moveBlock(int currentIndex, int direction) {
    final children = widget.editorState.document.root.children;
    final metadataBlock =
        children.isNotEmpty && children.first.type == 'metadata_block'
            ? children.first
            : null;
    final blocksToReorder =
        metadataBlock != null ? children.sublist(1) : children;
    final validBlocks = _flattenNodes(blocksToReorder);
    if (validBlocks.isEmpty) {
      Log.info('🔍 No blocks to reorder');
      return;
    }

    int newIndex;
    if (direction == -1) {
      // Move up, prevent moving before first block
      newIndex = currentIndex == 0 ? 0 : currentIndex - 1;
    } else {
      // Move down, allow moving to the end
      newIndex = currentIndex + 1;
    }

    if (currentIndex == newIndex || newIndex >= validBlocks.length) {
      Log.info(
          '🔍 Move blocked: Already at boundary (index: $currentIndex, newIndex: $newIndex)');
      return;
    }

    Log.info('🔍 Moving block from visual index $currentIndex to $newIndex');
    _onReorderCustom(currentIndex, newIndex, validBlocks, isDrag: false);
  }

  void _onBlockSelected(List<int> path) {
    if (mounted && path.join() != widget.selectedBlockPath?.join()) {
      // Update the editor selection to match the tapped block
      final documentPath = [path[0] + 1]; // Adjust for metadata block
      widget.editorState.selection = Selection.collapsed(
        Position(path: documentPath, offset: 0),
      );
      // Notify parent of selection change
      widget.onBlockSelected(path);
      // Request focus to ensure cursor is visible
      widget.focusNode?.requestFocus();
    }
  }
}

class _BlockEntry {
  _BlockEntry({
    required this.node,
    required this.path,
    required this.depth,
    required this.documentIndex,
  });

  final Node node;
  final List<int> path;
  final int depth;
  final int documentIndex;
}
