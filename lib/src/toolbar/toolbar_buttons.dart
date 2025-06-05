// lib/src/toolbar/toolbar_buttons.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';
import '../models/block_type_constants.dart';

/// Configuration for a toolbar button, including icon, action, and active state.
class ToolbarButtonConfig {
  final IconData icon;
  final VoidCallback? onPressed;
  final bool Function()? isActive;
  final String key;

  ToolbarButtonConfig({
    required this.icon,
    required this.key,
    this.onPressed,
    this.isActive,
  });
}

/// Manages the toolbar buttons for the journal editor, including drag and move actions.
/// - Ensures drag button toggles isDragMode and sets initial selection if none exists.
/// - Returns move up/down buttons in getDragButtons for drag submenu, inspired by epistle_editor.
/// - Disables up arrow for the first reorderable block (visual index 0) to protect metadata block.
/// - Includes debug logs with 🔍 prefix for button states and actions.
/// - Compatible with AppFlowy 4.0.0 and single-editor drag-and-drop approach.
class ToolbarButtons {
  final EditorState editorState;
  final ToolbarState toolbarState;
  final ToolbarActions actions;
  final FocusNode? focusNode;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final BuildContext context;

  ToolbarButtons({
    required this.editorState,
    required this.toolbarState,
    required this.actions,
    required this.context,
    this.focusNode,
    this.onMoveUp,
    this.onMoveDown,
  });

  List<ToolbarButtonConfig> getMainButtons() {
    Log.info(
        '🔧 ToolbarButtons: Current block type: ${toolbarState.currentBlockType}, isDragMode: ${toolbarState.isDragMode}');

    final canIndentNode = [
      BlockTypeConstants.paragraph,
      BlockTypeConstants.heading,
      'todo_list',
      'bulleted_list',
      'numbered_list'
    ].contains(toolbarState.currentBlockType);

    // Get position information
    final isTopLevel = toolbarState.currentSelectionPath != null &&
        toolbarState.currentSelectionPath!.length == 1;
    final isChildNode = toolbarState.currentSelectionPath != null &&
        toolbarState.currentSelectionPath!.length > 1;

    // Check if this is the first item in its parent's children
    bool isFirstChild = false;
    if (toolbarState.currentSelectionPath != null) {
      final currentIndex = toolbarState.currentSelectionPath!.last;
      isFirstChild = currentIndex == 0;
    }

    // Determine indent/outdent permissions
    // Can indent if not the first child at any level
    final canIndent = !isFirstChild;
    // Can outdent if it's a child node (not top level) and either not the first child or it's not the top level
    final canOutdent = isChildNode && (!isFirstChild || !isTopLevel);

    Log.info(
        '🔧 Position info: isTopLevel: $isTopLevel, isChildNode: $isChildNode, isFirstChild: $isFirstChild, canIndent: $canIndent, canOutdent: $canOutdent');

    final selection = editorState.selection;
    final currentNodeType = selection != null
        ? editorState.getNodeAtPath(selection.start.path)?.type ??
            BlockTypeConstants.paragraph
        : BlockTypeConstants.paragraph;
    Log.info('🔧 ToolbarButtons: EditorState node type: $currentNodeType');

    return [
      ToolbarButtonConfig(
        key: BlockTypeConstants.heading,
        icon: _getHeadingIcon(),
        onPressed:
            toolbarState.isDragMode ? null : () => actions.handleCycleHeading(),
        isActive: () {
          final active = currentNodeType == BlockTypeConstants.heading ||
              currentNodeType == BlockTypeConstants.paragraph;
          Log.info(
              '🔘 Heading button isActive: $active for node type: $currentNodeType');
          return active;
        },
      ),
      ToolbarButtonConfig(
        key: BlockTypeConstants.quote,
        icon: JournalIcons.jalignLeftSimple,
        onPressed:
            toolbarState.isDragMode ? null : () => actions.handleInsertQuote(),
        isActive: () {
          final active = currentNodeType == BlockTypeConstants.quote;
          Log.info(
              '🔘 Quote button isActive: $active for node type: $currentNodeType');
          return active;
        },
      ),
      ToolbarButtonConfig(
        key: 'list',
        icon: _getListIcon(),
        onPressed:
            toolbarState.isDragMode ? null : () => actions.handleCycleList(),
        isActive: () {
          final active = ['bulleted_list', 'numbered_list', 'todo_list']
              .contains(currentNodeType);
          Log.info(
              '🔘 List button isActive: $active for node type: $currentNodeType');
          return active;
        },
      ),
      if (canIndentNode)
        ToolbarButtonConfig(
          key: 'outdent',
          icon: JournalIcons.jtextOutdent,
          onPressed: canOutdent ? () => actions.handleOutdent() : null,
        ),
      if (canIndentNode)
        ToolbarButtonConfig(
          key: 'indent',
          icon: JournalIcons.jtextIndent,
          onPressed: canIndent ? () => actions.handleIndent() : null,
        ),
      if (![
        'todo_list',
        'bulleted_list',
        'numbered_list',
        BlockTypeConstants.quote
      ].contains(currentNodeType))
        ToolbarButtonConfig(
          key: 'alignment',
          icon: _getAlignmentIcon(),
          onPressed: toolbarState.isDragMode
              ? null
              : () => actions.handleCycleAlignment(),
        ),
      // ToolbarButtonConfig(
      //   key: 'undo',
      //   icon: JournalIcons.jarrowArcLeft,
      //   onPressed: toolbarState.isDragMode
      //       ? null
      //       : () => editorState.undoManager.undo(),
      // ),
      // ToolbarButtonConfig(
      //   key: 'redo',
      //   icon: JournalIcons.jarrowArcRight,
      //   onPressed: toolbarState.isDragMode
      //       ? null
      //       : () => editorState.undoManager.redo(),
      // ),
    ];
  }

  List<ToolbarButtonConfig> getInsertButtons() {
    return [
      ToolbarButtonConfig(
        key: 'insert_above',
        icon: JournalIcons.jrowsPlusTop,
        onPressed: () => actions.handleInsertAbove(),
      ),
      ToolbarButtonConfig(
        key: 'insert_below',
        icon: JournalIcons.jrowsPlusBottom,
        onPressed: () => actions.handleInsertBelow(),
      ),
      ToolbarButtonConfig(
        key: BlockTypeConstants.divider,
        icon: JournalIcons.jminus,
        onPressed: () => actions.handleInsertDivider(),
        isActive: () =>
            toolbarState.currentBlockType == BlockTypeConstants.divider,
      ),
      ToolbarButtonConfig(
        key: 'actions',
        icon: JournalIcons.jdotsThree,
        onPressed: () =>
            toolbarState.showActionsMenu = !toolbarState.showActionsMenu,
        isActive: () => toolbarState.showActionsMenu,
      ),
    ];
  }

  List<ToolbarButtonConfig> getActionButtons() {
    final buttons = <ToolbarButtonConfig>[];

    // Add delete button for dividers
    if (toolbarState.currentBlockType == BlockTypeConstants.divider) {
      buttons.add(ToolbarButtonConfig(
        key: 'delete',
        icon: JournalIcons.jxCircle,
        onPressed: () => actions.handleDelete(),
      ));
    }

    // Add copy, cut, paste buttons
    buttons.addAll([
      ToolbarButtonConfig(
        key: 'copy',
        icon: JournalIcons.jcopy,
        onPressed: () => actions.handleCopyToClipboard(),
      ),
      ToolbarButtonConfig(
        key: 'cut',
        icon: JournalIcons.jscissors,
        onPressed: () => actions.handleCutToClipboard(),
      ),
      ToolbarButtonConfig(
        key: 'paste',
        icon: JournalIcons.jclipboard,
        onPressed: () => actions.handlePasteFromClipboard(),
      ),
    ]);

    return buttons;
  }

  List<ToolbarButtonConfig> getSelectionButtons() {
    return [
      ToolbarButtonConfig(
        key: 'bold',
        icon: JournalIcons.jtextB,
        onPressed: () => actions.handleToggleStyle('bold'),
        isActive: () => toolbarState.isStyleBold,
      ),
      ToolbarButtonConfig(
        key: 'italic',
        icon: JournalIcons.jtextItalic,
        onPressed: () => actions.handleToggleStyle('italic'),
        isActive: () => toolbarState.isStyleItalic,
      ),
      ToolbarButtonConfig(
        key: 'underline',
        icon: JournalIcons.jtextUnderline,
        onPressed: () => actions.handleToggleStyle('underline'),
        isActive: () => toolbarState.isStyleUnderline,
      ),
      ToolbarButtonConfig(
        key: 'strikethrough',
        icon: JournalIcons.jtextStrikethrough,
        onPressed: () => actions.handleToggleStyle('strikethrough'),
        isActive: () => toolbarState.isStyleStrikethrough,
      ),
      ToolbarButtonConfig(
        key: 'color_sheet',
        icon: JournalIcons.jtextAUnderline,
        onPressed: () => actions.showColorBottomSheet(),
        isActive: () => false,
      ),
    ];
  }

  List<ToolbarButtonConfig> getDragButtons() {
    // Disable move up for the first reorderable block (visual index 0)
    final isFirstBlock = toolbarState.currentSelectionPath != null &&
        toolbarState.currentSelectionPath!.length == 1 &&
        toolbarState.currentSelectionPath![0] == 0;

    return [
      ToolbarButtonConfig(
        key: 'move_up',
        icon: JournalIcons.jarrowLineUp,
        onPressed: isFirstBlock ? null : onMoveUp,
      ),
      ToolbarButtonConfig(
        key: 'move_down',
        icon: JournalIcons.jarrowLineDown,
        onPressed: onMoveDown,
      ),
    ];
  }

  IconData _getHeadingIcon() {
    if (toolbarState.currentBlockType == BlockTypeConstants.heading) {
      return toolbarState.headingLevel == 2
          ? JournalIcons.jtextHTwo
          : JournalIcons.jtextHThree;
    }
    return JournalIcons.jparagraph;
  }

  IconData _getListIcon() {
    switch (toolbarState.currentBlockType) {
      case 'todo_list':
        return JournalIcons.jcheckSquare;
      case 'bulleted_list':
        return JournalIcons.jlistBullets;
      case 'numbered_list':
        return JournalIcons.jlistNumbers;
      default:
        return JournalIcons.jlistBullets;
    }
  }

  IconData _getAlignmentIcon() {
    final selection = editorState.selection;
    if (selection == null) return JournalIcons.jtextAlignLeft;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return JournalIcons.jtextAlignLeft;
    final align = node.attributes['align'] as String? ?? 'left';
    switch (align) {
      case 'center':
        return JournalIcons.jtextAlignCenter;
      case 'right':
        return JournalIcons.jtextAlignRight;
      default:
        return JournalIcons.jtextAlignLeft;
    }
  }
}
