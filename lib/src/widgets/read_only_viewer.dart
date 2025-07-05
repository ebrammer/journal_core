import 'package:flutter/material.dart';
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
      // Skip metadata and spacer blocks
      if (node.type == BlockTypeConstants.metadata ||
          node.type == BlockTypeConstants.spacer) {
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
      case BlockTypeConstants.paragraph:
        return _buildParagraphBlock(blockData);
      case divider.DividerBlockKeys.type:
        return _buildDividerBlock(blockData);
      case BlockTypeConstants.heading:
        return _buildHeadingBlock(blockData);
      case BlockTypeConstants.bulletedList:
      case BlockTypeConstants.numberedList:
        return _buildListBlock(blockData);
      case BlockTypeConstants.quote:
        return _buildQuoteBlock(blockData);
      default:
        return _buildUnknownBlock(blockData);
    }
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
        style = style.copyWith(decoration: TextDecoration.underline);
      }
      if (opAttributes['strikethrough'] == true) {
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

  Widget _buildHeadingBlock(Map<String, dynamic> blockData) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final attributes = blockData['attributes'] as Map<String, dynamic>;
    final delta = attributes['delta'] as List<dynamic>?;

    if (delta == null || delta.isEmpty) {
      return const SizedBox(height: 16.0);
    }

    final text = delta.map((op) => op['insert'] as String? ?? '').join('');

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

  Widget _buildListBlock(Map<String, dynamic> blockData) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final attributes = blockData['attributes'] as Map<String, dynamic>;
    final delta = attributes['delta'] as List<dynamic>?;

    if (delta == null || delta.isEmpty) {
      return const SizedBox(height: 16.0);
    }

    final text = delta.map((op) => op['insert'] as String? ?? '').join('');
    final isNumbered = blockData['type'] == BlockTypeConstants.numberedList;

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

  Widget _buildQuoteBlock(Map<String, dynamic> blockData) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final attributes = blockData['attributes'] as Map<String, dynamic>;
    final delta = attributes['delta'] as List<dynamic>?;

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
            color: theme.primaryText.withValues(alpha: 0.3),
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
