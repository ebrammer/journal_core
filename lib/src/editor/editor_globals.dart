// src/editor/editor_globals.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

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
  if (attributes == null) {
    print('TextSpanDecorator: No attributes found, returning before span');
    return before;
  }

  var style = before.style ?? const TextStyle();
  if (attributes['bold'] == true) {
    style = style.copyWith(fontWeight: FontWeight.bold);
  }
  if (attributes['italic'] == true) {
    style = style.copyWith(fontStyle: FontStyle.italic);
  }
  if (attributes['underline'] == true) {
    style = style.copyWith(decoration: TextDecoration.underline);
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
  if (attributes['backgroundColor'] != null) {
    final colorHex = attributes['backgroundColor'] as String;
    print('TextSpanDecorator: Found background color: $colorHex');
    final color = Color(int.parse(colorHex, radix: 16));
    style = style.copyWith(backgroundColor: color);
    print(
        'TextSpanDecorator: Applied background color: ${color.value.toRadixString(16)}');
  }
  final result = TextSpan(text: text.text, style: style);
  print(
      'TextSpanDecorator: Returning styled span with text "${text.text}" and style: ${style.toString()}');
  return result;
}
