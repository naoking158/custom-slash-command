# Change Plan: Review Multi-Perspective with Maint Default

## Overview

`/my:review` command で複数 perspective を同時適用可能にし、`security:` / `perf:` 以外では `maint:` を自動付与する。

## Changes

### 1. `prompts/8_review.md` - Perspective 説明の更新

**Location**: Lines 10-19 (Perspectives セクション)

**Current**:
```
Perspectives (prefix):
  fe:        → Frontend review
  be:        → Backend review
  security:  → Security review
  perf:      → Performance review
  doc:       → Documentation review
  maint:     → Maintainability review (naming, comments, readability, consistency)
  (none)     → Auto-select based on target content
```

**After**:
```
Perspectives (prefix):
  fe:        → Frontend review (+ maint auto-applied)
  be:        → Backend review (+ maint auto-applied)
  security:  → Security review (standalone)
  perf:      → Performance review (standalone)
  doc:       → Documentation review (+ maint auto-applied)
  maint:     → Maintainability review only
  (none)     → Auto-select based on target content (fallback: maint)

Maint Auto-Apply Rule:
  - fe, be, doc → maint checklist is automatically combined
  - security, perf → standalone (maint NOT auto-applied)
  - no match → maint only
```

### 2. `prompts/8_review.md` - Parse Input step の更新

**Location**: Lines 102-107 (Step 1)

**Current**:
```
1. Extract perspective prefix (if any): `fe|be|security|perf|doc|maint`
2. Extract target prefix (if any): `spec|plan|code|commit|pr`
3. Extract identifier
4. Resolve to input file(s) or Git/PR content
```

**After**:
```
1. Extract perspective prefix (if any): `fe|be|security|perf|doc|maint`
2. Extract target prefix (if any): `spec|plan|code|commit|pr`
3. Extract identifier
4. Resolve to input file(s) or Git/PR content
5. Determine perspective list:
   - If `security` or `perf` → [that perspective] (standalone)
   - If `fe`, `be`, or `doc` → [that perspective, maint]
   - If `maint` → [maint]
   - If auto-selected as fe/be/doc → [selected, maint]
   - If auto-selected as security/perf → [selected] (standalone)
   - If no match → [maint]
```

### 3. `prompts/8_review.md` - Load Checklist step の更新

**Location**: Lines 109-128 (Step 2)

**Current**:
```
Based on perspective and target type:

| Perspective | Checklist File |
|-------------|----------------|
| `fe:` | `.prompts/templates/checklists/review_fe_checklist.md` |
...
| (auto) | Infer from content type and file patterns |

Auto-Selection Rules:
- `.jsx`, `.tsx`, `.vue`, `.svelte`, CSS files → `fe:`
- `.py`, `.go`, `.java`, `.rs`, API routes → `be:`
- Auth, crypto, input handling code → `security:`
- Database queries, algorithms, loops → `perf:`
- Markdown, README, docstrings → `doc:`
```

**After**:
```
Load all checklists for the determined perspective list:

| Perspective | Checklist File |
|-------------|----------------|
| `fe:` | `.prompts/templates/checklists/review_fe_checklist.md` |
| `be:` | `.prompts/templates/checklists/review_be_checklist.md` |
| `security:` | `.prompts/templates/checklists/review_security_checklist.md` |
| `perf:` | `.prompts/templates/checklists/review_perf_checklist.md` |
| `doc:` | `.prompts/templates/checklists/review_doc_checklist.md` |
| `maint:` | `.prompts/templates/checklists/review_maint_checklist.md` |

Auto-Selection Rules (determines primary perspective):
- `.jsx`, `.tsx`, `.vue`, `.svelte`, CSS files → `fe:`
- `.py`, `.go`, `.java`, `.rs`, API routes → `be:`
- Auth, crypto, input handling code → `security:`
- Database queries, algorithms, loops → `perf:`
- Markdown, README, docstrings → `doc:`
- (no match / fallback) → `maint:`

Maint Auto-Apply: Unless primary is `security` or `perf`, also load `maint` checklist.
```

### 4. `prompts/8_review.md` - Output path の更新

**Location**: Lines 146, 152-163

**Current**: `{{PERSPECTIVE}}` を単一値として使用

**After**: `{{PERSPECTIVE}}` はプライマリ perspective（リストの先頭）を使用。レポートファイルは1つに統合。

出力パスの規則は変更なし（プライマリ perspective をパスに使う）。

### 5. `prompts/templates/review_template.md` - テンプレートの更新

**Location**: Line 5, Detailed Findings セクション

**Current**:
```
- **Perspective**: {perspective}
```

**After**:
```
- **Perspectives**: {perspectives} (e.g., "be, maint")
```

**Detailed Findings**: perspective ごとにセクションを分ける:
```
## Detailed Findings

### [be] Backend Review
#### ✅ Passed
...
#### ⚠️ Warnings
...

### [maint] Maintainability Review
#### ✅ Passed
...
#### ⚠️ Warnings
...
```

### 6. `prompts/_shared/processes/review.md` - 共有プロセスの更新

**Location**: Lines 1-26

Auto-Selection Rules に `(no match / fallback) → maint:` を追加し、Maint Auto-Apply ルールを追記。Step 2 の説明を「Load all checklists for the determined perspective list」に変更。

## File Summary

| File | Change |
|------|--------|
| `prompts/8_review.md` | Perspective 説明、Parse/Load/Output step 更新 |
| `prompts/_shared/processes/review.md` | Auto-Selection + maint auto-apply ルール追加 |
| `prompts/templates/review_template.md` | Perspective → Perspectives、セクション構造変更 |

## Verification

| Test | Expected |
|------|----------|
| `/my:review be:code:user-auth` | be + maint 両方のチェックリスト適用 |
| `/my:review security:code:payment` | security のみ（maint なし） |
| `/my:review perf:code:query` | perf のみ（maint なし） |
| `/my:review code:user-auth` (auto→be) | be + maint 適用 |
| `/my:review maint:code:user-auth` | maint のみ |
| `/my:review spec:something` (no match) | maint のみ（フォールバック） |
| レポート出力 | perspectives セクション別に findings 表示 |
