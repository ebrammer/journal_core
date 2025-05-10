# Changelog

## 0.1.0 – Initial Package Setup (2025-05-07)

### ✨ Features

- Created initial `journal_core` Dart package for a modular block-based editor.
- Added `journal_core.dart` barrel file for public exports.
- Set up core editor structure:
  - `journal_editor_controller.dart`
  - `journal_editor_initializer.dart`
  - `editor_globals.dart`
  - `document_loader.dart`

### 📦 Custom Block Support

- Added full AppFlowy-based custom block components:
  - `DividerBlock`
  - `DateBlock`
  - `TitleBlock`
  - `PrayerBlock`
  - `ScriptureBlock`
  - `TagPickerBlock` (placeholder UI)

### 🧱 Architecture

- Modular folder structure: `editor/`, `blocks/`, `models/`, `utils/`, etc.
- All editor-global state (EditorState, FocusNode) isolated and shared safely.
