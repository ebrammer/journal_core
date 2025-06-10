import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/src/toolbar/color_picker/color_picker_constants.dart';
import 'package:journal_core/src/toolbar/color_picker/color_picker_widgets.dart'
    as picker;
import 'package:journal_core/src/theme/journal_theme.dart';

class ColorPickerColumn extends StatefulWidget {
  final EditorState editorState;
  final Function(Color) onTextColorChanged;
  final Function(Color) onBackgroundColorChanged;
  final Function(Color) onUnderlineColorChanged;
  final Function(String) onUnderlineStyleChanged;
  final VoidCallback onDone;

  const ColorPickerColumn({
    super.key,
    required this.editorState,
    required this.onTextColorChanged,
    required this.onBackgroundColorChanged,
    required this.onUnderlineColorChanged,
    required this.onUnderlineStyleChanged,
    required this.onDone,
  });

  @override
  State<ColorPickerColumn> createState() => _ColorPickerColumnState();
}

class _ColorPickerColumnState extends State<ColorPickerColumn> {
  Color? _selectedTextColor;
  Color? _selectedBackgroundColor;
  Color? _selectedUnderlineColor;
  String _selectedUnderlineStyle = 'solid';

  @override
  void initState() {
    super.initState();
    _updateSelectedColors();
  }

  void _updateSelectedColors() {
    final selection = widget.editorState.selection;
    if (selection == null) return;

    final node = widget.editorState.getNodeAtPath(selection.start.path);
    if (node == null) return;

    final attributes = node.attributes;
    final delta = attributes['delta'] as List? ?? [];
    if (delta.isEmpty) return;

    if (selection.isCollapsed) {
      var currentOffset = 0;
      final cursorOffset = selection.start.offset;
      for (final op in delta) {
        final opText = op['insert'] as String;
        final opLength = opText.length;
        final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};
        if (currentOffset <= cursorOffset &&
            cursorOffset <= currentOffset + opLength) {
          setState(() {
            _selectedTextColor = _parseColor(opAttributes['text_color']);
            _selectedBackgroundColor =
                _parseColor(opAttributes['background_color']);
            _selectedUnderlineColor =
                _parseColor(opAttributes['underline_color']);
            _selectedUnderlineStyle =
                opAttributes['underline_style'] ?? 'solid';
          });
          break;
        }
        currentOffset += opLength;
      }
    }
  }

  Color? _parseColor(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return Color(int.parse(value.replaceAll('#', '0xFF')));
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Calculate button size based on screen width
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = screenWidth - 32; // Account for horizontal padding
    final buttonSize =
        (availableWidth - 12) / 7; // 12 is total margin space (6 gaps * 2px)
    final finalSize = buttonSize.clamp(40.0, 54.0);

    // Get keyboard height
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      color: theme.toolbarBackground,
      height: keyboardHeight > 0 ? keyboardHeight : null,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Underline section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Underline',
                        style: TextStyle(
                          color: isDarkMode ? Colors.white70 : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // Style buttons
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          picker.UnderlineStyleButton(
                            label: 'Solid',
                            isSelected: _selectedUnderlineStyle == 'solid',
                            onTap: () {
                              setState(() => _selectedUnderlineStyle = 'solid');
                              widget.onUnderlineStyleChanged('solid');
                            },
                          ),
                          Text(
                            ' | ',
                            style: TextStyle(
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black87,
                            ),
                          ),
                          picker.UnderlineStyleButton(
                            label: 'Dashed',
                            isSelected: _selectedUnderlineStyle == 'dashed',
                            onTap: () {
                              setState(
                                  () => _selectedUnderlineStyle = 'dashed');
                              widget.onUnderlineStyleChanged('dashed');
                            },
                          ),
                        ],
                      ),
                    ],
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
                            if (_selectedUnderlineStyle == 'solid') {
                              // If it's a solid underline, remove it completely
                              setState(() {
                                _selectedUnderlineColor = null;
                                _selectedUnderlineStyle = 'none';
                              });
                              widget
                                  .onUnderlineColorChanged(Colors.transparent);
                              widget.onUnderlineStyleChanged('none');
                            } else {
                              // Add normal underline
                              setState(() {
                                _selectedUnderlineColor = null;
                                _selectedUnderlineStyle = 'solid';
                              });
                              widget
                                  .onUnderlineColorChanged(Colors.transparent);
                              widget.onUnderlineStyleChanged('solid');
                            }
                          },
                          child: Container(
                            width: finalSize,
                            height: finalSize,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedUnderlineStyle == 'solid' &&
                                        _selectedUnderlineColor == null
                                    ? isDarkMode
                                        ? Colors.white
                                        : Colors.black
                                    : Theme.of(context)
                                        .dividerColor
                                        .withAlpha(26),
                                width: _selectedUnderlineStyle == 'solid' &&
                                        _selectedUnderlineColor == null
                                    ? 2
                                    : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.text_format,
                                color: isDarkMode ? Colors.white : Colors.black,
                                size: finalSize * 0.6,
                              ),
                            ),
                          ),
                        ),
                        ...ColorPickerConstants.underlineColorPairs.map((pair) {
                          final color = isDarkMode ? pair.$2 : pair.$1;
                          return picker.ColorOption(
                            color: color,
                            label: 'U',
                            selected: _selectedUnderlineColor == color &&
                                _selectedUnderlineStyle == 'solid',
                            onTap: () {
                              setState(() {
                                _selectedUnderlineColor = color;
                                _selectedUnderlineStyle = 'solid';
                              });
                              widget.onUnderlineColorChanged(color);
                              widget.onUnderlineStyleChanged('solid');
                            },
                            isUnderline: true,
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            // Text color section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                      children: ColorPickerConstants.textColorPairs.map((pair) {
                        final color = isDarkMode ? pair.$2 : pair.$1;
                        return picker.ColorOption(
                          color: color,
                          label: 'A',
                          selected: _selectedTextColor == color,
                          onTap: () {
                            setState(() => _selectedTextColor = color);
                            widget.onTextColorChanged(color);
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // Background color section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
                            setState(() => _selectedBackgroundColor = null);
                            widget.onBackgroundColorChanged(Colors.transparent);
                          },
                          child: Container(
                            width: finalSize,
                            height: finalSize,
                            margin: const EdgeInsets.symmetric(horizontal: 1),
                            decoration: BoxDecoration(
                              border: Border.all(
                                color: _selectedBackgroundColor == null
                                    ? isDarkMode
                                        ? Colors.white
                                        : Colors.black
                                    : Theme.of(context)
                                        .dividerColor
                                        .withAlpha(26),
                                width: _selectedBackgroundColor == null ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: _selectedBackgroundColor == null
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
                        ...ColorPickerConstants.bgColorPairs.map((pair) {
                          final color = isDarkMode ? pair.$2 : pair.$1;
                          return picker.ColorOption(
                            color: color,
                            label: 'A',
                            selected: _selectedBackgroundColor == color,
                            onTap: () {
                              setState(() => _selectedBackgroundColor = color);
                              widget.onBackgroundColorChanged(color);
                            },
                            isBackground: true,
                          );
                        }).toList(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
