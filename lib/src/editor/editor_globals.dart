// src/editor/editor_globals.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'dart:math';
import 'package:journal_core/src/toolbar/toolbar_actions.dart';

/// Globally accessible editor state & focus for components that can't access context.
class EditorGlobals {
  static EditorState? editorState;
  static FocusNode? editorFocusNode;
  static const String titleBlockType = 'title';
  static const int titleBlockLevel = 1;
  static const String titlePlaceholder = 'Untitled';
}

/// Theme configuration for the editor
class JournalEditorTheme {
  // Default colors
  static const Color primaryTextColor = Color(0xFF333333);
  static const Color secondaryTextColor = Color(0xFF666666);
  static const Color primaryBackgroundColor = Color(0xFFFFFFFF);
  static const Color accentBackgroundColor = Color(0xFFF5F5F5);
  static const Color highlightColor = Color(0xFFFFF176);

  // Block-specific colors
  static const Map<String, BlockTheme> blockThemes = {
    'prayer': BlockTheme(
      backgroundColor: Color(0xFFFDF9F2),
      borderColor: Color(0xFFEADBC0),
      textColor: Color(0xFF333333),
    ),
    'scripture': BlockTheme(
      backgroundColor: Color(0xFFF0F7FF),
      borderColor: Color(0xFFB3D4FF),
      textColor: Color(0xFF1A365D),
    ),
    'date': BlockTheme(
      backgroundColor: Color(0xFFF3F4F6),
      borderColor: Color(0xFFE5E7EB),
      textColor: Color(0xFF4B5563),
    ),
    'title': BlockTheme(
      backgroundColor: Color(0xFFFFFFFF),
      borderColor: Color(0xFFE5E7EB),
      textColor: Color(0xFF111827),
    ),
  };

  // Text styles
  static const TextStyle defaultTextStyle = TextStyle(
    fontSize: 16.0,
    color: primaryTextColor,
  );

  static const TextStyle boldTextStyle = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.bold,
    color: primaryTextColor,
  );

  static const TextStyle italicTextStyle = TextStyle(
    fontSize: 16.0,
    fontStyle: FontStyle.italic,
    color: secondaryTextColor,
  );

  // Editor-wide styles
  static EditorStyle get defaultEditorStyle => EditorStyle(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        cursorColor: primaryTextColor,
        dragHandleColor: primaryTextColor,
        selectionColor: highlightColor.withOpacity(0.3),
        textStyleConfiguration: TextStyleConfiguration(
          text: defaultTextStyle,
          bold: boldTextStyle,
          italic: italicTextStyle,
        ),
        textSpanDecorator: defaultTextSpanDecoratorForAttribute,
        cursorWidth: 2.0,
        textScaleFactor: 1.0,
      );
}

/// Theme configuration for a specific block type
class BlockTheme {
  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;

  const BlockTheme({
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
  });

  BoxDecoration get decoration => BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      );

  TextStyle get textStyle => TextStyle(
        color: textColor,
        fontSize: 16,
      );

  TextStyle get boldTextStyle => TextStyle(
        color: textColor,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      );
}

/// Default text span decorator that handles text attributes
TextSpan defaultTextSpanDecoratorForAttribute(
  BuildContext context,
  Node node,
  int index,
  TextInsert text,
  TextSpan before,
  TextSpan after,
) {
  final attributes = text.attributes;
  print(
      'TextSpanDecorator: Processing text "${text.text}" with attributes: $attributes');

  // Get the current selection
  final selection = EditorGlobals.editorState?.selection;

  // Create spans for each part
  final spans = <TextSpan>[];

  // Apply attributes to the text
  var style = before.style ?? const TextStyle();
  if (attributes != null) {
    if (attributes['bold'] == true) {
      style = style.copyWith(fontWeight: FontWeight.bold);
    }
    if (attributes['italic'] == true) {
      style = style.copyWith(fontStyle: FontStyle.italic);
    }
    if (attributes['underline'] == true) {
      final underlineColor = attributes['underlineColor'] as String?;
      if (underlineColor != null) {
        final color = Color(int.parse(underlineColor, radix: 16));
        final underlineStyle =
            attributes['underlineStyle'] as String? ?? 'solid';
        print('TextSpanDecorator: Found underline style: $underlineStyle');
        var decorationStyle = TextDecorationStyle.solid;
        switch (underlineStyle) {
          case 'dashed':
            decorationStyle = TextDecorationStyle.dashed;
            break;
          default:
            decorationStyle = TextDecorationStyle.solid;
        }
        print(
            'TextSpanDecorator: Setting decoration style to: $decorationStyle');

        // Apply the style
        style = style.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: color,
          decorationStyle: decorationStyle,
          decorationThickness: 1.0,
        );
      }
    }
    if (attributes['strikethrough'] == true) {
      style = style.copyWith(decoration: TextDecoration.lineThrough);
    }
    if (attributes['color'] != null) {
      final colorHex = attributes['color'] as String;
      print('TextSpanDecorator: Found text color: $colorHex');
      final color = Color(int.parse(colorHex, radix: 16));
      style = style.copyWith(color: color);
      print(
          'TextSpanDecorator: Applied text color: ${color.value.toRadixString(16)}');
    }

    // Handle background color
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final colorIndex = attributes['backgroundColorIndex'] as int?;
    if (colorIndex != null && colorIndex >= 0) {
      // Get the theme-aware color from ToolbarActions
      final (lightColor, darkColor) = ToolbarActions.bgColorPairs[colorIndex];
      final color = isDarkMode ? darkColor : lightColor;
      print('TextSpanDecorator: Found background color index: $colorIndex');
      style = style.copyWith(backgroundColor: color);
      print(
          'TextSpanDecorator: Applied theme-aware background color: ${color.value.toRadixString(16)}');
    }
  }

  // If there's no selection, just return the styled text
  if (selection == null) {
    return TextSpan(text: text.text, style: style);
  }

  // Calculate the text boundaries
  final nodePath = node.path;
  final nodeOffset = node.delta?.length ?? 0;
  final selectionStart =
      selection.start.path == nodePath ? selection.start.offset : 0;
  final selectionEnd =
      selection.end.path == nodePath ? selection.end.offset : nodeOffset;

  // If this text is outside the selection range, return it with its style
  if (index + text.text.length <= selectionStart || index >= selectionEnd) {
    print('TextSpanDecorator: Text outside selection range, keeping as is');
    return TextSpan(text: text.text, style: style);
  }

  // Calculate the split points relative to this text chunk
  final start = max(0, selectionStart - index);
  final end = min(text.text.length, selectionEnd - index);

  // Split the text
  final beforeText = text.text.substring(0, start);
  final selectedText = text.text.substring(start, end);
  final afterText = text.text.substring(end);

  print(
      'TextSpanDecorator: Split text into: before="$beforeText", selected="$selectedText", after="$afterText"');

  // Add before text
  if (beforeText.isNotEmpty) {
    spans.add(TextSpan(text: beforeText, style: style));
  }

  // Add selected text
  if (selectedText.isNotEmpty) {
    spans.add(TextSpan(text: selectedText, style: style));
  }

  // Add after text
  if (afterText.isNotEmpty) {
    spans.add(TextSpan(text: afterText, style: style));
  }

  // If we have multiple spans, combine them
  if (spans.length > 1) {
    final result = TextSpan(children: spans);
    print(
        'TextSpanDecorator: Returning combined span with ${spans.length} children');
    return result;
  }

  // If we only have one span, return it directly
  final result = spans.first;
  print(
      'TextSpanDecorator: Returning single span with text "${result.text}" and style: ${result.style?.toString()}');
  return result;
}

// Add this class at the end of the file
class DottedUnderlinePainter extends CustomPainter {
  final Color color;
  final double dotSize;
  final double dotSpacing;

  DottedUnderlinePainter({
    required this.color,
    required this.dotSize,
    required this.dotSpacing,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = dotSize
      ..strokeCap = StrokeCap.round;

    double x = 0;
    while (x < size.width) {
      canvas.drawLine(
        Offset(x, size.height / 2),
        Offset(x, size.height / 2),
        paint,
      );
      x += dotSpacing;
    }
  }

  @override
  bool shouldRepaint(DottedUnderlinePainter oldDelegate) {
    return color != oldDelegate.color ||
        dotSize != oldDelegate.dotSize ||
        dotSpacing != oldDelegate.dotSpacing;
  }
}
