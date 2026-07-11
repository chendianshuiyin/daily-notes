# Visual System

## Direction

Daily Notes is a cheerful capture tool, not a document dashboard. Cool neutral surfaces carry most of the screen while a clear sky blue marks dates, inline tags, selection, and the primary action. Sunny yellow appears only as a small identity accent. Avoid gradients, decorative charts, oversized headings, pills, and generic “AI magic” decoration.

## Built-In Palettes

- **Sky** is the default brand palette: clear blue `#356AE6`, sunny yellow `#F0B429`, white, charcoal text, and cool neutral page surfaces.
- **Tokyo Night** adapts the official light and dark palettes around blue, purple, and the `#1A1B26` editor background.
- **Everforest** uses its official medium-contrast light and dark greens, warm surfaces, and muted foregrounds.
- Palette and brightness are separate persisted settings. Every screen must use `ColorScheme`; feature widgets must not hard-code brand colors.

## Hierarchy

- Use the system font, no more than four visible type sizes, and at most two weights in one region.
- Use spacing, opacity, and position before adding another container.
- Keep a border only when it clarifies an editable field, an individual memo, a dialog, or destructive scope.
- Settings groups may use a subtle surface change; do not outline every group and child.
- Touch targets remain at least 44 logical pixels and all content must work at 360x640 and 1280x720.

## Capture And Notes

- The quick composer is the first visual anchor and may keep a restrained boundary.
- Titles stay optional. Memo body, inline tags, media preview, and time form one reading flow.
- Render tags where they occur in the body. Use medium-weight primary text without chips or detached tag rows.
- Image notes may designate one attachment as the stream cover. Missing or stale cover IDs fall back to the first image.
- A memo may use one flat card boundary. Do not place cards inside it.

## Sidebar And Heatmap

- The mobile sidebar slides from the main screen and restores the stream after selection.
- Tag tree labels omit the `#` marker and hash icons. Parent nodes use disclosure arrows and support independent expansion; leaves align without fake controls.
- The heatmap defaults to 12 weeks. Columns are weeks, rows are Monday through Sunday, and month labels align to the week containing the first day.
- Users can select 3 months, 6 months, or 1 year. Long ranges scroll horizontally at a stable cell size.
- Search replaces the redundant top-right all-notes shortcut. The recycle bin remains a secondary drawer destination with restore and permanent-delete actions.

## Settings

- Use one continuous page surface. Sections are separated by whitespace, muted headings, and indented dividers rather than repeated cards.
- Keep framed controls only where interaction ownership would otherwise be unclear, such as segmented palette/mode selectors and text fields.

## Review Checklist

1. Capture, note stream, and current filter are visible without decorative summaries.
2. No text, control, month label, or toolbar overflows at supported breakpoints.
3. Color communicates action or state, not decoration.
4. Removing any border must not make grouping or tap ownership ambiguous.
5. Light and dark themes preserve the same hierarchy and contrast.
