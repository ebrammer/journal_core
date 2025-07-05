import 'package:flutter/material.dart';
import 'package:journal_core/journal_core.dart';
import 'package:journal_core/src/theme/journal_theme.dart';
import 'package:journal_core/src/models/journal.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'dart:convert';

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
      darkTheme: ThemeData(
        colorScheme: ColorScheme.dark(
          surface: JournalTheme.dark().primaryBackground,
        ),
      ),
      themeMode: ThemeMode.system,
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isReadOnly = false;

  // Hardcoded journal list for demo
  List<Journal> _journals = [
    Journal(
      id: 'test-entry-1',
      title: 'Test Entry 1',
      createdAt: DateTime.now().millisecondsSinceEpoch,
      lastModified: DateTime.now().millisecondsSinceEpoch,
      content: Document.fromJson(jsonDecode(
        '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"Hello world!"}]}}]}}',
      )),
    ),
    Journal(
      id: 'test-entry-2',
      title: 'Test Entry 2',
      createdAt: DateTime.now().millisecondsSinceEpoch - 86400000, // 1 day ago
      lastModified: DateTime.now().millisecondsSinceEpoch - 86400000,
      content: Document.fromJson(jsonDecode(
        '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":"Another journal entry"}]}}]}}',
      )),
    ),
  ];

  void _addJournal(Journal journal) {
    setState(() {
      _journals = [..._journals.where((j) => j.id != journal.id), journal];
    });
  }

  void _removeJournal(String journalId) {
    setState(() {
      _journals = _journals.where((j) => j.id != journalId).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      appBar: AppBar(
        title: const Text('Journal Core Example'),
        backgroundColor: theme.primaryBackground,
        actions: [
          // Toggle button to switch between edit and read-only modes
          IconButton(
            icon: Icon(_isReadOnly ? Icons.edit : Icons.visibility),
            onPressed: () {
              setState(() {
                _isReadOnly = !_isReadOnly;
              });
            },
            tooltip: _isReadOnly
                ? 'Switch to Edit Mode'
                : 'Switch to Read-Only Mode',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () {
                        final newJournal = Journal(
                          id: 'journal-${DateTime.now().millisecondsSinceEpoch}',
                          title: '',
                          createdAt: DateTime.now().millisecondsSinceEpoch,
                          lastModified: DateTime.now().millisecondsSinceEpoch,
                          content: Document.fromJson(jsonDecode(
                              '{"document":{"type":"page","children":[{"type":"paragraph","data":{"delta":[{"insert":""}]}}]}}')),
                        );
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => EditorScreen(
                              journal: newJournal,
                              onJournalSaved: _addJournal,
                              onJournalDeleted: _removeJournal,
                              readOnly: _isReadOnly,
                            ),
                          ),
                        );
                      },
                      child: const Text('Create New Journal'),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 6.0),
                    decoration: BoxDecoration(
                      color: _isReadOnly
                          ? Colors.orange.withOpacity(0.2)
                          : Colors.green.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16.0),
                    ),
                    child: Text(
                      _isReadOnly ? 'Read-Only' : 'Edit Mode',
                      style: TextStyle(
                        color: _isReadOnly
                            ? Colors.orange[700]
                            : Colors.green[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: _journals.length,
                itemBuilder: (context, index) {
                  final journal = _journals[index];
                  return ListTile(
                    title: Text(
                        journal.title.isEmpty ? 'Untitled' : journal.title),
                    subtitle: Text(
                      DateTime.fromMillisecondsSinceEpoch(journal.createdAt)
                          .toString(),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => EditorScreen(
                            journal: journal,
                            onJournalSaved: _addJournal,
                            onJournalDeleted: _removeJournal,
                            readOnly: _isReadOnly,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EditorScreen extends StatelessWidget {
  final Journal journal;
  final void Function(Journal journal) onJournalSaved;
  final void Function(String journalId) onJournalDeleted;
  final bool readOnly;

  const EditorScreen({
    super.key,
    required this.journal,
    required this.onJournalSaved,
    required this.onJournalDeleted,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = JournalTheme.fromBrightness(Theme.of(context).brightness);
    return Scaffold(
      backgroundColor: theme.primaryBackground,
      body: EditorWidget(
        journal: journal,
        readOnly: readOnly,
        onSave: (updatedJournal, _) async {
          debugPrint("Saved: ${updatedJournal.toJson()}");
          onJournalSaved(updatedJournal);
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        },
        onBack: () async {
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        },
        onDelete: () async {
          onJournalDeleted(journal.id);
          if (Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        },
        onPrayer: () async {
          debugPrint("Adding prayer block");
        },
        onScripture: () async {
          debugPrint("Adding scripture block");
        },
        onTag: () async {
          debugPrint("Adding tag");
        },
      ),
    );
  }
}
