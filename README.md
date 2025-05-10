Absolutely — here’s a cleaned-up, accurate version of your `README.md` for the `journal_core` package, based on what you’re actually building:

---

````md
# journal_core

A reusable, modular content editor for Flutter and FlutterFlow, built on top of [AppFlowy Editor](https://github.com/AppFlowy-IO/appflowy_editor).  
Designed to support structured journal-like documents with rich block-based content, styling, and embedded metadata.

---

## ✨ Features

- 📚 **Block-based architecture**: Headings, paragraphs, quotes, dividers, lists, prayers, scripture, tags, and more
- 🎨 **Rich text styling**: Inline styles (bold, italic, underline, strikethrough)
- 🧩 **Custom blocks**: Built-in support for Scripture and Prayer blocks
- 🧰 **Configurable toolbar**: Floating editor toolbar with smart mode-switching
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
````

Then import it:

```dart
import 'package:journal_core/journal_core.dart';
```

---

## 🧪 Example Usage

```dart
EditorWidget(
  title: 'My Journal',
  createdAt: DateTime.now().millisecondsSinceEpoch,
  lastModified: DateTime.now().millisecondsSinceEpoch,
  content: '{}', // Pass a valid AppFlowy document JSON string
  onSave: (json) {
    // Save or sync the updated content
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

```

---

Would you like a matching `CHANGELOG.md` template or GitHub release guide next?
```
