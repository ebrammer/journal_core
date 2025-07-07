// lib/src/models/journal.dart
import 'package:appflowy_editor/appflowy_editor.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart'; // Add uuid package for generating IDs
import 'block_type_constants.dart';
import 'package:journal_core/journal_core.dart';

class Journal {
  final String id;
  final String title;
  final int createdAt;
  final int lastModified;
  final Document content;

  Journal({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.lastModified,
    required this.content,
  });

  factory Journal.fromJson(Map<String, dynamic> json) {
    try {
      print('🔍 [journal] Parsing JSON: $json');

      // Validate content field
      if (!json.containsKey('content') ||
          json['content'] == null ||
          (json['content'] is Map && json['content'].isEmpty)) {
        print(
            '⚠️ [journal] No content field found or content is empty in JSON');
        return Journal.blank();
      }

      // Parse content JSON
      final contentJson = json['content'];
      Document document;

      if (contentJson is String) {
        try {
          if (contentJson.isEmpty) {
            print('⚠️ [journal] Content string is empty');
            return Journal.blank();
          }
          final Map<String, dynamic> parsedJson = jsonDecode(contentJson);
          document = Document.fromJson(parsedJson);
        } catch (e) {
          print('❌ [journal] Failed to parse content JSON string: $e');
          return Journal.blank();
        }
      } else if (contentJson is Map<String, dynamic>) {
        try {
          if (contentJson.isEmpty) {
            print('⚠️ [journal] Content map is empty');
            return Journal.blank();
          }
          document = Document.fromJson(contentJson);
        } catch (e) {
          print('❌ [journal] Failed to parse content JSON map: $e');
          return Journal.blank();
        }
      } else {
        print('❌ [journal] Invalid content type: ${contentJson.runtimeType}');
        return Journal.blank();
      }

      // Ensure document has correct structure
      if (document.root.type != BlockTypeConstants.page) {
        print('⚠️ [journal] Root type is not page, fixing structure');
        document = Document(
          root: Node(
            type: BlockTypeConstants.page,
            children: document.root.children,
          ),
        );
      }

      // Create editor state for modifications
      final editorState = EditorState(document: document);

      // Add metadata and spacer if they don't exist
      if (document.root.children.isEmpty ||
          document.root.children.first.type != BlockTypeConstants.metadata) {
        final transaction = editorState.transaction;
        transaction.insertNode(
          [0],
          Node(
            type: BlockTypeConstants.metadata,
            attributes: {
              'created_at':
                  json['created_at'] ?? DateTime.now().millisecondsSinceEpoch
            },
          ),
        );
        editorState.apply(transaction);
        print('📌 [journal] Added metadata block');
      }

      if (document.root.children.isEmpty ||
          document.root.children.last.type != BlockTypeConstants.spacer) {
        final transaction = editorState.transaction;
        transaction.insertNode(
          [document.root.children.length],
          Node(
            type: BlockTypeConstants.spacer,
            attributes: {'height': 100},
          ),
        );
        editorState.apply(transaction);
        print('📌 [journal] Added spacer block');
      }

      print(
          '✅ [journal] Successfully parsed wrapped document: ${document.toJson()}');

      return Journal(
        id: json['id'] ?? '',
        title: json['title'] ?? '',
        createdAt: json['created_at'] ?? DateTime.now().millisecondsSinceEpoch,
        lastModified:
            json['last_modified'] ?? DateTime.now().millisecondsSinceEpoch,
        content: document,
      );
    } catch (e, stackTrace) {
      print('❌ [journal] Error parsing journal: $e');
      print('📚 [journal] Stack trace: $stackTrace');
      return Journal.blank();
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt,
      'last_modified': lastModified,
      'content': content.toJson(),
    };
  }

  factory Journal.blank() {
    final now = DateTime.now().millisecondsSinceEpoch;
    final document = Document(
      root: Node(
        type: BlockTypeConstants.page,
        children: [
          Node(
            type: BlockTypeConstants.metadata,
            attributes: {'created_at': now},
          ),
          Node(
            type: BlockTypeConstants.paragraph,
            attributes: {
              'delta': [
                {'insert': ''}
              ]
            },
          ),
          Node(
            type: BlockTypeConstants.spacer,
            attributes: {'height': 100},
          ),
        ],
      ),
    );

    return Journal(
      id: '',
      title: '',
      createdAt: now,
      lastModified: now,
      content: document,
    );
  }

  Journal clone() => Journal(
        id: this.id,
        title: this.title,
        createdAt: this.createdAt,
        lastModified: this.lastModified,
        content: Document.fromJson(this.content.toJson()),
        // Add other fields if present
      );
}
