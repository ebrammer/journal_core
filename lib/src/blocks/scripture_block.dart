// src/blocks/scripture_block.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import '../editor/editor_globals.dart';
import '../models/block_type_constants.dart';

/// Keys used to identify and manage scripture blocks
class ScriptureBlockKeys {
  const ScriptureBlockKeys._();

  static const String type = 'scripture';
  static const String isScripture = 'isScripture';

  static EditorState? editorState;
  static ValueNotifier<Path?> selectionNotifier = ValueNotifier(null);
  static ValueNotifier<Path?> deleteNotifier = ValueNotifier(null);
}

/// Creates a scripture node with a bold heading and multiple content paragraphs
Node scriptureNode({
  String id = '',
  String reference = '',
  String content = '',
}) {
  final List<Node> children = [
    Node(
      type: BlockTypeConstants.paragraph,
      attributes: {
        'delta': [
          {
            'insert': reference,
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
          type: BlockTypeConstants.paragraph,
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
    type: ScriptureBlockKeys.type,
    attributes: {
      'id': id,
      ScriptureBlockKeys.isScripture: true,
    },
    children: children,
  );
}

/// Component builder for scripture blocks
class ScriptureBlockComponentBuilder extends BlockComponentBuilder {
  ScriptureBlockComponentBuilder({
    required this.blockComponentBuilders,
    this.configuration = const BlockComponentConfiguration(),
  });

  @override
  final Map<String, BlockComponentBuilder> blockComponentBuilders;
  @override
  final BlockComponentConfiguration configuration;

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    final node = context.node;
    return ScriptureBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      blockComponentBuilders: blockComponentBuilders,
      editorState: ScriptureBlockKeys.editorState!,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (Node node) => node.type == ScriptureBlockKeys.type;
}

/// Renders scripture blocks using child paragraph nodes
class ScriptureBlockComponentWidget extends StatelessWidget
    implements BlockComponentWidget {
  const ScriptureBlockComponentWidget({
    super.key,
    required this.node,
    required this.configuration,
    required this.blockComponentBuilders,
    required this.editorState,
  });

  @override
  final Node node;
  @override
  final BlockComponentConfiguration configuration;
  final Map<String, BlockComponentBuilder> blockComponentBuilders;
  final EditorState editorState;

  @override
  BlockComponentActionBuilder? get actionBuilder => null;

  BlockComponentActionBuilder? get actionTrailingBuilder => null;

  @override
  bool get showActions => false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F4F9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFD8D8E0), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: node.children.map((child) {
          final builder = blockComponentBuilders[child.type];
          return builder?.build(BlockComponentContext(context, child)) ??
              const SizedBox.shrink();
        }).toList(),
      ),
    );
  }
}
