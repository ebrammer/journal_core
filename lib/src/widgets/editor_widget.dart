import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:journal_core/src/utils/focus_helpers.dart';
import 'package:journal_core/src/blocks/divider_block.dart' as divider;
import '../theme/journal_theme.dart';
import '../editor/editor_globals.dart';
import '../models/block_type_constants.dart';
import '../models/journal.dart';

class EditorWidget extends StatefulWidget {
  const EditorWidget({
    super.key,
    required this.journal,
    required this.onSave,
    required this.onBack,
    required this.onDelete,
  });

  final Journal journal;
  final Future Function(Journal updatedJournal, String contentJson) onSave;
  final Future Function() onBack;
  final Future Function() onDelete;

  @override
  State<EditorWidget> createState() => _EditorWidgetState();
}

class _EditorWidgetState extends State<EditorWidget> {
  late final EditorState _editorState;
  late final FocusNode _focusNode;
  late final JournalEditorController _controller;
  late final ToolbarState _toolbarState;
  late List<int>? _selectedBlockPath;
  bool _showDeleteFab = true;

  late TextEditingController titleController;
  late FocusNode _titleFocusNode;
  late String _currentTitle;
  bool _showCollapsedTitle = false;

  final GlobalKey<ReorderableEditorState> _reorderableKey =
      GlobalKey<ReorderableEditorState>();

  bool _isMovingBlock = false;

  bool _hasMeaningfulContent() {
    // Check if title is not empty
    if (_currentTitle.trim().isNotEmpty) {
      return true;
    }

    // Check if there are any content blocks (excluding metadata and spacer)
    for (final node in _editorState.document.root.children) {
      if (node.type != BlockTypeConstants.metadata &&
          node.type != BlockTypeConstants.spacer) {
        // For text blocks, check if they have any content
        if (node.type == BlockTypeConstants.paragraph) {
          final delta = node.attributes['delta'] as List<dynamic>?;
          if (delta != null && delta.isNotEmpty) {
            final text = delta.map((d) => d['insert'] as String).join('');
            if (text.trim().isNotEmpty) {
              return true;
            }
          }
        } else {
          // For other block types (like dividers), consider them as content
          return true;
        }
      }
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _currentTitle = widget.journal.title;
    titleController = TextEditingController(text: _currentTitle);
    _titleFocusNode = FocusNode();
    _focusNode = FocusNode();
    _selectedBlockPath = null;
    _toolbarState = ToolbarState();
    _initEditorState();
    _controller = JournalEditorController(
      editorState: _editorState,
      toolbarState: _toolbarState,
    );
    _controller.ensureValidSelection();
    _editorState.selectionNotifier.addListener(_onSelectionChanged);
    _titleFocusNode.addListener(() {
      if (_titleFocusNode.hasFocus) {
        _editorState.selection = null;
      }
    });
    // Add a listener to check for updated journal content after initial load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdatedContent();
    });
  }

  void _initEditorState() {
    try {
      final document = widget.journal.content;
      print('🔍 [editor_widget] Initializing editor with document');
      print('📄 [editor_widget] Document structure: ${document.toJson()}');

      // Ensure the document has a valid root structure
      if (document.root.type != BlockTypeConstants.page) {
        print('⚠️ [editor_widget] Root type is not page, fixing structure');
        final fixedDocument = Document(
          root: Node(
            type: BlockTypeConstants.page,
            children: document.root.children,
          ),
        );
        _editorState = EditorState(document: fixedDocument);
        EditorGlobals.editorState = _editorState;
      } else {
        _editorState = EditorState(document: document);
        EditorGlobals.editorState = _editorState;
      }

      // Add metadata and spacer blocks if they don't exist
      final transaction = _editorState.transaction;
      final validCreatedAt = widget.journal.createdAt > 0
          ? widget.journal.createdAt
          : DateTime.now().millisecondsSinceEpoch;

      // Only add metadata and spacer if they don't exist
      if (_editorState.document.root.children.isEmpty ||
          _editorState.document.root.children.first.type !=
              BlockTypeConstants.metadata) {
        transaction.insertNode(
          [0],
          Node(
            type: BlockTypeConstants.metadata,
            attributes: {'created_at': validCreatedAt},
          ),
        );
        print('📌 [editor_widget] Added metadata block');
      }
      if (_editorState.document.root.children.isEmpty ||
          _editorState.document.root.children.last.type !=
              BlockTypeConstants.spacer) {
        transaction.insertNode(
          [_editorState.document.root.children.length],
          Node(
            type: BlockTypeConstants.spacer,
            attributes: {'height': 100},
          ),
        );
        print('📌 [editor_widget] Added spacer block');
      }

      try {
        _editorState.apply(transaction);
        print('✅ [editor_widget] Editor state initialized successfully');
        print(
            '📊 [editor_widget] Final document structure: ${_editorState.document.toJson()}');
        // Log all block types in the document to check if builders are registered
        final blockTypes = _editorState.document.root.children
            .map((node) => node.type)
            .toSet();
        print('🧱 [editor_widget] Block types in document: $blockTypes');
        final registeredBuilders =
            standardBlockComponentBuilderMap.keys.toSet();
        print(
            '🧱 [editor_widget] Registered block builders: $registeredBuilders');
        final missingBuilders = blockTypes.difference(registeredBuilders);
        final knownCustomBlocks = {
          'metadata_block',
          'spacer_block',
          'date',
          'title'
        };
        final missingUnknownBuilders =
            missingBuilders.difference(knownCustomBlocks);
        if (missingUnknownBuilders.isNotEmpty) {
          print(
              '⚠️ [editor_widget] Missing builders for block types: $missingUnknownBuilders');
        }
      } catch (e, stackTrace) {
        print('❌ [editor_widget] Failed to apply transaction: $e');
        print('📚 [editor_widget] Stack trace: $stackTrace');
      }
    } catch (e, stackTrace) {
      print('❌ [editor_widget] Error initializing editor state: $e');
      print('📚 [editor_widget] Stack trace: $stackTrace');
      _editorState = EditorState(document: Document.blank());
    }
  }

  void _updateSelectedBlockPath() {
    if (_isMovingBlock) {
      return;
    }
    final selection = _editorState.selection;
    if (selection != null && selection.start.path.isNotEmpty) {
      final documentIndex = selection.start.path[0];
      if (documentIndex > 0) {
        final visualIndex = documentIndex - 1;
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
    EditorGlobals.editorState = null; // Clear the global editor state
    _editorState.selectionNotifier.removeListener(_onSelectionChanged);
    _titleFocusNode.dispose();
    _focusNode.dispose();
    titleController.dispose();
    _controller.dispose();
    _toolbarState.dispose();
    super.dispose();
  }

  void _onSelectionChanged() {
    Log.info('🔄 Selection changed to: ${_editorState.selection}');
    _controller.syncToolbarWithSelection();
    _updateSelectedBlockPath();
    if (mounted) {
      setState(() {
        _showDeleteFab = true;
      });
    }
  }

  void _handleTitleKeyPress(RawKeyEvent event) {
    if (event is RawKeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.enter) {
      // Find the first content block (after metadata)
      int firstContentIndex = 0;
      for (int i = 0; i < _editorState.document.root.children.length; i++) {
        if (_editorState.document.root.children[i].type !=
                BlockTypeConstants.metadata &&
            _editorState.document.root.children[i].type !=
                BlockTypeConstants.spacer) {
          firstContentIndex = i;
          break;
        }
      }

      // Set selection to the first content block
      _editorState.selection = Selection.collapsed(
        Position(path: [firstContentIndex], offset: 0),
      );

      // Request focus for the editor
      _focusNode.requestFocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_editorState == null) {
      print(
          '⚠️ [editor_widget] Editor state is null, showing loading indicator');
      return const Center(child: CircularProgressIndicator());
    }

    print('🏗️ [editor_widget] Building editor widget');
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    return ChangeNotifierProvider<ToolbarState>.value(
      value: _toolbarState,
      child: Scaffold(
        backgroundColor: theme.primaryBackground,
        appBar: AppBar(
          backgroundColor: theme.primaryBackground,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: theme.primaryBackground,
            statusBarIconBrightness:
                Theme.of(context).brightness == Brightness.dark
                    ? Brightness.light
                    : Brightness.dark,
          ),
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
          titleSpacing: 0,
          leadingWidth: 0,
          automaticallyImplyLeading: false,
          title: Padding(
            padding: const EdgeInsets.only(left: 4, right: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(JournalIcons.jarrowLeft, size: 24),
                      onPressed: () async {
                        if (!_hasMeaningfulContent()) {
                          // If no meaningful content, just go back without saving
                          await widget.onBack();
                          return;
                        }
                        final content = _controller.getDocumentContent();
                        final updatedJournal = Journal(
                          id: widget.journal.id,
                          title: _currentTitle,
                          createdAt: widget.journal.createdAt,
                          lastModified: DateTime.now().millisecondsSinceEpoch,
                          content: _editorState.document,
                        );
                        Log.info(
                            '🔍 Saving journal on back: ${updatedJournal.toJson()}');
                        await widget.onSave(updatedJournal, content);
                        await widget.onBack();
                      },
                      color: Theme.of(context).iconTheme.color,
                      iconSize: 24.0,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: EdgeInsets.zero,
                    ),
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
                      onPressed: () async {
                        Log.info(
                            '🔍 Deleting journal ID: ${widget.journal.id}');
                        await widget.onDelete();
                      },
                      color: Theme.of(context).iconTheme.color,
                      iconSize: 24.0,
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                      padding: const EdgeInsets.all(12.0),
                    ),
                  ],
                ),
              ],
            ),
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
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            unfocusAndHideKeyboard(context);
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
                                  journal: widget.journal,
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
                              key: ValueKey(
                                  _editorState.document.toJson().toString()),
                              editorState: _editorState,
                              focusNode: _focusNode,
                              blockComponentBuilders: {
                                ...standardBlockComponentBuilderMap,
                                'spacer_block': spacerBlockBuilder,
                                'metadata_block': MetadataBlockBuilder(
                                  titleController: titleController,
                                  createdAt: widget.journal.createdAt,
                                  onTitleChanged: (value) {
                                    setState(() {
                                      _currentTitle = value;
                                    });
                                  },
                                  titleFocusNode: _titleFocusNode,
                                  onTitleEditingComplete: () =>
                                      _titleFocusNode.unfocus(),
                                  onTitleSubmitted: (_) =>
                                      _titleFocusNode.unfocus(),
                                  readOnly: false,
                                ),
                                'date': MetadataBlockBuilder(
                                  titleController:
                                      TextEditingController(text: 'Date'),
                                  createdAt: widget.journal.createdAt,
                                  onTitleChanged: (_) {},
                                  titleFocusNode: FocusNode(),
                                  onTitleEditingComplete: () {},
                                  onTitleSubmitted: (_) {},
                                  readOnly: true,
                                ),
                                'title': MetadataBlockBuilder(
                                  titleController: TextEditingController(
                                      text: widget.journal.title),
                                  createdAt: widget.journal.createdAt,
                                  onTitleChanged: (value) {
                                    setState(() {
                                      _currentTitle = value;
                                    });
                                  },
                                  titleFocusNode: _titleFocusNode,
                                  onTitleEditingComplete: () =>
                                      _titleFocusNode.unfocus(),
                                  onTitleSubmitted: (_) =>
                                      _titleFocusNode.unfocus(),
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
                      if (!_hasMeaningfulContent()) {
                        // If no meaningful content, just go back without saving
                        await widget.onBack();
                        return;
                      }
                      final content = _controller.getDocumentContent();
                      final updatedJournal = Journal(
                        id: widget.journal.id,
                        title: _currentTitle,
                        createdAt: widget.journal.createdAt,
                        lastModified: DateTime.now().millisecondsSinceEpoch,
                        content: _editorState.document,
                      );
                      Log.info(
                          '🔍 Saving journal from toolbar: ${updatedJournal.toJson()}');
                      await widget.onSave(updatedJournal, content);
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
                        bottom: 56,
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

  void _deleteDivider(Node node) {
    final transaction = _editorState.transaction;
    transaction.deleteNode(node);
    try {
      _editorState.apply(transaction);
      _editorState.selection = null;
      _onDocumentChanged();
    } catch (e, stackTrace) {
      Log.error(
          '[EditorWidget._deleteDivider] Failed to delete divider: $e\n$stackTrace');
    }
  }

  // Add a method to check for updated content after initial load
  void _checkForUpdatedContent() {
    if (widget.journal.content != _editorState.document) {
      print(
          '🔄 [editor_widget] Detected updated content after initial load, updating document');
      setState(() {
        // Update the document without reinitializing _editorState
        final transaction = _editorState.transaction;
        // Clear existing content if necessary
        for (int i = _editorState.document.root.children.length - 1;
            i >= 0;
            i--) {
          if (_editorState.document.root.children[i].type !=
                  BlockTypeConstants.metadata &&
              _editorState.document.root.children[i].type !=
                  BlockTypeConstants.spacer) {
            transaction.deleteNode(_editorState.document.root.children[i]);
          }
        }
        // Add new content from widget.journal.content
        final newContentChildren = widget.journal.content.root.children;
        for (int i = 0; i < newContentChildren.length; i++) {
          if (newContentChildren[i].type != BlockTypeConstants.metadata &&
              newContentChildren[i].type != BlockTypeConstants.spacer) {
            transaction.insertNode(
              [_editorState.document.root.children.length - 1],
              newContentChildren[i],
            );
          }
        }
        _editorState.apply(transaction);
        // Update selection to ensure it points to a valid position
        if (_editorState.document.root.children.length > 1) {
          // Find the first non-metadata block
          int firstContentIndex = 0;
          for (int i = 0; i < _editorState.document.root.children.length; i++) {
            if (_editorState.document.root.children[i].type !=
                    BlockTypeConstants.metadata &&
                _editorState.document.root.children[i].type !=
                    BlockTypeConstants.spacer) {
              firstContentIndex = i;
              break;
            }
          }
          _editorState.selection = Selection.collapsed(
            Position(path: [firstContentIndex], offset: 0),
          );
          print(
              '🔍 [editor_widget] Selection updated to first content block at index: $firstContentIndex');
        }
        // Log detailed document structure for debugging
        print(
            '📊 [editor_widget] Updated document structure: ${_editorState.document.toJson()}');
        print(
            '🧱 [editor_widget] Block types after update: ${_editorState.document.root.children.map((node) => node.type).toList()}');
        print('✅ [editor_widget] Document updated with new content');
      });
    }
  }
}
