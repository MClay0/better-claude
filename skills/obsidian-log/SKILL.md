---
name: obsidian-log
description: "Log vault notes mid-session without breaking flow. Triggers on: log this, log this decision, log this pattern, save this, remember this, save this pattern, save this decision."
---

# Obsidian Log

Write the appropriate vault note immediately when the user asks to log or save something mid-session.

---

## Trigger Phrases

Activate when the user says any of:
- "log this"
- "log this decision"
- "log this pattern"
- "save this"
- "remember this"
- "save this pattern"
- "save this decision"

---

## Step 1: Identify Note Type

Determine note type from the trigger phrase and context:

| Trigger contains | Note type  | Target folder   | Template file           |
|-----------------|------------|-----------------|-------------------------|
| "decision"      | decision   | `Decisions/`    | `Templates/decision.md` |
| "pattern"       | pattern    | `Patterns/`     | `Templates/pattern.md`  |
| "session"       | session    | `Sessions/`     | `Templates/session.md`  |
| "this" (plain)  | decision   | `Decisions/`    | `Templates/decision.md` |

Default to **decision** when the type is ambiguous.

---

## Step 2: Read the Template

Read `$VAULT_PATH/Templates/<template-file>` to get the note structure.

If `$VAULT_PATH` is not set, tell the user: "VAULT_PATH is not set — run `bash install.sh --obsidian` first."

---

## Step 3: Determine the Filename

Use the current date (`date +%Y-%m-%d`) and a short slug derived from the note content:

- **Decision:** `Decisions/YYYY-MM-DD-<slug>.md`
- **Pattern:** `Patterns/<slug>.md`
- **Session:** `Sessions/YYYY-MM-DD-<repo>-<short-sha>.md`
  - `<repo>` = `basename $(git rev-parse --show-toplevel)` (or "no-repo" if not in a git repo)
  - `<short-sha>` = `git rev-parse --short HEAD` (or "nosync" if not in a git repo)

Slugify: lowercase, replace spaces and special chars with hyphens, max 40 chars.

---

## Step 4: Fill the Template

Fill in all `{{placeholder}}` fields from the template using:
- The current date for `date` fields
- `[[<current-repo>]]` wikilink for `project` fields (derive repo name from `basename $(git rev-parse --show-toplevel)`)
- The user's content for the body sections (Context, Decision, Description, etc.)

---

## Step 5: Write the Note

Write the filled note to `$VAULT_PATH/<target-folder>/<filename>.md`.

**Never overwrite an existing file** — if the file exists, append a new section with today's date instead.

---

## Step 6: Update the Project Note

Read `$VAULT_PATH/Projects/<current-repo>.md` (the current repo's project note).

If the file does not exist, skip this step silently.

If it exists, append a `[[wikilink]]` to the new note under the relevant section:
- Decision → under `## Key Decisions`
- Pattern → under `## Key Decisions` (or create `## Patterns` if that section exists)
- Session → under `## Recent Sessions`

Append format: `- [[<note-name-without-extension>]]` on a new line at the end of that section.

---

## Step 7: Confirm

Reply with exactly two lines:
```
[Logged] $VAULT_PATH/<target-folder>/<filename>.md
<one-line summary of what was written>
```

---

## Rules

- Never delete or overwrite existing vault files — append and create only.
- Never ask the user follow-up questions before writing; use context from the current conversation to fill the note.
- If critical information is missing (e.g., no content to log), ask ONE focused question, then write immediately.
