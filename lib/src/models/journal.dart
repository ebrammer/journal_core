// lib/src/models/journal.dart
import 'package:appflowy_editor/appflowy_editor.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart'; // Add uuid package for generating IDs
import 'block_type_constants.dart';

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
        throw FormatException('Missing or null content field: $json');
      }

      final contentJson = json['content'] as String;
      if (contentJson.isEmpty) {
        throw FormatException('Content is empty');
      }

      // Parse the content JSON
      final decoded = jsonDecode(contentJson);
      if (decoded is! Map<String, dynamic>) {
        throw FormatException('Content is not a valid JSON object');
      }

      // Ensure all nodes have IDs
      final documentWithIds = _addIdsToNodes(decoded);

      return Journal(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        createdAt: json['createdAt'] as int? ?? 0,
        lastModified: json['lastModified'] as int? ?? 0,
        content: Document.fromJson(documentWithIds),
      );
    } catch (e, stackTrace) {
      print('Journal.fromJson: Failed to parse Journal: $e');
      print('Journal.fromJson: Stack trace: $stackTrace');
      print('Journal.fromJson: Input JSON: $json');
      return Journal(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        createdAt: json['createdAt'] as int? ?? 0,
        lastModified: json['lastModified'] as int? ?? 0,
        content: Document(
          root: Node(
            type: BlockTypeConstants.page,
            children: [
              Node(
                type: BlockTypeConstants.paragraph,
                attributes: {
                  'delta': [
                    {'insert': 'Error parsing content: $e'}
                  ]
                },
              ),
            ],
          ),
        ),
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
