# Process: Learn (Session Knowledge Capture)

## Step 1: Resolve session_id (MVP)
- Prefer $CLAUDE_SESSION_ID if set
- Otherwise fallback to `mv-$(date +%Y%m%d-%H%M%S)` and emit a warning
- (Future) transcript_path-derived session_id is deferred until Claude Code exposes
  the value to the shell via a documented hook payload or env var. Do not rely on
  an undocumented `transcript_path` variable in MVP.

## Step 2: Build target path
- repo := basename "$PWD"
- target := $HOME/.claude/projects/<repo>/memory/journal/$(date +%Y-%m-%d)-<session_id>.md
- Assert target is NOT under "$PWD/" (else abort, exit 1)
- mkdir -p "$(dirname "$target")"

## Step 3: Upsert frontmatter
- If file absent: write full frontmatter (recurrence: 1, status: raw)
- If file present: parse frontmatter, bump `recurrence` += 1, append "Learned" bullet, leave other fields intact
- On parse failure: rename existing file to <name>.bak and start fresh with a warning

## Step 4: Render body sections
- Order is fixed and all 5 are required: Request / Investigated / Learned / Completed / Next Steps
- 6th "Suggested Actions" is optional
- Categories: infer from conversation OR honor --category flag (must be in the enum)

## Step 5: Report
- Print: "Journal entry appended.", path, categories, status
- Print next-step hint: "run /my:retro to see promotion candidates"
