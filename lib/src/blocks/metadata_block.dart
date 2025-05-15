// lib/src/blocks/metadata_block.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:intl/intl.dart';

/// Metadata block builder to display title and created date
class MetadataBlockBuilder extends BlockComponentBuilder {
  MetadataBlockBuilder({
    required this.titleController,
    required this.createdAt,
    required this.onTitleChanged,
    this.titleFocusNode,
    this.onTitleEditingComplete,
    this.onTitleSubmitted,
  });

  final TextEditingController titleController;
  final int createdAt;
  final ValueChanged<String> onTitleChanged;
  final FocusNode? titleFocusNode;
  final VoidCallback? onTitleEditingComplete;
  final ValueChanged<String>? onTitleSubmitted;

  @override
  String get blockType => 'metadata_block';

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    return MetadataBlockWidget(
      key: context.node.key,
      node: context.node,
      titleController: titleController,
      createdAt: createdAt,
      onTitleChanged: onTitleChanged,
      titleFocusNode: titleFocusNode,
      onTitleEditingComplete: onTitleEditingComplete,
      onTitleSubmitted: onTitleSubmitted,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (Node node) => node.type == 'metadata_block';
}

class MetadataBlockWidget extends StatelessWidget
    implements BlockComponentWidget {
  const MetadataBlockWidget({
    super.key,
    required this.node,
    required this.titleController,
    required this.createdAt,
    required this.onTitleChanged,
    this.titleFocusNode,
    this.onTitleEditingComplete,
    this.onTitleSubmitted,
  });

  @override
  final Node node;
  final TextEditingController titleController;
  final int createdAt;
  final ValueChanged<String> onTitleChanged;
  final FocusNode? titleFocusNode;
  final VoidCallback? onTitleEditingComplete;
  final ValueChanged<String>? onTitleSubmitted;

  @override
  BlockComponentConfiguration get configuration =>
      const BlockComponentConfiguration();

  @override
  BlockComponentActionBuilder? get actionBuilder => null;

  @override
  BlockComponentActionBuilder? get actionTrailingBuilder => null;

  @override
  bool get showActions => false;

  @override
  Widget build(BuildContext context) {
    final formattedDate = DateFormat('MMMM d, yyyy')
        .format(DateTime.fromMillisecondsSinceEpoch(createdAt));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 0.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: titleController,
            focusNode: titleFocusNode,
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
              hintStyle: TextStyle(
                color: Colors.grey,
                fontSize: 32.0,
              ),
            ),
            style: const TextStyle(
              fontSize: 32.0,
              fontWeight: FontWeight.w700,
              color: Colors.black,
              height: 1.5,
            ),
            onChanged: onTitleChanged,
            onEditingComplete: onTitleEditingComplete,
            onSubmitted: onTitleSubmitted,
          ),
          const SizedBox(height: 4.0),
          Text(
            '$formattedDate',
            style: const TextStyle(
              fontSize: 14.0,
              color: Colors.black,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
