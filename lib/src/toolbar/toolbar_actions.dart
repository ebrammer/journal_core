// lib/src/toolbar/toolbar_actions.dart

import 'package:flutter/material.dart'; // For FocusNode
import 'package:flutter/services.dart'; // For Clipboard
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';
import 'package:journal_core/src/blocks/divider_block.dart' as divider;
import '../models/block_type_constants.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'dart:math';
import 'dart:convert';

/// Manages toolbar actions for the journal editor, including formatting and insertion.
/// - Includes debug logs with 🔍 prefix for actions.
/// - Compatible with AppFlowy 4.0.0 and single-editor drag-and-drop approach.
class ToolbarActions {
  final EditorState editorState;
  final ToolbarState toolbarState;
  final FocusNode? focusNode; // For focus restoration
  final VoidCallback? onDocumentChanged; // Callback for document changes
  final BuildContext context; // For showing dialogs

  ToolbarActions({
    required this.editorState,
    required this.toolbarState,
    required this.context,
    this.focusNode,
    this.onDocumentChanged,
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

  void _changeBlockType(Node node, String type, {int? headingLevel}) {
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

    if (type == BlockTypeConstants.heading) {
      newAttributes[HeadingBlockKeys.level] = headingLevel ?? 2;
    }

    if (type == BlockTypeConstants.todoList) {
      newAttributes[TodoListBlockKeys.checked] = false;
    }

    final newNode = Node(
      type: type,
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
    toolbarState.setBlockType(type, headingLevel: headingLevel);

    Log.info(
        '🔁 Replaced node at path $oldPath with type "$type" at path $newPath');
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
    if (currentType != BlockTypeConstants.paragraph &&
        currentType != BlockTypeConstants.heading) {
      Log.info(
          '🔁 Normalize block at ${node.path} to paragraph before heading cycle');
      _changeBlockType(node, BlockTypeConstants.paragraph);
    }
    // Step 2: If currently paragraph, change to heading level 2
    else if (currentType == BlockTypeConstants.paragraph) {
      Log.info('🔁 Converting paragraph at ${node.path} → heading level 2');
      _changeBlockType(node, BlockTypeConstants.heading, headingLevel: 2);
    }
    // Step 3: If heading, cycle to next level or back to paragraph
    else if (currentLevel == 2) {
      Log.info('🔁 Cycling heading at ${node.path} → heading level 3');
      _changeBlockType(node, BlockTypeConstants.heading, headingLevel: 3);
    } else {
      Log.info('🔁 Cycling heading at ${node.path} → paragraph');
      _changeBlockType(node, BlockTypeConstants.paragraph);
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
    late String newType;

    switch (currentType) {
      case BlockTypeConstants.bulletedList:
        newType = BlockTypeConstants.numberedList;
        break;
      case BlockTypeConstants.numberedList:
        newType = BlockTypeConstants.todoList;
        break;
      case BlockTypeConstants.todoList:
        newType = BlockTypeConstants.paragraph;
        break;
      default:
        newType = BlockTypeConstants.bulletedList;
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

    if (node.type == BlockTypeConstants.quote) {
      Log.info('📝 Quote block tapped again — reverting to paragraph');
      _changeBlockType(node, BlockTypeConstants.paragraph);
    } else {
      Log.info('📝 Converting block at ${node.path} to quote');
      _changeBlockType(node, BlockTypeConstants.quote);
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

    // Insert the divider
    transaction.insertNode(
      Path.from([index + 1]),
      Node(
        type: divider.DividerBlockKeys.type,
        attributes: {
          'id': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      ),
    );

    // Always add a paragraph after the divider
    transaction.insertNode(
      Path.from([index + 2]),
      Node(
        type: BlockTypeConstants.paragraph,
        attributes: {
          'delta': [
            {'insert': ''}
          ]
        },
      ),
    );

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
        type: BlockTypeConstants.paragraph,
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
        type: BlockTypeConstants.paragraph,
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
    if (selection == null) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final transaction = editorState.transaction;
    final delta = node.delta?.toJson() ??
        [
          {'insert': ''}
        ];
    final newDelta = <Map<String, dynamic>>[];

    if (selection.isCollapsed) {
      var currentOffset = 0;
      final cursorOffset = selection.start.offset;
      for (final op in delta) {
        final opText = op['insert'] as String;
        final opLength = opText.length;
        final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
        if (currentOffset <= cursorOffset &&
            cursorOffset <= currentOffset + opLength) {
          final newAttributes = Map<String, dynamic>.from(opAttributes);
          newAttributes[style] = !(opAttributes[style] ?? false);
          newDelta.add({
            'insert': opText,
            'attributes': newAttributes,
          });
        } else {
          newDelta.add(op);
        }
        currentOffset += opLength;
      }
    } else {
      final startOffset = selection.start.offset;
      final endOffset = selection.end.offset;
      var currentOffset = 0;
      for (final op in delta) {
        final opText = op['insert'] as String;
        final opLength = opText.length;
        final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
        if (currentOffset + opLength > startOffset &&
            currentOffset < endOffset) {
          final newAttributes = Map<String, dynamic>.from(opAttributes);
          newAttributes[style] = !(opAttributes[style] ?? false);
          newDelta.add({
            'insert': opText,
            'attributes': newAttributes,
          });
        } else {
          newDelta.add(op);
        }
        currentOffset += opLength;
      }
    }

    transaction.updateNode(node, {'delta': newDelta});
    editorState.apply(transaction);

    // Update toolbar state
    switch (style) {
      case 'bold':
        toolbarState.isStyleBold = !toolbarState.isStyleBold;
        break;
      case 'italic':
        toolbarState.isStyleItalic = !toolbarState.isStyleItalic;
        break;
      case 'underline':
        toolbarState.isStyleUnderline = !toolbarState.isStyleUnderline;
        break;
      case 'strikethrough':
        toolbarState.isStyleStrikethrough = !toolbarState.isStyleStrikethrough;
        break;
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
    if (![
      BlockTypeConstants.paragraph,
      BlockTypeConstants.heading,
      'todo_list',
      'bulleted_list',
      'numbered_list'
    ].contains(node.type)) {
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
    if (![
      BlockTypeConstants.paragraph,
      BlockTypeConstants.heading,
      'todo_list',
      'bulleted_list',
      'numbered_list'
    ].contains(node.type)) {
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

  void handleDelete() {
    final selection = editorState.selection;
    if (selection == null) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final transaction = editorState.transaction;
    transaction.deleteNode(node);
    editorState.apply(transaction);

    // Try to select the previous node first, then fall back to next node if no previous exists
    final parentPath =
        selection.start.path.sublist(0, selection.start.path.length - 1);
    final currentIndex = selection.start.path.last;
    final parentNode = editorState.getNodeAtPath(parentPath);

    if (parentNode != null) {
      if (currentIndex > 0) {
        // Select previous node
        editorState.selection = Selection.single(
          path: [...parentPath, currentIndex - 1],
          startOffset: 0,
        );
      } else if (currentIndex < parentNode.children.length) {
        // Select next node if no previous node exists
        editorState.selection = Selection.single(
          path: [...parentPath, currentIndex],
          startOffset: 0,
        );
      }
    }

    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleCopyToClipboard() {
    final selection = editorState.selection;
    if (selection == null || selection.isCollapsed) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final attributes = Map<String, dynamic>.from(node.attributes);
    final delta = attributes['delta'] as List? ?? [];
    if (delta.isEmpty) return;

    final startOffset = selection.start.offset;
    final endOffset = selection.end.offset;
    var currentOffset = 0;
    final selectedOps = <Map<String, dynamic>>[];

    for (final op in delta) {
      final text = op['insert'] as String;
      final length = text.length;
      if (currentOffset + length > startOffset && currentOffset < endOffset) {
        final start =
            startOffset > currentOffset ? startOffset - currentOffset : 0;
        final end = endOffset < currentOffset + length
            ? endOffset - currentOffset
            : length;
        final selectedText = text.substring(start, end);

        // Create a new operation with the selected text and its attributes
        final newOp = {
          'insert': selectedText,
          if (op['attributes'] != null)
            'attributes': Map<String, dynamic>.from(op['attributes']),
        };
        selectedOps.add(newOp);
      }
      currentOffset += length;
    }

    if (selectedOps.isNotEmpty) {
      // Convert the selected operations to a JSON string
      final jsonString = jsonEncode(selectedOps);
      Clipboard.setData(ClipboardData(text: jsonString));
      toolbarState.hasClipboardContent = true;
      toolbarState.notifyListeners();

      // Move selection to the left of the copied text
      editorState.selection = Selection.single(
        path: selection.start.path,
        startOffset: selection.start.offset,
      );
    }
  }

  void handleCutToClipboard() {
    final selection = editorState.selection;
    if (selection == null || selection.isCollapsed) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    // First copy the text with styling
    handleCopyToClipboard();

    // Then delete the selected text
    final transaction = editorState.transaction;
    transaction.deleteText(
      node,
      selection.start.offset,
      selection.end.offset - selection.start.offset,
    );
    editorState.apply(transaction);

    // Move cursor to the left of the cut text without selecting
    editorState.selection = Selection.single(
      path: savedSelection.start.path,
      startOffset: savedSelection.start.offset,
    );

    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handlePasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data == null || data.text == null || data.text!.isEmpty) return;

    final selection = editorState.selection;
    if (selection == null) return;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    try {
      // Try to parse the clipboard data as JSON (for styled text)
      final List<dynamic> ops = jsonDecode(data.text!);
      if (ops is List && ops.isNotEmpty) {
        final transaction = editorState.transaction;
        if (selection.isCollapsed) {
          // Insert each operation with its attributes
          for (final op in ops) {
            final text = op['insert'] as String;
            final attributes = op['attributes'] as Map<String, dynamic>?;
            transaction.insertText(
              node,
              selection.start.offset,
              text,
              attributes: attributes,
            );
          }
        } else {
          // Delete selected text first
          transaction.deleteText(
            node,
            selection.start.offset,
            selection.end.offset - selection.start.offset,
          );
          // Then insert each operation with its attributes
          for (final op in ops) {
            final text = op['insert'] as String;
            final attributes = op['attributes'] as Map<String, dynamic>?;
            transaction.insertText(
              node,
              selection.start.offset,
              text,
              attributes: attributes,
            );
          }
        }
        editorState.apply(transaction);
      }
    } catch (e) {
      // If parsing fails, treat as plain text
      final transaction = editorState.transaction;
      if (selection.isCollapsed) {
        transaction.insertText(
          node,
          selection.start.offset,
          data.text!,
        );
      } else {
        transaction.deleteText(
          node,
          selection.start.offset,
          selection.end.offset - selection.start.offset,
        );
        transaction.insertText(
          node,
          selection.start.offset,
          data.text!,
        );
      }
      editorState.apply(transaction);
    }

    // Clear the clipboard and update toolbar state
    await Clipboard.setData(const ClipboardData(text: ''));
    toolbarState.hasClipboardContent = false;
    toolbarState.notifyListeners();

    // Restore selection and focus
    editorState.selection = savedSelection;
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleInsertPrayer() {
    final selection = editorState.selection;
    if (selection == null) return;
    final index = selection.start.path.first;

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final transaction = editorState.transaction;
    transaction.insertNode(
      Path.from([index + 1]),
      Node(
        type: 'prayer',
        attributes: {
          'delta': [
            {'insert': ''}
          ]
        },
      ),
    );
    editorState.apply(transaction);
    toolbarState.showInsertMenu = false;

    editorState.selection = savedSelection;
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleInsertScripture() {
    final selection = editorState.selection;
    if (selection == null) return;
    final index = selection.start.path.first;

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final transaction = editorState.transaction;
    transaction.insertNode(
      Path.from([index + 1]),
      Node(
        type: 'scripture',
        attributes: {
          'delta': [
            {'insert': ''}
          ]
        },
      ),
    );
    editorState.apply(transaction);
    toolbarState.showInsertMenu = false;

    editorState.selection = savedSelection;
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }
  }

  void handleBackgroundColor() async {
    print('ToolbarActions: Opening background color picker');
    final selection = editorState.selection;
    if (selection == null) {
      print('ToolbarActions: No selection found');
      return;
    }
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      print('ToolbarActions: No node found at path ${selection.start.path}');
      return;
    }

    // Save the current selection and focus state
    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final color = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Background Color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: Colors.yellow,
            onColorChanged: (color) {
              Navigator.of(context).pop(color);
            },
            availableColors: [
              Colors.red,
              Colors.pink,
              Colors.purple,
              Colors.deepPurple,
              Colors.indigo,
              Colors.blue,
              Colors.lightBlue,
              Colors.cyan,
              Colors.teal,
              Colors.green,
              Colors.lightGreen,
              Colors.lime,
              Colors.yellow,
              Colors.amber,
              Colors.orange,
              Colors.deepOrange,
              Colors.brown,
              Colors.grey,
              Colors.blueGrey,
              Colors.black,
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // Restore the selection and focus
    editorState.selection = savedSelection;
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }

    if (color == null) {
      print('ToolbarActions: No color selected');
      return;
    }

    print('ToolbarActions: Color selected: ${color.value.toRadixString(16)}');
    setBackgroundColor(color);
  }

  void setBackgroundColor(Color color) {
    print(
        'ToolbarActions: Setting background color to ${color.value.toRadixString(16)}');
    final selection = editorState.selection;
    if (selection == null) {
      print('ToolbarActions: No selection found');
      return;
    }

    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      print('ToolbarActions: No node found at path ${selection.start.path}');
      return;
    }

    final attributes = node.attributes;
    final delta = attributes['delta'] as List? ?? [];
    if (delta.isEmpty) {
      print('ToolbarActions: Empty delta found');
      return;
    }

    print('ToolbarActions: Current delta: $delta');
    print(
        'ToolbarActions: Selection range: ${selection.start.offset} to ${selection.end.offset}');

    // Log the selected text
    final startOffset = selection.start.offset;
    final endOffset = selection.end.offset;
    var selectedText = '';
    var currentOffset = 0;
    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      print(
          'ToolbarActions: Processing delta operation: text="$opText", length=$opLength, currentOffset=$currentOffset');

      if (currentOffset + opLength > startOffset && currentOffset < endOffset) {
        final textStart = startOffset - currentOffset;
        final textEnd = min(endOffset - currentOffset, opLength);
        final extractedText = opText.substring(textStart, textEnd);
        selectedText += extractedText;
        print(
            'ToolbarActions: Extracted text from operation: "$extractedText"');
      }
      currentOffset += opLength;
    }
    print(
        'ToolbarActions: Final selected text: "$selectedText" (from $startOffset to $endOffset)');

    final transaction = editorState.transaction;
    final newDelta = <Map<String, dynamic>>[];
    currentOffset = 0;

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
      print(
          'ToolbarActions: Processing text "$opText" at offset $currentOffset with attributes: $opAttributes');

      if (currentOffset + opLength <= startOffset ||
          currentOffset >= endOffset) {
        // Text is outside selection range, keep as is
        print('ToolbarActions: Text outside selection range, keeping as is');
        newDelta.add(op);
      } else {
        // Text overlaps with selection
        final beforeSelection =
            opText.substring(0, startOffset - currentOffset);
        final selectedText = opText.substring(
          startOffset - currentOffset,
          min(endOffset - currentOffset, opLength),
        );
        final afterSelection =
            opText.substring(min(endOffset - currentOffset, opLength));

        print(
            'ToolbarActions: Splitting text: before="$beforeSelection", selected="$selectedText", after="$afterSelection"');

        // Add text before selection
        if (beforeSelection.isNotEmpty) {
          newDelta.add({
            'insert': beforeSelection,
            'attributes': Map<String, dynamic>.from(opAttributes),
          });
        }

        // Add selected text with background color
        if (selectedText.isNotEmpty) {
          final newAttributes = {
            ...Map<String, dynamic>.from(opAttributes),
            'backgroundColor': color.value.toRadixString(16).padLeft(8, '0'),
          };
          print(
              'ToolbarActions: Adding selected text with attributes: $newAttributes');
          newDelta.add({
            'insert': selectedText,
            'attributes': newAttributes,
          });
        }

        // Add text after selection
        if (afterSelection.isNotEmpty) {
          newDelta.add({
            'insert': afterSelection,
            'attributes': Map<String, dynamic>.from(opAttributes),
          });
        }
      }
      currentOffset += opLength;
    }

    print('ToolbarActions: Final new delta: $newDelta');
    transaction.updateNode(node, {'delta': newDelta});
    editorState.apply(transaction);

    // Update toolbar state
    toolbarState.isStyleBackgroundColor = true;
  }

  void handleTextColor() async {
    print('ToolbarActions: Opening text color picker');
    final selection = editorState.selection;
    if (selection == null) {
      print('ToolbarActions: No selection found');
      return;
    }
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      print('ToolbarActions: No node found at path ${selection.start.path}');
      return;
    }

    // Save the current selection and focus state
    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final color = await showDialog<Color>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Text Color'),
        content: SingleChildScrollView(
          child: BlockPicker(
            pickerColor: Colors.black,
            onColorChanged: (color) {
              Navigator.of(context).pop(color);
            },
            availableColors: [
              Colors.red,
              Colors.pink,
              Colors.purple,
              Colors.deepPurple,
              Colors.indigo,
              Colors.blue,
              Colors.lightBlue,
              Colors.cyan,
              Colors.teal,
              Colors.green,
              Colors.lightGreen,
              Colors.lime,
              Colors.yellow,
              Colors.amber,
              Colors.orange,
              Colors.deepOrange,
              Colors.brown,
              Colors.grey,
              Colors.blueGrey,
              Colors.black,
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    // Restore the selection and focus
    editorState.selection = savedSelection;
    if (hadFocus && focusNode != null) {
      focusNode!.requestFocus();
    }

    if (color == null) {
      print('ToolbarActions: No color selected');
      return;
    }

    print('ToolbarActions: Color selected: ${color.value.toRadixString(16)}');
    setTextColor(color);
  }

  void setTextColor(Color color) {
    print(
        'ToolbarActions: Setting text color to ${color.value.toRadixString(16)}');
    final selection = editorState.selection;
    if (selection == null) {
      print('ToolbarActions: No selection found');
      return;
    }

    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      print('ToolbarActions: No node found at path ${selection.start.path}');
      return;
    }

    final attributes = node.attributes;
    final delta = attributes['delta'] as List? ?? [];
    if (delta.isEmpty) {
      print('ToolbarActions: Empty delta found');
      return;
    }

    print('ToolbarActions: Current delta: $delta');
    print(
        'ToolbarActions: Selection range: ${selection.start.offset} to ${selection.end.offset}');

    // Log the selected text
    final startOffset = selection.start.offset;
    final endOffset = selection.end.offset;
    var selectedText = '';
    var currentOffset = 0;
    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      print(
          'ToolbarActions: Processing delta operation: text="$opText", length=$opLength, currentOffset=$currentOffset');

      if (currentOffset + opLength > startOffset && currentOffset < endOffset) {
        final textStart = startOffset - currentOffset;
        final textEnd = min(endOffset - currentOffset, opLength);
        final extractedText = opText.substring(textStart, textEnd);
        selectedText += extractedText;
        print(
            'ToolbarActions: Extracted text from operation: "$extractedText"');
      }
      currentOffset += opLength;
    }
    print(
        'ToolbarActions: Final selected text: "$selectedText" (from $startOffset to $endOffset)');

    final transaction = editorState.transaction;
    final newDelta = <Map<String, dynamic>>[];
    currentOffset = 0;

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
      print(
          'ToolbarActions: Processing text "$opText" at offset $currentOffset with attributes: $opAttributes');

      if (currentOffset + opLength <= startOffset ||
          currentOffset >= endOffset) {
        // Text is outside selection range, keep as is
        print('ToolbarActions: Text outside selection range, keeping as is');
        newDelta.add(op);
      } else {
        // Text overlaps with selection
        final beforeSelection =
            opText.substring(0, startOffset - currentOffset);
        final selectedText = opText.substring(
          startOffset - currentOffset,
          min(endOffset - currentOffset, opLength),
        );
        final afterSelection =
            opText.substring(min(endOffset - currentOffset, opLength));

        print(
            'ToolbarActions: Splitting text: before="$beforeSelection", selected="$selectedText", after="$afterSelection"');

        // Add text before selection
        if (beforeSelection.isNotEmpty) {
          newDelta.add({
            'insert': beforeSelection,
            'attributes': Map<String, dynamic>.from(opAttributes),
          });
        }

        // Add selected text with text color
        if (selectedText.isNotEmpty) {
          final newAttributes = {
            ...Map<String, dynamic>.from(opAttributes),
            'color': color.value.toRadixString(16).padLeft(8, '0'),
          };
          print(
              'ToolbarActions: Adding selected text with attributes: $newAttributes');
          newDelta.add({
            'insert': selectedText,
            'attributes': newAttributes,
          });
        }

        // Add text after selection
        if (afterSelection.isNotEmpty) {
          newDelta.add({
            'insert': afterSelection,
            'attributes': Map<String, dynamic>.from(opAttributes),
          });
        }
      }
      currentOffset += opLength;
    }

    print('ToolbarActions: Final new delta: $newDelta');
    transaction.updateNode(node, {'delta': newDelta});
    editorState.apply(transaction);

    // Update toolbar state
    toolbarState.isStyleTextColor = true;
  }

  void showColorBottomSheet() {
    print('ToolbarActions: Opening persistent color bottom sheet');
    final scaffold = Scaffold.of(context);
    // Save selection and focus
    final hadFocus = focusNode?.hasFocus ?? false;

    scaffold.showBottomSheet(
      (context) => StreamBuilder(
        stream: Stream.periodic(const Duration(milliseconds: 100)),
        builder: (context, snapshot) {
          final currentSelection = editorState.selection;
          return _ColorPickerBottomSheet(
            onTextColorChanged: (color) {
              // Use current selection instead of saved selection
              if (currentSelection != null) {
                editorState.selection = currentSelection;
                if (hadFocus && focusNode != null) {
                  focusNode!.requestFocus();
                }
                setTextColor(color);
              }
            },
            onBackgroundColorChanged: (color) {
              // Use current selection instead of saved selection
              if (currentSelection != null) {
                editorState.selection = currentSelection;
                if (hadFocus && focusNode != null) {
                  focusNode!.requestFocus();
                }
                setBackgroundColor(color);
              }
            },
            onDone: () {
              Navigator.of(context).pop();
            },
            editorState: editorState,
          );
        },
      ),
      backgroundColor: Colors.white,
      elevation: 1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
  }
}

// Stub for the custom color picker bottom sheet
class _ColorPickerBottomSheet extends StatefulWidget {
  final ValueChanged<Color> onTextColorChanged;
  final ValueChanged<Color> onBackgroundColorChanged;
  final VoidCallback onDone;
  final EditorState editorState;

  const _ColorPickerBottomSheet({
    required this.onTextColorChanged,
    required this.onBackgroundColorChanged,
    required this.onDone,
    required this.editorState,
    Key? key,
  }) : super(key: key);

  @override
  State<_ColorPickerBottomSheet> createState() =>
      _ColorPickerBottomSheetState();
}

class _ColorPickerBottomSheetState extends State<_ColorPickerBottomSheet> {
  static const List<Color> textColors = [
    Color(0xFF000000), // Default text color (will be overridden by theme)
    Color(0xFF2196F3), // Blue
    Color(0xFF4CAF50), // Green
    Color(0xFFFF9800), // Orange
    Color(0xFF9C27B0), // Purple
    Color(0xFFE91E63), // Pink
  ];
  static const List<Color> bgColors = [
    // Light colors
    Color(0xFFF5F5F5), // Light Gray
    Color(0xFFE3F2FD), // Light Blue
    Color(0xFFE8F5E9), // Light Green
    Color(0xFFFFF3E0), // Light Orange
    Color(0xFFF3E5F5), // Light Purple
    Color(0xFFFCE4EC), // Light Pink

    // Darker shades
    Color(0xFFBDBDBD), // Dark Gray
    Color(0xFF90CAF9), // Dark Blue
    Color(0xFFA5D6A7), // Dark Green
    Color(0xFFFFB74D), // Dark Orange
    Color(0xFFCE93D8), // Dark Purple
    Color(0xFFF48FB1), // Dark Pink
  ];

  late int selectedTextColor;
  late int selectedBgColor;

  @override
  void initState() {
    super.initState();
    _updateColorsFromSelection();
  }

  void _updateColorsFromSelection() {
    final selection = widget.editorState.selection;
    if (selection == null) return;

    final node = widget.editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final delta = node.delta?.toJson() ?? [];
    if (delta.isEmpty) return;

    var currentOffset = 0;
    final cursorOffset = selection.start.offset;

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};

      if (currentOffset <= cursorOffset &&
          cursorOffset <= currentOffset + opLength) {
        // Update text color
        if (opAttributes['color'] != null) {
          final color =
              Color(int.parse(opAttributes['color'] as String, radix: 16));
          final index = textColors.indexOf(color);
          if (index != -1) {
            setState(() => selectedTextColor = index);
          }
        } else {
          setState(() => selectedTextColor = 0); // Default to black
        }

        // Update background color
        if (opAttributes['backgroundColor'] != null) {
          final color = Color(
              int.parse(opAttributes['backgroundColor'] as String, radix: 16));
          final index = bgColors.indexOf(color);
          if (index != -1) {
            setState(() => selectedBgColor = index);
          }
        } else {
          setState(() => selectedBgColor = 0); // Default to white
        }
        break;
      }
      currentOffset += opLength;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Update colors whenever the widget rebuilds
    _updateColorsFromSelection();

    // Create a new list with the first color replaced by the theme's text color
    final themeAwareTextColors = [
      Theme.of(context).textTheme.bodyLarge?.color ?? Colors.black,
      ...textColors.sublist(1),
    ];

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        padding: const EdgeInsets.only(left: 16, right: 16, top: 8, bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Color',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).textTheme.titleLarge?.color,
                  ),
                ),
                TextButton(
                  onPressed: widget.onDone,
                  child: Text(
                    'Done',
                    style: TextStyle(
                      fontSize: 16,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Divider(
              height: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor.withOpacity(0.1),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Text Color',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => selectedTextColor = -1);
                    widget.onTextColorChanged(Colors.black);
                  },
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(textColors.length, (i) {
                return _ColorOption(
                  color: themeAwareTextColors[i],
                  label: 'A',
                  selected: selectedTextColor == i,
                  onTap: () {
                    setState(() => selectedTextColor = i);
                    widget.onTextColorChanged(themeAwareTextColors[i]);
                  },
                );
              }),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Background Color',
                  style: TextStyle(
                    color: Theme.of(context).textTheme.bodyLarge?.color,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() => selectedBgColor = -1);
                    widget.onBackgroundColorChanged(Colors.transparent);
                  },
                  child: Text(
                    'Reset',
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).textTheme.bodyLarge?.color,
                    ),
                  ),
                ),
              ],
            ),
            Column(
              children: [
                // First row - light colors
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return _ColorOption(
                      color: bgColors[i],
                      label: 'A',
                      selected: selectedBgColor == i,
                      isBackground: true,
                      onTap: () {
                        setState(() => selectedBgColor = i);
                        widget.onBackgroundColorChanged(bgColors[i]);
                      },
                    );
                  }),
                ),
                const SizedBox(height: 12),
                // Second row - darker shades
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) {
                    return _ColorOption(
                      color: bgColors[i + 6],
                      label: 'A',
                      selected: selectedBgColor == i + 6,
                      isBackground: true,
                      onTap: () {
                        setState(() => selectedBgColor = i + 6);
                        widget.onBackgroundColorChanged(bgColors[i + 6]);
                      },
                    );
                  }),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ColorOption extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isBackground;

  const _ColorOption({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isBackground = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border.all(
            color: selected
                ? Colors.black
                : (isBackground
                    ? color
                    : Theme.of(context).dividerColor.withOpacity(0.1)),
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color:
              isBackground ? color : Theme.of(context).scaffoldBackgroundColor,
        ),
        child: isBackground
            ? null
            : Center(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
      ),
    );
  }
}

class _BgColorOption extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _BgColorOption({
    required this.color,
    required this.selected,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? Colors.blue : Colors.transparent,
            width: 2,
          ),
        ),
        child: selected ? const Icon(Icons.check, color: Colors.blue) : null,
      ),
    );
  }
}
