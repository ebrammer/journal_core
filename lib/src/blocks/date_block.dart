// src/blocks/date_block.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:intl/intl.dart';

/// Constants for identifying a date block
class DateBlockKeys {
  const DateBlockKeys._();

  static const String type = 'date';
  static const String isDate = 'isDate';

  static EditorState? editorState;
}

/// Creates a date block node using the provided timestamp (or now)
Node dateNode({int? lastModified}) {
  final date = lastModified != null
      ? DateTime.fromMillisecondsSinceEpoch(lastModified)
      : DateTime.now();
  final formattedDate = DateFormat('MMMM d, yyyy h:mm a').format(date);

  return Node(
    type: DateBlockKeys.type,
    attributes: {
      DateBlockKeys.isDate: true,
      'delta': [
        {'insert': formattedDate}
      ],
    },
  );
}

/// Builder for the date block
class DateBlockComponentBuilder extends BlockComponentBuilder {
  DateBlockComponentBuilder({
    this.configuration = const BlockComponentConfiguration(),
  });

  @override
  final BlockComponentConfiguration configuration;

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    final node = context.node;
    return DateBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (Node node) => node.type == DateBlockKeys.type;
}

/// Renders a date block in read-only format
class DateBlockComponentWidget extends StatelessWidget
    implements BlockComponentWidget {
  const DateBlockComponentWidget({
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

  BlockComponentActionBuilder? get actionTrailingBuilder => null;

  @override
  bool get showActions => false;

  @override
  Widget build(BuildContext context) {
    final delta = node.attributes['delta'] as List?;
    final text = delta?.isNotEmpty == true ? delta![0]['insert'] as String : '';

    return Container(
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: Color(0xFF888888),
        ),
      ),
    );
  }
}
