// lib/src/widgets/editor_widget.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:journal_core/src/utils/focus_helpers.dart';
import 'package:journal_core/src/blocks/divider_block.dart' as divider;
import '../theme/journal_theme.dart';

class EditorWidget extends StatefulWidget {
  const EditorWidget({
    super.key,
    required this.title,
    required this.createdAt,
    required this.lastModified,
    required this.content,
    required this.onSave,
    this.onBack,
  });

  final String title;
  final int createdAt;
  final int lastModified;
  final String content;
  final Future Function(dynamic updatedJson) onSave;
  final Future Function()? onBack;

  @override
  State<EditorWidget> createState() => _EditorWidgetState();
}

class _EditorWidgetState extends State<EditorWidget> {
  late final EditorState _editorState;
  late final FocusNode _focusNode;
  late final JournalEditorController _controller;
  late List<int>? _selectedBlockPath;
  bool _showDeleteFab = true;

  late TextEditingController titleController;
  late FocusNode _titleFocusNode;
  String _currentTitle = "";
  bool _showCollapsedTitle = false;

  final GlobalKey<ReorderableEditorState> _reorderableKey =
      GlobalKey<ReorderableEditorState>();

  // Add a flag to track if a move is in progress
  bool _isMovingBlock = false;

  @override
  void initState() {
    super.initState();

    _currentTitle = widget.title;
    titleController = TextEditingController(text: _currentTitle);
    _titleFocusNode = FocusNode();
    _selectedBlockPath = null;

    Log.info('Initializing editor state with content...');
    final document = loadDocumentFromJson(widget.content);
    _editorState = EditorState(document: document);
    EditorGlobals.editorState = _editorState; // Set the global editor state

    final transaction = _editorState.transaction;
    // Insert metadata_block at the top instead of spacer_block
    if (document.root.children.isEmpty ||
        document.root.children.first.type != 'metadata_block') {
      transaction.insertNode(
          [0],
          Node(
            type: 'metadata_block',
            attributes: {'created_at': widget.createdAt},
          ));
    }
    // Keep bottom spacer_block
    if (document.root.children.isEmpty ||
        document.root.children.last.type != 'spacer_block') {
      transaction.insertNode(
          [document.root.children.length],
          Node(
            type: 'spacer_block',
            attributes: {'height': 100},
          ));
    }

    try {
      _editorState.apply(transaction);
      Log.info(
          'Created document with metadata_block and spacer: ${document.toJson()}');
    } catch (e, s) {
      Log.error('[EditorWidget.initState] Failed to apply transaction: $e\n$s');
    }

    _focusNode = FocusNode();
    _controller = JournalEditorController(editorState: _editorState);
    _editorState.selectionNotifier.addListener(_onSelectionChanged);

    _titleFocusNode.addListener(() {
      if (_titleFocusNode.hasFocus) {
        // Don't unfocus the editor's focus node, just clear its selection
        _editorState.selection = null;
      }
    });
  }

  void _updateSelectedBlockPath() {
    if (_isMovingBlock) {
      // Skip updating during a move to prevent jank
      return;
    }
    final selection = _editorState.selection;
    if (selection != null && selection.start.path.isNotEmpty) {
      final documentIndex = selection.start.path[0];
      if (documentIndex > 0) {
        // Adjust for metadata block
        final visualIndex = documentIndex - 1;
        // Only update if significantly different to avoid jank during transactions
        if (_selectedBlockPath == null ||
            _selectedBlockPath!.join() != [visualIndex].join()) {
          setState(() {
            _selectedBlockPath = [visualIndex];
          });
          Log.info('🔍 Updated selectedBlockPath to: $_selectedBlockPath');
        }
      }
    }
  }

  void _onBlockSelected(List<int> path) {
    setState(() {
      _selectedBlockPath = path;
      _showDeleteFab = true;
    });
    // Ensure a valid selection exists to keep toolbar visible
    if (_editorState.selection == null) {
      _editorState.selection = Selection.collapsed(
        Position(path: path, offset: 0),
      );
    }
  }

  void _onDocumentChanged([List<int>? newSelectedPath]) {
    Log.info('🔍 EditorWidget: Notified of document change');
    if (newSelectedPath != null) {
      setState(() {
        _selectedBlockPath = newSelectedPath;
      });
    }
    _updateBlocks();
  }

  @override
  void dispose() {
    // First remove listeners
    _editorState.selectionNotifier.removeListener(_onSelectionChanged);
    _titleFocusNode.removeListener(() {});

    // Then dispose controllers and focus nodes
    titleController.dispose();
    _titleFocusNode.dispose();
    _focusNode.dispose();

    // Finally dispose the editor controller and clean up globals
    _controller.dispose();
    EditorGlobals.editorState = null;

    super.dispose();
  }

  void _onSelectionChanged() {
    Log.info('🔄 Selection changed to: ${_editorState.selection}');
    _controller.syncToolbarWithSelection();
    _updateSelectedBlockPath();
    // Reset FAB visibility when selection changes
    if (mounted) {
      setState(() {
        _showDeleteFab = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    return ChangeNotifierProvider<ToolbarState>(
      create: (_) => _controller.toolbarState,
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: theme.primaryBackground,
          elevation: 0,
          title: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(JournalIcons.jarrowLeft, size: 24),
                    onPressed: () async {
                      // Save before navigating
                      final content = _controller.getDocumentContent();
                      await widget.onSave(jsonDecode(content));

                      // Ensure we dispose of the controller and its state before going back
                      _controller.dispose();

                      if (widget.onBack != null) {
                        await widget.onBack!();
                      } else {
                        Navigator.of(context).pop();
                      }
                    },
                    color: Theme.of(context).iconTheme.color,
                    iconSize: 24.0,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 8.0),
                  if (_showCollapsedTitle)
                    Container(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.6,
                      ),
                      child: Text(
                        _currentTitle.isEmpty ? 'Title' : _currentTitle,
                        style: TextStyle(
                          fontSize: 16.0,
                          fontWeight: FontWeight.w400,
                          color: theme.primaryText,
                          letterSpacing: 0.5,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(JournalIcons.jtrash, size: 20),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text('Delete Journal'),
                            content: const Text(
                                'Are you sure you want to delete this journal? This action cannot be undone.'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).pop(); // Close dialog
                                  Navigator.of(context)
                                      .pop(); // Go back to previous page
                                  widget.onSave(null);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Colors.red,
                                ),
                                child: const Text('Delete'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                    color: Theme.of(context).iconTheme.color,
                    iconSize: 24.0,
                    constraints: const BoxConstraints(
                      minWidth: 24,
                      minHeight: 24,
                    ),
                    padding: EdgeInsets.zero,
                  ),
                  const SizedBox(width: 12.0),
                  TextButton(
                    onPressed: () async {
                      final content = _controller.getDocumentContent();
                      await widget.onSave(jsonDecode(content));
                      Log.info('🔍 Saved document content: $content');
                    },
                    style: TextButton.styleFrom(
                      backgroundColor: theme.primaryText,
                      foregroundColor: theme.primaryBackground,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 6.0),
                      minimumSize: const Size(0, 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    child: const Text(
                      'Done',
                      style: TextStyle(
                        fontSize: 14.0,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        body: Container(
          color: theme.primaryBackground,
          child: Stack(
            children: [
              Column(
                children: [
                  Expanded(
                    child: Consumer<ToolbarState>(
                      builder: (context, toolbarState, _) {
                        if (toolbarState.isDragMode) {
                          // Hide the keyboard when entering reorder mode
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            unfocusAndHideKeyboard(context);
                            // Ensure a valid selection exists to keep toolbar visible
                            if (_editorState.selection == null &&
                                _selectedBlockPath != null) {
                              _editorState.selection = Selection.collapsed(
                                Position(path: _selectedBlockPath!, offset: 0),
                              );
                            }
                          });
                          Log.info(
                              '🔍 Switching to ReorderableEditor, nodes: ${_editorState.document.root.children.length}, '
                              'selection: ${_editorState.selection}, selectedBlockPath: $_selectedBlockPath');
                          return _editorState.document.root.children.isEmpty
                              ? const Center(
                                  child: Text('No blocks to reorder'))
                              : ReorderableEditor(
                                  key: _reorderableKey,
                                  editorState: _editorState,
                                  selectedBlockPath: _selectedBlockPath,
                                  onBlockSelected: _onBlockSelected,
                                  onDocumentChanged: (List<int>? newPath) =>
                                      _onDocumentChanged(newPath),
                                  titleController: titleController,
                                  createdAt: widget.createdAt,
                                  onTitleChanged: (value) {
                                    setState(() {
                                      _currentTitle = value;
                                    });
                                  },
                                  focusNode: _focusNode,
                                  readOnly: true,
                                );
                        } else {
                          return NotificationListener<ScrollNotification>(
                            onNotification: (notification) {
                              if (notification is ScrollUpdateNotification ||
                                  notification is UserScrollNotification) {
                                final offset = notification.metrics.pixels;
                                final shouldShow = offset > 80.0;
                                if (_showCollapsedTitle != shouldShow) {
                                  setState(() {
                                    _showCollapsedTitle = shouldShow;
                                  });
                                }
                              }
                              return false;
                            },
                            child: AppFlowyEditor(
                              editorState: _editorState,
                              focusNode: _focusNode,
                              blockComponentBuilders: {
                                ...standardBlockComponentBuilderMap,
                                'spacer_block': spacerBlockBuilder,
                                'metadata_block': MetadataBlockBuilder(
                                  titleController: titleController,
                                  createdAt: widget.createdAt,
                                  onTitleChanged: (value) {
                                    setState(() {
                                      _currentTitle = value;
                                    });
                                  },
                                  titleFocusNode: _titleFocusNode,
                                  onTitleEditingComplete: _focusFirstRealBlock,
                                  onTitleSubmitted: (_) =>
                                      _focusFirstRealBlock(),
                                  readOnly: false,
                                ),
                                divider.DividerBlockKeys.type:
                                    divider.DividerBlockComponentBuilder(),
                              },
                              editorStyle: EditorStyle.mobile(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 18, vertical: 8),
                                cursorColor: theme.primaryText,
                                textStyleConfiguration: TextStyleConfiguration(
                                  text: TextStyle(
                                    fontSize: 16,
                                    height: 1.5,
                                    color: theme.primaryText,
                                  ),
                                  bold: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: theme.primaryText,
                                  ),
                                  italic: TextStyle(
                                    fontStyle: FontStyle.italic,
                                    color: theme.primaryText,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                  ),
                  JournalToolbar(
                    editorState: _editorState,
                    controller: _controller,
                    onSave: () async {
                      final content = _controller.getDocumentContent();
                      await widget.onSave(jsonDecode(content));
                      Log.info('🔍 Saved document content: $content');
                    },
                    focusNode: _focusNode,
                    onDocumentChanged: () => _onDocumentChanged(),
                    onMoveUp: () {
                      if (_selectedBlockPath != null &&
                          _reorderableKey.currentState != null) {
                        _reorderableKey.currentState!
                            .moveBlock(_selectedBlockPath![0], -1);
                      }
                    },
                    onMoveDown: () {
                      if (_selectedBlockPath != null &&
                          _reorderableKey.currentState != null) {
                        _reorderableKey.currentState!
                            .moveBlock(_selectedBlockPath![0], 1);
                      }
                    },
                  ),
                ],
              ),
              // Floating delete button for selected divider
              if (_editorState.selection != null && _showDeleteFab)
                Consumer<ToolbarState>(
                  builder: (context, toolbarState, _) {
                    if (toolbarState.isDragMode) {
                      return const SizedBox.shrink();
                    }
                    final selectedNode = _editorState
                        .getNodeAtPath(_editorState.selection!.start.path);
                    if (selectedNode?.type == divider.DividerBlockKeys.type) {
                      return Positioned(
                        bottom: 56, // Position above the toolbar
                        left: 0,
                        right: 0,
                        child: Center(
                          child: TextButton(
                            onPressed: () {
                              setState(() {
                                _showDeleteFab = false;
                              });
                              _deleteDivider(selectedNode!);
                            },
                            style: TextButton.styleFrom(
                              backgroundColor: theme.primaryBackground,
                              foregroundColor: theme.primaryText,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8.0, vertical: 8.0),
                              minimumSize: const Size(0, 0),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(999),
                                side: BorderSide(
                                    color: theme.primaryText, width: 0.5),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(JournalIcons.jxCircle, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Divider',
                                  style: TextStyle(
                                    fontSize: 12.0,
                                    fontWeight: FontWeight.w400,
                                    color: theme.primaryText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _updateBlocks() {
    Log.info('🔍 EditorWidget: Triggered _updateBlocks');
  }

  void _focusFirstRealBlock() {
    final children = _editorState.document.root.children;
    for (int i = 0; i < children.length; i++) {
      final node = children[i];
      if (node.type != 'metadata_block' && node.type != 'spacer_block') {
        // Unfocus the title field first
        _titleFocusNode.unfocus();
        // Set the selection to the start of the first real block
        _editorState.selection =
            Selection.collapsed(Position(path: [i], offset: 0));
        // Request focus for the editor
        _focusNode.requestFocus();
        break;
      }
    }
  }

  void _deleteDivider(Node node) {
    final transaction = _editorState.transaction;
    transaction.deleteNode(node);
    try {
      _editorState.apply(transaction);
      _editorState.selection = null;
      _onDocumentChanged();
    } catch (e, s) {
      Log.error(
          '[EditorWidget._deleteDivider] Failed to delete divider: $e\n$s');
    }
  }
}
