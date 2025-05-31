import 'package:flutter/material.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';
import 'package:journal_core/src/models/journal.dart';
import 'package:journal_core/src/models/block_type_constants.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Journal Editor',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const EditorPage(),
    );
  }
}

class EditorPage extends StatefulWidget {
  const EditorPage({super.key});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  late final JournalEditorController _controller;
  late final EditorState _editorState;

  @override
  void initState() {
    super.initState();
    final document = Document(
      root: Node(
        type: BlockTypeConstants.page,
        children: [
          Node(
            type: BlockTypeConstants.paragraph,
            children: [
              Node(
                type: 'text',
                attributes: {
                  'delta': [
                    {'insert': 'Hello World!'}
                  ]
                },
              ),
            ],
          ),
        ],
      ),
    );
    _editorState = EditorState(document: document);
    _controller = JournalEditorController(
      editorState: _editorState,
      toolbarState: ToolbarState(),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave(Journal journal) async {
    // Handle save logic here
    print('Saving journal: ${journal.toJson()}');
  }

  @override
  Widget build(BuildContext context) {
    final journal = Journal(
      id: 'test-journal',
      title: 'Test Journal',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      content: _editorState.document,
    );

    return EditorWidget(
      journal: journal,
      onSave: _handleSave,
      onBack: () async {
        // Get the current content before navigating
        final updatedJournal = Journal(
          id: journal.id,
          title: journal.title,
          createdAt: journal.createdAt,
          lastModified: DateTime.now().millisecondsSinceEpoch,
          content: _editorState.document,
        );
        // Save the content
        await _handleSave(updatedJournal);
        // Navigate back
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}
