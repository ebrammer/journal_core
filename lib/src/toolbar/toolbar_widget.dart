// lib/src/toolbar/toolbar_widget.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:provider/provider.dart';
import 'package:journal_core/journal_core.dart';

/// The toolbar widget for the journal editor, displaying formatting and reordering options.
/// - Enhances drag submenu to include move up/down buttons alongside "Long press and drag to reorder" message.
/// - Forces rebuild on drag mode toggle for UI consistency.
/// - Preserves editor selection when exiting drag mode to prevent toolbar hiding.
/// - Includes debug logs with 🔍 prefix for toolbar rendering and interactions.
/// - Compatible with AppFlowy 4.0.0 and single-editor drag-and-drop approach.
class JournalToolbar extends StatefulWidget {
  const JournalToolbar({
    super.key,
    required this.editorState,
    required this.controller,
    this.onSave,
    required this.focusNode,
    this.onDocumentChanged, // Callback for document changes
    this.onMoveUp,
    this.onMoveDown,
  });

  final EditorState editorState;
  final JournalEditorController controller;
  final Future Function()? onSave;
  final FocusNode focusNode;
  final VoidCallback? onDocumentChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

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
      toolbarState: widget.controller.toolbarState,
      focusNode: widget.focusNode,
      onDocumentChanged: widget.onDocumentChanged, // Pass to ToolbarActions
    );
    _buttonFactory = ToolbarButtons(
      editorState: widget.editorState,
      toolbarState: widget.controller.toolbarState,
      actions: _actions,
      focusNode: widget.focusNode,
      onMoveUp: widget.onMoveUp,
      onMoveDown: widget.onMoveDown,
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
        '🔧 Toolbar rendering with block type: ${toolbarState.currentBlockType}, isDragMode: ${toolbarState.isDragMode}');

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
                    ? () {
                        setState(() {
                          if (toolbarState.isDragMode) {
                            // Preserve selection when exiting drag mode
                            if (widget.editorState.selection == null) {
                              final firstNode = widget.editorState.document.root
                                      .children.isNotEmpty
                                  ? widget
                                      .editorState.document.root.children.first
                                  : null;
                              if (firstNode != null) {
                                widget.editorState.selection =
                                    Selection.collapsed(
                                        Position(path: firstNode.path));
                                Log.info(
                                    '🔍 Restored selection on drag mode exit: ${widget.editorState.selection}');
                              }
                            }
                            toolbarState.isDragMode = false;
                            Log.info('🔍 Exited drag mode');
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
                        });
                        widget.controller.syncToolbarWithSelection();
                      }
                    : () {
                        setState(() {
                          toolbarState.showInsertMenu = true;
                        });
                      },
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
              else ...[
                _buildToolbarButton(ToolbarButtonConfig(
                  key: 'drag',
                  icon: AppIcons.karrowsDownUp,
                  onPressed: () {
                    toolbarState.isDragMode = !toolbarState.isDragMode;
                    // Ensure a selection exists to keep toolbar visible
                    if (toolbarState.isDragMode) {
                      widget.controller.ensureValidSelection();
                      Log.info(
                          '🔍 Drag mode entered, selection: ${widget.editorState.selection}');
                    }
                    toolbarState.notifyListeners();
                    Log.info(
                        '🔍 Drag mode toggled: ${toolbarState.isDragMode}');
                  },
                  isActive: () => toolbarState.isDragMode,
                )),
                _buildToolbarButton(ToolbarButtonConfig(
                  key: 'keyboard',
                  icon: AppIcons.kkeyboard,
                  onPressed: () {
                    Log.info('🔧 Keyboard button tapped, unfocusing editor');
                    // Hide the keyboard
                    FocusScope.of(context).unfocus();
                    // Remove focus from the editor
                    widget.focusNode.unfocus();
                    // Clear the selection to hide the cursor
                    widget.editorState.selection = null;
                    // Hide the toolbar
                    widget.controller.toolbarState.setSelectionInfo(
                      isVisible: false,
                      showTextStyles: false,
                      isDragMode: false,
                      selectionPath: null,
                      previousSiblingType: null,
                    );
                    // Execute save
                    if (widget.onSave != null) {
                      widget.onSave!();
                      Log.info('🔍 Triggered onSave from keyboard button');
                    }
                    // Log focus state for debugging
                    Log.info(
                        '🔧 Editor focus after unfocus: ${widget.focusNode.hasFocus}');
                  },
                )),
              ],
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
              // Force rebuild for drag mode toggle to ensure UI updates
              if (config.key == 'drag') {
                this.setState(() {});
                Log.info('🔍 Forced toolbar rebuild after drag mode toggle');
              }
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
