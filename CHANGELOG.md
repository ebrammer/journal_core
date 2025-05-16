Changelog
0.0.2 – Editor Enhancements and Metadata Integration (2025-05-16)
✨ Features

Metadata Block Integration:

Added MetadataWidget and metadata_block.dart to manage title and metadata, fixed at the top of the editor while scrolling.
Implemented JournalTopBar with SliverAppBar and ScrollController to display a compact title, back button, and done button after scrolling 120px.
Ensured metadata block is non-reorderable, rendered separately from other blocks, and excluded from document saves.

Reorderable Editor Improvements:

Enhanced ReorderableEditor to support drag-and-drop block reordering with stable cursor and focus management.
Fixed up/down arrow functionality in toolbar_buttons.dart to align with drag-and-drop logic, ensuring consistent block movement and selection updates.
Corrected index calculations to account for the non-reorderable metadata block, preventing reordering issues and cursor jank.

Toolbar Enhancements:

Updated toolbar_actions.dart and toolbar_buttons.dart to fix disabled up/down buttons and improve selection handling.
Disabled up arrow for the first reorderable block (post-metadata) and down arrow for the last block to prevent invalid moves.

🐛 Bug Fixes

Selection and Cursor Issues:

Resolved cursor jumping and focus loss during block reordering (drag-and-drop and up/down buttons) by stabilizing selection updates in editor_widget.dart and reorderable_editor.dart.
Fixed selection path mismatches caused by the metadata block offset, ensuring accurate cursor placement in \_onBlockSelected and \_onReorderCustom.
Prevented recursive selection updates by refining selectionNotifier logic in editor_widget.dart.

Move Logic:

Corrected moveBlock and \_onReorderCustom in reorderable_editor.dart to fix blocks reinserting at the same index when moving down.
Eliminated document state corruption by preserving node IDs during transactions and verifying selection paths.

Metadata Block Editing:

Fixed title field editability in the main editor by adjusting gesture and focus handling in AppFlowyEditor and EditorWidget.
Ensured consistent editability between the main editor and reorder menu by refining block component configurations.

🧱 Architecture

Streamlined scroll handling by integrating editorScrollController from AppFlowy, removing redundant showTitleNotifier logic in JournalTopBar.
Removed unused methods (\_flattenedBlocks, \_updateBlocks) from reorderable_editor.dart to simplify codebase.
Enhanced modularity by isolating metadata rendering and scroll behavior, maintaining compatibility with AppFlowy’s architecture.

📝 Notes

Addressed build errors in toolbar_buttons.dart by updating getDragButtons to include required arguments (EditorState, toolbarState.currentSelectionPath, null for onDocumentChanged).
Improved logging by correcting Log.warning to Log.warn for consistency.

0.0.1 – Initial Package Setup (2025-05-07)
✨ Features

Created initial journal_core Dart package for a modular block-based editor.
Added journal_core.dart barrel file for public exports.
Set up core editor structure:
journal_editor_controller.dart
journal_editor_initializer.dart
editor_globals.dart
document_loader.dart

📦 Custom Block Support

Added full AppFlowy-based custom block components:
DividerBlock
DateBlock
TitleBlock
PrayerBlock
ScriptureBlock
TagPickerBlock (placeholder UI)

🧱 Architecture

Modular folder structure: editor/, blocks/, models/, utils/, etc.
All editor-global state (EditorState, FocusNode) isolated and shared safely.
