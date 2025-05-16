import 'package:flutter/material.dart';
import 'package:journal_core/journal_core.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'dart:convert';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Journal Core Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Journal Core Demo'),
      ),
      body: Center(
        child: ElevatedButton(
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => const EditorPage(),
              ),
            );
          },
          child: const Text('Open Editor'),
        ),
      ),
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
    final document = loadDocumentFromJson(
        '{"type":"page","children":[{"type":"paragraph","children":[{"type":"text","text":"Hello World!"}]}]}');
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

  Future<void> _handleSave(dynamic json) async {
    // Handle save logic here
    print('Saving content: $json');
  }

  @override
  Widget build(BuildContext context) {
    return EditorWidget(
      title: 'Test Journal',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      content:
          '{"type":"page","children":[{"type":"paragraph","children":[{"type":"text","text":"Hello World!"}]}]}',
      onSave: _handleSave,
      onBack: () async {
        // Get the current content before navigating
        final content = _controller.getDocumentContent();
        // Save the content
        await _handleSave(jsonDecode(content));
        // Navigate back
        if (mounted) {
          Navigator.of(context).pop();
        }
      },
    );
  }
}
