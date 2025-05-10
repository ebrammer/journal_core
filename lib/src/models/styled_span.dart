// src/models/styled_span.dart

/// A simplified representation of styled text used within a block delta.
class StyledSpan {
  final String text;
  final Set<String> styles;

  StyledSpan({
    required this.text,
    Set<String>? styles,
  }) : styles = styles ?? {};

  factory StyledSpan.fromJson(Map<String, dynamic> json) {
    return StyledSpan(
      text: json['text'] ?? '',
      styles: Set<String>.from(json['styles'] ?? []),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'styles': styles.toList(),
    };
  }

  @override
  String toString() => 'StyledSpan(text: "$text", styles: $styles)';
}
