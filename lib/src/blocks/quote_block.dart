import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import '../theme/journal_theme.dart';
import '../editor/editor_globals.dart';

/// Constants for quote block
class QuoteBlockKeys {
  const QuoteBlockKeys._();

  static const String type = 'quote';
}

/// Custom quote block builder that matches our read-only viewer styling
class QuoteBlockComponentBuilder extends BlockComponentBuilder {
  QuoteBlockComponentBuilder({
    this.configuration = const BlockComponentConfiguration(),
  });

  @override
  final BlockComponentConfiguration configuration;

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    final node = context.node;
    return QuoteBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (Node node) => node.type == QuoteBlockKeys.type;
}

/// Widget that renders a quote block with custom styling
class QuoteBlockComponentWidget extends StatefulWidget
    implements BlockComponentWidget {
  const QuoteBlockComponentWidget({
    super.key,
    required this.node,
    required this.configuration,
  });

  @override
  final Node node;

  @override
  final BlockComponentConfiguration configuration;

  @override
  BlockComponentActionBuilder? get actionBuilder => null;

  @override
  BlockComponentActionBuilder? get actionTrailingBuilder => null;

  @override
  bool get showActions => false;

  @override
  State<QuoteBlockComponentWidget> createState() =>
      _QuoteBlockComponentWidgetState();
}

class _QuoteBlockComponentWidgetState extends State<QuoteBlockComponentWidget> {
  late EditorState _editorState;

  @override
  void initState() {
    super.initState();
    _editorState = EditorGlobals.editorState!;
    _editorState.selectionNotifier.addListener(_onSelectionChanged);
  }

  @override
  void dispose() {
    _editorState.selectionNotifier.removeListener(_onSelectionChanged);
    super.dispose();
  }

  void _onSelectionChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final selection = _editorState.selection;
    final isSelected = selection != null &&
        selection.start.path.isNotEmpty &&
        selection.start.path.first == widget.node.path.first;
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // Get the text content from the node
    final delta = widget.node.delta?.toJson() ?? [];
    final textSpans = <TextSpan>[];

    for (final op in delta) {
      final text = op['insert'] as String? ?? '';
      final attributes = op['attributes'] as Map<String, dynamic>? ?? {};

      TextStyle style = TextStyle(
        fontSize: JournalEditorTheme.defaultFontSize,
        height: 1.5,
        color: theme.primaryText,
      );

      // Apply text styling
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

      // Apply text color
      if (attributes['color'] != null) {
        final colorHex = attributes['color'] as String;
        final color = Color(int.parse(colorHex, radix: 16));
        style = style.copyWith(color: color);
      }

      // Apply background color
      final colorIndex = attributes['backgroundColorIndex'] as int?;
      if (colorIndex != null && colorIndex >= 0 && colorIndex < 5) {
        // Assuming 5 background colors
        // Apply background color logic here if needed
      }

      textSpans.add(TextSpan(text: text, style: style));
    }

    // Get alignment from block attributes
    final align = widget.node.attributes['align'] as String? ?? 'left';
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

    return InkWell(
      onTap: () {
        _editorState.selection = Selection.single(
          path: widget.node.path,
          startOffset: 0,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(
              color: isDarkMode ? Colors.grey[600]! : Colors.grey[400]!,
              width: 3.0,
            ),
          ),
          borderRadius: BorderRadius.circular(2.0),
          color: isSelected
              ? theme.secondaryBackground.withValues(alpha: 0.3)
              : Colors.transparent,
        ),
        child: SizedBox(
          width: double.infinity,
          child: RichText(
            text: TextSpan(children: textSpans),
            textAlign: textAlign,
          ),
        ),
      ),
    );
  }
}

final quoteBlockBuilder = QuoteBlockComponentBuilder();
