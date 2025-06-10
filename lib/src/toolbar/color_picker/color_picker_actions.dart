import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/src/toolbar/color_picker/color_picker_constants.dart';
import 'dart:math';
import 'package:journal_core/src/theme/journal_theme.dart';

/// Manages color picker actions for the journal editor
class ColorPickerActions {
  final EditorState editorState;
  final BuildContext context;
  Selection? _visualSelection;

  set visualSelection(Selection? selection) {
    _visualSelection = selection;
  }

  ColorPickerActions({
    required this.editorState,
    required this.context,
  });

  void setTextColor(Color color) {
    print('Setting text color to ${color.value.toRadixString(16)}');
    final selection = _visualSelection ?? editorState.selection;
    if (selection == null) {
      print('No selection found');
      return;
    }

    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      print('No node found at path');
      return;
    }

    final attributes = node.attributes;
    final delta = attributes['delta'] as List? ?? [];
    if (delta.isEmpty) {
      print('Empty delta found');
      return;
    }

    print('Current delta: $delta');

    final transaction = editorState.transaction;
    final newDelta = <Map<String, dynamic>>[];
    var currentOffset = 0;

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
      print('Processing text: "$opText" with attributes: $opAttributes');

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

        print(
            'Split text: before="$beforeSelection", selected="$selectedText", after="$afterSelection"');

        if (beforeSelection.isNotEmpty) {
          newDelta.add({
            'insert': beforeSelection,
            'attributes': Map<String, dynamic>.from(opAttributes),
          });
        }

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
          print('New attributes for selected text: $newAttributes');
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

    print('Final new delta: $newDelta');
    transaction.updateNode(node, {'delta': newDelta});
    editorState.apply(transaction);
  }

  void setBackgroundColor(Color color) {
    print('Setting background color to ${color.value.toRadixString(16)}');
    final selection = _visualSelection ?? editorState.selection;
    if (selection == null) {
      print('No selection found');
      return;
    }

    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      print('No node found at path');
      return;
    }

    final attributes = node.attributes;
    final delta = attributes['delta'] as List? ?? [];
    if (delta.isEmpty) {
      print('Empty delta found');
      return;
    }

    print('Current delta: $delta');

    final transaction = editorState.transaction;
    final newDelta = <Map<String, dynamic>>[];
    var currentOffset = 0;

    // Find the color index
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    int colorIndex = -1;
    for (int i = 0; i < ColorPickerConstants.bgColorPairs.length; i++) {
      final (lightColor, darkColor) = ColorPickerConstants.bgColorPairs[i];
      if (color == (isDarkMode ? darkColor : lightColor)) {
        colorIndex = i;
        break;
      }
    }

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
      print('Processing text: "$opText" with attributes: $opAttributes');

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

        print(
            'Split text: before="$beforeSelection", selected="$selectedText", after="$afterSelection"');

        if (beforeSelection.isNotEmpty) {
          newDelta.add({
            'insert': beforeSelection,
            'attributes': Map<String, dynamic>.from(opAttributes),
          });
        }

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
          print('New attributes for selected text: $newAttributes');
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

    print('Final new delta: $newDelta');
    transaction.updateNode(node, {'delta': newDelta});
    editorState.apply(transaction);
  }

  void setUnderlineColor(Color color) {
    print('Setting underline color to: ${color.value.toRadixString(16)}');
    final selection = _visualSelection ?? editorState.selection;
    if (selection == null) {
      print('No selection found');
      return;
    }

    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      print('No node found at path');
      return;
    }

    final attributes = node.attributes;
    final delta = attributes['delta'] as List? ?? [];
    if (delta.isEmpty) {
      print('Empty delta found');
      return;
    }

    print('Current delta: $delta');

    final transaction = editorState.transaction;
    final newDelta = <Map<String, dynamic>>[];
    var currentOffset = 0;

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
      print('Processing text: "$opText" with attributes: $opAttributes');

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

        print(
            'Split text: before="$beforeSelection", selected="$selectedText", after="$afterSelection"');

        if (beforeSelection.isNotEmpty) {
          newDelta.add({
            'insert': beforeSelection,
            'attributes': Map<String, dynamic>.from(opAttributes),
          });
        }

        if (selectedText.isNotEmpty) {
          final newAttributes = Map<String, dynamic>.from(opAttributes);

          // Always set underline and color
          newAttributes['underline'] = true;
          newAttributes['underlineColor'] = color == Colors.transparent
              ? null
              : 'FF${color.value.toRadixString(16).substring(2)}';

          // Keep existing style or use default
          if (opAttributes['underlineStyle'] == null) {
            newAttributes['underlineStyle'] = 'solid';
          }

          // Keep existing color or use default
          if (opAttributes['underlineColor'] == null) {
            final theme =
                JournalTheme.fromBrightness(Theme.of(context).brightness);
            newAttributes['underlineColor'] =
                theme.primaryText.value.toRadixString(16).padLeft(8, '0');
          }

          print('New attributes for selected text: $newAttributes');
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

    print('Final new delta: $newDelta');
    transaction.updateNode(node, {'delta': newDelta});
    editorState.apply(transaction);
  }

  void setUnderlineStyle(String style) {
    print('Setting underline style to: $style');
    final selection = _visualSelection ?? editorState.selection;
    if (selection == null) {
      print('No selection found');
      return;
    }

    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) {
      print('No node found at path');
      return;
    }

    final attributes = node.attributes;
    final delta = attributes['delta'] as List? ?? [];
    if (delta.isEmpty) {
      print('Empty delta found');
      return;
    }

    print('Current delta: $delta');

    final transaction = editorState.transaction;
    final newDelta = <Map<String, dynamic>>[];
    var currentOffset = 0;

    for (final op in delta) {
      final opText = op['insert'] as String;
      final opLength = opText.length;
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
      print('Processing text: "$opText" with attributes: $opAttributes');

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

        print(
            'Split text: before="$beforeSelection", selected="$selectedText", after="$afterSelection"');

        if (beforeSelection.isNotEmpty) {
          newDelta.add({
            'insert': beforeSelection,
            'attributes': Map<String, dynamic>.from(opAttributes),
          });
        }

        if (selectedText.isNotEmpty) {
          final newAttributes = Map<String, dynamic>.from(opAttributes);

          if (style == 'none') {
            // Remove underline completely
            newAttributes.remove('underline');
            newAttributes.remove('underlineStyle');
            newAttributes.remove('underlineColor');
          } else {
            // Set underline and style
            newAttributes['underline'] = true;
            newAttributes['underlineStyle'] = style;

            // Keep existing color or use default
            if (opAttributes['underlineColor'] == null) {
              final theme =
                  JournalTheme.fromBrightness(Theme.of(context).brightness);
              newAttributes['underlineColor'] =
                  theme.primaryText.value.toRadixString(16).padLeft(8, '0');
            }
          }

          print('New attributes for selected text: $newAttributes');
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

    print('Final new delta: $newDelta');
    transaction.updateNode(node, {'delta': newDelta});
    editorState.apply(transaction);
  }
}
