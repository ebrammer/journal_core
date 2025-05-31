import 'package:flutter/material.dart';
import 'package:journal_core/journal_core.dart';
import 'package:journal_core/src/theme/journal_theme.dart';
import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart';

void main() => runApp(const JournalExampleApp());

class JournalExampleApp extends StatelessWidget {
  const JournalExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Journal Core Example',
      theme: ThemeData(
        colorScheme: ColorScheme.light(
          surface: JournalTheme.light().primaryBackground,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JournalTheme.light().primaryBackground,
      body: SafeArea(
        child: Center(
          child: TextButton(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (context) => const EditorScreen(),
                ),
              );
            },
            child: const Text('Open Editor'),
          ),
        ),
      ),
    );
  }
}

class EditorScreen extends StatelessWidget {
  const EditorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: JournalTheme.light().primaryBackground,
      body: EditorWidget(
        journal: Journal(
          id: 'test-entry',
          title: 'Test Entry',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          lastModified: DateTime.now().millisecondsSinceEpoch,
          content: Document.fromJson(jsonDecode(
            '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"Hello world!"}]}}]}}',
          )),
        ),
        onSave: (updatedJournal) async =>
            debugPrint("Saved: ${updatedJournal.toJson()}"),
        onBack: () async => Navigator.of(context).pop(),
      ),
    );
  }
}
