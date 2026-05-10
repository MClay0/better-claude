---
name: obsidian-contacts
description: "Extract people from meeting notes or emails and create/update their vault person notes. Triggers on: extract contacts, log meeting notes, process this email, update contacts from this."
---

# Obsidian Contacts

Identify all named people in pasted content, then create or update their `People/<Name>.md` vault notes.

---

## Trigger Phrases

Activate when the user says any of:
- "extract contacts"
- "log meeting notes"
- "process this email"
- "update contacts from this"

---

## Step 1: Verify Vault

Check that `$VAULT_PATH` is set. If not, tell the user:
"VAULT_PATH is not set — run `bash install.sh --obsidian` first."

Read `$VAULT_PATH/Templates/person.md` to get the person note structure.

---

## Step 2: Extract Named People

Scan the pasted content and identify all distinct named individuals (full names where available, first-name-only as fallback). Ignore generic roles without names (e.g., "the manager", "a colleague").

For each name, determine a canonical filename: `People/<Firstname-Lastname>.md` — title case, hyphens between name parts, no other punctuation.

---

## Step 3: Create or Update Each Person Note

For each person identified:

**If `$VAULT_PATH/People/<Name>.md` does NOT exist:**
1. Read the person template from `$VAULT_PATH/Templates/person.md`
2. Fill in all `{{placeholder}}` fields:
   - `name` — full name as it appears in the content
   - `role` — inferred role/title from content, or leave as `{{role}}` if unknown
   - `company` — inferred company/org from content, or leave as `{{company}}` if unknown
   - `first-met` — today's date (`YYYY-MM-DD`)
   - The Interactions section: today's date + a one-line summary from the content
3. Write the filled template to `$VAULT_PATH/People/<Name>.md`
4. Track this person as **created**

**If `$VAULT_PATH/People/<Name>.md` EXISTS:**
1. Read the existing note
2. Append a new line under `## Interactions`:
   `- YYYY-MM-DD — <one-line summary from content>`
3. Write the updated file back (never modify Background or Notes sections)
4. Track this person as **updated**

---

## Step 4: Link to Relevant Project or Decision Notes

If the pasted content mentions a specific project or decision that has a corresponding vault note:
- In each person note, add a `[[wikilink]]` reference in the Notes section if one doesn't already exist.

---

## Step 5: Confirm

After processing all people, reply with a summary table:

```
Contacts processed:
- [[Firstname-Lastname]] — created / updated
- [[Firstname-Lastname]] — created / updated
```

One line per person. If no named people were found, say: "No named individuals found in the provided content."

---

## Rules

- Never overwrite or clear existing `## Background` or `## Notes` sections — only append to `## Interactions`.
- Never ask the user follow-up questions before processing; use context from the pasted content.
- Use today's date for all new Interactions entries.
- Wikilinks use note name only (no folder prefix): `[[Firstname-Lastname]]`.
