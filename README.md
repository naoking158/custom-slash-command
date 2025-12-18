# Custom Slash Commands for Claude Code

Custom slash commands for implementing the SDD (Spec-Driven Development) pipeline in Claude Code.

## Overview

This repository provides custom slash commands for Claude Code, enabling a systematic software development workflow: Research → Spec → Plan → Do → Review.

### Available Commands

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

2. **Create symlinks**

   ```bash
   # Link the commands directory
   ln -sf "$(pwd)/commands" ~/.claude/commands

   # Link the prompts directory (as .prompts)
   ln -sf "$(pwd)/prompts" ~/.claude/.prompts
   ```

3. **Verify the setup**

   ```bash
   # Verify symlinks are created correctly
   ls -la ~/.claude/commands
   ls -la ~/.claude/.prompts

   # Verify command files are accessible
   ls ~/.claude/commands/
   ```

### Uninstall

```bash
rm ~/.claude/commands
rm ~/.claude/.prompts
```

## Usage

### New Feature Development Flow

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

### Bug Fix Flow

```bash
# 1. Analyze the bug (auto-generates analysis and plan)
/debug login button not working

# 2. Execute the fix
/do 20241217-login-button-fix
```

### Refactoring Flow

```bash
# 1. Analyze for refactoring
/refactor auth-module

# 2. Execute the refactoring
/do 20241217-auth-module
```

### Feature Modification Flow

```bash
# 1. Analyze the change
/change fix chat input width expanding issue

# 2. Execute the change
/do 20241217-chat-input-width
```

### Review Flow

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

## Directory Structure

### Repository Structure

```
custom-slash-command/
├── commands/           # Slash command definitions
│   ├── research.md
│   ├── spec.md
│   ├── plan.md
│   ├── debug.md
│   ├── refactor.md
│   ├── change.md
│   ├── do.md
│   └── review.md
├── prompts/            # Prompt logic
│   ├── _shared/               # Shared content
│   │   ├── file-naming-rules.md
│   │   ├── output-constraints.md
│   │   ├── placeholders.md
│   │   └── quality-standards.md
│   ├── 1_research.md
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

All prompts use XML tags optimized for Claude's parsing:

| Tag | Purpose |
|-----|---------|
| `<role>` | Expert role definition |
| `<process>` | Step-by-step workflow with `<step n="N">` |
| `<rules>` | Constraints and requirements |
| `<output>` | Output format specification |
| `<critical>` | Critical constraints (must follow) |
| `<example>` | Few-shot examples |

### Shared Content

Common patterns are centralized in `prompts/_shared/`:

| File | Description |
|------|-------------|
| `file-naming-rules.md` | Date-prefixed kebab-case naming with multilingual examples |
| `output-constraints.md` | Standard output rules (file-only, no console) |
| `placeholders.md` | `{{PLACEHOLDER}}` syntax reference |
| `quality-standards.md` | Code and document quality checklists |

### Placeholder Convention

All placeholders use double-brace uppercase syntax:
- `{{IDENTIFIER}}` - Normalized feature/bug identifier
- `{{DATE}}` - Current date (YYYYMMDD)
- `{{INPUT}}` - Raw user input

## License

MIT
