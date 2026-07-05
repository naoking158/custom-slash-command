# Implementation Plan: {feature_name}

## 1. Overview

### 1.1 Input Source
- **Source Type:** Feature | Fix | Refactor | Change
- **Source Document:** `docs/specs/{id}.md` | `docs/analysis/{type}/{id}.md`

### 1.2 References
<!-- Related docs: research, spec, analysis — as applicable -->

### 1.3 Implementation Strategy
<!-- High-level approach; include assumptions made where the source was ambiguous -->

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose |
|-----------|---------|
|           |         |

### 2.2 Files to Modify

| File Path | Changes Required |
|-----------|------------------|
|           |                  |

### 2.3 Files to Delete
<!-- N/A: <reason> if none -->

---

## 3. Implementation Steps
<!-- Phase count matches the Size: S usually one phase, M fewer than four,
     L may use the full Foundation / Core / Integration / Testing split.
     Every step's Verification is an executable command, not a checklist item. -->

### Phase 1: {phase_name}

#### Step 1.1: {step_title}
**File:** `path/to/file`
**Action:** Create | Modify | Delete

**Details:**
- Task 1
- Task 2

**Verification:**
```bash
npm test -- path/to.test.ts   # replace with this project's real command
```

#### Step 1.2: {step_title}
**File:** `path/to/file`
**Action:** Create | Modify | Delete

**Details:**
- Task 1

**Verification:**
```bash
{executable command that proves this step is done}
```

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies
<!-- New packages/libraries. N/A: <reason> if none. -->

| Package | Version | Purpose |
|---------|---------|---------|
|         |         |         |

### 4.2 Internal Dependencies
<!-- Other features/modules this depends on. N/A: <reason> if none. -->

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [ ] Source document reviewed
- [ ] Dependencies identified and available

### 5.2 Post-Implementation
- [ ] Full test suite passing (command: `{test command}`)
- [ ] Lint / type-check clean (command: `{lint command}`)
- [ ] Changed behavior exercised end-to-end

### 5.3 Acceptance Criteria Verification
<!-- Map every AC from the source document to the step(s) that satisfy it -->
- [ ] AC-001: → Step {n}
- [ ] AC-002: → Step {n}

---

## 6. Rollback Plan (optional)
<!-- How to revert if something goes wrong. S/M may use `N/A: <reason>`. -->

---

## 7. Estimated Effort (optional)
<!-- Per-phase complexity. S/M may use `N/A: <reason>`. -->

| Phase | Complexity | Notes |
|-------|------------|-------|
|       |            |       |

---
**Size:** S | M | L
**Created:** {date}
**Status:** Draft | Ready | In Progress | Completed
