// lib/src/toolbar/toolbar_actions.dart

import 'package:flutter/material.dart'; // For FocusNode
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';

class ToolbarActions {
  final EditorState editorState;
  final ToolbarState toolbarState;
  final FocusNode? focusNode; // Add FocusNode for focus restoration
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
    if (selection == null || selection.isCollapsed) return false;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return false;
    final attributes = node.attributes;
    final delta = attributes['delta'] as List?;
    if (delta == null || delta.isEmpty) return false;
    final startOffset = selection.start.offset;
    final endOffset = selection.end.offset;
    var currentOffset = 0;

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = op['attributes'] as Map<String, dynamic>?;
      if (currentOffset + opLength > startOffset && currentOffset < endOffset) {
        return opAttributes?[style] == true;
      }
      currentOffset += opLength;
    }
    return false;
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

    final newPath = Path.from([...parentPath, originalIndex + 1]);

    // Step 1: Insert new node after the old one
    transaction.insertNode(newPath, newNode);

    // Step 2: Delete the original node
    transaction.deleteNode(node);

    // Step 3: Apply changes
    editorState.apply(transaction, withUpdateSelection: false);

    // Step 4: Optionally, set selection to the new node
    editorState.selection =
        Selection.collapsed(Position(path: newPath, offset: 0));

    // Step 5: Notify UI
    toolbarState.setBlockType(type.name, headingLevel: headingLevel);

    Log.info(
        '🔁 Replaced node at path $oldPath with type "${type.name}" at new path $newPath');
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
    if (currentType != BlockType.paragraph.name &&
        currentType != BlockType.heading.name) {
      Log.info(
          '🔁 Normalize block at ${node.path} to paragraph before heading cycle');
      _changeBlockType(node, BlockType.paragraph);
    }

    // Step 2: If currently paragraph, change to heading level 2
    else if (currentType == BlockType.paragraph.name) {
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

    // Save selection and focus state
    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    print('Before: node.type=${node.type}');

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

    print(
        'After: node.type=${editorState.getNodeAtPath(selection.start.path)?.type}');

    // Restore selection and focus
    editorState.selection = Selection.single(
      path: savedSelection.start.path,
      startOffset: savedSelection.start.offset,
      endOffset: savedSelection.end.offset,
    );
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }

    // Restore selection and focus
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

    if (node.type == BlockType.quote.name) {
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

    // Save selection and focus state
    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final transaction = editorState.transaction;
    transaction.insertNode(Path.from([index + 1]), Node(type: 'divider'));
    editorState.apply(transaction);
    toolbarState.showInsertMenu = false;

    // Restore selection and focus
    editorState.selection = savedSelection;
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  // Insert block below the current block

  void handleInsertBelow() {
    final selection = editorState.selection;
    if (selection == null) return;
    final index = selection.start.path.first;

    // Save focus state (no selection preservation since we want new paragraph selected)
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

    // Restore focus
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

// Insert block above the current block

  void handleInsertAbove() {
    final selection = editorState.selection;
    if (selection == null) return;

    final index = selection.start.path.first;

    // Save focus state
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

    // Move selection to the new node
    editorState.selection = Selection.single(
      path: [index],
      startOffset: 0,
    );

    // Restore focus
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleToggleStyle(String style) {
    final selection = editorState.selection;
    if (selection == null || selection.isCollapsed) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    // Save selection and focus state
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

    // Restore selection and focus
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

    // Save selection and focus state
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

    // Restore selection and focus
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
    if (!['todo_list', 'bulleted_list', 'numbered_list'].contains(node.type)) {
      return;
    }
    final currentIndex = selection.start.path.first;
    if (currentIndex == 0) return;
    final previousNode = editorState.getNodeAtPath([currentIndex - 1]);
    if (previousNode == null || previousNode.type != node.type) return;

    // Save selection and focus state
    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final transaction = editorState.transaction;
    transaction.deleteNode(node);
    transaction.insertNode(
      Path.from([currentIndex - 1, previousNode.children.length]),
      node,
    );
    editorState.apply(transaction);
    editorState.selection = Selection.single(
      path: [currentIndex - 1, previousNode.children.length],
      startOffset: selection.start.offset,
    );

    // Restore focus
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleOutdent() {
    final selection = editorState.selection;
    if (selection == null || selection.start.path.length <= 1) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;
    if (!['todo_list', 'bulleted_list', 'numbered_list'].contains(node.type)) {
      return;
    }

    // Save selection and focus state
    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final parentPath =
        selection.start.path.sublist(0, selection.start.path.length - 1);
    final transaction = editorState.transaction;
    transaction.deleteNode(node);
    transaction.insertNode(
      Path.from([
        ...parentPath.sublist(0, parentPath.length - 1),
        parentPath.last + 1
      ]),
      node,
    );
    editorState.apply(transaction);
    editorState.selection = Selection.single(
      path: [
        ...parentPath.sublist(0, parentPath.length - 1),
        parentPath.last + 1
      ],
      startOffset: selection.start.offset,
    );

    // Restore focus
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  Future<void> handleMoveUp() async {
    // TODO: Implement move up logic (reference epistle_editor.dart's _moveBlockUp)
  }

  Future<void> handleMoveDown() async {
    // TODO: Implement move down logic (reference epistle_editor.dart's _moveBlockDown)
  }
}
