// lib/src/toolbar/toolbar_buttons.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';

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

class ToolbarButtons {
  final EditorState editorState;
  final ToolbarState toolbarState;
  final ToolbarActions actions;
  final FocusNode? focusNode; // Add FocusNode

  ToolbarButtons({
    required this.editorState,
    required this.toolbarState,
    required this.actions,
    this.focusNode, // Add to constructor
  });

  List<ToolbarButtonConfig> getMainButtons() {
    // Log current block type for debugging
    Log.info(
        '🔧 ToolbarButtons: Current block type: ${toolbarState.currentBlockType}');

    final isListBlock = ['todo_list', 'bulleted_list', 'numbered_list']
        .contains(toolbarState.currentBlockType);
    final isTopLevel = toolbarState.currentSelectionPath != null &&
        toolbarState.currentSelectionPath!.length == 1;
    final isChildNode = toolbarState.currentSelectionPath != null &&
        toolbarState.currentSelectionPath!.length > 1;
    final prevIsListBlock = ['todo_list', 'bulleted_list', 'numbered_list']
        .contains(toolbarState.previousSiblingType);

    // Directly query EditorState for block type, similar to _getAlignmentIcon
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
      if (isListBlock)
        ToolbarButtonConfig(
          key: 'outdent',
          icon: AppIcons.ktextOutdent,
          onPressed: isChildNode ? () => actions.handleOutdent() : null,
          isActive: () => isChildNode, // Activate if nested
        ),
      if (isListBlock)
        ToolbarButtonConfig(
          key: 'indent',
          icon: AppIcons.ktextIndent,
          onPressed: prevIsListBlock ? () => actions.handleIndent() : null,
          isActive: () =>
              prevIsListBlock, // Activate if previous sibling is a list
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
      if (!isListBlock)
        ToolbarButtonConfig(
          key: 'alignment',
          icon: _getAlignmentIcon(),
          onPressed: toolbarState.isDragMode
              ? null
              : () => actions.handleCycleAlignment(),
        ),
      ToolbarButtonConfig(
        key: 'drag',
        icon: AppIcons.kswap,
        onPressed: () => toolbarState.isDragMode = !toolbarState.isDragMode,
        isActive: () => toolbarState.isDragMode,
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
