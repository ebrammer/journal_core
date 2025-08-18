// lib/src/models/related_content.dart

/// Represents related content that can be inserted into the journal
class RelatedContent {
  final String id;
  final String itemType;
  final String createdBy;
  final int createdAt;
  final int lastModified;
  final String title;
  final String content;
  final String artworkID;

  RelatedContent({
    required this.id,
    required this.itemType,
    required this.createdBy,
    required this.createdAt,
    required this.lastModified,
    required this.title,
    required this.content,
    required this.artworkID,
  });

  factory RelatedContent.fromJson(Map<String, dynamic> json) {
    return RelatedContent(
      id: json['id'] as String,
      itemType: json['itemType'] as String,
      createdBy: json['createdBy'] as String,
      createdAt: json['createdAt'] as int,
      lastModified: json['lastModified'] as int,
      title: json['title'] as String,
      content: json['content'] as String,
      artworkID: json['artworkID'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'itemType': itemType,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'lastModified': lastModified,
      'title': title,
      'content': content,
      'artworkID': artworkID,
    };
  }

  @override
  String toString() =>
      'RelatedContent(id: $id, title: $title, type: $itemType)';
}

/// Enum for display options when inserting related content
enum RelatedContentDisplay {
  link, // Only show link/pills
  text, // Only show title and content
  both, // Show both link and content
}
