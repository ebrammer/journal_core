import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:journal_core/journal_core.dart';
import '../theme/journal_theme.dart';
import '../blocks/divider_block.dart' as divider;
import '../toolbar/color_picker/color_picker_constants.dart';

/// A read-only viewer that displays journal content with the same styling as the editor
class ReadOnlyViewer extends StatefulWidget {
  const ReadOnlyViewer({
    super.key,
    required this.journal,
    this.onContentTap,
  });

  final Journal journal;
  final Future<void> Function()? onContentTap;

  @override
  State<ReadOnlyViewer> createState() => _ReadOnlyViewerState();
}

class _ReadOnlyViewerState extends State<ReadOnlyViewer> {
  final ScrollController _scrollController = ScrollController();
  late final List<Map<String, dynamic>> _contentBlocks;

  @override
  void initState() {
    super.initState();
    // Extract content data as plain objects to prevent disposal issues
    _contentBlocks = _extractContentData();
  }

  List<Map<String, dynamic>> _extractContentData() {
    final children = widget.journal.content.root.children;
    final blocks = <Map<String, dynamic>>[];

    for (final node in children) {
      // Skip spacer blocks but include metadata blocks for title and date
      if (node.type == BlockTypeConstants.spacer) {
        continue;
      }

      // Extract node data as plain objects
      final blockData = {
        'type': node.type,
        'attributes': Map<String, dynamic>.from(node.attributes),
        'id': node.id,
      };

      blocks.add(blockData);
    }

    return blocks;
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);

    return Container(
      color: theme.primaryBackground,
      child: GestureDetector(
        onTap: () async {
          if (widget.onContentTap != null) {
            await widget.onContentTap!();
          }
        },
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Content blocks using extracted data
        ..._contentBlocks.map((blockData) => _buildBlock(blockData)),
      ],
    );
  }

  Widget _buildBlock(Map<String, dynamic> blockData) {
    final type = blockData['type'] as String;

    switch (type) {
      case BlockTypeConstants.metadata:
        return _buildMetadataBlock(blockData);
      case BlockTypeConstants.paragraph:
        return _buildParagraphBlock(blockData);
      case divider.DividerBlockKeys.type:
        return _buildDividerBlock(blockData);
      case BlockTypeConstants.heading:
        return _buildHeadingBlock(blockData);
      case BlockTypeConstants.bulletedList:
      case BlockTypeConstants.numberedList:
        return _buildListBlock(blockData);
      case BlockTypeConstants.todoList:
        return _buildTodoListBlock(blockData);
      case BlockTypeConstants.quote:
        return _buildQuoteBlock(blockData);
      default:
        return _buildUnknownBlock(blockData);
    }
  }

  Widget _buildMetadataBlock(Map<String, dynamic> blockData) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);

    // Get the title from the journal
    final title = widget.journal.title;
    final createdAt = widget.journal.createdAt;

    // Format the date
    final formattedDate = DateFormat('MMMM d, yyyy')
        .format(DateTime.fromMillisecondsSinceEpoch(createdAt));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.isEmpty ? 'Title' : title,
            style: TextStyle(
              fontSize: 24.0,
              fontWeight: FontWeight.w700,
              color: theme.primaryText,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 4.0),
          Text(
            formattedDate,
            style: TextStyle(
              fontSize: 14.0,
              color: theme.secondaryText,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParagraphBlock(Map<String, dynamic> blockData) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final attributes = blockData['attributes'] as Map<String, dynamic>;
    final delta = attributes['delta'] as List<dynamic>?;

    if (delta == null || delta.isEmpty) {
      return const SizedBox(height: 16.0);
    }

    final textSpans = <TextSpan>[];

    for (final op in delta) {
      final text = op['insert'] as String? ?? '';
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};

      TextStyle style = TextStyle(
        fontSize: 16,
        height: 1.5,
        color: theme.primaryText,
      );

      // Apply text styling
      if (opAttributes['bold'] == true) {
        style = style.copyWith(fontWeight: FontWeight.bold);
      }
      if (opAttributes['italic'] == true) {
        style = style.copyWith(fontStyle: FontStyle.italic);
      }
      if (opAttributes['underline'] == true) {
        final underlineColor = opAttributes['underlineColor'] as String?;
        final underlineStyle =
            opAttributes['underlineStyle'] as String? ?? 'solid';

        if (underlineColor != null) {
          final color = Color(int.parse(underlineColor, radix: 16));
          var decorationStyle = TextDecorationStyle.solid;
          switch (underlineStyle) {
            case 'dashed':
              decorationStyle = TextDecorationStyle.dashed;
              break;
            default:
              decorationStyle = TextDecorationStyle.solid;
          }

          style = style.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: color,
            decorationStyle: decorationStyle,
            decorationThickness: 1.0,
          );
        } else {
          style = style.copyWith(decoration: TextDecoration.underline);
        }
      }
      if (opAttributes['strikethrough'] == true) {
        style = style.copyWith(decoration: TextDecoration.lineThrough);
      }

      // Apply text color
      if (opAttributes['color'] != null) {
        final colorHex = opAttributes['color'] as String;
        final color = Color(int.parse(colorHex, radix: 16));
        style = style.copyWith(color: color);
      }

      // Apply background color
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      final colorIndex = opAttributes['backgroundColorIndex'] as int?;
      if (colorIndex != null &&
          colorIndex >= 0 &&
          colorIndex < ColorPickerConstants.bgColorPairs.length) {
        final (lightColor, darkColor) =
            ColorPickerConstants.bgColorPairs[colorIndex];
        final color = isDarkMode ? darkColor : lightColor;
        style = style.copyWith(backgroundColor: color);
      }

      textSpans.add(TextSpan(text: text, style: style));
    }

    // Get alignment from block attributes
    final align = attributes['align'] as String? ?? 'left';
    TextAlign textAlign;
    switch (align) {
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      default:
        textAlign = TextAlign.left;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: RichText(
        textAlign: textAlign,
        text: TextSpan(children: textSpans),
      ),
    );
  }

  Widget _buildHeadingBlock(Map<String, dynamic> blockData) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final attributes = blockData['attributes'] as Map<String, dynamic>;
    final delta = attributes['delta'] as List<dynamic>?;

    if (delta == null || delta.isEmpty) {
      return const SizedBox(height: 16.0);
    }

    final textSpans = <TextSpan>[];

    for (final op in delta) {
      final text = op['insert'] as String? ?? '';
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};

      // Get heading level from attributes, default to 1
      final level = attributes['level'] as int? ?? 1;

      double fontSize;
      FontWeight fontWeight;

      switch (level) {
        case 1:
          fontSize = 24.0;
          fontWeight = FontWeight.bold;
          break;
        case 2:
          fontSize = 20.0;
          fontWeight = FontWeight.bold;
          break;
        case 3:
          fontSize = 18.0;
          fontWeight = FontWeight.w600;
          break;
        default:
          fontSize = 16.0;
          fontWeight = FontWeight.normal;
      }

      TextStyle style = TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: theme.primaryText,
        height: 1.4,
      );

      // Apply text styling
      if (opAttributes['bold'] == true) {
        style = style.copyWith(fontWeight: FontWeight.bold);
      }
      if (opAttributes['italic'] == true) {
        style = style.copyWith(fontStyle: FontStyle.italic);
      }
      if (opAttributes['underline'] == true) {
        final underlineColor = opAttributes['underlineColor'] as String?;
        final underlineStyle =
            opAttributes['underlineStyle'] as String? ?? 'solid';

        if (underlineColor != null) {
          final color = Color(int.parse(underlineColor, radix: 16));
          var decorationStyle = TextDecorationStyle.solid;
          switch (underlineStyle) {
            case 'dashed':
              decorationStyle = TextDecorationStyle.dashed;
              break;
            default:
              decorationStyle = TextDecorationStyle.solid;
          }

          style = style.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: color,
            decorationStyle: decorationStyle,
            decorationThickness: 1.0,
          );
        } else {
          style = style.copyWith(decoration: TextDecoration.underline);
        }
      }
      if (opAttributes['strikethrough'] == true) {
        style = style.copyWith(decoration: TextDecoration.lineThrough);
      }

      // Apply text color
      if (opAttributes['color'] != null) {
        final colorHex = opAttributes['color'] as String;
        final color = Color(int.parse(colorHex, radix: 16));
        style = style.copyWith(color: color);
      }

      // Apply background color
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      final colorIndex = opAttributes['backgroundColorIndex'] as int?;
      if (colorIndex != null &&
          colorIndex >= 0 &&
          colorIndex < ColorPickerConstants.bgColorPairs.length) {
        final (lightColor, darkColor) =
            ColorPickerConstants.bgColorPairs[colorIndex];
        final color = isDarkMode ? darkColor : lightColor;
        style = style.copyWith(backgroundColor: color);
      }

      textSpans.add(TextSpan(text: text, style: style));
    }

    // Get alignment from block attributes
    final align = attributes['align'] as String? ?? 'left';
    TextAlign textAlign;
    switch (align) {
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      default:
        textAlign = TextAlign.left;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: RichText(
        textAlign: textAlign,
        text: TextSpan(children: textSpans),
      ),
    );
  }

  Widget _buildListBlock(Map<String, dynamic> blockData) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final attributes = blockData['attributes'] as Map<String, dynamic>;
    final delta = attributes['delta'] as List<dynamic>?;

    if (delta == null || delta.isEmpty) {
      return const SizedBox(height: 16.0);
    }

    final textSpans = <TextSpan>[];
    final isNumbered = blockData['type'] == BlockTypeConstants.numberedList;
    final indent = attributes['indent'] as int? ?? 0;

    for (final op in delta) {
      final text = op['insert'] as String? ?? '';
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};

      TextStyle style = TextStyle(
        fontSize: 16,
        height: 1.5,
        color: theme.primaryText,
      );

      // Apply text styling
      if (opAttributes['bold'] == true) {
        style = style.copyWith(fontWeight: FontWeight.bold);
      }
      if (opAttributes['italic'] == true) {
        style = style.copyWith(fontStyle: FontStyle.italic);
      }
      if (opAttributes['underline'] == true) {
        final underlineColor = opAttributes['underlineColor'] as String?;
        final underlineStyle =
            opAttributes['underlineStyle'] as String? ?? 'solid';

        if (underlineColor != null) {
          final color = Color(int.parse(underlineColor, radix: 16));
          var decorationStyle = TextDecorationStyle.solid;
          switch (underlineStyle) {
            case 'dashed':
              decorationStyle = TextDecorationStyle.dashed;
              break;
            default:
              decorationStyle = TextDecorationStyle.solid;
          }

          style = style.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: color,
            decorationStyle: decorationStyle,
            decorationThickness: 1.0,
          );
        } else {
          style = style.copyWith(decoration: TextDecoration.underline);
        }
      }
      if (opAttributes['strikethrough'] == true) {
        style = style.copyWith(decoration: TextDecoration.lineThrough);
      }

      // Apply text color
      if (opAttributes['color'] != null) {
        final colorHex = opAttributes['color'] as String;
        final color = Color(int.parse(colorHex, radix: 16));
        style = style.copyWith(color: color);
      }

      // Apply background color
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      final colorIndex = opAttributes['backgroundColorIndex'] as int?;
      if (colorIndex != null &&
          colorIndex >= 0 &&
          colorIndex < ColorPickerConstants.bgColorPairs.length) {
        final (lightColor, darkColor) =
            ColorPickerConstants.bgColorPairs[colorIndex];
        final color = isDarkMode ? darkColor : lightColor;
        style = style.copyWith(backgroundColor: color);
      }

      textSpans.add(TextSpan(text: text, style: style));
    }

    // Get alignment from block attributes
    final align = attributes['align'] as String? ?? 'left';
    TextAlign textAlign;
    MainAxisAlignment rowAlignment;
    switch (align) {
      case 'center':
        textAlign = TextAlign.center;
        rowAlignment = MainAxisAlignment.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        rowAlignment = MainAxisAlignment.end;
        break;
      default:
        textAlign = TextAlign.left;
        rowAlignment = MainAxisAlignment.start;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: rowAlignment,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rowAlignment == MainAxisAlignment.start) ...[
            SizedBox(
              width: 24.0 + (indent * 16.0),
              child: Padding(
                padding: EdgeInsets.only(left: indent * 16.0),
                child: Text(
                  isNumbered ? '1.' : '•',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.primaryText,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8.0),
          ],
          Expanded(
            child: RichText(
              textAlign: textAlign,
              text: TextSpan(children: textSpans),
            ),
          ),
          if (rowAlignment == MainAxisAlignment.end) ...[
            const SizedBox(width: 8.0),
            SizedBox(
              width: 24.0 + (indent * 16.0),
              child: Padding(
                padding: EdgeInsets.only(right: indent * 16.0),
                child: Text(
                  isNumbered ? '1.' : '•',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.primaryText,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTodoListBlock(Map<String, dynamic> blockData) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final attributes = blockData['attributes'] as Map<String, dynamic>;
    final delta = attributes['delta'] as List<dynamic>?;

    if (delta == null || delta.isEmpty) {
      return const SizedBox(height: 16.0);
    }

    final textSpans = <TextSpan>[];
    final isChecked = attributes['checked'] as bool? ?? false;
    final indent = attributes['indent'] as int? ?? 0;

    for (final op in delta) {
      final text = op['insert'] as String? ?? '';
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};

      TextStyle style = TextStyle(
        fontSize: 16,
        height: 1.5,
        color: theme.primaryText,
        decoration: isChecked ? TextDecoration.lineThrough : null,
      );

      // Apply text styling
      if (opAttributes['bold'] == true) {
        style = style.copyWith(fontWeight: FontWeight.bold);
      }
      if (opAttributes['italic'] == true) {
        style = style.copyWith(fontStyle: FontStyle.italic);
      }
      if (opAttributes['underline'] == true) {
        final underlineColor = opAttributes['underlineColor'] as String?;
        final underlineStyle =
            opAttributes['underlineStyle'] as String? ?? 'solid';

        if (underlineColor != null) {
          final color = Color(int.parse(underlineColor, radix: 16));
          var decorationStyle = TextDecorationStyle.solid;
          switch (underlineStyle) {
            case 'dashed':
              decorationStyle = TextDecorationStyle.dashed;
              break;
            default:
              decorationStyle = TextDecorationStyle.solid;
          }

          // Combine with existing strikethrough if checked
          final existingDecorations =
              isChecked ? TextDecoration.lineThrough : TextDecoration.none;
          final newDecorations = TextDecoration.combine([
            existingDecorations,
            TextDecoration.underline,
          ]);

          style = style.copyWith(
            decoration: newDecorations,
            decorationColor: color,
            decorationStyle: decorationStyle,
            decorationThickness: 1.0,
          );
        } else {
          final existingDecorations =
              isChecked ? TextDecoration.lineThrough : TextDecoration.none;
          final newDecorations = TextDecoration.combine([
            existingDecorations,
            TextDecoration.underline,
          ]);
          style = style.copyWith(decoration: newDecorations);
        }
      }
      if (opAttributes['strikethrough'] == true) {
        final existingDecorations =
            isChecked ? TextDecoration.lineThrough : TextDecoration.none;
        final newDecorations = TextDecoration.combine([
          existingDecorations,
          TextDecoration.lineThrough,
        ]);
        style = style.copyWith(decoration: newDecorations);
      }

      // Apply text color
      if (opAttributes['color'] != null) {
        final colorHex = opAttributes['color'] as String;
        final color = Color(int.parse(colorHex, radix: 16));
        style = style.copyWith(color: color);
      }

      // Apply background color
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      final colorIndex = opAttributes['backgroundColorIndex'] as int?;
      if (colorIndex != null &&
          colorIndex >= 0 &&
          colorIndex < ColorPickerConstants.bgColorPairs.length) {
        final (lightColor, darkColor) =
            ColorPickerConstants.bgColorPairs[colorIndex];
        final color = isDarkMode ? darkColor : lightColor;
        style = style.copyWith(backgroundColor: color);
      }

      textSpans.add(TextSpan(text: text, style: style));
    }

    // Get alignment from block attributes
    final align = attributes['align'] as String? ?? 'left';
    TextAlign textAlign;
    MainAxisAlignment rowAlignment;
    switch (align) {
      case 'center':
        textAlign = TextAlign.center;
        rowAlignment = MainAxisAlignment.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        rowAlignment = MainAxisAlignment.end;
        break;
      default:
        textAlign = TextAlign.left;
        rowAlignment = MainAxisAlignment.start;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: rowAlignment,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (rowAlignment == MainAxisAlignment.start) ...[
            SizedBox(
              width: 24.0 + (indent * 16.0),
              child: Padding(
                padding: EdgeInsets.only(left: indent * 16.0),
                child: Icon(
                  isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20,
                  color: theme.primaryText,
                ),
              ),
            ),
            const SizedBox(width: 8.0),
          ],
          Expanded(
            child: RichText(
              textAlign: textAlign,
              text: TextSpan(children: textSpans),
            ),
          ),
          if (rowAlignment == MainAxisAlignment.end) ...[
            const SizedBox(width: 8.0),
            SizedBox(
              width: 24.0 + (indent * 16.0),
              child: Padding(
                padding: EdgeInsets.only(right: indent * 16.0),
                child: Icon(
                  isChecked ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 20,
                  color: theme.primaryText,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuoteBlock(Map<String, dynamic> blockData) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final attributes = blockData['attributes'] as Map<String, dynamic>;
    final delta = attributes['delta'] as List<dynamic>?;

    if (delta == null || delta.isEmpty) {
      return const SizedBox(height: 16.0);
    }

    final textSpans = <TextSpan>[];

    for (final op in delta) {
      final text = op['insert'] as String? ?? '';
      final opAttributes = op['attributes'] as Map<String, dynamic>? ?? {};

      TextStyle style = TextStyle(
        fontSize: 16,
        height: 1.5,
        color: theme.primaryText,
        // Don't force italic by default - let user styling control it
      );

      // Apply text styling
      if (opAttributes['bold'] == true) {
        style = style.copyWith(fontWeight: FontWeight.bold);
      }
      if (opAttributes['italic'] == true) {
        style = style.copyWith(fontStyle: FontStyle.italic);
      }
      if (opAttributes['underline'] == true) {
        final underlineColor = opAttributes['underlineColor'] as String?;
        final underlineStyle =
            opAttributes['underlineStyle'] as String? ?? 'solid';

        if (underlineColor != null) {
          final color = Color(int.parse(underlineColor, radix: 16));
          var decorationStyle = TextDecorationStyle.solid;
          switch (underlineStyle) {
            case 'dashed':
              decorationStyle = TextDecorationStyle.dashed;
              break;
            default:
              decorationStyle = TextDecorationStyle.solid;
          }

          style = style.copyWith(
            decoration: TextDecoration.underline,
            decorationColor: color,
            decorationStyle: decorationStyle,
            decorationThickness: 1.0,
          );
        } else {
          style = style.copyWith(decoration: TextDecoration.underline);
        }
      }
      if (opAttributes['strikethrough'] == true) {
        style = style.copyWith(decoration: TextDecoration.lineThrough);
      }

      // Apply text color
      if (opAttributes['color'] != null) {
        final colorHex = opAttributes['color'] as String;
        final color = Color(int.parse(colorHex, radix: 16));
        style = style.copyWith(color: color);
      }

      // Apply background color
      final isDarkMode = Theme.of(context).brightness == Brightness.dark;
      final colorIndex = opAttributes['backgroundColorIndex'] as int?;
      if (colorIndex != null &&
          colorIndex >= 0 &&
          colorIndex < ColorPickerConstants.bgColorPairs.length) {
        final (lightColor, darkColor) =
            ColorPickerConstants.bgColorPairs[colorIndex];
        final color = isDarkMode ? darkColor : lightColor;
        style = style.copyWith(backgroundColor: color);
      }

      textSpans.add(TextSpan(text: text, style: style));
    }

    // Get alignment from block attributes
    final align = attributes['align'] as String? ?? 'left';
    TextAlign textAlign;
    switch (align) {
      case 'center':
        textAlign = TextAlign.center;
        break;
      case 'right':
        textAlign = TextAlign.right;
        break;
      default:
        textAlign = TextAlign.left;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
            width: 3.0,
          ),
        ),
        color: isDarkMode
            ? Colors.grey[850]!.withValues(alpha: 0.3)
            : Colors.grey[50]!.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(2.0),
      ),
      child: SizedBox(
        width: double.infinity,
        child: RichText(
          textAlign: textAlign,
          text: TextSpan(children: textSpans),
        ),
      ),
    );
  }

  Widget _buildDividerBlock(Map<String, dynamic> blockData) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16.0),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width / 3,
          height: 1,
          color: theme.primaryText,
        ),
      ),
    );
  }

  Widget _buildUnknownBlock(Map<String, dynamic> blockData) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: theme.secondaryText.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Unknown block type: ${blockData['type']}',
        style: TextStyle(
          fontSize: 14,
          color: theme.secondaryText,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
