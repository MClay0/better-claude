# Obsidian Vault — Initial Intake

Bootstrap the vault with existing context from a structured conversation. Run this once when setting up a new vault, or when you want to seed it with knowledge that predates the hook installation.

## Triggers

Activate when the user says any of:
- "init vault" / "initialise vault" / "initialize vault"
- "bootstrap vault" / "seed vault"
- "obsidian init" / "set up vault context"
- "load my context into the vault"

---

## The Process

Work through four sections in order. Ask each section's questions, wait for the user's answers, write the notes, confirm what was written, then move to the next section. Do not dump all questions at once.

After completing all four sections, commit the vault:
```
git -C $VAULT_PATH add -A && git -C $VAULT_PATH commit -m "vault: initial intake"
```

---

## Section 1 — Active Projects

Say: *"Let's start with your active projects. For each one, tell me: the name and repo (if any), what it is, its current status, the tech stack, and any decisions or patterns already established. Take them one at a time."*

For each project the user describes, write `Projects/<project-name>.md` using the project template:
- Set `context` by inferring: code/engineering → `work`; coursework/academic → `school`; personal side project → `personal`
- Fill Overview from their description of what it is
- Add any decisions they mention to Key Decisions as `[[Decision-slug]]` placeholders
- Set status: active / paused / complete

If they mention decisions in detail, also write the decision note in `Decisions/`.

Confirm each note written before asking about the next project.

---

## Section 2 — Key People

Say: *"Now, who are the key people in your work or study? For each person: name, role, where you know them from, and anything important to remember about them."*

For each person, write `People/<Firstname-Lastname>.md` using the person template:
- Set `context`: colleague/client → `work`; professor/classmate → `school`; friend/family → `personal`
- Fill Background from what the user says about them
- Add a single Interactions entry: today's date + one-line summary of how they know each other

Confirm each note written before asking about the next person.

---

## Section 3 — Patterns and Conventions

Say: *"What recurring patterns or conventions do you always follow? These can be coding habits, workflow rules, tools you always reach for, or anything you'd want me to remember going forward."*

For each pattern, write `Patterns/<pattern-slug>.md` using the pattern template:
- Set `context` based on the domain (usually `work`)
- Fill Description from what the user says
- Add an Example if they provide one
- Add Gotchas if they mention any

Group closely related patterns into one note rather than creating many tiny notes.

---

## Section 4 — Personal Context

Say: *"Finally, any personal context that's useful for me to have — active courses, recurring bills, anything on your schedule I should know about?"*

Write notes in the appropriate `Personal/` subfolder:
- Courses → `Personal/School/<course-name>.md`
- Bills/subscriptions → `Personal/Bills/<name>.md`
- Scheduled commitments → `Personal/Scheduling/<name>.md`

Use the `personal-note.md` template with `context: school` for academic items, `context: personal` for everything else.

---

## Completion

After all four sections and the vault commit, summarise:
- Total notes written (breakdown by type)
- Any gaps mentioned by the user that weren't captured
- Suggest running `note backfill --repo <path>` for any repos mentioned to queue their git history
