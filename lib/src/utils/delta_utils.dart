// src/utils/delta_utils.dart

import '../models/styled_span.dart';

/// Converts a delta-style list (as used in AppFlowy) into styled spans.
List<StyledSpan> parseDeltaToStyledSpans(List<dynamic>? delta) {
  if (delta == null) return [];

  return delta.map<StyledSpan>((op) {
    final text = op['insert'] ?? '';
    final attrs = op['attributes'] as Map<String, dynamic>? ?? {};
    final styles =
        attrs.entries.where((e) => e.value == true).map((e) => e.key).toSet();

    return StyledSpan(text: text, styles: styles);
  }).toList();
}

/// Converts styled spans back to delta format
List<Map<String, dynamic>> convertStyledSpansToDelta(List<StyledSpan> spans) {
  return spans.map((span) {
    final Map<String, dynamic> map = {'insert': span.text};
    if (span.styles.isNotEmpty) {
      map['attributes'] = {
        for (var style in span.styles) style: true,
      };
    }
    return map;
  }).toList();
}
