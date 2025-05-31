/// Constants for block types used throughout the application
class BlockTypeConstants {
  const BlockTypeConstants._();

  // Document structure types
  static const String page = 'page';

  // Basic block types
  static const String paragraph = 'paragraph';
  static const String heading = 'heading';
  static const String quote = 'quote';
  static const String divider = 'divider';
  static const String title = 'title';
  static const String date = 'date';

  // List types
  static const String todoList = 'todo_list';
  static const String bulletedList = 'bulleted_list';
  static const String numberedList = 'numbered_list';

  // Custom block types
  static const String prayer = 'prayer';
  static const String scripture = 'scripture';
  static const String tagPicker = 'tag_picker';
  static const String spacer = 'spacer_block';
  static const String metadata = 'metadata_block';

  /// List of all block types that support indentation
  static const List<String> indentableTypes = [
    paragraph,
    heading,
    todoList,
    bulletedList,
    numberedList,
  ];

  /// List of all list types
  static const List<String> listTypes = [
    todoList,
    bulletedList,
    numberedList,
  ];
}
