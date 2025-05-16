// src/blocks/tag_picker_block.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import '../editor/editor_globals.dart';

/// Keys used to identify and manage tag picker blocks
class TagPickerBlockKeys {
  const TagPickerBlockKeys._();

  static const String type = 'tag_picker';
  static const String isTagPicker = 'isTagPicker';

  static EditorState? editorState;
  static ValueNotifier<Path?> selectionNotifier = ValueNotifier(null);
  static ValueNotifier<Path?> deleteNotifier = ValueNotifier(null);
}

/// Creates a node representing a tag picker block
Node tagPickerNode({
  List<String> tagIds = const [],
  String journalId = '',
}) {
  return Node(
    type: TagPickerBlockKeys.type,
    attributes: {
      TagPickerBlockKeys.isTagPicker: true,
      'tagIds': tagIds,
      'journalId': journalId,
    },
  );
}

/// Builder for tag picker blocks (currently placeholder UI)
class TagPickerBlockComponentBuilder extends BlockComponentBuilder {
  TagPickerBlockComponentBuilder({
    this.configuration = const BlockComponentConfiguration(),
  });

  @override
  final BlockComponentConfiguration configuration;

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    final node = context.node;
    return TagPickerBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      editorState: TagPickerBlockKeys.editorState!,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (Node node) => node.type == TagPickerBlockKeys.type;
}

/// Minimal placeholder version of tag picker UI (real tag logic omitted for now)
class TagPickerBlockComponentWidget extends StatelessWidget
    implements BlockComponentWidget {
  const TagPickerBlockComponentWidget({
    super.key,
    required this.node,
    required this.configuration,
    required this.editorState,
  });

  @override
  final Node node;
  @override
  final BlockComponentConfiguration configuration;
  final EditorState editorState;

  @override
  BlockComponentActionBuilder? get actionBuilder => null;

  BlockComponentActionBuilder? get actionTrailingBuilder => null;

  @override
  bool get showActions => false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF2FF),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: const Color(0xFFB9D4FF), width: 1),
      ),
      child: const Text(
        'Tag Picker (placeholder)',
        style: TextStyle(fontSize: 14, fontStyle: FontStyle.italic),
      ),
    );
  }
}
