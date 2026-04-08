# Custom Slash Commands for Claude Code & gemini-cli

Custom slash commands for implementing the SDD (Spec-Driven Development) pipeline in Claude Code and gemini-cli.

## Overview

This repository provides custom slash commands for Claude Code and gemini-cli, enabling a systematic software development workflow: Research → Spec → Plan → Do → Review. Both tools share the same prompt logic, ensuring consistent behavior across different AI assistants.

### Available Commands

#### Claude Code

| Command | Description | Output |
|---------|-------------|--------|
| `/my:research` | Research and analyze requirements | `docs/research/` |
| `/my:spec` | Create specifications from research | `docs/specs/` |
| `/my:plan` | Create implementation plans | `docs/plans/{type}/` |
| `/my:debug` | Analyze bugs + generate fix plans | `docs/analysis/bugs/` + `docs/plans/fixes/` |
| `/my:refactor` | Analyze code for refactoring | `docs/analysis/refactors/` + `docs/plans/refactors/` |
| `/my:change` | Analyze feature modifications | `docs/analysis/changes/` + `docs/plans/changes/` |
| `/my:do` | Execute implementation plans | Source code files |
| `/my:do-by-gemini` | Execute plans via gemini-cli | Source code files |
| `/my:review` | Review artifacts | `docs/reviews/{type}/` |
| `/my:pipeline` | Run sequential pipeline (feature: research → spec → plan → do, change: change → do) | Multiple `docs/` outputs |

#### gemini-cli

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

## Installation

### Prerequisites

- Claude Code and/or gemini-cli installed
- `~/.claude/` directory exists (for Claude Code)
- `~/.gemini/` directory exists (for gemini-cli)
- gemini-cli v0.23.0+ (for `@{path}` syntax support)

### Setup

1. **Clone the repository**

   ```bash
   git clone https://github.com/naoking158/custom-slash-command.git
   cd custom-slash-command
   ```

2. **Create shared prompts symlink**

   ```bash
   # Link the prompts directory to HOME (shared by both tools)
   ln -sf "$(pwd)/prompts" ~/.prompts
   ```

3. **Create symlinks for Claude Code**

   ```bash
   # Link the commands directory
   ln -sf "$(pwd)/commands" ~/.claude/commands
   ```

4. **Create symlinks for gemini-cli**

   ```bash
   # Link the my commands directory
   ln -sf "$(pwd)/gemini/commands/my" ~/.gemini/commands/my
   ```

5. **Configure gemini-cli workspace**

   Add `~/.prompts` to gemini-cli's workspace by editing `~/.gemini/settings.json`:

   ```json
   {
     "context": {
       "includeDirectories": ["~/.prompts"]
     }
   }
   ```

   Or if you already have a settings.json, add the `context.includeDirectories` field to it.

6. **Verify the setup**

   ```bash
   # Verify shared prompts
   ls -la ~/.prompts

   # Verify Claude Code symlinks
   ls -la ~/.claude/commands

   # Verify gemini-cli symlinks
   ls -la ~/.gemini/commands/my
   ```

### Uninstall

```bash
# Remove shared prompts
rm ~/.prompts

# Remove Claude Code symlinks
rm ~/.claude/commands

# Remove gemini-cli symlinks
rm ~/.gemini/commands/my
```

## Usage

### Claude Code

#### New Feature Development Flow

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

#### Bug Fix Flow

```bash
# 1. Analyze the bug (auto-generates analysis and plan)
/my:debug login button not working

# 2. Execute the fix
/my:do 20241217-login-button-fix
```

#### Refactoring Flow

```bash
# 1. Analyze for refactoring
/my:refactor auth-module

# 2. Execute the refactoring
/my:do 20241217-auth-module
```

#### Feature Modification Flow

```bash
# 1. Analyze the change
/my:change fix chat input width expanding issue

# 2. Execute the change
/my:do 20241217-chat-input-width
```

#### Pipeline Flow

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

#### Review Flow

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

### gemini-cli

#### New Feature Development Flow

```bash
# 1. Research requirements
gemini "/my:research implement user authentication feature"

# 2. Create specification
gemini "/my:spec 20241217-user-auth"

# 3. Create implementation plan
gemini "/my:plan 20241217-user-auth"

# 4. Execute implementation
gemini "/my:do 20241217-user-auth"

# 5. Review the code
gemini "/my:review code:20241217-user-auth"
```

#### Bug Fix Flow

```bash
# 1. Analyze the bug (auto-generates analysis and plan)
gemini "/my:debug login button not working"

# 2. Execute the fix
gemini "/my:do 20241217-login-button-fix"
```

#### Refactoring Flow

```bash
# 1. Analyze for refactoring
gemini "/my:refactor auth-module"

# 2. Execute the refactoring
gemini "/my:do 20241217-auth-module"
```

#### Feature Modification Flow

```bash
# 1. Analyze the change
gemini "/my:change fix chat input width expanding issue"

# 2. Execute the change
gemini "/my:do 20241217-chat-input-width"
```

#### Review Flow

```bash
# Review a specification
gemini "/my:review spec:20241218-user-auth"

# Backend review of a plan
gemini "/my:review be:plan:20241218-user-auth"

# Security review of code
gemini "/my:review security:code:payment"
```

**Available perspectives:** `fe:` (frontend), `be:` (backend), `security:`, `perf:` (performance), `doc:` (documentation)

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
│       ├── do-by-gemini.md
│       ├── review.md
│       └── pipeline.md
├── gemini/             # gemini-cli commands
│   └── commands/
│       └── my/         # my: namespace commands
│           ├── research.toml
│           ├── spec.toml
│           ├── plan.toml
│           ├── do.toml
│           ├── debug.toml
│           ├── refactor.toml
│           ├── change.toml
│           └── review.toml
├── prompts/            # Shared prompt logic
│   ├── _shared/               # Shared content (tool-agnostic)
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
│   ├── 1_research.md          # Claude Code specific prompts
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

**Claude Code** prompts use XML tags optimized for Claude's parsing:

| Tag | Purpose |
|-----|---------|
| `<role>` | Expert role definition |
| `<process>` | Step-by-step workflow with `<step n="N">` |
| `<rules>` | Constraints and requirements |
| `<output>` | Output format specification |
| `<critical>` | Critical constraints (must follow) |
| `<example>` | Few-shot examples |

**gemini-cli** commands use TOML format with `@{path}` injection:

```toml
description = "Command description"
prompt = """
@{_shared/roles/research.md}

## Task
Your task instructions here.

Feature: {{args}}

@{_shared/processes/research.md}
"""
```

Note: The `@{path}` syntax resolves paths from directories listed in `context.includeDirectories` (configured in `~/.gemini/settings.json`).

### Shared Content Architecture

Both Claude Code and gemini-cli share the same prompt logic through `prompts/_shared/`:

| Directory | Content |
|-----------|---------|
| `roles/` | Tool-agnostic role definitions (Research, Spec, Plan, Do, etc.) |
| `processes/` | Tool-agnostic process steps |

| File | Description |
|------|-------------|
| `file-naming-rules.md` | Date-prefixed kebab-case naming with multilingual examples |
| `output-constraints.md` | Standard output rules (file-only, no console) |
| `placeholders.md` | `{{PLACEHOLDER}}` syntax reference |
| `quality-standards.md` | Code and document quality checklists |

### Placeholder Convention

**Claude Code:** Uses double-brace uppercase syntax:
- `{{IDENTIFIER}}` - Normalized feature/bug identifier
- `{{DATE}}` - Current date (YYYYMMDD)
- `{{INPUT}}` - Raw user input

**gemini-cli:** Uses double-brace lowercase syntax:
- `{{args}}` - Command arguments passed by user

## License

MIT
