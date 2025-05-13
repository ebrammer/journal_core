// lib/src/blocks/spacer_block.dart

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';

/// Spacer block builder to add extra scrollable space
class SpacerBlockBuilder extends BlockComponentBuilder {
  SpacerBlockBuilder({
    this.configuration = const BlockComponentConfiguration(),
  });

  final BlockComponentConfiguration configuration;

  @override
  String get blockType => 'spacer_block';

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    return SpacerBlockWidget(
      key: context.node.key,
      node: context.node,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (Node node) => node.type == 'spacer_block';
}

class SpacerBlockWidget extends StatelessWidget
    implements BlockComponentWidget {
  const SpacerBlockWidget({
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
  Widget build(BuildContext context) {
    final height = (node.attributes['height'] as num?)?.toDouble() ?? 100.0;
    return Container(
      height: height,
      margin:
          const EdgeInsets.symmetric(vertical: 2.0), // Match ReorderableEditor
      padding: EdgeInsets.zero, // No extra padding
    );
  }
}

final spacerBlockBuilder = SpacerBlockBuilder();
