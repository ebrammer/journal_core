// lib/src/toolbar/toolbar_buttons.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';

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
/// - Includes debug logs with 🔍 prefix for button states and actions.
/// - Compatible with AppFlowy 4.0.0 and single-editor drag-and-drop approach.
class ToolbarButtons {
  final EditorState editorState;
  final ToolbarState toolbarState;
  final ToolbarActions actions;
  final FocusNode? focusNode;

  ToolbarButtons({
    required this.editorState,
    required this.toolbarState,
    required this.actions,
    this.focusNode,
  });

  List<ToolbarButtonConfig> getMainButtons() {
    Log.info(
        '🔧 ToolbarButtons: Current block type: ${toolbarState.currentBlockType}, isDragMode: ${toolbarState.isDragMode}');

    final canIndentNode = [
      'paragraph',
      'heading',
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
        ? editorState.getNodeAtPath(selection.start.path)?.type ?? 'paragraph'
        : 'paragraph';
    Log.info('🔧 ToolbarButtons: EditorState node type: $currentNodeType');

    return [
      ToolbarButtonConfig(
        key: 'heading',
        icon: _getHeadingIcon(),
        onPressed:
            toolbarState.isDragMode ? null : () => actions.handleCycleHeading(),
        isActive: () {
          final active =
              currentNodeType == 'heading' || currentNodeType == 'paragraph';
          Log.info(
              '🔘 Heading button isActive: $active for node type: $currentNodeType');
          return active;
        },
      ),
      ToolbarButtonConfig(
        key: 'quote',
        icon: AppIcons.kalignLeftSimple,
        onPressed:
            toolbarState.isDragMode ? null : () => actions.handleInsertQuote(),
        isActive: () {
          final active = currentNodeType == 'quote';
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
          icon: AppIcons.ktextOutdent,
          onPressed: canOutdent ? () => actions.handleOutdent() : null,
        ),
      if (canIndentNode)
        ToolbarButtonConfig(
          key: 'indent',
          icon: AppIcons.ktextIndent,
          onPressed: canIndent ? () => actions.handleIndent() : null,
        ),
      if (!['todo_list', 'bulleted_list', 'numbered_list', 'quote']
          .contains(currentNodeType))
        ToolbarButtonConfig(
          key: 'alignment',
          icon: _getAlignmentIcon(),
          onPressed: toolbarState.isDragMode
              ? null
              : () => actions.handleCycleAlignment(),
        ),
      ToolbarButtonConfig(
        key: 'undo',
        icon: AppIcons.karrowArcLeft,
        onPressed: toolbarState.isDragMode
            ? null
            : () => editorState.undoManager.undo(),
      ),
      ToolbarButtonConfig(
        key: 'redo',
        icon: AppIcons.karrowArcRight,
        onPressed: toolbarState.isDragMode
            ? null
            : () => editorState.undoManager.redo(),
      ),
    ];
  }

  List<ToolbarButtonConfig> getInsertButtons() {
    return [
      ToolbarButtonConfig(
        key: 'insert_above',
        icon: AppIcons.krowsPlusTop,
        onPressed: () => actions.handleInsertAbove(),
      ),
      ToolbarButtonConfig(
        key: 'insert_below',
        icon: AppIcons.krowsPlusBottom,
        onPressed: () => actions.handleInsertBelow(),
      ),
      ToolbarButtonConfig(
        key: 'divider',
        icon: AppIcons.kminus,
        onPressed: () => actions.handleInsertDivider(),
        isActive: () => toolbarState.currentBlockType == 'divider',
      ),
    ];
  }

  List<ToolbarButtonConfig> getSelectionButtons() {
    return [
      ToolbarButtonConfig(
        key: 'bold',
        icon: AppIcons.ktextB,
        onPressed: () => actions.handleToggleStyle('bold'),
        isActive: () => toolbarState.isStyleBold,
      ),
      ToolbarButtonConfig(
        key: 'italic',
        icon: AppIcons.ktextItalic,
        onPressed: () => actions.handleToggleStyle('italic'),
        isActive: () => toolbarState.isStyleItalic,
      ),
      ToolbarButtonConfig(
        key: 'underline',
        icon: AppIcons.ktextUnderline,
        onPressed: () => actions.handleToggleStyle('underline'),
        isActive: () => toolbarState.isStyleUnderline,
      ),
      ToolbarButtonConfig(
        key: 'strikethrough',
        icon: AppIcons.ktextStrikethrough,
        onPressed: () => actions.handleToggleStyle('strikethrough'),
        isActive: () => toolbarState.isStyleStrikethrough,
      ),
    ];
  }

  List<ToolbarButtonConfig> getDragButtons() {
    return [
      ToolbarButtonConfig(
        key: 'move_up',
        icon: AppIcons.karrowLineUp,
        onPressed: () => actions.handleMoveUp(),
      ),
      ToolbarButtonConfig(
        key: 'move_down',
        icon: AppIcons.karrowLineDown,
        onPressed: () => actions.handleMoveDown(),
      ),
    ];
  }

  IconData _getHeadingIcon() {
    if (toolbarState.currentBlockType == 'heading') {
      return toolbarState.headingLevel == 2
          ? AppIcons.ktextHTwo
          : AppIcons.ktextHThree;
    }
    return AppIcons.kparagraph;
  }

  IconData _getListIcon() {
    switch (toolbarState.currentBlockType) {
      case 'todo_list':
        return AppIcons.kcheckSquare;
      case 'bulleted_list':
        return AppIcons.klistBullets;
      case 'numbered_list':
        return AppIcons.klistNumbers;
      default:
        return AppIcons.klistBullets;
    }
  }

  IconData _getAlignmentIcon() {
    final selection = editorState.selection;
    if (selection == null) return AppIcons.ktextAlignLeft;
    final node = editorState.getNodeAtPath(selection.start.path);
    if (node == null) return AppIcons.ktextAlignLeft;
    final align = node.attributes['align'] as String? ?? 'left';
    switch (align) {
      case 'center':
        return AppIcons.ktextAlignCenter;
      case 'right':
        return AppIcons.ktextAlignRight;
      default:
        return AppIcons.ktextAlignLeft;
    }
  }
}
