# Block Editor Architecture

## Decision

Store note bodies as a versioned sequence of app-owned blocks. The UI editor is an adapter, not the source of truth. This prevents lock-in to a third-party editor format and lets JSON backup, WebDAV merge, search, Markdown export, and future AI operate on one stable schema.

The first integration spike will use `appflowy_editor` for selection, IME, shortcuts, and block editing. Its document JSON must be translated at the boundary; it must not be stored directly. If the four-platform spike fails the acceptance matrix, use `super_editor` behind the same adapter without changing persisted data.

## Content Schema V2

```json
{
  "contentVersion": 2,
  "blocks": [
    {"id": "b1", "type": "paragraph", "text": "A thought with #work"},
    {"id": "b2", "type": "image", "imageId": "img1", "caption": "Sketch"},
    {"id": "b3", "type": "bulletList", "text": "Next action", "indent": 0}
  ]
}
```

Supported block types in the first release: `paragraph`, `heading`, `bulletList`, `numberList`, `quote`, `code`, `image`, and `divider`. Inline marks are `bold`, `italic`, `underline`, `strike`, `highlight`, `code`, and `link`. Tags remain plain source text and are derived, never stored as editor-only marks.

Each block has a stable ID. Image binary data remains in the existing `NoteImage` collection and is referenced by `imageId`; this avoids duplicating base64 payloads during reorder operations.

## Markdown-Like Input

This is a shortcut layer, not a full page-layout language.

| Typed at block start | Result |
| --- | --- |
| `# `, `## `, `### ` | heading levels 1-3 |
| `- ` or `* ` | bullet list |
| `1. ` | numbered list |
| `> ` | quote |
| triple backticks | code block |
| `---` then Enter | divider |

Inline pairs: `**bold**`, `_italic_`, `~~strike~~`, `` `code` ``, `==highlight==`, and `[label](url)`. `#tag` without a following space remains a tag, so heading and tag parsing do not conflict. Undo immediately restores the literal source after an automatic conversion.

## Mixed Media Behavior

- Multi-select inserts images at the current block position in picker order.
- Support up to 12 image blocks per note; preserve current 12 MB source and 2 MB stored-image limits.
- Image blocks support caption, move up/down, drag reorder on desktop, preview, replace, and remove.
- Pasting a supported bitmap inserts an image block; pasting unsupported binary data leaves the editor unchanged and reports an error.
- Markdown export writes local image references plus an adjacent assets directory; JSON/WebDAV backups remain self-contained.

## Voice Session

Voice must not mutate document blocks while partial recognition is unstable.

```text
idle -> initializing -> listening -> reviewing -> inserting -> idle
                         |             |
                         +-> error <---+
```

- Capture the selected block ID and text offset when recording starts.
- Display partial transcript in a fixed voice panel with elapsed time and language.
- Stop opens Review with Insert, Retry, and Discard. Final recognized text is inserted as one transaction so Undo removes it once.
- If the anchor block was deleted, insert after the nearest surviving block and notify the user.
- Locale choices are Auto, Simplified Chinese, and English, sourced from installed recognition locales.

## Migration and Compatibility

1. Legacy `content` becomes one or more paragraph blocks, preserving exact line breaks.
2. Existing images are appended as image blocks in their current order because legacy data has no positions.
3. Keep `content` as a generated plain-Markdown shadow during a two-release compatibility window.
4. `Note.fromJson` accepts V1 and V2. `toJson` writes V2 plus the compatibility shadow.
5. Backups remain format version 1 until V1 readers are proven to fail safely; add `contentVersion` per note instead of breaking the whole archive.

## Acceptance Matrix

- Chinese, English, emoji, composition/IME, selection, undo/redo, and clipboard pass on Android, Windows, Linux, and Web.
- Text can appear before, between, and after at least three images and survives save/reload, JSON restore, and WebDAV merge.
- Old notes load without content loss and can be saved back to V2.
- Search, previews, tags, character count, and AI context derive from blocks, not stale compatibility text.
- A 200-block note remains responsive while typing and scrolling.

## Library Evidence

- `appflowy_editor` provides block components, Markdown conversion, and customizable shortcuts: https://pub.dev/packages/appflowy_editor
- `super_editor` provides a composable document model and custom component builders under MIT: https://pub.dev/packages/super_editor
- Read-only rendering and export validation can use the maintained `flutter_markdown_plus`: https://pub.dev/packages/flutter_markdown_plus
