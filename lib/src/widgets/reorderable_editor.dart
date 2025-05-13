// lib/src/widgets/reorderable_editor.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';
import 'package:provider/provider.dart';
import 'dart:ui' show lerpDouble;

class ReorderableEditor extends StatefulWidget {
  const ReorderableEditor({
    super.key,
    required this.editorState,
    required this.selectedBlockPath,
    required this.onBlockSelected,
    this.customBlockRenderers,
  });

  final EditorState editorState;
  final List<int>? selectedBlockPath;
  final void Function(List<int> path) onBlockSelected;
  final Map<String, Widget Function(Node, int depth)>? customBlockRenderers;

  @override
  State<ReorderableEditor> createState() => _ReorderableEditorState();
}

class _ReorderableEditorState extends State<ReorderableEditor> {
  late List<_BlockEntry> _flattenedBlocks; // Top-level blocks only

  @override
  void initState() {
    super.initState();
    _flattenedBlocks = _flattenNodes(widget.editorState.document.root.children);
  }

  @override
  void didUpdateWidget(covariant ReorderableEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editorState != oldWidget.editorState) {
      _flattenedBlocks =
          _flattenNodes(widget.editorState.document.root.children);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  List<_BlockEntry> _flattenNodes(List<Node?> nodes) {
    if (nodes.isEmpty) {
      return [];
    }
    final result = <_BlockEntry>[];
    for (var i = 0; i < nodes.length; i++) {
      final node = nodes[i];
      if (node == null) {
        continue;
      }
      final path = [i]; // Top-level path only
      result.add(_BlockEntry(node: node, path: path, depth: 0));
      // Children are rendered by parent's builder, not flattened
    }
    return result;
  }

  void _onReorderCustom(
      int oldIndex, int newIndex, List<_BlockEntry> currentValidBlocks) {
    if (oldIndex < 0 ||
        oldIndex >= currentValidBlocks.length ||
        newIndex < 0 ||
        newIndex > currentValidBlocks.length) {
      return;
    }

    final _BlockEntry movedEntry = currentValidBlocks[oldIndex];
    final Node nodeToMove = movedEntry.node;
    final List<int> originalPath = movedEntry.path;

    if (originalPath[0] != oldIndex) {
      return;
    }

    final Transaction transaction = widget.editorState.transaction;

    final Node? nodeToDelete = widget.editorState.getNodeAtPath(originalPath);
    if (nodeToDelete == null || nodeToDelete.id != nodeToMove.id) {
      return;
    }
    transaction.deleteNode(nodeToDelete);

    // Adjust effectiveTargetIndex for document state after deletion
    final int effectiveTargetIndex = newIndex;
    List<int> finalInsertionPath;

    // Get current children length after deletion
    final currentChildrenLength =
        widget.editorState.document.root.children.length;
    if (effectiveTargetIndex > currentChildrenLength) {
      finalInsertionPath = [currentChildrenLength];
    } else {
      finalInsertionPath = [effectiveTargetIndex];
    }

    transaction.insertNode(finalInsertionPath, nodeToMove);

    try {
      widget.editorState.apply(transaction);
      setState(() {
        _flattenedBlocks =
            _flattenNodes(widget.editorState.document.root.children);
      });
    } catch (e, s) {
      Log.error(
          '[ReorderableEditor._onReorderCustom] Failed to apply transaction: $e\n$s');
      return;
    }

    // Set focus to the moved block's final position
    final finalIndex = newIndex > oldIndex ? newIndex - 1 : newIndex;
    final adjustedInsertionPath = [finalIndex];
    widget.onBlockSelected(adjustedInsertionPath);
  }

  Widget _buildBlock(_BlockEntry entry) {
    final isSelected = entry.path.join() == widget.selectedBlockPath?.join();
    final indent = entry.depth * 16.0;

    // Base style for fallback rendering
    const baseStyle = TextStyle(
      fontSize: 16,
      height: 1.5,
      color: Colors.black,
    );

    Widget child;

    if (widget.customBlockRenderers?.containsKey(entry.node.type) ?? false) {
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
          child = Container(
            padding: const EdgeInsets.all(8.0),
            color: Colors.red.withValues(alpha: 0.1),
            child: RichText(
              text: TextSpan(
                children: textSpans,
                style: baseStyle,
              ),
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

    return GestureDetector(
      key: ValueKey(
          'reorderable_block_${entry.path.join("_")}_${entry.node.id}'),
      onTap: () {
        if (entry.path.join() != widget.selectedBlockPath?.join()) {
          widget.onBlockSelected(entry.path);
        }
      },
      child: IntrinsicHeight(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 2.0),
          padding: EdgeInsets.fromLTRB(indent + 6, 4, 6, 4),
          decoration: BoxDecoration(
            color: isSelected
                ? Theme.of(context).primaryColorLight.withValues(alpha: 0.3)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? Theme.of(context).primaryColor
                  : Colors.transparent,
              width: isSelected ? 1.5 : 0,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _proxyDecorator(Widget child, int index, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (BuildContext context, Widget? child) {
        final double animValue = Curves.easeInOut.transform(animation.value);
        final double scale = lerpDouble(1, 1.02, animValue)!;
        return Material(
          color: Colors.transparent,
          shadowColor: Colors.black.withValues(alpha: 0.3),
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
    if (_flattenedBlocks.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'No blocks to reorder.',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
        ),
      );
    }

    final validFlattenedBlocks = _flattenedBlocks;
    return ReorderableListView.builder(
      key: const PageStorageKey('reorderable_editor_list_view'),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      itemCount: validFlattenedBlocks.length,
      onReorder: (oldIndex, newIndex) {
        _onReorderCustom(oldIndex, newIndex, validFlattenedBlocks);
      },
      proxyDecorator: _proxyDecorator,
      itemBuilder: (context, index) {
        if (index >= validFlattenedBlocks.length) {
          Log.error(
              '[ReorderableEditor.build] Index $index out of bounds for validFlattenedBlocks length ${validFlattenedBlocks.length}');
          return Container(
            key: ValueKey('block_$index'),
            child: const Text(
              '[Error: Index out of bounds]',
              style: TextStyle(fontSize: 14, color: Colors.red),
            ),
          );
        }
        return _buildBlock(validFlattenedBlocks[index]);
      },
    );
  }
}

class _BlockEntry {
  _BlockEntry({
    required this.node,
    required this.path,
    required this.depth,
  });

  final Node node;
  final List<int> path;
  final int depth;
}
