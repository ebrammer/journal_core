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

/// Manages toolbar actions for the journal editor, including formatting and insertion.
/// - Includes debug logs with 🔍 prefix for actions.
/// - Compatible with AppFlowy 4.0.0 and single-editor drag-and-drop approach.
class ToolbarActions {
  final EditorState editorState;
  final ToolbarState toolbarState;
  final FocusNode? focusNode; // For focus restoration
  final VoidCallback? onDocumentChanged; // Callback for document changes
  final BuildContext context; // For showing dialogs

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

    // Save the current selection and focus state
    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

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

        // Calculate the overlap with the selection
        final opStart = currentOffset;
        final opEnd = currentOffset + opLength;
        final selectionStart = max(opStart, startOffset);
        final selectionEnd = min(opEnd, endOffset);

        if (selectionStart < selectionEnd) {
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

    transaction.updateNode(node, {'delta': newDelta});
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

    final savedSelection = selection;
    final hadFocus = focusNode?.hasFocus ?? false;

    final transaction = editorState.transaction;

    // If we're at the root level, create a new parent node
    if (currentPath.length == 1) {
      // Create a new parent node of the same type
      final parentNode = Node(
        type: node.type,
        attributes: {
          'delta': [
            {'insert': ''}
          ]
        },
        children: [],
      );

      // Insert the parent node at the current position
      transaction.insertNode(Path.from([currentIndex]), parentNode);

      // Move the current node to be a child of the new parent
      transaction.deleteNode(node);
      transaction.insertNode(Path.from([currentIndex, 0]), node);
    } else {
      // Normal indentation logic for nested items
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

      transaction.deleteNode(node);
      final newPath = [...previousPath!, previousNode.children.length];
      transaction.insertNode(Path.from(newPath), node);
    }

    editorState.apply(transaction);

    // Update selection to the new position
    final newPath = currentPath.length == 1
        ? [currentIndex, 0] // If we created a new parent, select the child
        : [
            ...parentPath,
            currentIndex - 1,
            0
          ]; // If we moved to a sibling, select its first child

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

  PersistentBottomSheetController? _colorBottomSheetController;
  void showColorBottomSheet() {
    print('ToolbarActions: Opening persistent color bottom sheet');
    final scaffold = Scaffold.of(context);
    // Save selection and focus
    final hadFocus = focusNode?.hasFocus ?? false;
    final savedSelection = editorState.selection;

    // Hide keyboard using SystemChannels
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    // Close any existing bottom sheet
    _colorBottomSheetController?.close();
    _colorBottomSheetController = null;

    // Add a listener to close the bottom sheet when selection changes
    void selectionListener() {
      final currentSelection = editorState.selection;
      if (currentSelection != null &&
          (savedSelection == null ||
              currentSelection.start.path != savedSelection.start.path ||
              currentSelection.start.offset != savedSelection.start.offset)) {
        _colorBottomSheetController?.close();
        _colorBottomSheetController = null;
        editorState.selectionNotifier.removeListener(selectionListener);
      }
    }

    editorState.selectionNotifier.addListener(selectionListener);

    _colorBottomSheetController = scaffold.showBottomSheet(
      (context) => SafeArea(
        bottom: true,
        child: StreamBuilder(
          stream: Stream.periodic(const Duration(milliseconds: 100)),
          builder: (context, snapshot) {
            return _ColorPickerBottomSheet(
              onTextColorChanged: (color) {
                // Use saved selection
                if (savedSelection != null) {
                  setTextColor(color);
                  // Restore selection after color change
                  editorState.selection = savedSelection;
                  if (hadFocus && focusNode != null) {
                    focusNode!.requestFocus();
                  }
                  // Keep the bottom sheet open
                }
              },
              onBackgroundColorChanged: (color) {
                // Use saved selection
                if (savedSelection != null) {
                  setBackgroundColor(color);
                  // Restore selection after color change
                  editorState.selection = savedSelection;
                  if (hadFocus && focusNode != null) {
                    focusNode!.requestFocus();
                  }
                  // Keep the bottom sheet open
                }
              },
              onUnderlineColorChanged: (color) {
                // Use saved selection
                if (savedSelection != null) {
                  setUnderlineColor(color);
                  // Restore selection after color change
                  editorState.selection = savedSelection;
                  if (hadFocus && focusNode != null) {
                    focusNode!.requestFocus();
                  }
                  // Keep the bottom sheet open
                }
              },
              onDone: () {
                // Restore selection when closing without color change
                if (savedSelection != null) {
                  editorState.selection = savedSelection;
                  if (hadFocus && focusNode != null) {
                    focusNode!.requestFocus();
                  }
                }
                _colorBottomSheetController?.close();
                _colorBottomSheetController = null;
                editorState.selectionNotifier.removeListener(selectionListener);
              },
              editorState: editorState,
            );
          },
        ),
      ),
      backgroundColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
    );
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

    final transaction = editorState.transaction;
    final newDelta = <Map<String, dynamic>>[];
    var currentOffset = 0;

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
      print(
          'ToolbarActions: Processing text "$opText" at offset $currentOffset with attributes: $opAttributes');

      if (currentOffset + opLength <= selection.start.offset ||
          currentOffset >= selection.end.offset) {
        // Text is outside selection range, keep as is
        print('ToolbarActions: Text outside selection range, keeping as is');
        newDelta.add(op);
      } else {
        // Text overlaps with selection
        final beforeSelection =
            opText.substring(0, max(0, selection.start.offset - currentOffset));
        final selectedText = opText.substring(
          max(0, selection.start.offset - currentOffset),
          min(opLength, selection.end.offset - currentOffset),
        );
        final afterSelection = opText
            .substring(min(opLength, selection.end.offset - currentOffset));

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
          final newAttributes = Map<String, dynamic>.from(opAttributes);
          if (color == Colors.transparent) {
            // When resetting, only remove text styling attributes
            newAttributes.remove('color');
            newAttributes.remove('bold');
            newAttributes.remove('italic');
            newAttributes.remove('underline');
            newAttributes.remove('strike');
            newAttributes.remove('underlineColor');
            // Preserve background color
          } else {
            newAttributes['color'] =
                color.value.toRadixString(16).padLeft(8, '0');
          }
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
    toolbarState.isStyleTextColor = color != Colors.transparent;
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

    final transaction = editorState.transaction;
    final newDelta = <Map<String, dynamic>>[];
    var currentOffset = 0;

    // Find the color index
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    int colorIndex = -1;
    for (int i = 0; i < bgColorPairs.length; i++) {
      final (lightColor, darkColor) = bgColorPairs[i];
      if (color == (isDarkMode ? darkColor : lightColor)) {
        colorIndex = i;
        break;
      }
    }

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
      print(
          'ToolbarActions: Processing text "$opText" at offset $currentOffset with attributes: $opAttributes');

      if (currentOffset + opLength <= selection.start.offset ||
          currentOffset >= selection.end.offset) {
        // Text is outside selection range, keep as is
        print('ToolbarActions: Text outside selection range, keeping as is');
        newDelta.add(op);
      } else {
        // Text overlaps with selection
        final beforeSelection =
            opText.substring(0, max(0, selection.start.offset - currentOffset));
        final selectedText = opText.substring(
          max(0, selection.start.offset - currentOffset),
          min(opLength, selection.end.offset - currentOffset),
        );
        final afterSelection = opText
            .substring(min(opLength, selection.end.offset - currentOffset));

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
          final newAttributes = Map<String, dynamic>.from(opAttributes);
          if (color == Colors.transparent) {
            newAttributes.remove('backgroundColor');
            newAttributes.remove('backgroundColorIndex');
          } else {
            newAttributes['backgroundColor'] =
                color.value.toRadixString(16).padLeft(8, '0');
            newAttributes['backgroundColorIndex'] = colorIndex;
          }
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
  }

  void setUnderlineColor(Color color) {
    print(
        'ToolbarActions: Setting underline color to ${color.value.toRadixString(16)}');
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

    final transaction = editorState.transaction;
    final newDelta = <Map<String, dynamic>>[];
    var currentOffset = 0;

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};

      if (currentOffset + opLength <= selection.start.offset ||
          currentOffset >= selection.end.offset) {
        newDelta.add(op);
      } else {
        final beforeSelection =
            opText.substring(0, max(0, selection.start.offset - currentOffset));
        final selectedText = opText.substring(
          max(0, selection.start.offset - currentOffset),
          min(opLength, selection.end.offset - currentOffset),
        );
        final afterSelection = opText
            .substring(min(opLength, selection.end.offset - currentOffset));

        if (beforeSelection.isNotEmpty) {
          newDelta.add({
            'insert': beforeSelection,
            'attributes': Map<String, dynamic>.from(opAttributes),
          });
        }

        if (selectedText.isNotEmpty) {
          final newAttributes = Map<String, dynamic>.from(opAttributes);
          if (color == Colors.transparent) {
            newAttributes.remove('underline');
            newAttributes.remove('underlineColor');
          } else {
            newAttributes['underline'] = true;
            newAttributes['underlineColor'] =
                color.value.toRadixString(16).padLeft(8, '0');
          }
          newDelta.add({
            'insert': selectedText,
            'attributes': newAttributes,
          });
        }

        if (afterSelection.isNotEmpty) {
          newDelta.add({
            'insert': afterSelection,
            'attributes': Map<String, dynamic>.from(opAttributes),
          });
        }
      }
      currentOffset += opLength;
    }

    transaction.updateNode(node, {'delta': newDelta});
    editorState.apply(transaction);
  }
}

// Stub for the custom color picker bottom sheet
class _ColorPickerBottomSheet extends StatefulWidget {
  final ValueChanged<Color> onTextColorChanged;
  final ValueChanged<Color> onBackgroundColorChanged;
  final ValueChanged<Color> onUnderlineColorChanged;
  final VoidCallback onDone;
  final EditorState editorState;

  const _ColorPickerBottomSheet({
    required this.onTextColorChanged,
    required this.onBackgroundColorChanged,
    required this.onUnderlineColorChanged,
    required this.onDone,
    required this.editorState,
    Key? key,
  }) : super(key: key);

  @override
  State<_ColorPickerBottomSheet> createState() =>
      _ColorPickerBottomSheetState();
}

class _ColorPickerBottomSheetState extends State<_ColorPickerBottomSheet> {
  late int selectedTextColor;
  late int selectedBgColor;
  late int selectedUnderlineColor;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    selectedTextColor = 0;
    selectedBgColor = -1;
    selectedUnderlineColor = -1;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _updateColorsFromSelection();
      _initialized = true;
    }
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
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    if (!selection.isCollapsed) {
      final startOffset = selection.start.offset;
      final endOffset = selection.end.offset;
      bool foundTextColor = false;
      bool foundBgColor = false;
      bool foundUnderlineColor = false;
      Color? lastTextColor;
      Color? lastBgColor;
      Color? lastUnderlineColor;

      for (final op in delta) {
        final opText = op['insert'] as String;
        final opLength = opText.length;
        final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};

        if (currentOffset + opLength > startOffset &&
            currentOffset < endOffset) {
          if (opAttributes['color'] != null) {
            final color =
                Color(int.parse(opAttributes['color'] as String, radix: 16));
            lastTextColor = color;
            foundTextColor = true;
          }
          if (opAttributes['backgroundColor'] != null) {
            final color = Color(int.parse(
                opAttributes['backgroundColor'] as String,
                radix: 16));
            lastBgColor = color;
            foundBgColor = true;
          }
          if (opAttributes['underlineColor'] != null) {
            final color = Color(
                int.parse(opAttributes['underlineColor'] as String, radix: 16));
            lastUnderlineColor = color;
            foundUnderlineColor = true;
          }
        }
        currentOffset += opLength;
      }

      if (foundTextColor && lastTextColor != null) {
        for (int i = 0; i < ToolbarActions.textColorPairs.length; i++) {
          if (ToolbarActions.textColorPairs[i].$1 == lastTextColor ||
              ToolbarActions.textColorPairs[i].$2 == lastTextColor) {
            setState(() => selectedTextColor = i);
            break;
          }
        }
      } else {
        setState(() => selectedTextColor = 0);
      }

      if (foundBgColor && lastBgColor != null) {
        for (int i = 0; i < ToolbarActions.bgColorPairs.length; i++) {
          if (ToolbarActions.bgColorPairs[i].$1 == lastBgColor ||
              ToolbarActions.bgColorPairs[i].$2 == lastBgColor) {
            setState(() => selectedBgColor = i);
            break;
          }
        }
      } else {
        setState(() => selectedBgColor = -1);
      }

      if (foundUnderlineColor && lastUnderlineColor != null) {
        for (int i = 0; i < ToolbarActions.underlineColorPairs.length; i++) {
          if (ToolbarActions.underlineColorPairs[i].$1 == lastUnderlineColor ||
              ToolbarActions.underlineColorPairs[i].$2 == lastUnderlineColor) {
            setState(() => selectedUnderlineColor = i);
            break;
          }
        }
      } else {
        setState(() => selectedUnderlineColor = -1);
      }
      return;
    }

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};

      if (currentOffset <= cursorOffset &&
          cursorOffset <= currentOffset + opLength) {
        if (opAttributes['color'] != null) {
          final color =
              Color(int.parse(opAttributes['color'] as String, radix: 16));
          for (int i = 0; i < ToolbarActions.textColorPairs.length; i++) {
            if (ToolbarActions.textColorPairs[i].$1 == color ||
                ToolbarActions.textColorPairs[i].$2 == color) {
              setState(() => selectedTextColor = i);
              break;
            }
          }
        } else {
          setState(() => selectedTextColor = 0);
        }

        if (opAttributes['backgroundColor'] != null) {
          final color = Color(
              int.parse(opAttributes['backgroundColor'] as String, radix: 16));
          for (int i = 0; i < ToolbarActions.bgColorPairs.length; i++) {
            if (ToolbarActions.bgColorPairs[i].$1 == color ||
                ToolbarActions.bgColorPairs[i].$2 == color) {
              setState(() => selectedBgColor = i);
              break;
            }
          }
        } else {
          setState(() => selectedBgColor = -1);
        }

        if (opAttributes['underlineColor'] != null) {
          final color = Color(
              int.parse(opAttributes['underlineColor'] as String, radix: 16));
          for (int i = 0; i < ToolbarActions.underlineColorPairs.length; i++) {
            if (ToolbarActions.underlineColorPairs[i].$1 == color ||
                ToolbarActions.underlineColorPairs[i].$2 == color) {
              setState(() => selectedUnderlineColor = i);
              break;
            }
          }
        } else {
          setState(() => selectedUnderlineColor = -1);
        }
        break;
      }
      currentOffset += opLength;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final currentTextColors = ToolbarActions.textColorPairs
        .map((pair) => isDarkMode ? pair.$2 : pair.$1)
        .toList();
    final currentBgColors = ToolbarActions.bgColorPairs
        .map((pair) => isDarkMode ? pair.$2 : pair.$1)
        .toList();
    final currentUnderlineColors = ToolbarActions.underlineColorPairs
        .map((pair) => isDarkMode ? pair.$2 : pair.$1)
        .toList();

    // Calculate button size based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32; // Account for horizontal padding
    final buttonSize =
        (availableWidth - 12) / 7; // 12 is total margin space (6 gaps * 2px)
    final finalSize = buttonSize.clamp(40.0, 54.0);

    final backgroundColor = isDarkMode
        ? const Color(0xFF3D3D3D)
        : const Color.fromARGB(255, 255, 255, 255);

    // Calculate max height as 50% of screen height
    final maxHeight = MediaQuery.of(context).size.height * 0.5;

    return Container(
      constraints: BoxConstraints(
        maxHeight: maxHeight,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
          border: Border(
            top: BorderSide(
              color: isDarkMode
                  ? Colors.white.withAlpha(26)
                  : Colors.black.withAlpha(26),
              width: 0.5,
            ),
          ),
        ),
        child: SafeArea(
          bottom: true,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row with done button
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Color Options',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white : Colors.black,
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      TextButton(
                        onPressed: widget.onDone,
                        child: Text(
                          'Done',
                          style: TextStyle(
                            color: isDarkMode ? Colors.white : Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Underline section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Underline',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Underline reset button
                            GestureDetector(
                              onTap: () {
                                setState(() => selectedUnderlineColor = -1);
                                widget.onUnderlineColorChanged(
                                    Colors.transparent);
                              },
                              child: Container(
                                width: finalSize,
                                height: finalSize,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedUnderlineColor == -1
                                        ? isDarkMode
                                            ? Colors.white
                                            : Colors.black
                                        : Theme.of(context)
                                            .dividerColor
                                            .withAlpha(26),
                                    width: selectedUnderlineColor == -1 ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: selectedUnderlineColor == -1
                                      ? Icon(
                                          Icons.check,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                          size: finalSize * 0.5,
                                        )
                                      : Icon(
                                          Icons.format_color_reset,
                                          color: Theme.of(context)
                                              .dividerColor
                                              .withAlpha(128),
                                          size: finalSize * 0.5,
                                        ),
                                ),
                              ),
                            ),
                            ...List.generate(currentUnderlineColors.length,
                                (i) {
                              return _ColorOption(
                                color: currentUnderlineColors[i],
                                label: 'U',
                                selected: selectedUnderlineColor == i,
                                isUnderline: true,
                                onTap: () {
                                  setState(() => selectedUnderlineColor = i);
                                  widget.onUnderlineColorChanged(
                                      currentUnderlineColors[i]);
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Text color section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Text',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Black/white reset
                            _ColorOption(
                              color: currentTextColors[0],
                              label: 'A',
                              selected: selectedTextColor == 0,
                              onTap: () {
                                setState(() => selectedTextColor = 0);
                                widget.onTextColorChanged(Colors.transparent);
                              },
                            ),
                            // Yellow
                            _ColorOption(
                              color: currentTextColors[1],
                              label: 'A',
                              selected: selectedTextColor == 1,
                              onTap: () {
                                setState(() => selectedTextColor = 1);
                                widget.onTextColorChanged(currentTextColors[1]);
                              },
                            ),
                            // Green
                            _ColorOption(
                              color: currentTextColors[2],
                              label: 'A',
                              selected: selectedTextColor == 2,
                              onTap: () {
                                setState(() => selectedTextColor = 2);
                                widget.onTextColorChanged(currentTextColors[2]);
                              },
                            ),
                            // Blue
                            _ColorOption(
                              color: currentTextColors[3],
                              label: 'A',
                              selected: selectedTextColor == 3,
                              onTap: () {
                                setState(() => selectedTextColor = 3);
                                widget.onTextColorChanged(currentTextColors[3]);
                              },
                            ),
                            // Purple
                            _ColorOption(
                              color: currentTextColors[4],
                              label: 'A',
                              selected: selectedTextColor == 4,
                              onTap: () {
                                setState(() => selectedTextColor = 4);
                                widget.onTextColorChanged(currentTextColors[4]);
                              },
                            ),
                            // Red
                            _ColorOption(
                              color: currentTextColors[5],
                              label: 'A',
                              selected: selectedTextColor == 5,
                              onTap: () {
                                setState(() => selectedTextColor = 5);
                                widget.onTextColorChanged(currentTextColors[5]);
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Background color section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Background',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Background reset button
                            GestureDetector(
                              onTap: () {
                                setState(() => selectedBgColor = -1);
                                widget.onBackgroundColorChanged(
                                    Colors.transparent);
                              },
                              child: Container(
                                width: finalSize,
                                height: finalSize,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedBgColor == -1
                                        ? isDarkMode
                                            ? Colors.white
                                            : Colors.black
                                        : Theme.of(context)
                                            .dividerColor
                                            .withAlpha(26),
                                    width: selectedBgColor == -1 ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: selectedBgColor == -1
                                      ? Icon(
                                          Icons.check,
                                          color: isDarkMode
                                              ? Colors.white
                                              : Colors.black,
                                          size: finalSize * 0.5,
                                        )
                                      : Icon(
                                          Icons.format_color_reset,
                                          color: Theme.of(context)
                                              .dividerColor
                                              .withAlpha(128),
                                          size: finalSize * 0.5,
                                        ),
                                ),
                              ),
                            ),
                            ...List.generate(currentBgColors.length, (i) {
                              return _ColorOption(
                                color: currentBgColors[i],
                                label: 'A',
                                selected: selectedBgColor == i,
                                isBackground: true,
                                onTap: () {
                                  setState(() => selectedBgColor = i);
                                  widget.onBackgroundColorChanged(
                                      currentBgColors[i]);
                                },
                              );
                            }),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
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
  final bool isUnderline;

  const _ColorOption({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
    this.isBackground = false,
    this.isUnderline = false,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Calculate button size based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32; // Account for horizontal padding
    final buttonSize =
        (availableWidth - 12) / 7; // 12 is total margin space (6 gaps * 2px)
    final finalSize = buttonSize.clamp(40.0, 54.0);

    // For background colors, use the corresponding text color for outline and checkmark
    Color outlineColor;
    if (isBackground && selected) {
      // Map background colors to their corresponding text colors
      // Yellow background -> Yellow text
      // Green background -> Green text
      // Blue background -> Blue text
      // Purple background -> Purple text
      // Red background -> Red text
      if (color == ToolbarActions.bgColorPairs[0].$1) {
        outlineColor = ToolbarActions.textColorPairs[1].$1; // Yellow
      } else if (color == ToolbarActions.bgColorPairs[1].$1) {
        outlineColor = ToolbarActions.textColorPairs[2].$1; // Green
      } else if (color == ToolbarActions.bgColorPairs[2].$1) {
        outlineColor = ToolbarActions.textColorPairs[3].$1; // Blue
      } else if (color == ToolbarActions.bgColorPairs[3].$1) {
        outlineColor = ToolbarActions.textColorPairs[4].$1; // Purple
      } else if (color == ToolbarActions.bgColorPairs[4].$1) {
        outlineColor = ToolbarActions.textColorPairs[5].$1; // Red
      } else {
        outlineColor = color; // Fallback
      }
    } else {
      outlineColor =
          selected ? color : Theme.of(context).dividerColor.withAlpha(26);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: finalSize,
        height: finalSize,
        margin: const EdgeInsets.symmetric(horizontal: 1),
        decoration: BoxDecoration(
          border: Border.all(
            color: outlineColor,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: isBackground && (!selected || !isDarkMode)
              ? color
              : Colors.transparent,
        ),
        child: Center(
          child: selected
              ? Icon(Icons.check, color: outlineColor)
              : isUnderline
                  ? Icon(
                      Icons.text_format,
                      color: color,
                      size: finalSize * 0.6,
                    )
                  : Text(
                      label,
                      style: TextStyle(
                        color: color,
                        fontSize: finalSize * 0.4,
                        fontWeight: FontWeight.bold,
                        decoration:
                            isUnderline ? TextDecoration.underline : null,
                        decorationColor: color,
                        decorationThickness: 1,
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
