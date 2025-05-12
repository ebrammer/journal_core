// lib/src/toolbar/toolbar_widget.dart

import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:provider/provider.dart';
import 'package:journal_core/journal_core.dart';

class JournalToolbar extends StatefulWidget {
  const JournalToolbar({
    super.key,
    required this.editorState,
    required this.controller,
    this.onSave,
    required this.focusNode,
  });

  final EditorState editorState;
  final JournalEditorController controller;
  final Future Function()? onSave;
  final FocusNode focusNode;

  @override
  State<JournalToolbar> createState() => _JournalToolbarState();
}

class _JournalToolbarState extends State<JournalToolbar> {
  late final ToolbarActions _actions;
  late final ToolbarButtons _buttonFactory;

  @override
  void initState() {
    super.initState();
    _actions = ToolbarActions(
      editorState: widget.editorState,
      toolbarState:
          widget.controller.toolbarState, // Use controller's toolbarState
      focusNode: widget.focusNode, // Pass FocusNode to ToolbarActions
    );
    _buttonFactory = ToolbarButtons(
      editorState: widget.editorState,
      toolbarState:
          widget.controller.toolbarState, // Use controller's toolbarState
      actions: _actions,
      focusNode: widget.focusNode, // Pass FocusNode to ToolbarButtons
    );
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final toolbarState = context.watch<ToolbarState>();
    Log.info(
        '🔧 Toolbar rendering with block type: ${toolbarState.currentBlockType}');

    if (!toolbarState.isVisible) {
      Log.info('🔧 Toolbar: Not visible');
      return const SizedBox.shrink();
    }

    final isSubMenu = toolbarState.showTextStyles ||
        toolbarState.showInsertMenu ||
        toolbarState.showLayoutMenu ||
        toolbarState.isDragMode;

    Log.info(
        '🔧 Toolbar state: isSubMenu=$isSubMenu, showTextStyles=${toolbarState.showTextStyles}, showInsertMenu=${toolbarState.showInsertMenu}, showLayoutMenu=${toolbarState.showLayoutMenu}, isDragMode=${toolbarState.isDragMode}');

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha(36),
            blurRadius: 14,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Non-expanded: Plus or Circle X
          Row(
            children: [
              _buildToolbarButton(ToolbarButtonConfig(
                key: 'menu_toggle',
                icon: isSubMenu ? AppIcons.kxCircle : AppIcons.kplusCircle,
                onPressed: isSubMenu
                    ? () => setState(() {
                          if (toolbarState.isDragMode) {
                            toolbarState.isDragMode = false;
                          } else if (toolbarState.showTextStyles) {
                            widget.editorState.selection = Selection.single(
                              path: widget.editorState.selection!.start.path,
                              startOffset:
                                  widget.editorState.selection!.start.offset,
                            );
                            toolbarState.showTextStyles = false;
                          } else if (toolbarState.showLayoutMenu) {
                            toolbarState.showLayoutMenu = false;
                            toolbarState.isDragMode = false;
                          } else {
                            toolbarState.showInsertMenu = false;
                          }
                        })
                    : () => setState(() {
                          toolbarState.showInsertMenu = true;
                        }),
              )),
              DividerVertical(),
            ],
          ),
          // Expanded: Scrollable button row
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(width: 4.0),
                  ..._getCurrentMenuButtons(),
                ],
              ),
            ),
          ),
          // Non-expanded: Keyboard or drag buttons
          Row(
            children: [
              const SizedBox(width: 4.0),
              DividerVertical(),
              if (toolbarState.isDragMode)
                ..._buttonFactory.getDragButtons().map(_buildToolbarButton)
              else
                _buildToolbarButton(ToolbarButtonConfig(
                  key: 'keyboard',
                  icon: AppIcons.kkeyboard,
                  onPressed: () => widget.focusNode.requestFocus(),
                )),
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _getCurrentMenuButtons() {
    final toolbarState = context.watch<ToolbarState>();
    if (toolbarState.isDragMode) {
      Log.info('🔧 Toolbar: Showing drag mode buttons');
      return [
        const SizedBox(width: 8.0),
        Text(
          'Long press and drag to reorder',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ];
    } else if (toolbarState.showInsertMenu) {
      Log.info('🔧 Toolbar: Showing insert menu buttons');
      return _buttonFactory
          .getInsertButtons()
          .map(_buildToolbarButton)
          .toList();
    } else if (toolbarState.showTextStyles) {
      Log.info('🔧 Toolbar: Showing text style buttons');
      return _buttonFactory
          .getSelectionButtons()
          .map(_buildToolbarButton)
          .toList();
    }
    Log.info('🔧 Toolbar: Showing main buttons');
    return _buttonFactory.getMainButtons().map(_buildToolbarButton).toList();
  }

  Widget _buildToolbarButton(ToolbarButtonConfig config) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isTapped = false;
        bool active = config.isActive?.call() ?? false;
        return GestureDetector(
          onTapDown: (_) {
            setState(() {
              isTapped = true;
            });
          },
          onTapUp: (_) {
            setState(() {
              isTapped = false;
            });
            if (config.onPressed != null) {
              config.onPressed!();
            }
          },
          onTapCancel: () {
            setState(() {
              isTapped = false;
            });
          },
          child: Container(
            width: 40.0,
            height: 40.0,
            decoration: BoxDecoration(
              color: isTapped
                  ? Colors.grey.shade200
                  : active
                      ? Colors.grey.shade100
                      : null,
              borderRadius: BorderRadius.circular(8.0),
              border: active
                  ? Border.all(color: Colors.grey.shade300, width: 1.0)
                  : null,
            ),
            child: Icon(
              config.icon,
              color: config.onPressed == null
                  ? Colors.grey.shade400
                  : Colors.black,
              size: 24.0,
            ),
          ),
        );
      },
    );
  }
}
