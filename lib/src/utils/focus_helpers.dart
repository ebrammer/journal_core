// src/utils/focus_helpers.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appflowy_editor/appflowy_editor.dart';

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
