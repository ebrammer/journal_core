// src/blocks/divider_block.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import '../editor/editor_globals.dart';
import '../theme/journal_theme.dart';

/// Constants for divider block
class DividerBlockKeys {
  const DividerBlockKeys._();

  static const String type = 'divider';
}

/// Divider block builder
class DividerBlockComponentBuilder extends BlockComponentBuilder {
  DividerBlockComponentBuilder({
    this.configuration = const BlockComponentConfiguration(),
  });

  @override
  final BlockComponentConfiguration configuration;

  @override
  BlockComponentWidget build(BlockComponentContext context) {
    final node = context.node;
    return DividerBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
    );
  }

  @override
  BlockComponentValidate get validate =>
      (Node node) => node.type == DividerBlockKeys.type;
}

/// Widget that renders a horizontal divider
class DividerBlockComponentWidget extends StatefulWidget
    implements BlockComponentWidget {
  const DividerBlockComponentWidget({
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
  State<DividerBlockComponentWidget> createState() =>
      _DividerBlockComponentWidgetState();
}

class _DividerBlockComponentWidgetState
    extends State<DividerBlockComponentWidget> {
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

    return InkWell(
      onTap: () {
        _editorState.selection = Selection.single(
          path: widget.node.path,
          startOffset: 0,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8.0),
        decoration: BoxDecoration(
          color: isSelected
              ? theme.primaryText.withOpacity(0.05)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Container(
              width: MediaQuery.of(context).size.width / 3,
              height: 1,
              color: theme.primaryText,
            ),
          ),
        ),
      ),
    );
  }
}
