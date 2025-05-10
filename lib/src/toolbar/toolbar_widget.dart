// lib/src/toolbar/toolbar_widget.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/src/icons/journal_icons.dart';
import 'package:journal_core/src/editor/journal_editor_controller.dart';
import 'toolbar.dart';
import 'package:provider/provider.dart';

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
  late ToolbarState _toolbarState;
  late final ToolbarActions _actions;
  late final ToolbarButtons _buttonFactory;

  @override
  void initState() {
    super.initState();
    _toolbarState = ToolbarState();
    _actions = ToolbarActions(
      editorState: widget.editorState,
      toolbarState: _toolbarState,
      focusNode: widget.focusNode, // Pass FocusNode to ToolbarActions
    );
    _buttonFactory = ToolbarButtons(
      editorState: widget.editorState,
      toolbarState: _toolbarState,
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
    _toolbarState = context.watch<ToolbarState>();

    if (!_toolbarState.isVisible) return const SizedBox.shrink();

    final isSubMenu = _toolbarState.showTextStyles ||
        _toolbarState.showInsertMenu ||
        _toolbarState.showLayoutMenu ||
        _toolbarState.isDragMode;

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
                          if (_toolbarState.isDragMode) {
                            _toolbarState.isDragMode = false;
                          } else if (_toolbarState.showTextStyles) {
                            widget.editorState.selection = Selection.single(
                              path: widget.editorState.selection!.start.path,
                              startOffset:
                                  widget.editorState.selection!.start.offset,
                            );
                            _toolbarState.showTextStyles = false;
                          } else if (_toolbarState.showLayoutMenu) {
                            _toolbarState.showLayoutMenu = false;
                            _toolbarState.isDragMode = false;
                          } else {
                            _toolbarState.showInsertMenu = false;
                          }
                        })
                    : () => setState(() {
                          _toolbarState.showInsertMenu = true;
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
              if (_toolbarState.isDragMode)
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
    if (_toolbarState.isDragMode) {
      return [
        const SizedBox(width: 8.0),
        Text(
          'Long press and drag to reorder',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
      ];
    } else if (_toolbarState.showInsertMenu) {
      return _buttonFactory
          .getInsertButtons()
          .map(_buildToolbarButton)
          .toList();
    } else if (_toolbarState.showTextStyles) {
      return _buttonFactory
          .getSelectionButtons()
          .map(_buildToolbarButton)
          .toList();
    }
    return _buttonFactory.getMainButtons().map(_buildToolbarButton).toList();
  }

  Widget _buildToolbarButton(ToolbarButtonConfig config) {
    return StatefulBuilder(
      builder: (context, setState) {
        bool isTapped = false;

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
                  : config.isActive
                      ? Colors.grey.shade100
                      : null,
              borderRadius: BorderRadius.circular(8.0),
              border: config.isActive
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
