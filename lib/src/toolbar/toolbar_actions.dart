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
import 'package:journal_core/src/theme/journal_theme.dart';
import 'package:journal_core/src/toolbar/color_picker/color_picker_constants.dart';
import 'package:journal_core/src/toolbar/color_picker/color_picker_actions.dart';
import 'package:journal_core/src/toolbar/color_picker/color_picker_widgets.dart';
import 'package:journal_core/src/toolbar/color_picker/color_picker_column.dart';

/// Manages toolbar actions for the journal editor, including formatting and insertion.
/// - Includes debug logs with 🔍 prefix for actions.
/// - Compatible with AppFlowy 4.0.0 and single-editor drag-and-drop approach.
class ToolbarActions {
  final EditorState editorState;
  final ToolbarState toolbarState;
  final FocusNode? focusNode; // For focus restoration
  final VoidCallback? onDocumentChanged; // Callback for document changes
  final BuildContext context; // For showing dialogs

  // Add new field to track visual selection state
  Selection? _visualSelection;

  // Theme-aware color pairs (light, dark)
  static const List<(Color, Color)> textColorPairs = [
    (Colors.black, Colors.white), // black/white
    (Color(0xFFF5B40B), Color(0xFFF5B40B)), // yellow
    (Color(0xFF79CE0A), Color(0xFF79CE0A)), // green
    (Color(0xFF317FFF), Color(0xFF317FFF)), // blue
    (Color(0xFF9D68FF), Color(0xFF9D68FF)), // purple
    (Color(0xFFEF4444), Color(0xFFEF4444)), // red
  ];

  // Theme-aware background color pairs (light, dark)
  static const List<(Color, Color)> bgColorPairs = [
    (Color(0xFFFBE28F), Color(0xFFF5B40B)), // yellow
    (Color(0xFFB8EA8C), Color(0xFF79CE0A)), // green
    (Color(0xFFAED6FF), Color(0xFF317FFF)), // blue
    (Color(0xFFD9BFFF), Color(0xFF9D68FF)), // purple
    (Color(0xFFF9A3A3), Color(0xFFEF4444)), // red
  ];

  // Theme-aware underline color pairs (light, dark)
  static const List<(Color, Color)> underlineColorPairs = [
    (Color(0xFFF5B40B), Color(0xFFF5B40B)), // yellow
    (Color(0xFF79CE0A), Color(0xFF79CE0A)), // green
    (Color(0xFF317FFF), Color(0xFF317FFF)), // blue
    (Color(0xFF9D68FF), Color(0xFF9D68FF)), // purple
    (Color(0xFFEF4444), Color(0xFFEF4444)), // red
  ];

  // Add this as a class field at the top of the ToolbarActions class
  String? _lastCopiedStyledJson;

  ToolbarActions({
    required this.editorState,
    required this.toolbarState,
    required this.context,
    this.focusNode,
    this.onDocumentChanged,
  });

  /// Get a theme-aware color based on the color index and theme mode
  static Color getThemeAwareColor(int colorIndex, bool isDarkMode) {
    // Get the theme colors from JournalTheme
    final theme = isDarkMode ? JournalTheme.dark() : JournalTheme.light();

    // Define color mappings based on theme colors
    final colors = [
      theme.secondaryBackground, // Light/dark background
      theme.toolbarBackground, // Toolbar background
      theme.dividerColor, // Divider color
      theme.metadataText, // Metadata text
      theme.secondaryText, // Secondary text
      theme.link, // Link color
      theme.error, // Error color
      theme.cursor, // Cursor color
    ];

    // Ensure the color index is within bounds
    final index = colorIndex % colors.length;
    return colors[index];
  }

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
    print('🔍 Checking if style is active: $style');
    // First check visual selection
    final visualSelection = toolbarState.visualSelection;
    if (visualSelection != null) {
      print('🔍 Using visual selection for style check');
      final node = editorState.getNodeAtPath(visualSelection.start.path);
      if (node == null) {
        print('🔍 No node found at visual selection path');
        return false;
      }

      final attributes = node.attributes;
      final delta = attributes['delta'] as List? ?? [];
      if (delta.isEmpty) {
        print('🔍 Empty delta in visual selection');
        return false;
      }

      if (visualSelection.isCollapsed) {
        var currentOffset = 0;
        final cursorOffset = visualSelection.start.offset;
        for (final op in delta) {
          final opText = op['insert'] as String;
          final opLength = opText.length;
          final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
          if (currentOffset <= cursorOffset &&
              cursorOffset <= currentOffset + opLength) {
            print('🔍 Found style in visual selection: ${opAttributes[style]}');
            return opAttributes[style] == true;
          }
          currentOffset += opLength;
        }
        return false;
      } else {
        final startOffset = visualSelection.start.offset;
        final endOffset = visualSelection.end.offset;
        var currentOffset = 0;
        for (final op in delta) {
          final opText = op['insert'] as String;
          final opLength = opText.length;
          final opAttributes = op['attributes'] as Map<String, dynamic>?;
          if (currentOffset + opLength > startOffset &&
              currentOffset < endOffset) {
            if (opAttributes?[style] == true) {
              print('🔍 Found active style in visual selection range');
              return true;
            }
          }
          currentOffset += opLength;
        }
        return false;
      }
    }

    // Fall back to editor selection if no visual selection
    final selection = editorState.selection;
    if (selection == null) {
      print('🔍 No selection found for style check');
      return false;
    }

    print('🔍 Using editor selection for style check');
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      print('🔍 No node found at selection path');
      return false;
    }

    final attributes = node.attributes;
    final delta = attributes['delta'] as List? ?? [];
    if (delta.isEmpty) {
      print('🔍 Empty delta in selection');
      return false;
    }

    if (selection.isCollapsed) {
      var currentOffset = 0;
      final cursorOffset = selection.start.offset;
      for (final op in delta) {
        final opText = op['insert'] as String;
        final opLength = opText.length;
        final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
        if (currentOffset <= cursorOffset &&
            cursorOffset <= currentOffset + opLength) {
          print('🔍 Found style in selection: ${opAttributes[style]}');
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
          if (opAttributes?[style] == true) {
            print('🔍 Found active style in selection range');
            return true;
          }
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
    print('🔍 handleToggleStyle called with style: $style');

    // Try to get the current selection first, fall back to visual selection if needed
    final currentSelection =
        editorState.selection ?? toolbarState.visualSelection;
    if (currentSelection == null) {
      print('🔍 No selection found (current or visual), returning');
      return;
    }

    // Save the current selection as visual selection
    toolbarState.setVisualSelection(currentSelection);
    print(
        '🔍 Using selection: ${currentSelection.start.path}, offset: ${currentSelection.start.offset}');

    // Create style actions and apply the style
    final styleActions = StyleActions(
      editorState: editorState,
      context: context,
    );
    styleActions.visualSelection = currentSelection;
    print('🔍 Created StyleActions with selection');

    styleActions.toggleStyle(style);
    print('🔍 Called toggleStyle with style: $style');

    // Only restore the selection if color picker is not open
    if (!toolbarState.showColorPicker) {
      editorState.selection = currentSelection;
      print('🔍 Restored selection after applying style (color picker closed)');
    } else {
      // Keep selection cleared but maintain visual selection
      editorState.selection = null;
      print(
          '🔍 Kept selection cleared but maintained visual selection (color picker open)');
    }

    // Update toolbar state with current styles
    toolbarState.setTextStyles(
      bold: isStyleActive('bold'),
      italic: isStyleActive('italic'),
      underline: isStyleActive('underline'),
      strikethrough: isStyleActive('strikethrough'),
    );
    print('🔍 Updated text styles');

    // Ensure style submenu stays visible
    toolbarState.showTextStyles = true;
    toolbarState.notifyListeners();
    print('🔍 Ensured style submenu visibility and notified listeners');
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
    if (selection == null) {
      Log.info('🔍 Indent: No selection');
      return;
    }
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      Log.info('🔍 Indent: No node at path ${selection.start.path}');
      return;
    }

    // Only allow indentation for list items
    if (![
      BlockTypeConstants.todoList,
      BlockTypeConstants.bulletedList,
      BlockTypeConstants.numberedList
    ].contains(node.type)) {
      Log.info('🔍 Indent: Node type ${node.type} not allowed for indent');
      return;
    }

    final currentPath = selection.start.path;
    final currentIndex = currentPath.last;
    final parentPath = currentPath.length > 1
        ? currentPath.sublist(0, currentPath.length - 1)
        : <int>[];

    Log.info(
        '🔍 Indent: Node type: ${node.type}, currentPath: $currentPath, parentPath: $parentPath, currentIndex: $currentIndex');

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;
    final transaction = editorState.transaction;

    // Block indent if at root level and first block
    if (currentPath.length == 1 && currentIndex == 0) {
      Log.info('🔍 Indent blocked: First block at root cannot indent');
      return;
    }

    if (currentPath.length == 1) {
      // At root level
      final previousPath = [currentIndex - 1];
      final previousNode = editorState.getNodeAtPath(previousPath);
      if (previousNode == null) {
        Log.info('🔍 Indent blocked: No previous sibling at root');
        return;
      }

      // List items can only indent under same type
      if (node.type != previousNode.type) {
        Log.info(
            '🔍 Indent blocked: List item can only indent under same type');
        return;
      }

      transaction.deleteNode(node);
      final newPath = [...previousPath, previousNode.children.length];
      transaction.insertNode(Path.from(newPath), node);
      editorState.apply(transaction);
      editorState.selection = Selection.single(
        path: newPath,
        startOffset: savedSelection.start.offset,
      );
      Log.info('🔍 Indented list item from $currentPath to $newPath');
      if (hadFocus && focusNode != null) {
        focusNode!.requestFocus();
      }
      return;
    }

    // For nested list items
    if (currentIndex > 0) {
      final previousPath = [...parentPath, currentIndex - 1];
      final previousNode = editorState.getNodeAtPath(previousPath);
      Log.info(
          '🔍 Indent: Previous sibling path: $previousPath, node: ${previousNode?.type}');

      if (previousNode != null) {
        // List items can only indent under same type
        if (node.type != previousNode.type) {
          Log.info(
              '🔍 Indent blocked: List item can only indent under same type');
          return;
        }

        transaction.deleteNode(node);
        final newPath = [...previousPath, previousNode.children.length];
        transaction.insertNode(Path.from(newPath), node);
        editorState.apply(transaction);
        editorState.selection = Selection.single(
          path: newPath,
          startOffset: savedSelection.start.offset,
        );
        Log.info(
            '🔍 Indented nested list item from path $currentPath to $newPath');
        if (hadFocus && focusNode != null) {
          focusNode!.requestFocus();
        }
        return;
      }
    }

    Log.info(
        '🔍 Indent blocked: No valid indentation target found at path $currentPath');
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
    final plainText = StringBuffer();

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

        // Add to plain text buffer
        plainText.write(selectedText);

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
      // Store the styled version in memory
      _lastCopiedStyledJson = jsonEncode(selectedOps);

      // Only store plain text in the clipboard
      Clipboard.setData(ClipboardData(text: plainText.toString()));
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
      // Check if we have a styled version in memory
      if (_lastCopiedStyledJson != null) {
        final List<dynamic> ops = jsonDecode(_lastCopiedStyledJson!);

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
          return;
        }
      }
    } catch (e) {
      // If parsing fails, fall back to plain text
    }

    // Fall back to plain text if styled version is not available
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

  void showColorBottomSheet() {
    print('ToolbarActions: Opening color picker column');

    // If color picker is already open, close it and restore selection
    if (toolbarState.showColorPicker) {
      print('🔍 Color picker already open, closing it');
      if (toolbarState.visualSelection != null) {
        editorState.selection = toolbarState.visualSelection;
      }
      toolbarState.setVisualSelection(null);
      toolbarState.showColorPicker = false;
      toolbarState.colorPickerWidget = null;
      toolbarState.showTextStyles = true;
      toolbarState.notifyListeners();
      return;
    }

    // Save the current selection as visual selection and ensure style submenu stays visible
    toolbarState.showTextStyles = true;
    toolbarState.setVisualSelection(editorState.selection);

    // Hide keyboard using SystemChannels
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    // Add a listener to close the color picker when selection changes
    void selectionListener() {
      // Check if we're in drag mode
      if (toolbarState.isDragMode) {
        print('🔍 Entering drag mode, cleaning up color picker');
        toolbarState.showColorPicker = false;
        toolbarState.colorPickerWidget = null;
        toolbarState.setVisualSelection(null);
        toolbarState.notifyListeners();
        editorState.selectionNotifier.removeListener(selectionListener);
        return;
      }

      final currentSelection = editorState.selection;
      print(
          '🔍 Color picker selection listener triggered. Current selection: ${currentSelection?.start.path}, offset: ${currentSelection?.start.offset}');
      print(
          '🔍 Visual selection: ${toolbarState.visualSelection?.start.path}, offset: ${toolbarState.visualSelection?.start.offset}');

      if (currentSelection != null &&
          (toolbarState.visualSelection == null ||
              currentSelection.start.path !=
                  toolbarState.visualSelection!.start.path ||
              currentSelection.start.offset !=
                  toolbarState.visualSelection!.start.offset)) {
        print(
            '🔍 Selection changed in color picker, checking if should clear visual selection');
        // Only clear visual selection if style menu is not active
        if (!toolbarState.showTextStyles) {
          print('🔍 Style menu not active, clearing color picker');
          toolbarState.showColorPicker = false;
          toolbarState.colorPickerWidget = null;
          toolbarState.setVisualSelection(null);
          toolbarState.notifyListeners();
        } else {
          print('🔍 Style menu active, keeping visual selection');
        }
        editorState.selectionNotifier.removeListener(selectionListener);
      }
    }

    editorState.selectionNotifier.addListener(selectionListener);

    // Create the color picker widget
    toolbarState.colorPickerWidget = ColorPickerColumn(
      editorState: editorState,
      onTextColorChanged: (color) {
        if (toolbarState.visualSelection != null) {
          final colorPickerActions = ColorPickerActions(
            editorState: editorState,
            context: context,
          );
          colorPickerActions.visualSelection = toolbarState.visualSelection;
          colorPickerActions.setTextColor(color);
          // Update style states and ensure style submenu stays visible
          toolbarState.setTextStyles(
            bold: isStyleActive('bold'),
            italic: isStyleActive('italic'),
            underline: isStyleActive('underline'),
            strikethrough: isStyleActive('strikethrough'),
          );
          toolbarState.showTextStyles = true;
          toolbarState.notifyListeners();
        }
      },
      onBackgroundColorChanged: (color) {
        if (toolbarState.visualSelection != null) {
          final colorPickerActions = ColorPickerActions(
            editorState: editorState,
            context: context,
          );
          colorPickerActions.visualSelection = toolbarState.visualSelection;
          colorPickerActions.setBackgroundColor(color);
          // Update style states and ensure style submenu stays visible
          toolbarState.setTextStyles(
            bold: isStyleActive('bold'),
            italic: isStyleActive('italic'),
            underline: isStyleActive('underline'),
            strikethrough: isStyleActive('strikethrough'),
          );
          toolbarState.showTextStyles = true;
          toolbarState.notifyListeners();
        }
      },
      onUnderlineColorChanged: (color) {
        if (toolbarState.visualSelection != null) {
          final colorPickerActions = ColorPickerActions(
            editorState: editorState,
            context: context,
          );
          colorPickerActions.visualSelection = toolbarState.visualSelection;
          colorPickerActions.setUnderlineColor(color);
          // Update style states and ensure style submenu stays visible
          toolbarState.setTextStyles(
            bold: isStyleActive('bold'),
            italic: isStyleActive('italic'),
            underline: isStyleActive('underline'),
            strikethrough: isStyleActive('strikethrough'),
          );
          toolbarState.showTextStyles = true;
          toolbarState.notifyListeners();
        }
      },
      onUnderlineStyleChanged: (style) {
        if (toolbarState.visualSelection != null) {
          final colorPickerActions = ColorPickerActions(
            editorState: editorState,
            context: context,
          );
          colorPickerActions.visualSelection = toolbarState.visualSelection;
          colorPickerActions.setUnderlineStyle(style);
          // Update style states and ensure style submenu stays visible
          toolbarState.setTextStyles(
            bold: isStyleActive('bold'),
            italic: isStyleActive('italic'),
            underline: isStyleActive('underline'),
            strikethrough: isStyleActive('strikethrough'),
          );
          toolbarState.showTextStyles = true;
          toolbarState.notifyListeners();
        }
      },
      onDone: () {
        // Restore the selection when closing
        if (toolbarState.visualSelection != null) {
          editorState.selection = toolbarState.visualSelection;
        }
        toolbarState.setVisualSelection(null);
        toolbarState.showColorPicker = false;
        toolbarState.colorPickerWidget = null;
        // Update style states and ensure style submenu stays visible
        toolbarState.setTextStyles(
          bold: isStyleActive('bold'),
          italic: isStyleActive('italic'),
          underline: isStyleActive('underline'),
          strikethrough: isStyleActive('strikethrough'),
        );
        toolbarState.showTextStyles = true;
        toolbarState.notifyListeners();
        editorState.selectionNotifier.removeListener(selectionListener);
      },
    );

    // Show the color picker and ensure style submenu stays visible
    toolbarState.showColorPicker = true;
    toolbarState.showTextStyles = true;
    toolbarState.notifyListeners();
  }
}

/// Manages style actions for the journal editor
class StyleActions {
  final EditorState editorState;
  final BuildContext context;
  Selection? _visualSelection;

  set visualSelection(Selection? selection) {
    print(
        '🔍 StyleActions: Setting visual selection to: ${selection?.start.path}, offset: ${selection?.start.offset}');
    _visualSelection = selection;
  }

  StyleActions({
    required this.editorState,
    required this.context,
  });

  void toggleStyle(String style) {
    print('🔍 StyleActions.toggleStyle called with style: $style');
    final selection = _visualSelection ?? editorState.selection;
    if (selection == null) {
      print('🔍 No selection found in toggleStyle');
      return;
    }

    print(
        '🔍 Using selection: ${selection.start.path}, offset: ${selection.start.offset}');

    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      print('🔍 No node found at path');
      return;
    }

    print('🔍 Found node at path: ${node.path}');

    final transaction = editorState.transaction;
    final delta = node.delta?.toJson() ??
        [
          {'insert': ''}
        ];
    print('🔍 Current delta: $delta');

    final newDelta = <Map<String, dynamic>>[];

    if (selection.isCollapsed) {
      print('🔍 Handling collapsed selection');
      var currentOffset = 0;
      final cursorOffset = selection.start.offset;
      for (final op in delta) {
        final opText = op['insert'] as String;
        final opLength = opText.length;
        final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
        if (currentOffset <= cursorOffset &&
            cursorOffset <= currentOffset + opLength) {
          print('🔍 Found cursor position in text: "$opText"');
          final newAttributes = Map<String, dynamic>.from(opAttributes);
          newAttributes[style] = !(opAttributes[style] ?? false);
          print('🔍 Toggled style $style to: ${newAttributes[style]}');
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
      print('🔍 Handling expanded selection');
      final startOffset = selection.start.offset;
      final endOffset = selection.end.offset;
      var currentOffset = 0;
      for (final op in delta) {
        final opText = op['insert'] as String;
        final opLength = opText.length;
        final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};

        // Calculate the overlap with the selection
        final opStart = currentOffset;
        final opEnd = currentOffset + opLength;
        final selectionStart = max(opStart, startOffset);
        final selectionEnd = min(opEnd, endOffset);

        if (selectionStart < selectionEnd) {
          print('🔍 Found selection overlap in text: "$opText"');
          // This operation overlaps with the selection
          if (opStart < selectionStart) {
            // Add text before selection
            newDelta.add({
              'insert': opText.substring(0, selectionStart - opStart),
              'attributes': Map<String, dynamic>.from(opAttributes),
            });
          }

          // Add selected text with toggled style
          final selectedText = opText.substring(
            selectionStart - opStart,
            selectionEnd - opStart,
          );
          final newAttributes = Map<String, dynamic>.from(opAttributes);
          newAttributes[style] = !(opAttributes[style] ?? false);
          print(
              '🔍 Toggled style $style to: ${newAttributes[style]} for selected text: "$selectedText"');
          newDelta.add({
            'insert': selectedText,
            'attributes': newAttributes,
          });

          if (opEnd > selectionEnd) {
            // Add text after selection
            newDelta.add({
              'insert': opText.substring(selectionEnd - opStart),
              'attributes': Map<String, dynamic>.from(opAttributes),
            });
          }
        } else {
          // This operation is outside the selection
          newDelta.add(op);
        }
        currentOffset += opLength;
      }
    }

    print('🔍 Final new delta: $newDelta');
    transaction.updateNode(node, {'delta': newDelta});
    editorState.apply(transaction);
    print('🔍 Applied transaction');
  }
}
