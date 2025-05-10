// src/widgets/editor_widget.dart

import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart'; // For AppFlowy integration
import 'dart:convert'; // For jsonEncode
import 'package:journal_core/journal_core.dart'; // For EditorWidget
import '../utils/content_utils.dart'; // Import content_utils.dart for JSON parsing
import 'package:provider/provider.dart';

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
  late final Map<String, BlockComponentBuilder> _blockBuilders;
  late final JournalEditorController _controller;

  late TextEditingController titleController;
  String _currentTitle = "";

  @override
  void initState() {
    super.initState();

    _currentTitle = widget.title;
    titleController = TextEditingController(text: _currentTitle);

    // Initialize the editor state with the raw JSON string (content)
    print('Initializing editor state with content...'); // Debug log
    final document = loadDocumentFromJson(widget.content);
    print('Created document: ${document.toJson()}'); // Debug log

    _editorState = EditorState(document: document);
    print('Editor state initialized with document'); // Debug log

    _focusNode = FocusNode();

    // Initialize with standard block builders
    _blockBuilders = standardBlockComponentBuilderMap;

    _controller = JournalEditorController(editorState: _editorState);
    _editorState.selectionNotifier
        .addListener(_controller.syncToolbarWithSelection);
  }

  @override
  void dispose() {
    _editorState.selectionNotifier
        .removeListener(_controller.syncToolbarWithSelection);
    titleController.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ToolbarState>(
        create: (_) => _controller.toolbarState,
        child: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            children: [
              // Title Editing Block
              TextField(
                controller: titleController,
                decoration: InputDecoration(labelText: 'Title'),
                onChanged: (value) {
                  setState(() {
                    _currentTitle = value; // Update title state
                  });
                },
              ),

              // Editor Content (AppFlowy)
              Expanded(
                child: AppFlowyEditor(
                  editorState: _editorState,
                  focusNode: _focusNode,
                  blockComponentBuilders: _blockBuilders,
                  editorStyle: EditorStyle.mobile(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    cursorColor: Colors.blueAccent,
                    textStyleConfiguration: const TextStyleConfiguration(
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
                onSave: () async {},
                focusNode: _focusNode, // Pass the FocusNode
              ),
            ],
          ),
        ));
  }
}
