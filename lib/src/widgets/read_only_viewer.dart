import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';
import '../theme/journal_theme.dart';
import '../blocks/divider_block.dart' as divider;

/// A read-only viewer that displays journal content with the same styling as the editor
class ReadOnlyViewer extends StatefulWidget {
  const ReadOnlyViewer({
    super.key,
    required this.journal,
    this.onContentTap,
  });

  final Journal journal;
  final VoidCallback? onContentTap;

  @override
  State<ReadOnlyViewer> createState() => _ReadOnlyViewerState();
}

class _ReadOnlyViewerState extends State<ReadOnlyViewer> {
  final ScrollController _scrollController = ScrollController();
  late final Document _contentCopy;

  @override
  void initState() {
    super.initState();
    // Create a deep copy of the document to prevent disposal issues
    _contentCopy = Document.fromJson(widget.journal.content.toJson());
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
        onTap: widget.onContentTap,
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
    final children = _contentCopy.root.children;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Content blocks (skip metadata and spacer blocks)
        ...children
            .where((node) =>
                node.type != BlockTypeConstants.metadata &&
                node.type != BlockTypeConstants.spacer)
            .map((node) => _buildBlock(node)),
      ],
    );
  }

  Widget _buildBlock(Node node) {
    switch (node.type) {
      case BlockTypeConstants.paragraph:
        return _buildParagraphBlock(node);
      case divider.DividerBlockKeys.type:
        return _buildDividerBlock(node);
      case BlockTypeConstants.heading:
        return _buildHeadingBlock(node);
      case BlockTypeConstants.bulletedList:
      case BlockTypeConstants.numberedList:
        return _buildListBlock(node);
      case BlockTypeConstants.quote:
        return _buildQuoteBlock(node);
      default:
        return _buildUnknownBlock(node);
    }
  }

  Widget _buildParagraphBlock(Node node) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final delta = node.attributes['delta'] as List<dynamic>?;

    if (delta == null || delta.isEmpty) {
      return const SizedBox(height: 16.0);
    }

    final textSpans = <TextSpan>[];

    for (final op in delta) {
      final text = op['insert'] as String? ?? '';
      final attributes = op['attributes'] as Map<String, dynamic>? ?? {};

      TextStyle style = TextStyle(
        fontSize: 16,
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

      textSpans.add(TextSpan(text: text, style: style));
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: RichText(
        text: TextSpan(children: textSpans),
      ),
    );
  }

  Widget _buildHeadingBlock(Node node) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final delta = node.attributes['delta'] as List<dynamic>?;

    if (delta == null || delta.isEmpty) {
      return const SizedBox(height: 16.0);
    }

    final text = delta.map((op) => op['insert'] as String? ?? '').join('');

    // Get heading level from attributes, default to 1
    final level = node.attributes['level'] as int? ?? 1;

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: theme.primaryText,
          height: 1.4,
        ),
      ),
    );
  }

  Widget _buildListBlock(Node node) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final delta = node.attributes['delta'] as List<dynamic>?;

    if (delta == null || delta.isEmpty) {
      return const SizedBox(height: 16.0);
    }

    final text = delta.map((op) => op['insert'] as String? ?? '').join('');
    final isNumbered = node.type == BlockTypeConstants.numberedList;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24.0,
            child: Text(
              isNumbered ? '1.' : '•',
              style: TextStyle(
                fontSize: 16,
                color: theme.primaryText,
                fontWeight: FontWeight.normal,
              ),
            ),
          ),
          const SizedBox(width: 8.0),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                height: 1.5,
                color: theme.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuoteBlock(Node node) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final delta = node.attributes['delta'] as List<dynamic>?;

    if (delta == null || delta.isEmpty) {
      return const SizedBox(height: 16.0);
    }

    final text = delta.map((op) => op['insert'] as String? ?? '').join('');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: theme.primaryText.withOpacity(0.3),
            width: 4.0,
          ),
        ),
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(4.0),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          height: 1.5,
          color: theme.primaryText,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  Widget _buildDividerBlock(Node node) {
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

  Widget _buildUnknownBlock(Node node) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: theme.secondaryBackground,
        borderRadius: BorderRadius.circular(4.0),
        border: Border.all(color: theme.secondaryText.withOpacity(0.3)),
      ),
      child: Text(
        'Unknown block type: ${node.type}',
        style: TextStyle(
          fontSize: 14,
          color: theme.secondaryText,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
