# Implementation Plan: Prompt Optimization

## 1. Overview

Optimize the custom slash command prompt system to reduce redundancy, improve Claude-specific formatting with XML tags, enhance clarity, and ensure consistency across all 8 workflow phases.

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20241218-prompt-optimization.md`

### 1.2 References
- Specification: `docs/specs/20241218-prompt-optimization.md`
- Research: `docs/research/20241218-prompt-optimization.md`

### 1.3 Implementation Strategy

Apply a phased approach:
1. Extract shared content to `prompts/_shared/` directory
2. Convert all prompts to XML structure
3. Standardize placeholders and convert directives
4. Validate through manual testing

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `prompts/_shared/file-naming-rules.md` | Centralized file naming rules with examples | High |
| `prompts/_shared/output-constraints.md` | Common output rules and constraints | High |
| `prompts/_shared/placeholders.md` | Placeholder reference documentation | Medium |
| `prompts/_shared/quality-standards.md` | Reusable quality checklists | Medium |

### 2.2 Files to Modify

| File Path | Changes Required | Impact |
|-----------|------------------|--------|
| `prompts/1_research.md` | XML conversion, reference shared files, standardize placeholders | Medium |
| `prompts/2_spec.md` | XML conversion, reference shared files, standardize placeholders | Medium |
| `prompts/3_plan.md` | XML conversion, reference shared files, standardize placeholders | Medium |
| `prompts/4_debug.md` | XML conversion, reference shared files, standardize placeholders | Medium |
| `prompts/5_refactor.md` | XML conversion, reference shared files, standardize placeholders | Medium |
| `prompts/6_change.md` | XML conversion, reference shared files, standardize placeholders | Medium |
| `prompts/7_do.md` | XML conversion, reference shared files, convert DO NOT → DO | Medium |
| `prompts/8_review.md` | XML conversion, reference shared files, standardize placeholders | Medium |

### 2.3 Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| (none) | No files to delete |

---

## 3. Implementation Steps

### Phase 1: Foundation - Shared Content Extraction

#### Step 1.1: Create Shared Directory Structure
**File:** `prompts/_shared/`
**Action:** Create

**Details:**
- Create `prompts/_shared/` directory
- This will contain all extracted shared content

**Verification:**
- [ ] Directory exists at `prompts/_shared/`

---

#### Step 1.2: Create File Naming Rules Shared Content
**File:** `prompts/_shared/file-naming-rules.md`
**Action:** Create

**Details:**
- Extract the duplicated file naming logic from prompts (1, 4, 5, 6)
- Use XML structure for Claude optimization
- Include multilingual examples (Japanese/English inputs)
- Document normalization rules

**Content Structure:**
```xml
<file-naming>
<rules>
1. Extract identifier from input (remove date prefix if present)
2. Convert to kebab-case (lowercase, hyphens)
3. Prepend today's date as YYYYMMDD
4. Result: {{DATE}}-{{IDENTIFIER}}.md
</rules>

<examples>
<example>
<input>ユーザー認証機能を追加</input>
<identifier>user-auth</identifier>
<filename>20241218-user-auth.md</filename>
</example>
...
</examples>

<normalization>
1. Lowercase all characters
2. Replace spaces, slashes, underscores → hyphens
3. Convert camelCase → kebab-case
4. Collapse multiple hyphens → single hyphen
</normalization>
</file-naming>
```

**Verification:**
- [ ] File exists with XML structure
- [ ] Contains at least 3 examples (English, Japanese, with-date-prefix)
- [ ] Normalization rules are clear

---

#### Step 1.3: Create Output Constraints Shared Content
**File:** `prompts/_shared/output-constraints.md`
**Action:** Create

**Details:**
- Extract common "Do NOT output to console" rules
- Define standard confirmation format
- Use `<critical>` XML tags

**Content Structure:**
```xml
<output-constraints>
<critical>
Write output ONLY to specified file path.
Console output = summary confirmation only.
Source document is your single source of truth.
</critical>

<directory-creation>
Create output directory if it does not exist before writing.
</directory-creation>

<confirmation-format>
After writing, confirm with:
- File path written
- Key metrics (counts)
- Next step command
</confirmation-format>
</output-constraints>
```

**Verification:**
- [ ] File exists with XML structure
- [ ] Critical constraints are wrapped in `<critical>` tags

---

#### Step 1.4: Create Placeholders Reference
**File:** `prompts/_shared/placeholders.md`
**Action:** Create

**Details:**
- Document all standard placeholders
- Use consistent `{{PLACEHOLDER}}` syntax
- Include usage examples

**Content:**
| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{FEATURE_NAME}}` | Feature identifier (kebab-case) | `user-auth` |
| `{{DATE}}` | Current date (YYYYMMDD) | `20241218` |
| `{{INPUT}}` | Raw user input | `ユーザー認証` |
| `{{IDENTIFIER}}` | Normalized identifier | `user-auth` |
| `{{SOURCE_PATH}}` | Source document path | `docs/specs/user-auth.md` |

**Verification:**
- [ ] All placeholders documented
- [ ] Consistent `{{}}` syntax throughout

---

#### Step 1.5: Create Quality Standards Shared Content
**File:** `prompts/_shared/quality-standards.md`
**Action:** Create

**Details:**
- Extract common quality checklist items
- Define reusable verification criteria

**Verification:**
- [ ] File exists
- [ ] Contains reusable checklist items

---

### Phase 2: Core Logic - XML Structure Conversion

#### Step 2.1: Convert 1_research.md to XML Format
**File:** `prompts/1_research.md`
**Action:** Modify

**Details:**
- Wrap role definition in `<role>` tags
- Wrap process steps in `<process>` with `<step n="N">` format
- Wrap constraints in `<rules>` and `<critical>` tags
- Wrap output format in `<output>` tags
- Replace File Name Extraction section with reference to shared file
- Standardize placeholders to `{{PLACEHOLDER}}` syntax

**Structure Transformation:**
```markdown
# Before:
## Role Definition
You are an **Expert Technical Analyst**...

# After:
<role>
Expert Technical Analyst specializing in requirements gathering and technology research.
</role>
```

**Verification:**
- [ ] XML tags: `<role>`, `<process>`, `<rules>`, `<output>` present
- [ ] File naming section references `_shared/file-naming-rules.md`
- [ ] No duplicate placeholder formats

---

#### Step 2.2: Convert 2_spec.md to XML Format
**File:** `prompts/2_spec.md`
**Action:** Modify

**Details:**
- Apply same XML structure as 1_research.md
- Wrap steps in `<step n="N">` format
- Reference shared output constraints

**Verification:**
- [ ] XML structure applied
- [ ] Steps numbered with `<step n="N">` format

---

#### Step 2.3: Convert 3_plan.md to XML Format
**File:** `prompts/3_plan.md`
**Action:** Modify

**Details:**
- Apply XML structure
- Reference shared file naming rules
- Standardize placeholders

**Verification:**
- [ ] XML structure applied
- [ ] References shared files

---

#### Step 2.4: Convert 4_debug.md to XML Format
**File:** `prompts/4_debug.md`
**Action:** Modify

**Details:**
- Apply XML structure
- Replace duplicated File Name Extraction with reference
- Convert negative directives to affirmative

**Verification:**
- [ ] XML structure applied
- [ ] File naming references shared content
- [ ] Negative directives converted

---

#### Step 2.5: Convert 5_refactor.md to XML Format
**File:** `prompts/5_refactor.md`
**Action:** Modify

**Details:**
- Apply XML structure
- Replace duplicated File Name Extraction with reference
- Add few-shot examples in `<example>` tags

**Verification:**
- [ ] XML structure applied
- [ ] Examples wrapped in `<example>` tags

---

#### Step 2.6: Convert 6_change.md to XML Format
**File:** `prompts/6_change.md`
**Action:** Modify

**Details:**
- Apply XML structure
- Replace duplicated File Name Extraction with reference
- Standardize placeholders

**Verification:**
- [ ] XML structure applied
- [ ] Consistent placeholder syntax

---

#### Step 2.7: Convert 7_do.md to XML Format
**File:** `prompts/7_do.md`
**Action:** Modify

**Details:**
- Apply XML structure
- Convert "DO NOT" section to affirmative form:
  - "DO NOT: Add features not in the source document" → "Keep implementation strictly within source document scope"
  - "DO NOT: Skip writing tests" → "Write tests for all new code"
- Reference shared quality standards

**Verification:**
- [ ] XML structure applied
- [ ] All negative directives converted to affirmative
- [ ] No "DO NOT", "NEVER" without affirmative alternative

---

#### Step 2.8: Convert 8_review.md to XML Format
**File:** `prompts/8_review.md`
**Action:** Modify

**Details:**
- Apply XML structure
- Standardize placeholders
- Wrap error messages in consistent format

**Verification:**
- [ ] XML structure applied
- [ ] Error messages formatted consistently

---

### Phase 3: Integration - Content Optimization

#### Step 3.1: Standardize All Placeholders
**File:** All prompt files
**Action:** Modify

**Details:**
- Search and replace:
  - `{feature}` → `{{FEATURE_NAME}}`
  - `{identifier}` → `{{IDENTIFIER}}`
  - `{id}` → `{{IDENTIFIER}}`
  - `$ARGUMENTS` → `{{INPUT}}`
- Ensure consistency across all 8 prompts

**Verification:**
- [ ] No `{single-brace}` placeholders remain
- [ ] No `$VARIABLE` placeholders remain
- [ ] All use `{{DOUBLE_BRACE}}` format

---

#### Step 3.2: Add Few-Shot Examples to All Prompts
**File:** All prompt files
**Action:** Modify

**Details:**
- Ensure each prompt has at least 1 input→output example
- Wrap examples in `<example>` XML tags
- Include both English and Japanese input examples where applicable

**Verification:**
- [ ] Each prompt has at least 1 example
- [ ] Examples use `<example>` XML tags

---

#### Step 3.3: Consolidate Redundant Warnings
**File:** All prompt files
**Action:** Modify

**Details:**
- Identify duplicate "CRITICAL" warnings
- Consolidate into single `<critical>` block per prompt
- Remove redundant emphasis

**Verification:**
- [ ] Each prompt has max 1-2 `<critical>` blocks
- [ ] No duplicate warnings within same prompt

---

#### Step 3.4: Compress Error Message Templates
**File:** All prompt files (especially 3, 7, 8)
**Action:** Modify

**Details:**
- Reduce verbose error message templates
- Use consistent error format across all prompts
- Keep essential information only

**Verification:**
- [ ] Error messages are concise
- [ ] Consistent format across prompts

---

### Phase 4: Testing & Validation

#### Step 4.1: Token Count Comparison
**File:** N/A (measurement)

**Details:**
- Count tokens in original prompts (baseline)
- Count tokens in optimized prompts
- Calculate reduction percentage
- Target: 20-25% reduction

**Verification:**
- [ ] Token count documented (before/after)
- [ ] Reduction meets target (1,000-1,500 tokens)

---

#### Step 4.2: Manual Testing - Research Phase
**File:** `prompts/1_research.md`

**Test Cases:**
- [ ] Test with English feature name
- [ ] Test with Japanese feature name
- [ ] Verify output file created in correct location
- [ ] Verify output format matches template

---

#### Step 4.3: Manual Testing - Full Workflow
**File:** All prompts

**Test Cases:**
- [ ] Execute `/research test-feature`
- [ ] Execute `/spec test-feature`
- [ ] Execute `/plan test-feature`
- [ ] Verify each phase produces correct output

---

#### Step 4.4: Format Compliance Validation
**File:** All optimized prompts

**Test Cases:**
- [ ] All prompts have `<role>` section
- [ ] All prompts have `<process>` section
- [ ] All prompts have `<output>` section
- [ ] No mixed placeholder formats
- [ ] Shared content properly referenced

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| (none) | - | No external packages required |

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `.prompts/templates/*.md` | Exists | Templates remain unchanged |
| `docs/` directory | Exists | Output directories may need creation |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [ ] Spec document reviewed and approved
- [ ] Current prompt files backed up (git tracked)
- [ ] Template files identified and unchanged

### 5.2 Post-Implementation
- [ ] All shared files created in `prompts/_shared/`
- [ ] All 8 prompts converted to XML format
- [ ] All placeholders standardized
- [ ] No linting errors in markdown
- [ ] Manual testing completed

### 5.3 Acceptance Criteria Verification

**US-001: Eliminate Duplicate Content**
- [ ] AC-001: `prompts/_shared/file-naming-rules.md` exists
- [ ] AC-002: All prompts reference shared file
- [ ] AC-003: Total line reduction ~150-200 lines

**US-002: Apply XML Structure**
- [ ] AC-001: All prompts use `<role>`, `<process>`, `<rules>`, `<output>` tags
- [ ] AC-002: Steps use `<step n="N">` format
- [ ] AC-003: Critical constraints wrapped in `<critical>` tags

**US-003: Standardize Placeholders**
- [ ] AC-001: All placeholders use `{{PLACEHOLDER}}` syntax
- [ ] AC-002: No mixed formats remain
- [ ] AC-003: Placeholder reference document created

**US-004: Add Few-Shot Examples**
- [ ] AC-001: Each prompt has at least 1 example
- [ ] AC-002: Examples cover Japanese and English inputs
- [ ] AC-003: Examples wrapped in `<example>` tags

**US-005: Convert to Affirmative Directives**
- [ ] AC-001: Negative instructions converted to affirmative
- [ ] AC-002: No standalone "DON'T", "DO NOT", "NEVER" remain
- [ ] AC-003: Critical constraints restated as required actions

**US-006: Reduce Token Usage**
- [ ] AC-001: Total token reduction 1,000-1,500 tokens
- [ ] AC-002: Redundant warnings consolidated
- [ ] AC-003: Error templates compressed

---

## 6. Rollback Plan

1. Revert to previous commit: `git checkout HEAD~1 -- prompts/`
2. Verify prompts work as before
3. Document what caused the issue for future reference

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Foundation | Low | Create 4 shared files |
| Phase 2: Core Logic | Medium | Convert 8 prompts to XML |
| Phase 3: Integration | Medium | Standardize and optimize |
| Phase 4: Testing | Low | Manual validation |

---
**Created:** 2024-12-18
**Status:** Ready
**Assignee:** (unassigned)
