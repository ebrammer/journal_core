import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/src/toolbar/color_picker/color_picker_constants.dart';

/// A bottom sheet widget for picking colors
class ColorPickerBottomSheet extends StatefulWidget {
  final ValueChanged<Color> onTextColorChanged;
  final ValueChanged<Color> onBackgroundColorChanged;
  final ValueChanged<Color> onUnderlineColorChanged;
  final ValueChanged<String> onUnderlineStyleChanged;
  final VoidCallback onDone;
  final EditorState editorState;

  const ColorPickerBottomSheet({
    required this.onTextColorChanged,
    required this.onBackgroundColorChanged,
    required this.onUnderlineColorChanged,
    required this.onUnderlineStyleChanged,
    required this.onDone,
    required this.editorState,
    Key? key,
  }) : super(key: key);

  @override
  State<ColorPickerBottomSheet> createState() => _ColorPickerBottomSheetState();
}

class _ColorPickerBottomSheetState extends State<ColorPickerBottomSheet> {
  late int selectedTextColor;
  late int selectedBgColor;
  late int selectedUnderlineColor;
  String selectedUnderlineStyle = 'solid';
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    selectedTextColor = 0;
    selectedBgColor = -1;
    selectedUnderlineColor = -1;
  }

  void setUnderlineStyle(String style) {
    setState(() => selectedUnderlineStyle = style);
    widget.onUnderlineStyleChanged(style);
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
      String? lastUnderlineStyle;

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
            lastUnderlineStyle =
                opAttributes['underlineStyle'] as String? ?? 'solid';
          }
        }
        currentOffset += opLength;
      }

      if (foundTextColor && lastTextColor != null) {
        for (int i = 0; i < ColorPickerConstants.textColorPairs.length; i++) {
          if (ColorPickerConstants.textColorPairs[i].$1 == lastTextColor ||
              ColorPickerConstants.textColorPairs[i].$2 == lastTextColor) {
            setState(() => selectedTextColor = i);
            break;
          }
        }
      } else {
        setState(() => selectedTextColor = 0);
      }

      if (foundBgColor && lastBgColor != null) {
        for (int i = 0; i < ColorPickerConstants.bgColorPairs.length; i++) {
          if (ColorPickerConstants.bgColorPairs[i].$1 == lastBgColor ||
              ColorPickerConstants.bgColorPairs[i].$2 == lastBgColor) {
            setState(() => selectedBgColor = i);
            break;
          }
        }
      } else {
        setState(() => selectedBgColor = -1);
      }

      if (foundUnderlineColor && lastUnderlineColor != null) {
        for (int i = 0;
            i < ColorPickerConstants.underlineColorPairs.length;
            i++) {
          if (ColorPickerConstants.underlineColorPairs[i].$1 ==
                  lastUnderlineColor ||
              ColorPickerConstants.underlineColorPairs[i].$2 ==
                  lastUnderlineColor) {
            setState(() {
              selectedUnderlineColor = i;
              selectedUnderlineStyle = lastUnderlineStyle ?? 'solid';
            });
            break;
          }
        }
      } else {
        setState(() {
          selectedUnderlineColor = -1;
          selectedUnderlineStyle = 'solid';
        });
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
          for (int i = 0; i < ColorPickerConstants.textColorPairs.length; i++) {
            if (ColorPickerConstants.textColorPairs[i].$1 == color ||
                ColorPickerConstants.textColorPairs[i].$2 == color) {
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
          for (int i = 0; i < ColorPickerConstants.bgColorPairs.length; i++) {
            if (ColorPickerConstants.bgColorPairs[i].$1 == color ||
                ColorPickerConstants.bgColorPairs[i].$2 == color) {
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
          for (int i = 0;
              i < ColorPickerConstants.underlineColorPairs.length;
              i++) {
            if (ColorPickerConstants.underlineColorPairs[i].$1 == color ||
                ColorPickerConstants.underlineColorPairs[i].$2 == color) {
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
    final (currentTextColors, currentBgColors, currentUnderlineColors) =
        ColorPickerConstants.getCurrentThemeColors(isDarkMode);

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
                  padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
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
                Divider(
                  height: 1,
                  color: isDarkMode
                      ? Colors.white.withAlpha(26)
                      : Colors.black.withAlpha(26),
                ),
                const SizedBox(height: 16),
                // Underline section
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Underline',
                            style: TextStyle(
                              color:
                                  isDarkMode ? Colors.white70 : Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          // Style buttons
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              UnderlineStyleButton(
                                label: 'Solid',
                                isSelected: selectedUnderlineStyle == 'solid',
                                onTap: () => setUnderlineStyle('solid'),
                              ),
                              Text(
                                ' | ',
                                style: TextStyle(
                                  color: isDarkMode
                                      ? Colors.white70
                                      : Colors.black87,
                                ),
                              ),
                              UnderlineStyleButton(
                                label: 'Dashed',
                                isSelected: selectedUnderlineStyle == 'dashed',
                                onTap: () => setUnderlineStyle('dashed'),
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
                                if (selectedUnderlineStyle == 'solid') {
                                  // If it's a solid underline, remove it completely
                                  setState(() {
                                    selectedUnderlineColor = -1;
                                    selectedUnderlineStyle = 'none';
                                  });
                                  widget.onUnderlineColorChanged(
                                      Colors.transparent);
                                  widget.onUnderlineStyleChanged('none');
                                } else {
                                  // Add normal underline
                                  setState(() {
                                    selectedUnderlineColor = -1;
                                    selectedUnderlineStyle = 'solid';
                                  });
                                  widget.onUnderlineColorChanged(
                                      Colors.transparent);
                                  widget.onUnderlineStyleChanged('solid');
                                }
                              },
                              child: Container(
                                width: finalSize,
                                height: finalSize,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 1),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: selectedUnderlineStyle == 'solid' &&
                                            selectedUnderlineColor == -1
                                        ? isDarkMode
                                            ? Colors.white
                                            : Colors.black
                                        : Theme.of(context)
                                            .dividerColor
                                            .withAlpha(26),
                                    width: selectedUnderlineStyle == 'solid' &&
                                            selectedUnderlineColor == -1
                                        ? 2
                                        : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.text_format,
                                    color: isDarkMode
                                        ? Colors.white
                                        : Colors.black,
                                    size: finalSize * 0.6,
                                  ),
                                ),
                              ),
                            ),
                            ...List.generate(currentUnderlineColors.length,
                                (i) {
                              return ColorOption(
                                color: currentUnderlineColors[i],
                                label: 'U',
                                selected: selectedUnderlineColor == i &&
                                    selectedUnderlineStyle == 'solid',
                                isUnderline: true,
                                onTap: () {
                                  setState(() {
                                    selectedUnderlineColor = i;
                                    selectedUnderlineStyle = 'solid';
                                  });
                                  widget.onUnderlineColorChanged(
                                      currentUnderlineColors[i]);
                                  widget.onUnderlineStyleChanged('solid');
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
                            ColorOption(
                              color: currentTextColors[0],
                              label: 'A',
                              selected: selectedTextColor == 0,
                              onTap: () {
                                setState(() => selectedTextColor = 0);
                                widget.onTextColorChanged(Colors.transparent);
                              },
                            ),
                            // Yellow
                            ColorOption(
                              color: currentTextColors[1],
                              label: 'A',
                              selected: selectedTextColor == 1,
                              onTap: () {
                                setState(() => selectedTextColor = 1);
                                widget.onTextColorChanged(currentTextColors[1]);
                              },
                            ),
                            // Green
                            ColorOption(
                              color: currentTextColors[2],
                              label: 'A',
                              selected: selectedTextColor == 2,
                              onTap: () {
                                setState(() => selectedTextColor = 2);
                                widget.onTextColorChanged(currentTextColors[2]);
                              },
                            ),
                            // Blue
                            ColorOption(
                              color: currentTextColors[3],
                              label: 'A',
                              selected: selectedTextColor == 3,
                              onTap: () {
                                setState(() => selectedTextColor = 3);
                                widget.onTextColorChanged(currentTextColors[3]);
                              },
                            ),
                            // Purple
                            ColorOption(
                              color: currentTextColors[4],
                              label: 'A',
                              selected: selectedTextColor == 4,
                              onTap: () {
                                setState(() => selectedTextColor = 4);
                                widget.onTextColorChanged(currentTextColors[4]);
                              },
                            ),
                            // Red
                            ColorOption(
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
                              return ColorOption(
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
                // Add bottom padding
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ColorOption extends StatelessWidget {
  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool isBackground;
  final bool isUnderline;

  const ColorOption({
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
      if (color == ColorPickerConstants.bgColorPairs[0].$1) {
        outlineColor = ColorPickerConstants.textColorPairs[1].$1; // Yellow
      } else if (color == ColorPickerConstants.bgColorPairs[1].$1) {
        outlineColor = ColorPickerConstants.textColorPairs[2].$1; // Green
      } else if (color == ColorPickerConstants.bgColorPairs[2].$1) {
        outlineColor = ColorPickerConstants.textColorPairs[3].$1; // Blue
      } else if (color == ColorPickerConstants.bgColorPairs[3].$1) {
        outlineColor = ColorPickerConstants.textColorPairs[4].$1; // Purple
      } else if (color == ColorPickerConstants.bgColorPairs[4].$1) {
        outlineColor = ColorPickerConstants.textColorPairs[5].$1; // Red
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

class UnderlineStyleButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const UnderlineStyleButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: isDarkMode ? Colors.white : Colors.black,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }
}
