// lib/src/toolbar/toolbar_widget.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:provider/provider.dart';
import 'package:journal_core/journal_core.dart';
import '../theme/journal_theme.dart';

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
    this.onPrayer,
    this.onScripture,
    this.onTag,
  });

  final EditorState editorState;
  final JournalEditorController controller;
  final Future Function()? onSave;
  final FocusNode focusNode;
  final VoidCallback? onDocumentChanged;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final Future Function()? onPrayer;
  final Future Function()? onScripture;
  final Future Function()? onTag;

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
      context: context,
      focusNode: widget.focusNode,
      onDocumentChanged: widget.onDocumentChanged, // Pass to ToolbarActions
    );
    _buttonFactory = ToolbarButtons(
      editorState: widget.editorState,
      toolbarState: widget.controller.toolbarState,
      actions: _actions,
      context: context,
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
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
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
      color: theme.toolbarBackground,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Insert Menu
          Align(
            alignment:
                (toolbarState.currentBlockType == BlockTypeConstants.divider) ||
                        (widget.editorState.selection != null &&
                            !widget.editorState.selection!.isCollapsed) ||
                        toolbarState.isDragMode
                    ? Alignment.center
                    : Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.only(top: 0, bottom: 8.0),
              decoration: const BoxDecoration(
                color: Colors.transparent,
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  mainAxisAlignment: (toolbarState.currentBlockType ==
                              BlockTypeConstants.divider) ||
                          (widget.editorState.selection != null &&
                              !widget.editorState.selection!.isCollapsed) ||
                          toolbarState.isDragMode
                      ? MainAxisAlignment.center
                      : MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(width: 8.0),
                    if (toolbarState.isDragMode) ...[
                      // Count valid blocks (excluding metadata and spacer blocks)
                      Builder(
                        builder: (context) {
                          int validBlockCount = 0;
                          for (final node
                              in widget.editorState.document.root.children) {
                            if (node != null &&
                                node.type != 'spacer_block' &&
                                node.type != 'metadata_block') {
                              validBlockCount++;
                            }
                          }

                          // Only show delete button if there's more than one block
                          if (validBlockCount > 1) {
                            return _buildInsertPill(
                              icon: JournalIcons.jxCircle,
                              label: 'Delete Block',
                              onTap: () => _actions.handleDelete(),
                            );
                          }
                          return const SizedBox.shrink();
                        },
                      ),
                    ] else if (toolbarState.currentBlockType ==
                        BlockTypeConstants.divider)
                      _buildInsertPill(
                        icon: JournalIcons.jxCircle,
                        label: 'Delete',
                        onTap: () => _actions.handleDelete(),
                      )
                    else if (widget.editorState.selection != null &&
                        !widget.editorState.selection!.isCollapsed) ...[
                      _buildInsertPill(
                        icon: JournalIcons.jcopy,
                        label: 'Copy',
                        onTap: () => _actions.handleCopyToClipboard(),
                      ),
                      const SizedBox(width: 8),
                      _buildInsertPill(
                        icon: JournalIcons.jscissors,
                        label: 'Cut',
                        onTap: () => _actions.handleCutToClipboard(),
                      ),
                    ] else ...[
                      if (toolbarState.hasClipboardContent)
                        _buildInsertPill(
                          icon: JournalIcons.jclipboard,
                          label: 'Paste',
                          onTap: () => _actions.handlePasteFromClipboard(),
                        ),
                      if (toolbarState.hasClipboardContent)
                        const SizedBox(width: 8),
                      // _buildInsertPill(
                      //   icon: JournalIcons.jfire,
                      //   label: 'Prayer',
                      //   onTap: () async {
                      //     if (widget.onPrayer != null) {
                      //       await widget.onPrayer!();
                      //     }
                      //   },
                      // ),
                      // const SizedBox(width: 8),
                      // _buildInsertPill(
                      //   icon: JournalIcons.jbibleregular,
                      //   label: 'Scripture',
                      //   onTap: () async {
                      //     if (widget.onScripture != null) {
                      //       await widget.onScripture!();
                      //     }
                      //   },
                      // ),
                      // const SizedBox(width: 8),
                      // _buildInsertPill(
                      //   icon: JournalIcons.jtag,
                      //   label: 'Tag',
                      //   onTap: () async {
                      //     if (widget.onTag != null) {
                      //       await widget.onTag!();
                      //     }
                      //   },
                      // ),
                      // const SizedBox(width: 8),
                      _buildInsertPill(
                        icon: JournalIcons.jminus,
                        label: 'Divider',
                        onTap: () => _actions.handleInsertDivider(),
                        isActive: toolbarState.currentBlockType ==
                            BlockTypeConstants.divider,
                      ),
                      const SizedBox(width: 8),
                      _buildInsertPill(
                        icon: JournalIcons.jrowsPlusTop,
                        label: 'Insert Above',
                        onTap: () => _actions.handleInsertAbove(),
                      ),
                      const SizedBox(width: 8),
                      _buildInsertPill(
                        icon: JournalIcons.jrowsPlusBottom,
                        label: 'Insert Below',
                        onTap: () => _actions.handleInsertBelow(),
                      ),
                    ],
                    const SizedBox(width: 8.0),
                  ],
                ),
              ),
            ),
          ),
          // Main Toolbar
          Container(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            decoration: BoxDecoration(
              color: theme.toolbarBackground,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withAlpha(36),
                  blurRadius: 14,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Non-expanded: Drag button
                Row(
                  children: [
                    _buildToolbarButton(ToolbarButtonConfig(
                      key: 'drag',
                      icon: toolbarState.isDragMode
                          ? JournalIcons.jarrowLeft
                          : JournalIcons.jarrowsDownUp,
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
                    )),
                    const DividerVertical(),
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
                // Non-expanded: Keyboard button
                Row(
                  children: [
                    const SizedBox(width: 4.0),
                    const DividerVertical(),
                    if (toolbarState.isDragMode)
                      ..._buttonFactory
                          .getDragButtons()
                          .map(_buildToolbarButton)
                    else ...[
                      _buildToolbarButton(ToolbarButtonConfig(
                        key: 'keyboard',
                        icon: JournalIcons.jkeyboard,
                        onPressed: () {
                          Log.info(
                              '🔧 Keyboard button tapped, unfocusing editor');
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
                            Log.info(
                                '🔍 Triggered onSave from keyboard button');
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
          ),
        ],
      ),
    );
  }

  List<Widget> _getCurrentMenuButtons() {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    final toolbarState = context.watch<ToolbarState>();
    if (toolbarState.isDragMode) {
      Log.info('🔧 Toolbar: Showing drag mode buttons');
      return [
        const SizedBox(width: 8.0),
        Text(
          'Long press and drag to reorder',
          style: TextStyle(
            color: theme.secondaryText,
            fontSize: 14,
          ),
        ),
      ];
    } else if (toolbarState.showActionsMenu) {
      Log.info('🔧 Toolbar: Showing action buttons');
      return _buttonFactory
          .getActionButtons()
          .map(_buildToolbarButton)
          .toList();
    } else if (toolbarState.showInsertMenu) {
      Log.info('🔧 Toolbar: Showing insert menu buttons');
      return _buttonFactory
          .getInsertButtons()
          .map(_buildToolbarButton)
          .toList();
    } else if (toolbarState.showTextStyles) {
      Log.info('🔧 Toolbar: Showing text style buttons');
      final buttons = _buttonFactory.getSelectionButtons();
      return buttons.asMap().entries.map((entry) {
        final index = entry.key;
        final button = entry.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildToolbarButton(button),
            if (index < buttons.length - 1) const SizedBox(width: 4.0),
          ],
        );
      }).toList();
    }
    Log.info('🔧 Toolbar: Showing main buttons');
    final buttons = _buttonFactory.getMainButtons();
    return buttons.asMap().entries.map((entry) {
      final index = entry.key;
      final button = entry.value;
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildToolbarButton(button),
          if (index < buttons.length - 1) const SizedBox(width: 4.0),
        ],
      );
    }).toList();
  }

  Widget _buildToolbarButton(ToolbarButtonConfig config) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
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
              color: active ? theme.secondaryBackground : null,
              borderRadius: BorderRadius.circular(8.0),
              border: active
                  ? Border.all(color: theme.toolbarBorder, width: 1.0)
                  : null,
            ),
            child: Icon(
              config.icon,
              color: config.onPressed == null
                  ? theme.primaryText.withOpacity(0.5)
                  : theme.primaryText,
              size: 24.0,
            ),
          ),
        );
      },
    );
  }

  Widget _buildInsertPill({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        decoration: BoxDecoration(
          color: isActive ? theme.secondaryBackground : theme.toolbarBackground,
          borderRadius: BorderRadius.circular(999.0),
          border: Border.all(
            color: isActive
                ? theme.toolbarBorder
                : theme.toolbarBorder.withAlpha(128),
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14.0,
              color: theme.primaryText,
            ),
            const SizedBox(width: 4.0),
            Text(
              label,
              style: TextStyle(
                color: theme.primaryText,
                fontSize: 12.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
