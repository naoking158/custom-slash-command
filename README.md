# Custom Slash Commands for Claude Code & gemini-cli

Custom slash commands for implementing the SDD (Spec-Driven Development) pipeline in Claude Code and gemini-cli.

## Overview

This repository provides custom slash commands for Claude Code and gemini-cli, enabling a systematic software development workflow: Research → Spec → Plan → Do → Review. Both tools share the same prompt logic, ensuring consistent behavior across different AI assistants.

### Available Commands

#### Claude Code

| Command | Description | Output |
|---------|-------------|--------|
| `/research` | Research and analyze requirements | `docs/research/` |
| `/spec` | Create specifications from research | `docs/specs/` |
| `/plan` | Create implementation plans | `docs/plans/{type}/` |
| `/debug` | Analyze bugs + generate fix plans | `docs/analysis/bugs/` + `docs/plans/fixes/` |
| `/refactor` | Analyze code for refactoring | `docs/analysis/refactors/` + `docs/plans/refactors/` |
| `/change` | Analyze feature modifications | `docs/analysis/changes/` + `docs/plans/changes/` |
| `/do` | Execute implementation plans | Source code files |
| `/review` | Review artifacts | `docs/reviews/{type}/` |

#### gemini-cli

| Command | Description | Output |
|---------|-------------|--------|
| `/sdd:research` | Research and analyze requirements | `docs/research/` |
| `/sdd:spec` | Create specifications from research | `docs/specs/` |
| `/sdd:plan` | Create implementation plans | `docs/plans/{type}/` |
| `/sdd:debug` | Analyze bugs + generate fix plans | `docs/analysis/bugs/` + `docs/plans/fixes/` |
| `/sdd:refactor` | Analyze code for refactoring | `docs/analysis/refactors/` + `docs/plans/refactors/` |
| `/sdd:change` | Analyze feature modifications | `docs/analysis/changes/` + `docs/plans/changes/` |
| `/sdd:do` | Execute implementation plans | Source code files |
| `/sdd:review` | Review artifacts | `docs/reviews/{type}/` |

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
   # Link the sdd commands directory
   ln -sf "$(pwd)/gemini/commands/sdd" ~/.gemini/commands/sdd
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
   ls -la ~/.gemini/commands/sdd
   ```

### Uninstall

```bash
# Remove shared prompts
rm ~/.prompts

# Remove Claude Code symlinks
rm ~/.claude/commands

# Remove gemini-cli symlinks
rm ~/.gemini/commands/sdd
```

## Usage

### Claude Code

#### New Feature Development Flow

```bash
# 1. Research requirements
/research implement user authentication feature

# 2. Create specification (use the research document filename)
/spec 20241217-user-auth

# 3. Create implementation plan
/plan 20241217-user-auth

# 4. Execute implementation
/do 20241217-user-auth

# 5. Review the code
/review code:20241217-user-auth
```

#### Bug Fix Flow

```bash
# 1. Analyze the bug (auto-generates analysis and plan)
/debug login button not working

# 2. Execute the fix
/do 20241217-login-button-fix
```

#### Refactoring Flow

```bash
# 1. Analyze for refactoring
/refactor auth-module

# 2. Execute the refactoring
/do 20241217-auth-module
```

#### Feature Modification Flow

```bash
# 1. Analyze the change
/change fix chat input width expanding issue

# 2. Execute the change
/do 20241217-chat-input-width
```

#### Review Flow

```bash
# Review a specification
/review spec:20241218-user-auth

# Backend review of a plan
/review be:plan:20241218-user-auth

# Security review of code
/review security:code:payment

# Review a specific commit
/review commit:abc1234

# Review the current PR
/review pr:current
```

**Available perspectives:** `fe:` (frontend), `be:` (backend), `security:`, `perf:` (performance), `doc:` (documentation)

### gemini-cli

#### New Feature Development Flow

```bash
# 1. Research requirements
gemini "/sdd:research implement user authentication feature"

# 2. Create specification
gemini "/sdd:spec 20241217-user-auth"

# 3. Create implementation plan
gemini "/sdd:plan 20241217-user-auth"

# 4. Execute implementation
gemini "/sdd:do 20241217-user-auth"

# 5. Review the code
gemini "/sdd:review code:20241217-user-auth"
```

#### Bug Fix Flow

```bash
# 1. Analyze the bug (auto-generates analysis and plan)
gemini "/sdd:debug login button not working"

# 2. Execute the fix
gemini "/sdd:do 20241217-login-button-fix"
```

#### Refactoring Flow

```bash
# 1. Analyze for refactoring
gemini "/sdd:refactor auth-module"

# 2. Execute the refactoring
gemini "/sdd:do 20241217-auth-module"
```

#### Feature Modification Flow

```bash
# 1. Analyze the change
gemini "/sdd:change fix chat input width expanding issue"

# 2. Execute the change
gemini "/sdd:do 20241217-chat-input-width"
```

#### Review Flow

```bash
# Review a specification
gemini "/sdd:review spec:20241218-user-auth"

# Backend review of a plan
gemini "/sdd:review be:plan:20241218-user-auth"

# Security review of code
gemini "/sdd:review security:code:payment"
```

**Available perspectives:** `fe:` (frontend), `be:` (backend), `security:`, `perf:` (performance), `doc:` (documentation)

## Directory Structure

### Repository Structure

```
custom-slash-command/
├── commands/           # Claude Code slash command definitions
│   ├── research.md
│   ├── spec.md
│   ├── plan.md
│   ├── debug.md
│   ├── refactor.md
│   ├── change.md
│   ├── do.md
│   └── review.md
├── gemini/             # gemini-cli commands
│   └── commands/
│       └── sdd/        # SDD namespace commands
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
    ├── research/       # /research output
    ├── specs/          # /spec output
    ├── plans/          # /plan output
    │   ├── features/
    │   ├── fixes/
    │   ├── refactors/
    │   └── changes/
    ├── analysis/       # /debug, /refactor, /change analysis output
    │   ├── bugs/
    │   ├── refactors/
    │   └── changes/
    └── reviews/        # /review output
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
