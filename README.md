# Custom Slash Commands for Claude Code

Custom slash commands for implementing the SDD (Spec-Driven Development) pipeline in Claude Code.

## Overview

This repository provides custom slash commands for Claude Code, enabling a systematic software development workflow: Research → Spec → Plan → Do → Review.

### Available Commands

| Command | Description | Output |
|---------|-------------|--------|
| `/my:research` | Research and analyze requirements | `docs/research/` |
| `/my:spec` | Create specifications from research | `docs/specs/` |
| `/my:plan` | Create implementation plans | `docs/plans/{type}/` |
| `/my:debug` | Analyze bugs + generate fix plans | `docs/analysis/bugs/` + `docs/plans/fixes/` |
| `/my:refactor` | Analyze code for refactoring | `docs/analysis/refactors/` + `docs/plans/refactors/` |
| `/my:change` | Analyze feature modifications | `docs/analysis/changes/` + `docs/plans/changes/` |
| `/my:do` | Execute implementation plans | Source code files |
| `/my:review` | Review artifacts | `docs/reviews/{type}/` |
| `/my:pipeline` | Run sequential pipeline (feature: research → spec → plan → do, change: change → do) | Multiple `docs/` outputs |
| `/my:learn` | Capture session knowledge to machine-local journal | `~/.claude/projects/<repo>/memory/journal/` |
| `/my:retro` | Surface promotion candidates from journals | stdout (read-only) |

## Installation

### Prerequisites

- Claude Code installed
- `~/.claude/` directory exists

### Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/naoking158/custom-slash-command.git
   cd custom-slash-command
   ```

2. **Create shared prompts symlink**

   ```bash
   # Link the prompts directory to HOME
   ln -sf "$(pwd)/prompts" ~/.prompts
   ```

3. **Create symlinks for Claude Code**

   ```bash
   # Link the commands directory
   ln -sf "$(pwd)/commands" ~/.claude/commands
   ```

4. **Verify the setup**

   ```bash
   # Verify shared prompts
   ls -la ~/.prompts

   # Verify Claude Code symlinks
   ls -la ~/.claude/commands
   ```

### Uninstall

```bash
# Remove shared prompts
rm ~/.prompts

# Remove Claude Code symlinks
rm ~/.claude/commands
```

## Usage

### New Feature Development Flow

```bash
# 1. Research requirements
/my:research implement user authentication feature

# 2. Create specification (use the research document filename)
/my:spec 20241217-user-auth

# 3. Create implementation plan
/my:plan 20241217-user-auth

# 4. Execute implementation
/my:do 20241217-user-auth

# 5. Review the code
/my:review code:20241217-user-auth
```

### Bug Fix Flow

```bash
# 1. Analyze the bug (auto-generates analysis and plan)
/my:debug login button not working

# 2. Execute the fix
/my:do 20241217-login-button-fix
```

### Refactoring Flow

```bash
# 1. Analyze for refactoring
/my:refactor auth-module

# 2. Execute the refactoring
/my:do 20241217-auth-module
```

### Feature Modification Flow

```bash
# 1. Analyze the change
/my:change fix chat input width expanding issue

# 2. Execute the change
/my:do 20241217-chat-input-width
```

### Pipeline Flow

The pipeline supports two flow types:

- **Feature flow** (default): research → spec → plan → do
- **Change flow**: change → do

```bash
# Feature flow: research → spec → plan (with review)
/my:pipeline "implement user authentication feature"

# Feature flow: fast execution without review
/my:pipeline "新機能追加" --no-review

# Feature flow: resume from existing identifier (spec → plan only)
/my:pipeline 20241217-user-auth --from spec --to plan

# Feature flow: single step execution
/my:pipeline 20241217-user-auth --only research

# Feature flow: full pipeline including implementation
/my:pipeline "payment integration" --from research --to do --no-review

# Change flow: change → do (with review)
/my:pipeline "ダークモードのボタン改善" --flow change

# Change flow: change only (review plan before do)
/my:pipeline "ボタン改善" --flow change --to change

# Change flow: resume from existing change plan
/my:pipeline 20241217-button-contrast --flow change --from do

# Change flow: fast execution without review
/my:pipeline "ボタン改善" --flow change --no-review
```

**Options:**

| Option | Default | Description |
|--------|---------|-------------|
| `--flow <type>` | `feature` | Flow type (`feature`/`change`) |
| `--from <step>` | varies by flow | Start step (feature: `research`/`spec`/`plan`/`do`, change: `change`/`do`) |
| `--to <step>` | varies by flow | End step (feature: `research`/`spec`/`plan`/`do`, change: `change`/`do`) |
| `--only <step>` | - | Single step (mutually exclusive with `--from`/`--to`) |
| `--review` | enabled | Enable review cycle after each step |
| `--no-review` | - | Disable review cycle |

Each step runs in an isolated subagent context to prevent context pollution. When `--review` is enabled, a reviewer + fixer cycle runs after each step (Critical/Medium issues only).

### Review Flow

```bash
# Review a specification
/my:review spec:20241218-user-auth

# Backend review of a plan
/my:review be:plan:20241218-user-auth

# Security review of code
/my:review security:code:payment

# Review a specific commit
/my:review commit:abc1234

# Review the current PR
/my:review pr:current
```

**Available perspectives:** `fe:` (frontend), `be:` (backend), `security:`, `perf:` (performance), `doc:` (documentation)

### Session Knowledge Capture Flow

Capture in-session learnings, then promote them through the existing SDD
pipeline. Journals live in a **machine-local** store
(`~/.claude/projects/<repo>/memory/journal/`) and never enter the project
repository.

```bash
# 1. Capture a learning during any session (works from any project)
/my:learn --category mistake "TS catch は unknown 必須"

# 2. Surface promotion candidates from accumulated journals
#    (toolkit repo is auto-resolved; run this from any project)
/my:retro --since 14d

# 3. Copy the suggested command from the /my:retro output VERBATIM and run it.
#    The leading `cd` is REQUIRED — without it, /my:change would scaffold
#    docs/analysis/changes/ and docs/plans/changes/ under the wrong project.
cd ~/src/github.com/naoking158/custom-slash-command \
  && /my:change "ts-error-handling: enforce unknown in catch"

# 4. /my:do executes inside the toolkit repo (already cd'd by step 3)
/my:do 20260627-ts-error-handling

# 5. Manually flip the source journal entry's frontmatter
#    `status: raw` → `status: promoted` so it drops out of the next /my:retro
```

If `/my:retro` cannot auto-resolve the toolkit repo it prints the literal
placeholder `<TOOLKIT_REPO>` and a replacement guide. Either create the
symlink (`ln -s <toolkit-absolute-path>/commands ~/.claude/commands`) or
hand-edit the placeholder before running the command. The tool will **never**
silently substitute the current working directory.

### Journal Privacy

Journals are local-only by design. If you must keep them inside a repository
tree for some reason, append the provided template to that repo's `.gitignore`:

```bash
# Append journal patterns to your project's .gitignore
cat .gitignore.journal-template >> .gitignore
```

The repository tree of this toolkit MUST NOT contain a `docs/journal/`
directory at any point — `/my:learn` will refuse to write there.

## Directory Structure

### Repository Structure

```
custom-slash-command/
├── agents/             # Subagent definitions (used by /my:pipeline)
│   ├── researcher.md
│   ├── specifier.md
│   ├── planner.md
│   ├── implementer.md
│   ├── changer.md
│   ├── reviewer.md
│   └── fixer.md
├── commands/           # Claude Code slash command definitions
│   └── my/             # my: namespace commands
│       ├── research.md
│       ├── spec.md
│       ├── plan.md
│       ├── debug.md
│       ├── refactor.md
│       ├── change.md
│       ├── do.md
│       ├── review.md
│       ├── pipeline.md
│       ├── learn.md
│       └── retro.md
├── scripts/            # Helper shell scripts (no Python/Node deps)
│   ├── redact.sh       # Secret masking pipeline used by /my:retro
│   └── redact.denylist # User-extendable deny-list for redact.sh
├── prompts/            # Prompt logic
│   ├── _shared/               # Shared content (role/process definitions)
│   │   ├── roles/             # Role definitions
│   │   │   ├── research.md
│   │   │   ├── spec.md
│   │   │   ├── plan.md
│   │   │   ├── do.md
│   │   │   ├── debug.md
│   │   │   ├── refactor.md
│   │   │   ├── change.md
│   │   │   └── review.md
│   │   ├── processes/         # Process definitions
│   │   │   ├── research.md
│   │   │   ├── spec.md
│   │   │   ├── plan.md
│   │   │   ├── do.md
│   │   │   ├── debug.md
│   │   │   ├── refactor.md
│   │   │   ├── change.md
│   │   │   └── review.md
│   │   ├── file-naming-rules.md
│   │   ├── output-constraints.md
│   │   ├── placeholders.md
│   │   └── quality-standards.md
│   ├── 1_research.md          # Phase prompts
│   ├── 2_spec.md
│   ├── 3_plan.md
│   ├── 4_debug.md
│   ├── 5_refactor.md
│   ├── 6_change.md
│   ├── 7_do.md
│   ├── 8_review.md
│   ├── 10_pipeline.md
│   └── templates/      # Output templates
│       ├── research_template.md
│       ├── spec_template.md
│       ├── plan_template.md
│       ├── bug_analysis_template.md
│       ├── refactor_design_template.md
│       ├── change_template.md
│       ├── review_template.md
│       └── checklists/
│           ├── review_fe_checklist.md
│           ├── review_be_checklist.md
│           ├── review_security_checklist.md
│           ├── review_perf_checklist.md
│           ├── review_doc_checklist.md
│           ├── review_commit_checklist.md
│           └── review_pr_checklist.md
└── README.md
```

### Output Directories (in each project)

```
your-project/
└── docs/
    ├── research/       # /my:research output
    ├── specs/          # /my:spec output
    ├── plans/          # /my:plan output
    │   ├── features/
    │   ├── fixes/
    │   ├── refactors/
    │   └── changes/
    ├── analysis/       # /my:debug, /my:refactor, /my:change analysis output
    │   ├── bugs/
    │   ├── refactors/
    │   └── changes/
    └── reviews/        # /my:review output
```

### Machine-Local Journal Store (per user, per repo)

`/my:learn` and `/my:retro` operate exclusively on a per-user, per-repo
journal directory outside the project tree:

```
~/.claude/projects/<repo>/memory/
├── MEMORY.md           # Auto Memory (read-only — never touched by /my:learn)
└── journal/
    └── YYYY-MM-DD-<session_id>.md   # /my:learn appends; /my:retro reads
```

The repository tree itself MUST NOT contain a `docs/journal/` directory.

## File Naming Convention

- Date prefix: `YYYYMMDD-{identifier}.md`
- Use kebab-case
- Identifiers are automatically extracted from descriptions (including non-English input)

**Examples:**
| Input | Output |
|-------|--------|
| implement user authentication | `20241217-user-auth.md` |
| Fix login button not working | `20241217-login-button-fix.md` |

## Technical Details

### Prompt Architecture

Prompts use XML tags optimized for Claude's parsing:

| Tag | Purpose |
|-----|---------|
| `<role>` | Expert role definition |
| `<process>` | Step-by-step workflow with `<step n="N">` |
| `<rules>` | Constraints and requirements |
| `<output>` | Output format specification |
| `<critical>` | Critical constraints (must follow) |
| `<example>` | Few-shot examples |

### Shared Content Architecture

Role and process definitions live under `prompts/_shared/` and are reused across phase prompts:

| Directory | Content |
|-----------|---------|
| `roles/` | Role definitions (Research, Spec, Plan, Do, etc.) |
| `processes/` | Process steps |

| File | Description |
|------|-------------|
| `file-naming-rules.md` | Date-prefixed kebab-case naming with multilingual examples |
| `output-constraints.md` | Standard output rules (file-only, no console) |
| `placeholders.md` | `{{PLACEHOLDER}}` syntax reference |
| `quality-standards.md` | Code and document quality checklists |

### Placeholder Convention

Uses double-brace uppercase syntax:
- `{{IDENTIFIER}}` - Normalized feature/bug identifier
- `{{DATE}}` - Current date (YYYYMMDD)
- `{{INPUT}}` - Raw user input

## License

MIT
