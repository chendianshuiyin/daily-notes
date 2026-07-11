# Data Portability

## Format Roles

No single export format serves both exact recovery and migration well. Daily Notes therefore exposes two explicit exports:

- **Daily Notes JSON** is the lossless backup. It preserves IDs, timestamps, archive state, ordered blocks, text marks, captions, tags, the selected cover image, and embedded image bytes.
- **Markdown ZIP** is the interoperable export. UTF-8 Markdown files live under `notes/`, referenced images under `media/`, and YAML front matter carries metadata that Daily Notes can restore.

Clipboard backup is not a primary workflow: payload size grows with every image and can exceed platform clipboard limits. File export is the default for both formats.

## Import Contract

- Import `.json` backups without loss.
- Import a standalone `.md` or `.markdown` file as one note.
- Import a `.zip` containing multiple Markdown files and resolve relative local image links.
- Preserve external Markdown syntax that is outside the editor subset as readable text.
- Reject path traversal, symbolic links, excessive entries, and oversized expanded archives.
- Preview note and image counts before merging. Existing notes with the same Daily Notes ID are replaced; unrelated notes remain.

## Compatibility Rationale

Markdown is plain text, broadly supported by tools such as Joplin and Notion exports, and covered by CommonMark. ZIP keeps media beside text without platform-specific folder permissions. JSON remains app-owned because generic formats cannot represent every internal block, cover selection, and attachment invariant.
