// src/blocks/prayer_block.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import '../editor/editor_globals.dart';

/// Keys used to identify and manage prayer blocks
class PrayerBlockKeys {
  const PrayerBlockKeys._();

  static const String type = 'prayer';
  static const String isPrayer = 'isPrayer';

  static EditorState? editorState;
  static ValueNotifier<Path?> selectionNotifier = ValueNotifier(null);
  static ValueNotifier<Path?> deleteNotifier = ValueNotifier(null);
}

/// Creates a prayer node with title (bold) and multi-line content
Node prayerNode({
  String id = '',
  String title = '',
  String content = '',
}) {
  final List<Node> children = [
    Node(
      type: 'paragraph',
      attributes: {
        'delta': [
          {
            'insert': title,
            'attributes': {'bold': true}
          }
        ],
      },
    ),
  ];

  for (final line in content.split('\n')) {
    if (line.trim().isNotEmpty) {
      children.add(
        Node(
          type: 'paragraph',
          attributes: {
            'delta': [
              {'insert': line}
            ],
          },
        ),
      );
    }
  }

  return Node(
    type: PrayerBlockKeys.type,
    attributes: {
      'id': id,
      PrayerBlockKeys.isPrayer: true,
    },
    children: children,
  );
}

/// Builder for prayer block widgets
class PrayerBlockComponentBuilder extends BlockComponentBuilder {
  PrayerBlockComponentBuilder({
    required this.blockComponentBuilders,
    required this.isDragMode,
    this.configuration = const BlockComponentConfiguration(),
  });

  @override
  final Map<String, BlockComponentBuilder> blockComponentBuilders;
  final bool isDragMode;
  @override
  final BlockComponentConfiguration configuration;

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    final node = context.node;
    return PrayerBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      blockComponentBuilders: blockComponentBuilders,
      editorState: PrayerBlockKeys.editorState!,
      isDragMode: isDragMode,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (Node node) => node.type == PrayerBlockKeys.type;
}

/// Visual component for displaying a prayer block
class PrayerBlockComponentWidget extends StatelessWidget
    implements BlockComponentWidget {
  const PrayerBlockComponentWidget({
    super.key,
    required this.node,
    required this.configuration,
    required this.blockComponentBuilders,
    required this.editorState,
    required this.isDragMode,
  });

  @override
  final Node node;
  @override
  final BlockComponentConfiguration configuration;
  final Map<String, BlockComponentBuilder> blockComponentBuilders;
  final EditorState editorState;
  final bool isDragMode;

  @override
  BlockComponentActionBuilder? get actionBuilder => null;

  @override
  BlockComponentActionBuilder? get actionTrailingBuilder => null;

  @override
  bool get showActions => false;

  @override
  Widget build(BuildContext context) {
    // Title (first child node)
    String title = '';
    if (node.children.isNotEmpty) {
      final delta = node.children[0].attributes['delta'] as List?;
      if (delta != null) {
        title = delta.map((op) => op['insert'].toString()).join();
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF9F2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFEADBC0), width: 1),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_fire_department_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.isNotEmpty ? title : 'Prayer',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 16,
                overflow: TextOverflow.ellipsis,
              ),
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
