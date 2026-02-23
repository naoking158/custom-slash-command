# Process: Review

## Step 1: Parse Input
1. Extract perspective prefix (if any): `fe|be|security|perf|doc`
2. Extract target prefix (if any): `spec|plan|code|commit|pr`
3. Extract identifier
4. Resolve to input file(s) or Git/PR content

## Step 2: Load Checklist
Based on perspective and target type, load appropriate checklist:

| Perspective | Focus Area |
|-------------|------------|
| `fe:` | Frontend (UI, UX, accessibility) |
| `be:` | Backend (API, data, logic) |
| `security:` | Security (auth, validation, vulnerabilities) |
| `perf:` | Performance (queries, algorithms, caching) |
| `doc:` | Documentation (clarity, completeness) |

Auto-Selection Rules:
- `.jsx`, `.tsx`, `.vue`, `.svelte`, CSS files → `fe:`
- `.py`, `.go`, `.java`, `.rs`, API routes → `be:`
- Auth, crypto, input handling code → `security:`
- Database queries, algorithms, loops → `perf:`
- Markdown, README, docstrings → `doc:`

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
