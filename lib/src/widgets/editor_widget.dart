// lib/src/widgets/editor_widget.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';
import 'package:provider/provider.dart';
import 'reorderable_editor.dart'; // New widget for drag mode
import 'dart:convert';

class EditorWidget extends StatefulWidget {
  const EditorWidget({
    super.key,
    required this.title,
    required this.createdAt,
    required this.lastModified,
    required this.content, // Raw JSON string
    required this.onSave, // Callback for saving the updated content
  });

  final String title;
  final int createdAt; // Unix timestamp
  final int lastModified; // Unix timestamp
  final String content; // Raw JSON string passed from EditorWrapper
  final Future Function(dynamic updatedJson) onSave;

  @override
  State<EditorWidget> createState() => _EditorWidgetState();
}

class _EditorWidgetState extends State<EditorWidget> {
  late final EditorState _editorState;
  late final FocusNode _focusNode;
  late final JournalEditorController _controller;
  late List<int>? _selectedBlockPath; // Track selected block for styling

  late TextEditingController titleController;
  String _currentTitle = "";

  @override
  void initState() {
    super.initState();

    _currentTitle = widget.title;
    titleController = TextEditingController(text: _currentTitle);
    _selectedBlockPath = null;

    // Initialize the editor state with the raw JSON string
    Log.info('Initializing editor state with content...');
    final document = loadDocumentFromJson(widget.content);
    Log.info('Created document: ${document.toJson()}');

    _editorState = EditorState(document: document);
    Log.info('Editor state initialized with document');

    _focusNode = FocusNode();

    _controller = JournalEditorController(editorState: _editorState);
    _editorState.selectionNotifier.addListener(() {
      Log.info('🔄 Selection changed to: ${_editorState.selection}');
      _controller.syncToolbarWithSelection();
      _updateSelectedBlockPath();
    });
  }

  /// Updates the selected block path based on the current editor selection
  void _updateSelectedBlockPath() {
    final selection = _editorState.selection;
    if (selection != null && mounted) {
      setState(() {
        _selectedBlockPath = selection.start.path;
      });
      Log.info('🔍 Updated selected block path: $_selectedBlockPath');
    } else if (mounted) {
      setState(() {
        _selectedBlockPath = null;
      });
      Log.info('🔍 Cleared selected block path');
    }
  }

  /// Handles block selection from ReorderableEditor
  void _onBlockSelected(List<int> path) {
    if (mounted && path.join() != _selectedBlockPath?.join()) {
      setState(() {
        _selectedBlockPath = path;
      });
      // Delay selection update to avoid immediate recursion
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _editorState.selection =
              Selection.collapsed(Position(path: path, offset: 0));
          _controller.syncToolbarWithSelection();
        }
      });
    }
  }

  @override
  void dispose() {
    _editorState.selectionNotifier.removeListener(() {
      Log.info('🔄 Selection changed to: ${_editorState.selection}');
      _controller.syncToolbarWithSelection();
    });
    titleController.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ToolbarState>(
      create: (_) => _controller.toolbarState,
      child: Consumer<ToolbarState>(
        builder: (context, toolbarState, _) {
          // Log state before rendering ReorderableEditor
          if (toolbarState.isDragMode) {
            Log.info(
                '🔍 Switching to ReorderableEditor, nodes: ${_editorState.document.root.children.length}, '
                'selection: ${_editorState.selection}, selectedBlockPath: $_selectedBlockPath');
          }
          return SizedBox(
            width: double.infinity,
            height: double.infinity,
            child: Column(
              children: [
                // Title Editing Block
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                  onChanged: (value) {
                    setState(() {
                      _currentTitle = value;
                    });
                  },
                ),
                // Editor Content
                Expanded(
                  child: toolbarState.isDragMode
                      ? (_editorState.document.root.children.isEmpty
                          ? const Center(child: Text('No blocks to reorder'))
                          : ReorderableEditor(
                              editorState: _editorState,
                              selectedBlockPath: _selectedBlockPath,
                              onBlockSelected: _onBlockSelected,
                            ))
                      : AppFlowyEditor(
                          editorState: _editorState,
                          focusNode: _focusNode,
                          blockComponentBuilders:
                              standardBlockComponentBuilderMap,
                          editorStyle: EditorStyle.mobile(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            cursorColor: Colors.black,
                            textStyleConfiguration:
                                const TextStyleConfiguration(
                              text: TextStyle(
                                fontSize: 16,
                                height: 1.5,
                                color: Colors.black,
                              ),
                              bold: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                              italic: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.black,
                              ),
                            ),
                          ),
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
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
