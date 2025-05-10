// src/models/block_model.dart

/// Represents a serialized block used for local storage or syncing.
/// This is distinct from AppFlowy's in-memory Node tree.
class BlockModel {
  final String id;
  final String type;
  final Map<String, dynamic> attributes;
  final List<BlockModel> children;

  BlockModel({
    required this.id,
    required this.type,
    required this.attributes,
    this.children = const [],
  });

  factory BlockModel.fromJson(Map<String, dynamic> json) {
    return BlockModel(
      id: json['id'] as String,
      type: json['type'] as String,
      attributes: Map<String, dynamic>.from(json['attributes'] ?? {}),
      children: (json['children'] as List<dynamic>? ?? [])
          .map((child) => BlockModel.fromJson(child))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'attributes': attributes,
      'children': children.map((c) => c.toJson()).toList(),
    };
  }

  @override
  String toString() => 'BlockModel(id: $id, type: $type)';
}
