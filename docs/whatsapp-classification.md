# WhatsApp Chat Classification

Knowledge file for the Claude Desktop Project. Tracks which chats the assistant
may read and how they're categorized.

**Saving:** the assistant only ever *hands you back* the full new version of this
file — paste that whole thing in as the replacement knowledge file. Nothing
saves on its own; if you close the chat without pasting it back, changes are
lost. The assistant will remind you every time.

## Allowed chats

Set at first-time setup, extendable anytime. This is the **only** thing that
decides whether the assistant can see a chat at all — anything not listed here
is off limits by default, even for generic requests ("summarize everything").
Add a chat later just by asking.

Format: `- Chat name · last_digested: <ISO timestamp or "never">`

<!-- - Mom · last_digested: never -->
<!-- - TraceX - All - Employees · last_digested: never -->

## Classified

Empty at first. The **first time** an allowed chat actually comes up in a Digest
or Act request, the assistant asks a couple of quick questions about that one
chat and records it below. You're never asked about the same chat twice.

### Work

<!-- filled in automatically over time -->

### Personal

<!-- filled in automatically over time -->

### High priority (always flagged first in a Digest)

<!-- filled in automatically over time -->

## Notes

<!-- e.g. "Digest should default to Work chats only on weekdays" -->
