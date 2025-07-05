# journal_core

A reusable, modular content editor for Flutter and FlutterFlow, built on top of [AppFlowy Editor](https://github.com/AppFlowy-IO/appflowy_editor).  
Designed to support structured journal-like documents with rich block-based content, styling, and embedded metadata.

---

## ✨ Features

- 📚 **Block-based architecture**: Headings, paragraphs, quotes, dividers, lists, prayers, scripture, tags, and more
- 🎨 **Rich text styling**: Inline styles (bold, italic, underline, strikethrough)
- 🧩 **Custom blocks**: Built-in support for Scripture and Prayer blocks
- 🧰 **Configurable toolbar**: Floating editor toolbar with smart mode-switching
- 👁️ **Read-only mode**: Display content without editing capabilities using a dedicated viewer
- 🔁 **Sync-ready**: Built with SQLite and Supabase compatibility in mind
- 📦 **FlutterFlow-friendly**: Designed for seamless integration as a custom widget or GitHub dependency

---

## 🚀 Getting Started

Add `journal_core` to your `pubspec.yaml`:

```yaml
dependencies:
  journal_core:
    git:
      url: https://github.com/ebrammer/journal_core.git
```

Then import it:

```dart
import 'package:journal_core/journal_core.dart';
```

---

## 🧪 Example Usage

### Basic Editor

```dart
EditorWidget(
  journal: journal,
  readOnly: false, // Enable editing (default)
  onSave: (journal, content) async {
    // Save or sync the updated content
  },
  onBack: () async {
    // Handle back navigation
  },
  onDelete: () async {
    // Handle journal deletion
  },
)
```

### Read-Only Mode

```dart
EditorWidget(
  journal: journal,
  readOnly: true, // Disable editing
  onSave: (journal, content) async {
    // This won't be called in read-only mode
  },
  onBack: () async {
    // Handle back navigation
  },
  onDelete: () async {
    // This won't be called in read-only mode
  },
)
```

### Direct ReadOnlyViewer Usage

```dart
ReadOnlyViewer(
  journal: journal,
  onContentTap: () {
    // Handle content tap (optional)
    // For example, show a modal, navigate, etc.
  },
)
```

---

## 📁 Folder Structure

```
lib/
├── journal_core.dart               # Public API exports
└── src/
    ├── blocks/                     # Custom block builders
    ├── editor/                     # Editor state + controller
    ├── models/                     # Data models (BlockType, Journal, etc.)
    ├── toolbar/                    # Toolbar buttons, state, and actions
    ├── utils/                      # Delta parsing, focus helpers, logging
    └── widgets/                    # Editor + metadata widgets
```

## 👁️ Read-Only Mode

The `EditorWidget` supports a read-only mode that displays content without editing capabilities using a dedicated `ReadOnlyViewer`:

### How It Works:

- **Edit Mode** (`readOnly: false`): Uses the full AppFlowy editor with all editing capabilities
- **Read-Only Mode** (`readOnly: true`): Switches to a custom `ReadOnlyViewer` that renders the same content with identical styling but no editing functionality

### What's Disabled in Read-Only Mode:

- ✏️ **Text editing**: All text fields are non-editable
- 🧩 **Block manipulation**: Adding, deleting, or reordering blocks
- 🧰 **Toolbar**: The editing toolbar is completely hidden
- 🖱️ **Drag & drop**: Block reordering is disabled
- ⌨️ **Keyboard shortcuts**: All editing shortcuts are disabled
- 🎯 **Selection**: Text and block selection is disabled
- 🔙 **Navigation**: No built-in navigation (handle externally)
- 🗑️ **Deletion**: No built-in deletion (handle externally)
- 📝 **Title display**: No title block rendering (handle externally)

### What's Still Available:

- 📖 **Content display**: All content is visible and properly formatted
- 📱 **Scrolling**: Users can scroll through the content
- 🎨 **Styling**: All visual styling and theming is preserved
- 👆 **Content tap**: Optional callback for handling content interactions

### Benefits of This Approach:

- **Perfect visual parity**: Read-only and edit modes look identical
- **Clean separation**: No complex conditional logic in the editor
- **Performance**: Read-only mode is lighter weight
- **Maintainability**: Changes to styling only need to be made in one place
- **Reliability**: No risk of accidentally enabling editing in read-only mode

### Use Cases:

- **Content preview**: Show users what their journal will look like
- **Shared viewing**: Allow others to view content without editing
- **Archived content**: Display old entries in a read-only format
- **Mobile optimization**: Reduce UI complexity on smaller screens

---

## 🧠 Philosophy

This package is built for:

- **Faith-based journaling**
- **Block-style flexibility**
- **Full control inside FlutterFlow**

---

## 🤝 Contributing

We welcome contributions!
To propose changes or custom blocks, open an issue or pull request.

---

## 🐞 Issues

If you find a bug or something doesn't work inside FlutterFlow, please [open an issue](https://github.com/ebrammer/journal_core/issues) with reproduction steps and context.

---

## 📜 License

MIT © 2024–2025 Evan Brammer
