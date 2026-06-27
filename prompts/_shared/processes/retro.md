# Process: Retro (Promotion Candidate Curation)

## Step 1: Enumerate
- glob "$HOME/.claude/projects/$(basename "$PWD")/memory/journal/*.md"
- If empty: emit "No journal entries found at <path>. Run /my:learn first." and exit 0

## Step 2: Filter
- Parse frontmatter via awk/sed/jq pipeline (NFR-006 compliant)
- Apply --since (default 14d), --category, --min-recurrence (default 1) filters
- Skip entries with status: promoted or status: archived

## Step 3: Resolve toolkit repo (spec §3.5)
- Priority 1: if `~/.claude/commands` is a symlink AND its target ends with `/commands`
              AND that target dir exists, set toolkit_repo := dirname(readlink(~/.claude/commands))
- Priority 2: if $CLAUDE_TOOLKIT_REPO is set AND is a directory, set toolkit_repo := $CLAUDE_TOOLKIT_REPO
- Else: toolkit_repo := "" (empty string)
- FORBIDDEN: do NOT fall back to $PWD or any cwd-derived path. cwd is an arbitrary project,
  not the toolkit repo (US-004 AC-004 / §7.4 threat model).

## Step 4: Build candidates
- For each entry, collect Suggested Actions; if empty, synthesize candidates from Learned bullets
- Each candidate: title / target_asset_path / change_summary / rationale / source_entries / recurrence

## Step 5: Duplicate detection
- If toolkit_repo is non-empty:
    grep nearby files under <toolkit_repo>/{rules,prompts,commands,agents}
    Annotate `duplicate_of` when a near-match is found; do not exclude.
- If toolkit_repo is empty:
    SKIP this step. Annotate each candidate with
    "(duplicate check skipped: toolkit repo not resolved)".

## Step 6: Redact
- Pipe each candidate's renderable text through scripts/redact.sh
- exit 0 → redaction_status: clean
- exit 2 → redaction_status: excluded (drop from output, log on stderr)
- script missing → warning on stderr, continue without redaction
- masked is reserved for Phase 2; do not emit in MVP

## Step 7: Group & sort
- Group by category, sort mistake first (then pattern, preference, domain-knowledge, open-question)
- Within a group, sort by recurrence desc, then by date desc

## Step 8: Render
- Output header: "Toolkit repo: <toolkit_repo>" (or "<TOOLKIT_REPO>  (⚠️ 自動解決に失敗)" on failure)
- markdown table per category H3 section
- After each candidate, print the safe copy-paste command (multi-line for readability):
      cd <toolkit_repo> \
        && /my:change "<title>"
  When toolkit_repo is empty, substitute the literal placeholder `<TOOLKIT_REPO>`
  (DO NOT substitute cwd).
- Footer Tip 1: warn that the command MUST be run with the leading `cd`, otherwise
  promotion artifacts will land in the wrong project (US-004 AC-001 / §7.4).
- Footer Tip 2: guidance to manually flip frontmatter status raw → promoted after a successful promotion.
- On resolution failure: additional footer with replacement guide
  ("symlink ~/.claude/commands or hand-edit <TOOLKIT_REPO>"; see spec §3.2 Output failure example).
