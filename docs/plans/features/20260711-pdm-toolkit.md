# Implementation Plan: PdM Toolkit (PRD / Product Spec / Backlog / Catchup)

## 1. Overview

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/research/20260711-pdm-toolkit.md`

### 1.2 References
- `skills/research/SKILL.md`, `skills/learn/SKILL.md` — skill format precedent
- `skills/review/SKILL.md` — extension point for `prd:` / `pspec:` targets
- README "Design rules the repo follows"

### 1.3 Implementation Strategy

Five new inline skills under the existing `my` namespace, one shared
machine-local config, review-loop integration, and scheduling assets. No
agents, no pipeline hooks (user constraint: nothing that overrides the
session model). The `docs/specs/` stage is intentionally skipped — the
deliverables are markdown instructions; the design is fully carried here.

Shared design decisions:

- **Config home:** `${MY_TOOLKIT_DATA:-$HOME/.claude/my-toolkit}/pdm/config.md`
  (human-editable markdown) + `state/` for timestamps. Never in a project
  tree. Every PdM skill starts with the same 3-line config check and routes
  to `/my:pdm-setup` when missing.
- **Workspace:** a user-chosen directory (default `~/pdm-workspace`) holding
  `docs/prd/`, `docs/product-specs/`, `docs/backlog/`, `docs/catchup/` so
  `/my:review` path conventions work when run from the workspace.
- **Language:** PdM artifacts in Japanese; SKILL.md files in English like the
  rest of the repo.
- **Degradation:** every MCP dependency optional; skills state what was
  skipped (e.g. "Slack connector not available in this session").
- **Approval gates:** ticket creation / Notion publish / Slack post always
  show a draft and require explicit confirmation.

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose |
|-----------|---------|
| `skills/pdm-setup/SKILL.md` | first-run wizard: discover + confirm backlog destination, channels, workspace; write config |
| `skills/prd/SKILL.md` | PRD creation: context gather → bounded interview → draft → self-check → optional Notion publish |
| `skills/prd/template.md` | Japanese PRD template |
| `skills/product-spec/SKILL.md` | PRD → functional spec with edge-case sweep and Given/When/Then AC |
| `skills/product-spec/template.md` | Japanese functional-spec template |
| `skills/backlog/SKILL.md` | spec/PRD → epics/stories with AC → review table → approval-gated filing (Notion DB / GitHub) + `quick` mode |
| `skills/backlog/template.md` | ticket format + decomposition table |
| `skills/catchup/SKILL.md` | Slack + Notion digest since last run; save + optional Slack DM; update state |
| `skills/catchup/template.md` | digest format |
| `skills/review/checklists/prd.md` | PRD review checklist (severity-tagged) |
| `skills/review/checklists/product-spec.md` | product-spec review checklist |
| `scripts/pdm/catchup-headless.sh` | `claude -p` wrapper for local scheduled runs (Notion-only, allowlisted tools, logs) |
| `scripts/pdm/com.my.pdm-catchup.plist.template` | launchd template for the wrapper |
| `scripts/pdm/README.md` | scheduling recipes: cloud routine (recommended) / Desktop / launchd |

### 2.2 Files to Modify

| File Path | Changes Required |
|-----------|------------------|
| `skills/review/SKILL.md` | add `prd:{id}` → `docs/prd/{id}.md`, `pspec:{id}` → `docs/product-specs/{id}.md` target rows; map their content checklists; extend output `{type}` list |
| `README.md` | PdM skills in the skills table + a "PdM flow" usage section + scheduling pointer |

### 2.3 Files to Delete
N/A: additive change.

## 3. Implementation Steps

### Phase 1: Skills

#### Step 1.1: `skills/pdm-setup/SKILL.md`
**Action:** Create — wizard steps: workspace dir → backlog destination
(Notion DB search + confirm, or GitHub repo, or "draft-only") → property
mapping → priority Slack channels (search + confirm) → digest prefs →
write config.md; `--show` prints current config.

#### Step 1.2: `skills/prd/SKILL.md` + `template.md`
**Action:** Create — modes: new / revise; inputs: free text, file path,
Notion URL, Slack thread URL. Max 2 AskUserQuestion rounds; unknowns become
TBD + Open Questions. Self-check against `checklists/prd.md` before saving.

#### Step 1.3: `skills/product-spec/SKILL.md` + `template.md`
**Action:** Create — transform skill (no questions; records Assumptions).
Systematic edge-case sweep (states, permissions, concurrency, empty/limit,
errors). AC in Given/When/Then per requirement.

#### Step 1.4: `skills/backlog/SKILL.md` + `template.md`
**Action:** Create — INVEST stories, S/M/L estimates, dependency notes;
review table first; file only approved rows; `quick` mode for one-offs.

#### Step 1.5: `skills/catchup/SKILL.md` + `template.md`
**Action:** Create — window = since `state/last-catchup` (fallback 24h,
override arg); Slack mentions/threads/priority channels + Notion recent +
meeting notes; digest: 要対応 / 議論 / FYI / 会議メモ / 提案アクション;
update state file after writing.

**Verification (whole phase):**
```bash
for d in pdm-setup prd product-spec backlog catchup; do python3 - "$d" <<'EOF'
import sys,re,yaml; p=f"skills/{sys.argv[1]}/SKILL.md"; t=open(p).read()
m=re.match(r"^---\n(.*?)\n---\n",t,re.S); d=yaml.safe_load(m.group(1))
assert d.get("description") and d.get("argument-hint") is not None, p
print("ok",p)
EOF
done
```

### Phase 2: Review integration + docs + scheduling

#### Step 2.1: checklists + `skills/review/SKILL.md` edits (see 2.2 table)
**Verification:**
```bash
grep -n "prd:" skills/review/SKILL.md && ls skills/review/checklists/prd.md skills/review/checklists/product-spec.md
```

#### Step 2.2: `scripts/pdm/*` scheduling assets
**Verification:**
```bash
bash -n scripts/pdm/catchup-headless.sh && plutil -lint scripts/pdm/com.my.pdm-catchup.plist.template
```

#### Step 2.3: README update
**Verification:**
```bash
grep -n "my:prd" README.md
```

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| N/A | – | markdown + existing MCP/CLI only |

### 4.2 Internal Dependencies
Notion MCP, Slack connector, `gh` CLI — all optional at runtime (NFR-002).

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [x] Source document reviewed
- [x] Dependencies identified and available

### 5.2 Post-Implementation
- [x] Full test suite passing (command: `npx -y bats -r tests/` — 49 ok)
- [x] Install intact (command: `./scripts/install.sh --check`)
- [x] Frontmatter of all new skills parses (Phase 1 verification script)
- [x] Skills discovered live in the running session (symlink install)

### 5.3 Acceptance Criteria Verification
- [x] FR-001 → Step 1.2, FR-002 → Step 1.3, FR-003 → Step 1.4,
      FR-004 → Step 1.5, FR-005 → Step 1.1, FR-006 → Step 2.1,
      FR-007 → Step 2.2/2.3

## 6. Rollback Plan (optional)
Additive change: `git rm -r` the new skill dirs / scripts and revert the two
modified files.

## 7. Estimated Effort (optional)
N/A: single-session documentation change.

---
**Size:** M
**Created:** 2026-07-11
**Status:** Completed
