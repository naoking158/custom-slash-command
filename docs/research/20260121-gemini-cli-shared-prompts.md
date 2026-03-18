# Research: gemini-cli Shared Prompts Architecture

## 1. Overview

This research explores how to create custom slash commands for `gemini-cli` that share the same prompt logic as the existing Claude Code custom commands. The goal is to enable the same SDD (Spec-Driven Development) workflow (/research → /spec → /plan → /do → /review) in gemini-cli while minimizing duplication and maintenance overhead.

## 2. Problem Statement

The current `custom-slash-command` repository provides a comprehensive SDD pipeline for Claude Code. Users want the same capabilities in `gemini-cli`, but:

- Creating entirely separate command definitions would lead to significant code duplication
- Maintaining two sets of prompts would double the maintenance burden
- The prompt logic (research methodology, spec structure, plan format) should be consistent across both tools

The challenge is to architect a solution where common prompt content is shared between Claude Code and gemini-cli commands, with only the tool-specific execution logic being different.

## 3. Requirements Analysis

### 3.1 Functional Requirements

- [ ] FR-001: Create gemini-cli equivalents for all SDD commands (/research, /spec, /plan, /do, /review, /debug, /refactor, /change)
- [ ] FR-002: Share common prompt logic (role definitions, process steps, templates, naming rules)
- [ ] FR-003: Support gemini-cli-specific features (TOML format, shell command injection, file content injection)
- [ ] FR-004: Maintain consistent output formats (same file naming, same directory structure)
- [ ] FR-005: Support both global (~/.gemini/commands/) and project-scoped commands
- [ ] FR-006: Pass arguments correctly using gemini-cli's `{{args}}` placeholder

### 3.2 Non-Functional Requirements

- [ ] NFR-001: Minimize duplicate content between Claude Code and gemini-cli commands
- [ ] NFR-002: Easy maintenance - changes to prompt logic should propagate to both tools
- [ ] NFR-003: Clear documentation for setup and usage
- [ ] NFR-004: Support namespaced commands (e.g., `/sdd:research`, `/sdd:spec`)

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| Developer | Same SDD workflow in gemini-cli | High |
| Developer | Minimal setup/maintenance effort | High |
| Developer | Consistent output across tools | Medium |
| Developer | Ability to customize per-tool behavior | Low |
| Team Lead | Shared standards across AI tools | Medium |

## 5. Technical Investigation

### 5.1 Current Claude Code Architecture

**Structure:**
```
custom-slash-command/
├── commands/           # Entry points (Claude Code reads these)
│   ├── research.md     # → References prompts/1_research.md
│   ├── spec.md
│   ├── plan.md
│   └── ...
├── prompts/            # Detailed prompt logic
│   ├── 1_research.md   # Full instructions, role, process
│   ├── 2_spec.md
│   ├── _shared/        # Common rules
│   │   ├── file-naming-rules.md
│   │   └── ...
│   └── templates/      # Output templates
│       ├── research_template.md
│       └── ...
└── docs/               # Generated outputs
```

**Key Characteristics:**
- Commands use Markdown format
- Entry points are minimal, reference detailed prompts via path
- Prompts use XML tags (`<role>`, `<process>`, `<rules>`)
- Supports `@import` for shared content
- Templates guide output structure

### 5.2 Gemini-CLI Custom Commands

**Location:**
- Global: `~/.gemini/commands/`
- Project: `.gemini/commands/`

**Format:**
- TOML files (`.toml` extension)
- Required: `prompt` field (string)
- Optional: `description` field (string)

**Features:**
- `{{args}}` - Argument substitution
- `!{command}` - Shell command injection
- `@{path}` - File content injection
- Namespaced commands via directory structure

**Example:**
```toml
description = "Research and analyze requirements"
prompt = """
You are an Expert Technical Analyst...

Feature description: {{args}}

Process:
1. Understand the request
2. Research best practices
...
"""
```

### 5.3 Architecture Comparison

| Aspect | Claude Code | gemini-cli |
|--------|-------------|------------|
| Format | Markdown | TOML |
| Reference mechanism | `~/.prompts/X.md` | File content embedded |
| Shared content | `@import` directive | `@{path}` injection |
| Arguments | `$ARGUMENTS` | `{{args}}` |
| Shell execution | Native (via Bash tool) | `!{command}` syntax |
| File reading | Native (via Read tool) | `@{path}` injection |

### 5.4 Technology Options

| Option | Description | Pros | Cons | Recommendation |
|--------|-------------|------|------|----------------|
| **A: Embedded Prompts** | Copy full prompt content into TOML files | Simple, self-contained | High duplication, maintenance burden | Not recommended |
| **B: File Injection** | Use `@{path}` to inject shared prompt files | Minimal duplication, shared logic | Requires adapting prompt format for both tools | **Recommended** |
| **C: Build Script** | Script that generates gemini TOML from Claude prompts | Single source of truth | Build step required, complexity | Consider for v2 |
| **D: Hybrid** | Share templates/rules, tool-specific entry points | Balance of sharing and customization | Some duplication remains | Alternative |

### 5.5 Recommended Architecture (Option B: File Injection)

```
custom-slash-command/
├── commands/               # Claude Code entry points
│   └── *.md
├── gemini/                 # NEW: gemini-cli commands
│   └── commands/
│       ├── sdd/            # Namespaced as /sdd:*
│       │   ├── research.toml
│       │   ├── spec.toml
│       │   ├── plan.toml
│       │   ├── do.toml
│       │   └── review.toml
│       └── setup.toml      # /setup command for initialization
├── prompts/
│   ├── _shared/            # Shared between both tools
│   │   ├── file-naming-rules.md
│   │   ├── roles/
│   │   │   ├── research.md   # Role definition for research
│   │   │   ├── spec.md
│   │   │   └── ...
│   │   └── processes/
│   │       ├── research.md   # Process steps for research
│   │       └── ...
│   ├── templates/          # Output templates (shared)
│   └── *.md                # Claude Code specific prompts
└── docs/
```

**Gemini TOML Example (sdd/research.toml):**
```toml
description = "Research and analyze requirements for new features"
prompt = """
@{../../../prompts/_shared/roles/research.md}

## Task
Analyze the following feature request:
{{args}}

@{../../../prompts/_shared/processes/research.md}

## File Naming Rules
@{../../../prompts/_shared/file-naming-rules.md}

## Output
Write research document to: docs/research/YYYYMMDD-{identifier}.md

Use template structure from:
@{../../../prompts/templates/research_template.md}
"""
```

### 5.6 Constraints & Dependencies

**Dependencies:**
- gemini-cli v0.23.0+ (custom command support)
- Existing prompt files must be accessible via relative paths
- File injection (`@{path}`) must resolve correctly

**Constraints:**
- TOML format required (not Markdown)
- No direct equivalent to Claude Code's tool system
- Shell command injection requires user confirmation
- Path resolution is relative to TOML file location

## 6. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Path resolution issues with `@{path}` | High | Medium | Test extensively, document symlink setup |
| Prompt format incompatibility | Medium | Medium | Create shared prompts in tool-agnostic format |
| gemini-cli version incompatibility | Low | Low | Document minimum version requirements |
| Maintenance of two entry point formats | Medium | High | Keep entry points minimal, share logic |
| Different AI behavior on same prompts | Medium | High | Accept as expected, focus on process consistency |

## 7. Open Questions

- [ ] Q1: Should gemini-cli commands use namespacing (/sdd:research) or flat (/research)?
  - **Recommendation:** Namespace as `/sdd:*` to avoid conflicts with user commands
- [ ] Q2: How to handle tool-specific features (Claude's tools vs gemini-cli's shell injection)?
  - **Recommendation:** Abstract to common patterns where possible, tool-specific wrappers where needed
- [ ] Q3: Should setup be automated via a /setup command or manual symlinks?
  - **Recommendation:** Provide both options, /setup for convenience, manual for flexibility
- [ ] Q4: How to handle output templates - inject full content or reference?
  - **Recommendation:** Inject full content for gemini to ensure complete context
- [ ] Q5: What's the best way to share prompts without breaking either tool?
  - **Recommendation:** Create tool-agnostic shared content, tool-specific entry points

## 8. Recommendations

### Primary Approach

1. **Create shared prompt modules** in `prompts/_shared/` that work for both tools:
   - Role definitions (tool-agnostic)
   - Process steps (tool-agnostic)
   - File naming rules
   - Templates

2. **Create gemini-cli entry points** in `gemini/commands/sdd/`:
   - TOML files that inject shared content
   - Handle gemini-cli specific syntax (`{{args}}`, `!{...}`)

3. **Installation via symlink** (same pattern as Claude Code):
   ```bash
   ln -sf "$(pwd)/gemini/commands" ~/.gemini/commands/sdd
   ```

4. **Namespace all commands** as `/sdd:*` to avoid conflicts

### Implementation Phases

**Phase 1: Core Commands**
- /sdd:research
- /sdd:spec
- /sdd:plan
- /sdd:do

**Phase 2: Extended Commands**
- /sdd:debug
- /sdd:refactor
- /sdd:change
- /sdd:review

**Phase 3: Utilities**
- /sdd:setup (initialization helper)
- /sdd:help (usage guide)

### Key Design Decisions

1. **Shared content format:** Plain Markdown without tool-specific syntax
2. **Entry points:** Tool-specific (Claude MD, Gemini TOML)
3. **Namespace:** `/sdd:*` for gemini-cli to avoid conflicts
4. **Installation:** Symlink pattern for both tools

## 9. Next Steps

- [ ] Proceed to `/spec` phase with: `20260121-gemini-cli-shared-prompts`
- [ ] Design shared prompt module structure
- [ ] Create first gemini-cli command (/sdd:research) as proof of concept
- [ ] Test file injection with relative paths
- [ ] Document installation and usage

---
**Created:** 2026-01-21
**Status:** Draft
