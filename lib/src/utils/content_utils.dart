import 'dart:convert';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:journal_core/journal_core.dart';
import '../models/block_type_constants.dart';

/// Ensures a valid editor document is created from raw JSON input.
/// Handles null, empty, and malformed input gracefully.
Document ensureValidEditorDocument(String? rawJson) {
  if (rawJson == null || rawJson.trim().isEmpty) {
    Log.warn('[journal_core] Null or empty content. Using blank document.');
    return _defaultDocument();
  }
  return loadDocumentFromJson(rawJson);
}

/// Loads content from raw JSON string into a Document.
/// If parsing fails, wraps the content in a paragraph block as a fallback.
Document loadDocumentFromJson(String content) {
  if (content.isEmpty) {
    Log.warn('[journal_core] Empty content. Returning default document.');
    return _defaultDocument();
  }

  try {
    final json = jsonDecode(content);
    if (json is Map<String, dynamic> && json.containsKey('document')) {
      final document = Document.fromJson(json);
      Log.info(
          '[journal_core] Successfully parsed document: ${document.toJson()}');
      return document;
    } else {
      // Fallback: Wrap non-document JSON in a paragraph block
      Log.warn(
          '[journal_core] JSON missing document key or invalid structure. Using fallback.');
      return _createFallbackDocument(jsonEncode(json));
    }
  } catch (e, stackTrace) {
    // Fallback: Wrap raw content in a paragraph block
    Log.error('[journal_core] Failed to parse content: $e');
    Log.error('[journal_core] Stack trace: $stackTrace');
    return _createFallbackDocument(content);
  }
}

/// Creates a default empty document with a single empty paragraph.
Document _defaultDocument() {
  return Document(
    root: Node(
      type: BlockTypeConstants.paragraph,
      attributes: {
        'delta': [
          {'insert': ''}
        ]
      },
    ),
  );
}

/// Creates a fallback document by wrapping the content in a paragraph block.
/// Used when JSON parsing fails or the structure is invalid.
Document _createFallbackDocument(String content) {
  String displayContent;
  try {
    // Attempt to decode content to extract usable text
    final decoded = jsonDecode(content);
    if (decoded is String) {
      displayContent = decoded;
    } else if (decoded is Map || decoded is List) {
      displayContent = jsonEncode(decoded);
    } else {
      displayContent = decoded.toString();
    }
  } catch (_) {
    // If decoding fails, use raw content
    displayContent = content;
  }

  Log.info(
      '[journal_core] Created fallback document with content: $displayContent');
  return Document(
    root: Node(
      type: BlockTypeConstants.paragraph,
      attributes: {
        'delta': [
          {'insert': '[Recovered Content] $displayContent'}
        ]
      },
    ),
  );
}
