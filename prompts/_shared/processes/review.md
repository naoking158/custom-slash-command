# Process: Review

## Step 1: Parse Input
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

## Step 2: Load Checklist
Load all checklists for the determined perspective list:

| Perspective | Focus Area |
|-------------|------------|
| `fe:` | Frontend (UI, UX, accessibility) |
| `be:` | Backend (API, data, logic) |
| `security:` | Security (auth, validation, vulnerabilities) |
| `perf:` | Performance (queries, algorithms, caching) |
| `doc:` | Documentation (clarity, completeness) |
| `maint:` | Maintainability (naming, comments, readability, consistency) |

Auto-Selection Rules (determines primary perspective):
- `.jsx`, `.tsx`, `.vue`, `.svelte`, CSS files → `fe:`
- `.py`, `.go`, `.java`, `.rs`, API routes → `be:`
- Auth, crypto, input handling code → `security:`
- Database queries, algorithms, loops → `perf:`
- Markdown, README, docstrings → `doc:`
- (no match / fallback) → `maint:`

Maint Auto-Apply: Unless primary is `security` or `perf`, also load `maint` checklist.

## Step 3: Review Execution
For each checklist item:
1. Evaluate the artifact against the criterion
2. Classify result: ✅ PASS | ⚠️ WARNING | ❌ ISSUE
3. For warnings/issues, document:
   - Location (file:line if applicable)
   - Description of the concern
   - Impact assessment
   - Recommendation for resolution

## Step 4: Generate Report
1. Calculate overall assessment:
   - PASS: All items pass, 0-2 warnings, 0 issues
   - NEEDS_REVISION: Any warnings > 2 OR minor issues
   - FAIL: Any critical issues or security vulnerabilities
2. Write structured report
3. Provide actionable next steps
