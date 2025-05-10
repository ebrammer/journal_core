// src/models/block_type.dart

enum BlockType {
  paragraph,
  heading,
  quote,
  divider,
  prayer,
  scripture,
  todoList,
  bulletedList,
  numberedList,
  title,
  date,
}

extension BlockTypeExtension on BlockType {
  String get name {
    switch (this) {
      case BlockType.paragraph:
        return 'paragraph';
      case BlockType.heading:
        return 'heading';
      case BlockType.quote:
        return 'quote';
      case BlockType.divider:
        return 'divider';
      case BlockType.prayer:
        return 'prayer';
      case BlockType.scripture:
        return 'scripture';
      case BlockType.todoList:
        return 'todo_list';
      case BlockType.bulletedList:
        return 'bulleted_list';
      case BlockType.numberedList:
        return 'numbered_list';
      case BlockType.title:
        return 'title';
      case BlockType.date:
        return 'date';
    }
  }

  static BlockType? fromName(String name) {
    return BlockType.values.firstWhere(
      (type) => type.name == name,
      orElse: () => BlockType.paragraph, // fallback
    );
  }
}
