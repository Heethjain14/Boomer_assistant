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

- TraceX - All - Employees · last_digested: 2026-09-14T10:30:00+05:30
- Hemanshu Tracex · last_digested: 2026-09-14T10:30:00+05:30
- Dad · last_digested: 2026-09-14T10:30:00+05:30
- Mumma · last_digested: 2026-09-14T10:30:00+05:30
- D. C. SHAH FAMILY · last_digested: 2026-09-14T10:30:00+05:30
- Khau shah family🌮🌮🍱🍭🍬🍩🍨 · last_digested: 2026-09-14T10:30:00+05:30
- Shagunnn:) · last_digested: 2026-09-14T10:30:00+05:30
- Saap🐍 · last_digested: 2026-09-14T10:30:00+05:30
- Pahel · last_digested: 2026-09-14T10:30:00+05:30
- DIDA · last_digested: 2026-09-14T10:30:00+05:30
- Vimal · last_digested: 2026-09-14T10:30:00+05:30
- Yash · last_digested: 2026-09-14T10:30:00+05:30
- Har💩 N · last_digested: 2026-09-14T10:30:00+05:30
- Jiju · last_digested: 2026-09-14T10:30:00+05:30
- Aakansh Roomate · last_digested: 2026-09-14T10:30:00+05:30
- Harsh Roomate Vir · last_digested: 2026-09-14T10:30:00+05:30
- Riddhish Cps · last_digested: 2026-09-14T10:30:00+05:30
- Nihara Cyscom · last_digested: 2026-09-14T10:30:00+05:30
- Chitwan Singh Cyscom · last_digested: 2026-09-14T10:30:00+05:30
- Khushal Kunjir Sir · last_digested: 2026-09-14T10:30:00+05:30
- Addyyy · last_digested: 2026-09-14T10:30:00+05:30
- Tanmay Vlsi Vit · last_digested: 2026-09-14T10:30:00+05:30
- 我自己和我. 😅 · last_digested: 2026-09-14T10:30:00+05:30
- Blr House Party 🎉 · last_digested: 2026-09-14T10:30:00+05:30
- Bangalore Buzzz · last_digested: 2026-09-14T10:30:00+05:30
- Bangalore House Party🥂 · last_digested: 2026-09-14T10:30:00+05:30
- Vijval Lafda · last_digested: 2026-09-14T10:30:00+05:30
- Panel of Guardians 2026-2027 · last_digested: 2026-09-14T10:30:00+05:30
- CC-Board Members · last_digested: 2026-09-14T10:30:00+05:30
- All in one 🤫 · last_digested: 2026-09-14T10:30:00+05:30

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

- College/club/community groups (VIT batches, CYSCOM sub-groups, placement groups, etc.) and promotional/transactional numbers (delivery, banks, redBus, etc.) were excluded by default during setup on 2026-09-14. Ask to add any of these back individually.
