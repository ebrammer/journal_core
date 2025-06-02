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

  Map<String, dynamic> toJson() {
    final documentJson = content.toJson();
    // Ensure all nodes have an ID
    final documentWithIds = _addIdsToNodes({'document': documentJson});
    return {
      'id': id,
      'title': title,
      'createdAt': createdAt,
      'lastModified': lastModified,
      'content': jsonEncode(documentWithIds),
    };
  }

  factory Journal.fromJson(Map<String, dynamic> json) {
    try {
      if (!json.containsKey('content') || json['content'] == null) {
        Log.warn('[journal_core] Missing or null content field: $json');
        return Journal(
          id: json['id'] as String? ?? '',
          title: json['title'] as String? ?? '',
          createdAt: json['createdAt'] as int? ?? 0,
          lastModified: json['lastModified'] as int? ?? 0,
          content: Document.blank(),
        );
      }

      final contentJson = json['content'] as String;
      if (contentJson.isEmpty) {
        Log.warn('[journal_core] Content is empty');
        return Journal(
          id: json['id'] as String? ?? '',
          title: json['title'] as String? ?? '',
          createdAt: json['createdAt'] as int? ?? 0,
          lastModified: json['lastModified'] as int? ?? 0,
          content: Document.blank(),
        );
      }

      Log.info('[journal_core] Parsing content JSON: $contentJson');
      final decoded = jsonDecode(contentJson);
      if (decoded is! Map<String, dynamic>) {
        Log.error(
            '[journal_core] Content is not a valid JSON object: $decoded');
        throw FormatException('Content is not a valid JSON object');
      }

      // Ensure the document has the correct structure
      Map<String, dynamic> documentWithIds;
      if (decoded.containsKey('document')) {
        final doc = decoded['document'] as Map<String, dynamic>;
        Log.info('[journal_core] Found document structure: $doc');

        // Ensure the document has a page type root
        if (!doc.containsKey('type') || doc['type'] != 'page') {
          Log.warn(
              '[journal_core] Document root type is not page, fixing structure');
          doc['type'] = 'page';
        }
        documentWithIds = _addIdsToNodes(decoded);
      } else {
        Log.warn('[journal_core] Document structure missing, wrapping content');
        documentWithIds = _addIdsToNodes({
          'document': {
            'type': 'page',
            'children': decoded['children'] ?? [],
          }
        });
      }

      Log.info(
          '[journal_core] Document structure before parsing: $documentWithIds');
      final document = Document.fromJson(documentWithIds);
      Log.info('[journal_core] Document after parsing: ${document.toJson()}');

      return Journal(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        createdAt: json['createdAt'] as int? ?? 0,
        lastModified: json['lastModified'] as int? ?? 0,
        content: document,
      );
    } catch (e, stackTrace) {
      Log.error('[journal_core] Failed to parse Journal: $e');
      Log.error('[journal_core] Stack trace: $stackTrace');
      Log.error('[journal_core] Input JSON: $json');
      return Journal(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        createdAt: json['createdAt'] as int? ?? 0,
        lastModified: json['lastModified'] as int? ?? 0,
        content: Document.blank(),
      );
    }
  }

  // Helper method to add IDs to nodes
  static Map<String, dynamic> _addIdsToNodes(Map<String, dynamic> json) {
    final uuid = Uuid();
    void addIds(Map<String, dynamic> node) {
      node['id'] ??= uuid.v4(); // Add ID if missing
      node['type'] ??= BlockTypeConstants.paragraph; // Ensure type is non-null
      node['attributes'] ??= {};
      if (node['children'] is List) {
        for (var child in node['children']) {
          if (child is Map<String, dynamic>) {
            addIds(child);
          }
        }
      }
    }

    final document = json['document'] as Map<String, dynamic>? ?? {};
    if (document.containsKey('root')) {
      addIds(document['root'] as Map<String, dynamic>);
    }
    return json;
  }
}
