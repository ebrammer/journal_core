// src/widgets/metadata_widget.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; // For date formatting

/// A widget that displays metadata (title, creation date, modification date)
/// for a journal entry, styled to match the AppFlowy editor's appearance.
/// This widget scrolls with the editor but is not part of the Document's JSON.
class MetadataWidget extends StatelessWidget {
  const MetadataWidget({
    super.key,
    required this.title,
    required this.createdAt,
    required this.lastModified,
    required this.titleController,
  });

  final String title;
  final int createdAt; // Unix timestamp in milliseconds
  final int lastModified; // Unix timestamp in milliseconds
  final TextEditingController titleController; // Controller for title input

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          TextField(
            controller: titleController,
            decoration: const InputDecoration(
              labelText: 'Title',
              border: OutlineInputBorder(),
            ),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          // Dates
          Text(
            'Created: ${createdAt > 0 ? DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(createdAt)) : 'N/A'}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
          Text(
            'Modified: ${lastModified > 0 ? DateFormat.yMMMd().format(DateTime.fromMillisecondsSinceEpoch(lastModified)) : 'N/A'}',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}
