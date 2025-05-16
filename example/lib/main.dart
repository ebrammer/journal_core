import 'package:flutter/material.dart';
import 'package:journal_core/journal_core.dart';
import 'package:journal_core/src/theme/journal_theme.dart';

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
      home: Scaffold(
        backgroundColor: JournalTheme.light().primaryBackground,
        body: SafeArea(
          child: EditorWidget(
            title: 'Test Entry',
            createdAt: DateTime.now().millisecondsSinceEpoch,
            lastModified: DateTime.now().millisecondsSinceEpoch,
            content:
                '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"Hello world!"}]}}]}}',
            onSave: (updatedJson) async => debugPrint("Saved: $updatedJson"),
          ),
        ),
      ),
    );
  }
}
