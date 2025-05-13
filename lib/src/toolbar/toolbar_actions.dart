// lib/src/toolbar/toolbar_actions.dart

import 'package:flutter/material.dart'; // For FocusNode
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';

/// Manages toolbar actions for the journal editor, including block reordering,
/// formatting, and insertion.
/// - Simplified handleMoveUp and handleMoveDown to reliably move top-level blocks.
/// - Ensures selection follows the moved block, fixing cursor movement issues.
/// - Adds bounds checking to prevent invalid moves (e.g., moving first block up).
/// - Includes debug logs with 🔍 prefix for reordering and other actions.
/// - Compatible with AppFlowy 4.0.0 and single-editor drag-and-drop approach.
class ToolbarActions {
  final EditorState editorState;
  final ToolbarState toolbarState;
  final FocusNode? focusNode; // For focus restoration
  Selection? _lastEditorSelection;

  ToolbarActions({
    required this.editorState,
    required this.toolbarState,
    this.focusNode,
  });

  String? getPreviousSiblingType(Selection? selection) {
    if (selection == null || selection.start.path.isEmpty) return null;
    final parentPath = selection.start.path.length > 1
        ? selection.start.path.sublist(0, selection.start.path.length - 1)
        : null;
    final index = selection.start.path.last;
    if (index > 0) {
      final siblingPath = [...?parentPath, index - 1];
      final siblingNode = editorState.getNodeAtPath(siblingPath);
      return siblingNode?.type;
    }
    return null;
  }

  bool isStyleActive(String style) {
    final selection = editorState.selection;
    if (selection == null) return false;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return false;
    final attributes = node.attributes;
    final delta = attributes['delta'] as List? ?? [];
    if (delta.isEmpty) return false;

    if (selection.isCollapsed) {
      var currentOffset = 0;
      final cursorOffset = selection.start.offset;
      for (final op in delta) {
        final opText = op['insert'] as String;
        final opLength = opText.length;
        final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
        if (currentOffset <= cursorOffset &&
            cursorOffset <= currentOffset + opLength) {
          return opAttributes[style] == true;
        }
        currentOffset += opLength;
      }
      return false;
    } else {
      final startOffset = selection.start.offset;
      final endOffset = selection.end.offset;
      var currentOffset = 0;
      for (final op in delta) {
        final opText = op['insert'] as String;
        final opLength = opText.length;
        final opAttributes = op['attributes'] as Map<String, dynamic>?;
        if (currentOffset + opLength > startOffset &&
            currentOffset < endOffset) {
          if (opAttributes?[style] == true) return true;
        }
        currentOffset += opLength;
      }
      return false;
    }
  }

  void _changeBlockType(Node node, BlockType type, {int? headingLevel}) {
    final transaction = editorState.transaction;
    final oldPath = node.path;
    final parentPath = oldPath.sublist(0, oldPath.length - 1);
    final originalIndex = oldPath.last;

    final newAttributes = <String, dynamic>{
      'delta': node.delta?.toJson() ??
          [
            {'insert': ''}
          ],
    };

    if (type == BlockType.heading) {
      newAttributes[HeadingBlockKeys.level] = headingLevel ?? 2;
    }

    if (type == BlockType.todoList) {
      newAttributes[TodoListBlockKeys.checked] = false;
    }

    final newNode = Node(
      type: type.name,
      attributes: newAttributes,
      children: [],
    );

    final newPath = Path.from([...parentPath, originalIndex]);

    // Step 1: Insert new node at the same position
    transaction.insertNode(newPath, newNode);
    // Step 2: Delete the original node
    transaction.deleteNode(node);
    // Step 3: Apply changes
    editorState.apply(transaction, withUpdateSelection: false);
    // Step 4: Set selection to the new node
    editorState.selection =
        Selection.collapsed(Position(path: newPath, offset: 0));
    // Step 5: Notify UI
    toolbarState.setBlockType(type.name, headingLevel: headingLevel);

    Log.info(
        '🔁 Replaced node at path $oldPath with type "${type.name}" at path $newPath');
  }

  void handleCycleHeading() {
    final selection = editorState.selection;
    if (selection == null) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final currentType = node.type;
    final currentLevel = node.attributes[HeadingBlockKeys.level] as int? ?? 2;

    // Step 1: If not paragraph or heading, convert to paragraph
    if (currentType != 'paragraph' && currentType != 'heading') {
      Log.info(
          '🔁 Normalize block at ${node.path} to paragraph before heading cycle');
      _changeBlockType(node, BlockType.paragraph);
    }
    // Step 2: If currently paragraph, change to heading level 2
    else if (currentType == 'paragraph') {
      Log.info('🔁 Converting paragraph at ${node.path} → heading level 2');
      _changeBlockType(node, BlockType.heading, headingLevel: 2);
    }
    // Step 3: If heading, cycle to next level or back to paragraph
    else if (currentLevel == 2) {
      Log.info('🔁 Cycling heading at ${node.path} → heading level 3');
      _changeBlockType(node, BlockType.heading, headingLevel: 3);
    } else {
      Log.info('🔁 Cycling heading at ${node.path} → paragraph');
      _changeBlockType(node, BlockType.paragraph);
    }

    editorState.selection = Selection.single(
      path: savedSelection.start.path,
      startOffset: savedSelection.start.offset,
      endOffset: savedSelection.end.offset,
    );

    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleCycleList() {
    final selection = editorState.selection;
    if (selection == null) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final currentType = node.type;
    late BlockType newType;

    switch (currentType) {
      case 'bulleted_list':
        newType = BlockType.numberedList;
        break;
      case 'numbered_list':
        newType = BlockType.todoList;
        break;
      case 'todo_list':
        newType = BlockType.paragraph;
        break;
      default:
        newType = BlockType.bulletedList;
    }

    _changeBlockType(node, newType);

    editorState.selection = Selection.single(
      path: savedSelection.start.path,
      startOffset: savedSelection.start.offset,
      endOffset: savedSelection.end.offset,
    );
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleInsertQuote() {
    final selection = editorState.selection;
    if (selection == null) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    if (node.type == 'quote') {
      Log.info('📝 Quote block tapped again — reverting to paragraph');
      _changeBlockType(node, BlockType.paragraph);
    } else {
      Log.info('📝 Converting block at ${node.path} to quote');
      _changeBlockType(node, BlockType.quote);
    }

    editorState.selection = Selection.single(
      path: selection.start.path,
      startOffset: selection.start.offset,
      endOffset: selection.end.offset,
    );

    if (focusNode?.hasFocus == true) {
      focusNode!.requestFocus();
    }
  }

  void handleInsertDivider() {
    final selection = editorState.selection;
    if (selection == null) return;
    final index = selection.start.path.first;

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final transaction = editorState.transaction;
    transaction.insertNode(Path.from([index + 1]), Node(type: 'divider'));
    editorState.apply(transaction);
    toolbarState.showInsertMenu = false;

    editorState.selection = savedSelection;
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleInsertBelow() {
    final selection = editorState.selection;
    if (selection == null) return;
    final index = selection.start.path.first;

    final hadFocus = focusNode?.hasFocus ?? false;

    final transaction = editorState.transaction;
    transaction.insertNode(
      Path.from([index + 1]),
      Node(
        type: 'paragraph',
        attributes: {
          'delta': [
            {'insert': ''}
          ]
        },
      ),
    );
    editorState.apply(transaction);
    editorState.selection = Selection.single(
      path: [index + 1],
      startOffset: 0,
    );

    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleInsertAbove() {
    final selection = editorState.selection;
    if (selection == null) return;

    final index = selection.start.path.first;

    final hadFocus = focusNode?.hasFocus ?? false;

    final transaction = editorState.transaction;
    transaction.insertNode(
      Path.from([index]),
      Node(
        type: 'paragraph',
        attributes: {
          'delta': [
            {'insert': ''}
          ]
        },
      ),
    );

    editorState.apply(transaction);

    editorState.selection = Selection.single(
      path: [index],
      startOffset: 0,
    );

    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleToggleStyle(String style) {
    final selection = editorState.selection;
    if (selection == null || selection.isCollapsed) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final attributes = Map<String, dynamic>.from(node.attributes);
    final delta = attributes['delta'] as List? ?? [];
    if (delta.isEmpty) return;

    final startOffset = selection.start.offset;
    final endOffset = selection.end.offset;
    var currentOffset = 0;
    final wasStyleActive = isStyleActive(style);
    final newDelta = <Map<String, dynamic>>[];

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = Map<String, dynamic>.from(op['attributes'] ?? {});
      if (currentOffset + opLength <= startOffset ||
          currentOffset >= endOffset) {
        newDelta.add({'insert': opText, 'attributes': opAttributes});
      } else {
        final selectionStart = startOffset - currentOffset;
        final selectionEnd = endOffset - currentOffset;
        if (selectionStart > 0) {
          newDelta.add({
            'insert': opText.substring(0, selectionStart),
            'attributes': opAttributes,
          });
        }
        final selectedText = opText.substring(
          selectionStart.clamp(0, opLength),
          selectionEnd.clamp(0, opLength),
        );
        final selectedAttributes = Map<String, dynamic>.from(opAttributes);
        if (wasStyleActive) {
          selectedAttributes.remove(style);
        } else {
          selectedAttributes[style] = true;
        }
        newDelta.add({
          'insert': selectedText,
          'attributes': selectedAttributes,
        });
        if (selectionEnd < opLength) {
          newDelta.add({
            'insert': opText.substring(selectionEnd),
            'attributes': opAttributes,
          });
        }
      }
      currentOffset += opLength;
    }

    attributes['delta'] = newDelta;
    final transaction = editorState.transaction;
    transaction.updateNode(node, attributes);
    editorState.apply(transaction);

    editorState.selection = savedSelection;
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleCycleAlignment() {
    final selection = editorState.selection;
    if (selection == null) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final attributes = Map<String, dynamic>.from(node.attributes);
    final currentAlign = attributes['align'] as String? ?? 'left';
    String nextAlign;
    switch (currentAlign) {
      case 'left':
        nextAlign = 'center';
        break;
      case 'center':
        nextAlign = 'right';
        break;
      case 'right':
        nextAlign = 'left';
        break;
      default:
        nextAlign = 'left';
    }
    attributes['align'] = nextAlign;
    final transaction = editorState.transaction;
    transaction.updateNode(node, attributes);
    editorState.apply(transaction);

    editorState.selection = savedSelection;
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleIndent() {
    final selection = editorState.selection;
    if (selection == null) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;
    if (!['paragraph', 'heading', 'todo_list', 'bulleted_list', 'numbered_list']
        .contains(node.type)) {
      return;
    }
    final currentPath = selection.start.path;
    final currentIndex = currentPath.last;
    final parentPath = currentPath.length > 1
        ? currentPath.sublist(0, currentPath.length - 1)
        : <int>[];

    if (currentPath.length >= 3) {
      Log.info(
          '🔍 Indent blocked: Maximum indent level 2 reached at path $currentPath');
      return;
    }

    List<int>? previousPath;
    Node? previousNode;
    if (currentIndex > 0) {
      previousPath = [...parentPath, currentIndex - 1];
      previousNode = editorState.getNodeAtPath(previousPath);
    }
    if (previousNode == null && currentPath.length > 1) {
      previousPath = parentPath;
      previousNode = editorState.getNodeAtPath(parentPath);
    }
    if (previousNode == null) {
      Log.info(
          '🔍 Indent blocked: No previous sibling or parent at path $currentPath');
      return;
    }

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final transaction = editorState.transaction;
    transaction.deleteNode(node);
    final newPath = [...previousPath!, previousNode.children.length];
    transaction.insertNode(Path.from(newPath), node);
    editorState.apply(transaction);
    editorState.selection = Selection.single(
      path: newPath,
      startOffset: savedSelection.start.offset,
    );

    Log.info(
        '🔍 Indented node from path $currentPath to $newPath, transaction applied');
    Log.info(
        '🔍 Document state after indent: ${editorState.document.toJson()}');

    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleOutdent() {
    final selection = editorState.selection;
    if (selection == null || selection.start.path.length <= 1) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;
    if (!['paragraph', 'heading', 'todo_list', 'bulleted_list', 'numbered_list']
        .contains(node.type)) {
      return;
    }

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final currentPath = selection.start.path;
    final parentPath = currentPath.sublist(0, currentPath.length - 1);
    final newIndex = parentPath.last + 1;
    final newPath = [...parentPath.sublist(0, parentPath.length - 1), newIndex];

    final transaction = editorState.transaction;
    transaction.deleteNode(node);
    transaction.insertNode(Path.from(newPath), node);
    editorState.apply(transaction);
    editorState.selection = Selection.single(
      path: newPath,
      startOffset: savedSelection.start.offset,
    );

    Log.info('🔍 Outdented node from path $currentPath to $newPath');

    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleMoveUp() {
    final selection = editorState.selection;
    if (selection == null) {
      Log.info('🔍 Move up blocked: No selection');
      return;
    }
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      Log.info('🔍 Move up blocked: No node at path ${selection.start.path}');
      return;
    }
    final currentPath = selection.start.path;
    if (currentPath.length != 1) {
      Log.info(
          '🔍 Move up blocked: Only top-level blocks supported, path=$currentPath');
      return;
    }
    final currentIndex = currentPath.last;
    if (currentIndex == 0) {
      Log.info(
          '🔍 Move up blocked: Node at index $currentIndex is already at the top');
      return;
    }

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final newIndex = currentIndex - 1;
    final newPath = [newIndex];

    final transaction = editorState.transaction;
    // Delete the current node
    transaction.deleteNode(node);
    // Insert it at the new position
    transaction.insertNode(newPath, node);
    // Apply the transaction
    editorState.apply(transaction);
    // Update selection to the new path
    editorState.selection = Selection.single(
      path: newPath,
      startOffset: savedSelection.start.offset,
    );

    Log.info(
        '🔍 Moved node up from index $currentIndex to $newIndex, path=$newPath');
    Log.info(
        '🔍 Document state after move up: ${editorState.document.toJson()}');

    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }

    // Notify toolbar to update block type and selection
    toolbarState.setSelectionInfo(
      isVisible: true,
      showTextStyles: !savedSelection.isCollapsed,
      isDragMode: toolbarState.isDragMode,
      selectionPath: newPath,
      previousSiblingType: getPreviousSiblingType(selection),
    );
  }

  void handleMoveDown() {
    final selection = editorState.selection;
    if (selection == null) {
      Log.info('🔍 Move down blocked: No selection');
      return;
    }
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      Log.info('🔍 Move down blocked: No node at path ${selection.start.path}');
      return;
    }
    final currentPath = selection.start.path;
    if (currentPath.length != 1) {
      Log.info(
          '🔍 Move down blocked: Only top-level blocks supported, path=$currentPath');
      return;
    }
    final currentIndex = currentPath.last;
    final totalBlocks = editorState.document.root.children.length;
    if (currentIndex >= totalBlocks - 1) {
      Log.info(
          '🔍 Move down blocked: Node at index $currentIndex is already at the bottom');
      return;
    }

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final newIndex = currentIndex + 1;
    final newPath = [newIndex];

    final transaction = editorState.transaction;
    // Delete the current node
    transaction.deleteNode(node);
    // Insert it at the new position
    transaction.insertNode(newPath, node);
    // Apply the transaction
    editorState.apply(transaction);
    // Update selection to the new path
    editorState.selection = Selection.single(
      path: newPath,
      startOffset: savedSelection.start.offset,
    );

    Log.info(
        '🔍 Moved node down from index $currentIndex to $newIndex, path=$newPath');
    Log.info(
        '🔍 Document state after move down: ${editorState.document.toJson()}');

    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }

    // Notify toolbar to update block type and selection
    toolbarState.setSelectionInfo(
      isVisible: true,
      showTextStyles: !savedSelection.isCollapsed,
      isDragMode: toolbarState.isDragMode,
      selectionPath: newPath,
      previousSiblingType: getPreviousSiblingType(selection),
    );
  }
}
