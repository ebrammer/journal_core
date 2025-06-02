// src/utils/focus_helpers.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'dart:math' as math;

void unfocusAndHideKeyboard(BuildContext context) {
  FocusScope.of(context).unfocus();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  });
}

void requestFocusDelayed(FocusNode focusNode, {int delayMs = 50}) {
  Future.delayed(Duration(milliseconds: delayMs), () {
    if (!focusNode.hasFocus) {
      focusNode.requestFocus();
    }
  });
}

class FocusHelpers {
  static void moveFocusToNextBlock(EditorState editorState, Node currentNode) {
    final document = editorState.document;
    final path = currentNode.path;
    final nextPath = path.next;
    if (nextPath != null && nextPath.isNotEmpty) {
      final nextNode = document.nodeAtPath(nextPath);
      if (nextNode != null) {
        editorState.selection = Selection.collapsed(
          Position(path: nextPath, offset: 0),
        );
      }
    }
  }
}

extension EditorStateSelection on EditorState {
  List<Node> getVisibleNodes(EditorScrollController controller) {
    final List<Node> sortedNodes = [];
    final positions = controller.visibleRangeNotifier.value;
    // https://github.com/AppFlowy-IO/AppFlowy/issues/3651
    final min = math.max(positions.$1 - 1, 0);
    final max = positions.$2;
    if (min < 0 || max < 0) {
      return sortedNodes;
    }

    int i = -1;
    for (final child in document.root.children) {
      i++;
      if (min > i) {
        continue;
      }
      if (i > max) {
        break;
      }
      sortedNodes.add(child);
    }
    return sortedNodes;
  }

  Node? getNodeInOffset(
    List<Node> sortedNodes,
    Offset offset,
    int start,
    int end,
  ) {
    if (sortedNodes.isEmpty || start < 0 || end >= sortedNodes.length) {
      return null;
    }

    var min = _findCloseNode(
      sortedNodes,
      start,
      end,
      (rect) => rect.bottom <= offset.dy,
    );

    if (min < 0 || min >= sortedNodes.length) {
      return null;
    }

    final filteredNodes = List.of(sortedNodes)
      ..retainWhere((n) => n.rect.bottom == sortedNodes[min].rect.bottom);

    if (filteredNodes.isEmpty) {
      return null;
    }

    min = 0;
    if (filteredNodes.length > 1) {
      min = _findCloseNode(
        sortedNodes,
        0,
        filteredNodes.length - 1,
        (rect) => rect.right <= offset.dx,
      );
    }

    if (min < 0 || min >= filteredNodes.length) {
      return null;
    }

    final node = filteredNodes[min];
    if (node.children.isNotEmpty &&
        node.children.first.renderBox != null &&
        node.children.first.rect.top <= offset.dy) {
      final children = node.children.toList(growable: false)
        ..sort(
          (a, b) => a.rect.bottom != b.rect.bottom
              ? a.rect.bottom.compareTo(b.rect.bottom)
              : a.rect.left.compareTo(b.rect.left),
        );

      return getNodeInOffset(
        children,
        offset,
        0,
        children.length - 1,
      );
    }
    return node;
  }

  int _findCloseNode(
    List<Node> sortedNodes,
    int start,
    int end,
    bool Function(Rect rect) compare,
  ) {
    if (start < 0 || end >= sortedNodes.length || start > end) {
      return -1;
    }

    var min = start;
    var max = end;
    while (min <= max) {
      final mid = min + ((max - min) >> 1);
      final rect = sortedNodes[mid].rect;
      if (compare(rect)) {
        min = mid + 1;
      } else {
        max = mid - 1;
      }
    }
    return min.clamp(start, end);
  }
}
