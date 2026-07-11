# Daily Notes 2.0 Design Index

This design set is the implementation contract for the next product phase. New editor and AI work must follow it unless a later decision record explicitly replaces a section.

- [Product experience](product_experience.md): navigation, capture, review, responsive behavior, and interaction acceptance criteria.
- [Visual system](visual_system.md): product tone, hierarchy, color, border, tag, and heatmap rules.
- [Block editor architecture](block_editor_architecture.md): Markdown-like input, mixed text/images, migration, persistence, and editor state.
- [Data portability](data_portability.md): lossless backup and interoperable import/export contracts.
- [App updates](app_updates.md): release channel, check cadence, platform assets, and installation safety.
- [AI assistance](ai_assistance.md): feature boundaries, privacy model, provider interfaces, and staged delivery.

## Delivery Order

1. Stabilize voice input and tag navigation without changing stored note data.
2. Introduce versioned content blocks and migrate legacy text/images losslessly.
3. Replace the plain content field with the block editor and lightweight Markdown shortcuts.
4. Add AI features behind explicit configuration and per-action confirmation.

Every phase must keep existing notes readable, JSON/WebDAV backups round-trippable, and Android, Windows, Linux, and Web builds green. iOS and macOS remain outside the active scope.
