# Research: Prompt Optimization

## 1. Overview

This research analyzes the current custom slash command prompt system and identifies optimization opportunities based on 2024/2025 prompt engineering best practices. The goal is to improve clarity, reduce token usage, enhance response quality, and ensure consistency across all workflow phases.

## 2. Problem Statement

The current prompt system consists of 8 main prompts and 7 templates that guide AI through a software development workflow (research → spec → plan → do, plus debug/refactor/change/review branches). While functional, the prompts can be optimized to:

1. **Reduce redundancy** - File naming rules and normalization appear in multiple prompts
2. **Improve Claude-specific formatting** - Leverage XML tags more effectively
3. **Enhance clarity** - Use affirmative directives and reduce ambiguity
4. **Streamline structure** - Apply consistent patterns across all prompts
5. **Add missing best practices** - Include few-shot examples, assistant pre-filling hints

## 3. Requirements Analysis

### 3.1 Functional Requirements
- [x] FR-001: Maintain all existing workflow functionality
- [x] FR-002: Support multi-language input (Japanese, English, etc.)
- [x] FR-003: Auto-generate file names with date prefix
- [x] FR-004: Write outputs to correct directory structure
- [x] FR-005: Chain commands via next-step suggestions

### 3.2 Non-Functional Requirements
- [x] NFR-001: Reduce total token count per prompt by ~20-30%
- [x] NFR-002: Improve response consistency and format compliance
- [x] NFR-003: Enhance maintainability of prompt system
- [x] NFR-004: Leverage Claude-specific optimizations (XML tags)
- [x] NFR-005: Ensure prompts work without modification across Claude model versions

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| Developers using the system | Clear, consistent outputs; fast execution | High |
| Prompt maintainers | Easy to update; DRY (Don't Repeat Yourself) | High |
| AI (Claude) | Clear instructions; proper context boundaries | High |

## 5. Technical Investigation

### 5.1 Current State Analysis

#### Identified Issues

| Issue | Location | Severity | Description |
|-------|----------|----------|-------------|
| ISS-001 | All prompts | Medium | File Name Extraction rules duplicated in 5 prompts (~40 lines each) |
| ISS-002 | All prompts | Medium | Role definitions vary in specificity and format |
| ISS-003 | 1_research.md | Low | MCP server recommendation is non-actionable |
| ISS-004 | All prompts | Medium | Markdown-style headers used instead of XML tags |
| ISS-005 | Templates | Low | Placeholder syntax inconsistent (`{feature}` vs `{feature_name}`) |
| ISS-006 | 7_do.md | Medium | Long error message templates consume tokens |
| ISS-007 | 8_review.md | Low | Mixed English/Japanese in error messages |
| ISS-008 | All prompts | Low | "CRITICAL" warnings could be stronger with XML emphasis |
| ISS-009 | Command files | Medium | Duplicates much of the prompt file content |

#### Positive Patterns (Keep)
- Clear phase-based structure
- Consistent output format confirmations
- Good use of tables for command resolution
- Step-by-step process definitions
- Quality standards checklists

### 5.2 Best Practices Research (2024/2025)

Based on current prompt engineering research:

#### Claude-Specific Optimizations
1. **XML Tags**: Claude is specifically trained on XML structure. Use `<instructions>`, `<context>`, `<rules>`, `<output>` tags
2. **Assistant Pre-filling**: Start Claude's response to force format compliance
3. **Affirmative Directives**: Use "DO X" instead of "DON'T do Y"
4. **Context at Top**: Place static context before dynamic input

#### General Best Practices
1. **Delimiters**: Use clear separators between sections
2. **Few-Shot Examples**: Provide 1-3 high-quality examples
3. **Task Decomposition**: Break complex tasks into atomic steps
4. **Variable Placeholders**: Use consistent `{{VARIABLE}}` syntax

### 5.3 Technology Options

| Approach | Pros | Cons | Recommendation |
|----------|------|------|----------------|
| Modular includes | DRY, easy maintenance | Requires tooling support | Investigate |
| XML restructure | Claude-optimized, clearer boundaries | Learning curve | **Recommended** |
| Template variables | Reduces redundancy | Adds complexity | Partial adoption |
| Shared constants file | Single source of truth | Extra file to manage | **Recommended** |

### 5.4 Constraints & Dependencies

- Must work with Claude Code's slash command system
- Commands reference `~/.prompts/` path (hardcoded)
- Templates use placeholder syntax that must be preserved
- Existing docs/output structure should remain compatible

## 6. Optimization Recommendations

### 6.1 Structural Improvements

#### A. Extract Shared Content

Create `prompts/_shared/` directory with:

```
prompts/
├── _shared/
│   ├── file-naming-rules.md      # 40-line block → single include
│   ├── output-constraints.md     # Common "CRITICAL" rules
│   └── quality-standards.md      # Reusable checklist items
├── 1_research.md
├── 2_spec.md
...
```

**Impact**: Reduces total line count by ~150-200 lines

#### B. Convert to XML Structure

**Before (Current):**
```markdown
## Role Definition
You are an **Expert Technical Analyst**...

## Process
### Step 1: Understand the Request
- Parse the user's input...
```

**After (Optimized):**
```xml
<role>
Expert Technical Analyst specializing in requirements gathering and technology research.
</role>

<process>
<step n="1" name="Understand Request">
- Parse the user's input to extract the core requirement
- Identify implicit requirements or assumptions
- Note ambiguities requiring clarification
</step>
</process>
```

**Impact**:
- Better section boundaries for Claude
- More consistent parsing
- ~10% token reduction from cleaner structure

#### C. Consolidate Command + Prompt Files

Current: `commands/research.md` + `prompts/1_research.md` = redundancy

Recommendation:
- Keep command files minimal (metadata + single reference)
- Move all logic to prompt files
- OR merge into single files in `commands/`

### 6.2 Content Improvements

#### A. Affirmative Directives

| Current | Optimized |
|---------|-----------|
| "Do NOT output the document content to console" | "Write output ONLY to file. Console output = summary only." |
| "Do NOT rely on chat history" | "Source document is your single source of truth." |

#### B. Consistent Placeholders

Standardize on `{{PLACEHOLDER}}` syntax:

| Current | Optimized |
|---------|-----------|
| `{feature_name}` | `{{FEATURE_NAME}}` |
| `{identifier}` | `{{IDENTIFIER}}` |
| `$ARGUMENTS` | `{{INPUT}}` |

#### C. Add Few-Shot Examples

For complex outputs, add a mini-example:

```xml
<example>
<input>ユーザー認証機能を追加</input>
<identifier>user-auth</identifier>
<filename>20241218-user-auth.md</filename>
</example>
```

### 6.3 Token Reduction Strategies

| Strategy | Estimated Savings | Implementation Effort |
|----------|-------------------|----------------------|
| Remove duplicate file-naming rules | ~200 tokens × 4 prompts = 800 tokens | Low |
| Compress error message templates | ~100-150 tokens per prompt | Low |
| Use XML instead of Markdown headers | ~50 tokens per prompt | Medium |
| Remove redundant "CRITICAL" warnings | ~30 tokens per prompt | Low |
| Shorter role definitions | ~20-40 tokens per prompt | Low |

**Total Estimated Savings**: 1,000-1,500 tokens across all prompts (~20-25%)

### 6.4 Specific Prompt Recommendations

#### 1_research.md
- Remove "Recommended MCP Servers" section (non-actionable)
- Consolidate Steps 1-5 into 3 cleaner phases
- Add concrete example of research output structure

#### 2_spec.md
- Remove "Reading the Input" subsection (redundant with Process)
- Simplify diagram requirements to "at least 1 Mermaid diagram"
- Add example of good acceptance criteria format

#### 3_plan.md
- Consolidate error handling into single template
- Use table format for phase descriptions instead of verbose lists

#### 4_debug.md / 5_refactor.md / 6_change.md
- Extract common "two-document output" pattern
- Standardize severity/complexity classifications
- Share common "Next steps" template

#### 7_do.md
- Simplify error handling (single generic template)
- Remove redundant "Implementation Rules" (covered in Quality Standards)
- Add assistant pre-fill hint for progress reporting format

#### 8_review.md
- Standardize language (all English or add i18n support)
- Consolidate perspective checklist loading into single table
- Remove duplicate command resolution table from command file

## 7. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Breaking existing workflows | High | Low | Test each prompt individually before merging |
| Claude version compatibility | Medium | Low | Avoid model-specific tricks; use stable patterns |
| Over-optimization reducing clarity | Medium | Medium | Get user feedback after changes |
| Shared file path changes breaking references | High | Low | Update all references atomically |

## 8. Open Questions

- [ ] Q1: Should command files be merged into prompt files, or kept separate for modularity?
- [ ] Q2: Is there a preference for English-only or bilingual (EN/JP) error messages?
- [ ] Q3: Should templates include more concrete examples or remain abstract?
- [ ] Q4: What is the tolerance for breaking changes to existing workflows?

## 9. Recommendations

### Immediate Actions (Low Risk, High Impact)
1. Standardize placeholder syntax across all prompts
2. Convert "DON'T" instructions to affirmative directives
3. Add 1 concrete example to each prompt's file naming section
4. Remove MCP recommendation from 1_research.md

### Short-Term Actions (Medium Effort)
1. Extract file naming rules to shared location
2. Convert prompt structure to use XML tags
3. Consolidate error message templates
4. Standardize role definitions

### Future Considerations
1. Create a prompt testing framework
2. Add version tracking to prompts
3. Consider i18n support for error messages
4. Implement prompt caching strategy for repeated elements

## 10. Next Steps

- [ ] Proceed to `/spec 20241218-prompt-optimization` to create detailed specification
- [ ] Prioritize recommendations based on stakeholder input
- [ ] Create implementation timeline

---
**Created:** 2024-12-18
**Status:** Draft
