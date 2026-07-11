# AI Assistance Design

## Product Rule

AI helps users rediscover and refine their own notes. It does not auto-generate a replacement personality, silently rewrite notes, or require cloud AI for core capture, search, tags, sync, and review.

## First Features

### 1. Tag Suggestions

- Analyze the current note and existing tag tree.
- Prefer existing tags; suggest at most three new or existing tags.
- Show the exact text change and apply only confirmed suggestions.

### 2. Voice Cleanup

- Correct obvious recognition errors and remove filler words while preserving meaning.
- Always show Original and Suggested tabs with an inline diff.
- Insert the original transcript when AI is unavailable; cleanup is optional and retryable.

### 3. Related Notes

- Find semantically related notes from the current note or selected text.
- Return note cards with a short match reason, never a fabricated quote.
- A local keyword scorer provides a private offline baseline before remote embeddings are enabled.

### 4. Ask My Notes

- Natural-language search over a user-selected scope: all notes, tags, or date range.
- Answers cite note IDs and dates; every claim opens its source note.
- “No evidence” is a valid result. The model must not answer from general knowledge by default.

### 5. Review Insight

- Summarize repeated themes, changes in viewpoint, unresolved questions, and possible contradictions.
- The user selects the source set before transmission and can inspect that set afterward.
- Insights are saved as a new note only after confirmation.

## Privacy and Configuration

- AI is off by default and has no effect on local-only operation.
- Support an OpenAI-compatible endpoint, model name, and API key stored in platform secure storage.
- Before first use, show which note text and image captions will leave the device. Images are excluded by default.
- Never send WebDAV credentials, attachment bytes, archived notes outside the selected scope, or hidden app metadata.
- Provide Clear history and Delete AI configuration actions. Do not log prompts, keys, or note contents.

## Architecture

```dart
abstract interface class AiAssistant {
  Future<List<TagSuggestion>> suggestTags(AiNoteContext context);
  Future<TranscriptSuggestion> cleanTranscript(String transcript);
  Future<List<RelatedNote>> findRelated(AiQuery query);
  Future<GroundedAnswer> askNotes(AiQuery query);
  Future<ReviewInsight> createInsight(AiReviewScope scope);
}
```

- `AiProvider` owns operation state, cancellation, progress, and user-facing errors.
- `AiConfigStore` owns encrypted endpoint/key/model settings.
- `AiContextBuilder` converts blocks to bounded plain text, records included note IDs, and enforces scope.
- `AiRemoteClient` speaks an OpenAI-compatible API behind the interface.
- `LocalRelatedNotesService` offers deterministic keyword similarity without network access.
- Results are typed objects. UI code never parses free-form model output for destructive operations.

## Safety and Failure Behavior

- Every write is previewed and confirmed; bulk tag changes show the affected count.
- Cancellation stops network streaming and leaves the editor unchanged.
- Timeouts, quota, malformed output, and unsupported models have distinct messages.
- Prompt injection inside note text is treated as note content, never as an instruction to the application.
- AI results include provider/model, source note IDs, and generation time for local audit.

## Delivery Phases

1. Local related notes and deterministic tag suggestions, no network configuration.
2. Remote voice cleanup and tag suggestions with secure BYOK settings.
3. Grounded Ask My Notes with source citations.
4. Review Insight and bulk organization after retrieval quality and privacy tests pass.

## Acceptance Criteria

- Core app remains fully usable with AI disabled or offline.
- No note data is transmitted before explicit setup and action-time scope confirmation.
- Suggested edits are reversible in one Undo operation.
- Ask My Notes returns only sourced answers and can open every cited note.
- Tests cover cancellation, timeout, malformed responses, injection-like note text, and secret redaction.

## Reference Principles

- Exploratory AI search should retrieve from the user's own notes rather than replace exact search: https://help.flomoapp.com/ai/aifind.html
- Insight should surface themes, blind spots, and questions over a user-selected note scope: https://help.flomoapp.com/ai/insight.html
- AI-assisted voice cleanup should preserve the user's thought rather than over-polish it: https://help.flomoapp.com/ai/aivoice.html
