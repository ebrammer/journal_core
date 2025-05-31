// lib/src/utils/content_utils.dart

import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart'; // AppFlowy dependencies
import 'package:journal_core/journal_core.dart';

/// Ensures a valid editor document is created from raw JSON input.
/// Handles null, empty, and malformed input gracefully.
Document ensureValidEditorDocument(String? rawJson) {
  if (rawJson == null || rawJson.trim().isEmpty) {
    Log.warn('[journal_core] Null or empty content. Using blank document.');
    return _defaultDocument();
  }

  try {
    final decoded = jsonDecode(rawJson);
    if (decoded is Map<String, dynamic> && decoded.containsKey('document')) {
      try {
        return Document.fromJson(decoded);
      } catch (e) {
        Log.error('[journal_core] Failed to create document from JSON: $e');
        return _defaultDocument();
      }
    }
    Log.warn('[journal_core] JSON missing document key. Using blank document.');
  } catch (e) {
    Log.error('[journal_core] JSON parse failed: $e');
  }

  return _defaultDocument();
}

/// Creates a default empty document with a single empty paragraph.
Document _defaultDocument() {
  return Document(
    root: Node(
      type: 'page',
      children: [
        Node(
          type: 'paragraph',
          attributes: {
            'delta': [
              {'insert': ''}
            ]
          },
        ),
      ],
    ),
  );
}

/// Function to load content from raw JSON string into a Document
Document loadDocumentFromJson(String content) {
  try {
    print('Raw content: $content'); // Debug log
    final Map<String, dynamic> json = jsonDecode(content);
    print('Parsed JSON: $json'); // Debug log

    // If the content is already a document structure, use it directly
    if (json.containsKey('document')) {
      print('Found document key: ${json['document']}'); // Debug log
      // Create a new document with the inner structure
      final Map<String, dynamic> documentMap = json['document'];
      print('Document map: $documentMap'); // Debug log

      // Create the root node with all its attributes
      final rootNode = Node(
        type: documentMap['type'] as String,
        attributes: Map<String, Object>.from(documentMap['data'] ?? {}),
        children: (documentMap['children'] as List).map((child) {
          final childMap = child as Map<String, dynamic>;
          final childData = childMap['data'] as Map<String, dynamic>? ?? {};

          // Handle delta content
          if (childData.containsKey('delta')) {
            return Node(
              type: childMap['type'] as String,
              attributes: {
                'delta': childData['delta'],
              },
            );
          }

          // Handle blocks with children
          return Node(
            type: childMap['type'] as String,
            attributes: Map<String, Object>.from(childData),
            children: (childMap['children'] as List?)?.map((grandChild) {
                  final grandChildMap = grandChild as Map<String, dynamic>;
                  final grandChildData =
                      grandChildMap['data'] as Map<String, dynamic>? ?? {};

                  if (grandChildData.containsKey('delta')) {
                    return Node(
                      type: grandChildMap['type'] as String,
                      attributes: {
                        'delta': grandChildData['delta'],
                      },
                    );
                  }

                  return Node(
                    type: grandChildMap['type'] as String,
                    attributes: Map<String, Object>.from(grandChildData),
                  );
                }).toList() ??
                [],
          );
        }).toList(),
      );

      print('Created root node: ${rootNode.toJson()}'); // Debug log
      return Document(root: rootNode);
    }

    // If content is a string, wrap it in a document structure
    if (content is String) {
      print('Wrapping string content in document structure'); // Debug log
      return Document(
        root: Node(
          type: 'page',
          children: [
            Node(
              type: 'paragraph',
              attributes: {
                'delta': [
                  {'insert': content}
                ]
              },
            ),
          ],
        ),
      );
    }

    // If we have a map but no document key, wrap it in a document structure
    print('Wrapping map content in document structure'); // Debug log
    return Document(
      root: Node(
        type: 'page',
        children: [
          Node(
            type: 'paragraph',
            attributes: {
              'delta': [
                {'insert': jsonEncode(json)}
              ]
            },
          ),
        ],
      ),
    );
  } catch (e) {
    print('Failed to parse content: $e');
    // Return a default empty document if parsing fails
    return Document(
      root: Node(
        type: 'page',
        children: [
          Node(
            type: 'paragraph',
            attributes: {
              'delta': [
                {'insert': ''}
              ]
            },
          ),
        ],
      ),
    );
  }
}
