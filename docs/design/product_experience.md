# Product Experience Design

## Product Direction

Daily Notes should feel like a quiet stream of thoughts rather than a document manager. The primary loop is **capture, find, revisit, connect**. We adopt flomo's low-friction capture, inline hierarchical tags, and review mindset, but keep an original visual system and extend the product with mixed media, lightweight Markdown, self-hosted sync, and optional AI.

## Current-State Audit

| Area | Current behavior | Required correction |
| --- | --- | --- |
| Voice | Recognition writes partial results directly over a saved content snapshot. Locale and session state are invisible. | Use an explicit voice session, preserve cursor position, expose language, allow stop/retry/insert, and never replace edits made during recognition. |
| Tags | Desktop tags exist only inside History; mobile uses a modal snapshot. | Make tags part of the app shell, persist desktop expansion, reset stale filters, and preserve selection across list refreshes. |
| Capture | New notes open a full editor with a prominent title. | Keep title optional and secondary; focus body immediately and support a compact quick-capture path. |
| Images | Notes support up to 12 ordered images. | Keep text/image order, captions, reordering, preview, multi-select insertion, and an optional stream cover. |
| Formatting | One plain multiline field. | Add a restrained Markdown-like shortcut set and a formatting menu without turning the app into a page designer. |
| Review | Random review opens an unfiltered active note. | Add time/tag scope, history, previous/next, and a place to append a reflection. |

## Responsive App Shell

### Wide, 960 px and above

- Left sidebar, 240 px: Home, Notes, Review, AI, Settings, then the tag tree.
- Sidebar can collapse to a 64 px icon rail with `Ctrl+\`; the preference is persisted.
- Main pane uses a readable 760-900 px content width. No nested page cards.
- Search is available through `Ctrl+K` and keeps active tag/date/media filters visible.

### Medium, 600-959 px

- Use a 72 px navigation rail; tags open in an anchored side panel.
- The panel does not cover the full work surface and closes with Escape or outside click.

### Narrow, below 600 px

- Home remains the first screen, with one floating compose command.
- Tags and primary navigation share a left side sheet with a visible close action.
- Parent tags expose disclosure arrows; collapsing one branch must not reset the active filter.
- The sheet owns focus while open, restores focus when closed, and respects system back.

## Capture Flow

1. Open capture with the compose button or `Ctrl+N`.
2. Focus the first body block; title is optional and visually quiet.
3. Type text, `#tags`, Markdown-like shortcuts, insert images, or start voice input.
4. Autosave a local draft after 600 ms idle. Explicit Save publishes the draft to the note stream.
5. After Save, show a non-blocking confirmation with Undo; keep the user in context on desktop and return to the stream on mobile.

## Review Flow

- Review scope supports all notes, selected tags, untagged notes, and a date range.
- One note is shown at a time with previous/next, edit, move-to-trash, and “append reflection”.
- Review ordering avoids immediate repeats and stores only local review history.
- Heatmap day selection and tag selection can both start a scoped review.

## Interaction Requirements

- No toolbar item may move when count, listening state, or loading text changes.
- Disabled actions explain why through tooltip or nearby status.
- Destructive actions require confirmation; AI and sync actions never silently overwrite text.
- Editor, side sheets, dialogs, and menus must remain usable at 360x640 and 1280x720 logical pixels.
- Keyboard users can reach every command, close overlays with Escape, and see focus state.

## Reference Principles

- flomo quick capture emphasizes low-pressure input and deliberately avoids document-layout complexity: https://help.flomoapp.com/basic/quick-input.html
- Inline hierarchical tags use `#parent/child` and remain part of body content: https://help.flomoapp.com/basic/tag.html
- Review works best when users can choose tag and time scopes: https://help.flomoapp.com/advance/lucky.html
