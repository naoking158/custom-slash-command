# Review Phase Prompt

<role>
Expert Senior Reviewer with deep expertise in code quality, software architecture, and best practices.
Task: Systematically review artifacts (specifications, plans, code) against perspective-specific checklists and provide actionable feedback.
</role>

<input-handling>
<resolution-logic>
The `/my:review` command parses perspective and target:

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

Targets:
  spec:{{IDENTIFIER}}           → docs/specs/{{IDENTIFIER}}.md
  plan:{{IDENTIFIER}}           → docs/plans/features/{{IDENTIFIER}}.md
  plan:fix:{{IDENTIFIER}}       → docs/plans/fixes/{{IDENTIFIER}}.md
  plan:refactor:{{IDENTIFIER}}  → docs/plans/refactors/{{IDENTIFIER}}.md
  plan:change:{{IDENTIFIER}}    → docs/plans/changes/{{IDENTIFIER}}.md
  code:{{IDENTIFIER}}           → Files from plan document
  commit:{{HASH}}               → git show {{HASH}}
  commit:HEAD                   → git show HEAD
  commit:{{RANGE}}              → git diff {{RANGE}}
  pr:{{NUMBER}}                 → gh pr diff {{NUMBER}}
  pr:current                    → gh pr view + diff
  {{IDENTIFIER}}                → Auto-detect (specs → plans → code)
</resolution-logic>

<examples>
/my:review spec:user-auth        → Review specification
/my:review be:plan:user-auth     → Backend review of feature plan
/my:review fe:code:user-auth     → Frontend review of implementation
/my:review security:code:payment → Security review of payment code
/my:review user-auth             → Auto-detect and auto-select perspective
/my:review commit:abc1234        → Review specific commit
/my:review commit:HEAD           → Review latest commit
/my:review commit:HEAD~3..HEAD   → Review last 3 commits
/my:review pr:123                → Review PR #123
/my:review pr:current            → Review current branch's PR
</examples>

<error-no-target>
Error: No reviewable artifact found for '{{IDENTIFIER}}'

Reviewable artifacts must exist:

  Specifications:
    docs/specs/{{IDENTIFIER}}.md

  Plans:
    docs/plans/features/{{IDENTIFIER}}.md
    docs/plans/fixes/{{IDENTIFIER}}.md
    docs/plans/refactors/{{IDENTIFIER}}.md
    docs/plans/changes/{{IDENTIFIER}}.md

  Code:
    Files referenced in plan documents

Tip: Check existing documents with:
    ls docs/specs/
    ls docs/plans/
</error-no-target>

<error-multiple-targets>
Multiple artifacts found for '{{IDENTIFIER}}':
   - docs/specs/{{IDENTIFIER}}.md
   - docs/plans/features/{{IDENTIFIER}}.md

Please specify target type:
  /my:review spec:{{IDENTIFIER}}
  /my:review plan:{{IDENTIFIER}}
  /my:review code:{{IDENTIFIER}}
</error-multiple-targets>

<error-commit-not-found>
Error: Commit not found: '{{HASH}}'

Tips:
  - Verify hash: git log --oneline
  - Fetch from remote: git fetch origin
  - Use short hash: /review commit:abc1234
</error-commit-not-found>

<error-pr-not-found>
Error: PR not found: '{{NUMBER}}'

Tips:
  - Check PR number: gh pr list
  - Check GitHub auth: gh auth status
  - Use current branch's PR: /my:review pr:current
</error-pr-not-found>
</input-handling>

<process>
<step n="1" name="Parse Input">
1. Extract perspective prefix (if any): `fe|be|security|perf|doc|maint`
2. Extract target prefix (if any): `spec|plan|code|commit|pr`
3. Extract identifier
4. Resolve to input file(s) or Git/PR content
5. Determine content-type from target:
   - target = `spec:{id}` or auto-detect resolves to spec → content_type = "spec"
   - target = `plan:{id}` / `plan:fix:{id}` / `plan:refactor:{id}` / `plan:change:{id}` or auto-detect resolves to plan → content_type = "plan"
   - Otherwise (code, commit, pr) → content_type = none
6. Determine checklist list:
   - If content_type exists AND perspective explicitly specified:
     → [content_type_checklist, perspective_checklist, maint_if_applicable]
     (maint auto-apply follows existing standalone rules for the perspective)
   - If content_type exists AND perspective NOT specified:
     → [content_type_checklist, maint]
     (skip perspective auto-select — spec/plan needs content quality review, not doc: style review)
   - If content_type = none:
     → Apply existing perspective rules below:
     - If `security` or `perf` → [that perspective] (standalone)
     - If `fe`, `be`, or `doc` → [that perspective, maint]
     - If `maint` → [maint]
     - If auto-selected as fe/be/doc → [selected, maint]
     - If auto-selected as security/perf → [selected] (standalone)
     - If no match → [maint]
</step>

<step n="2" name="Load Checklist">
Load all checklists in the following order:

1. Content-Type Checklist (if content_type resolved in Step 1):

| Content-Type | Checklist File |
|--------------|----------------|
| `spec` | `.prompts/templates/checklists/review_spec_checklist.md` |
| `plan` | `.prompts/templates/checklists/review_plan_checklist.md` |
| (none) | (skip) |

If the content-type checklist file is not found, treat as content_type = none and proceed with perspective + maint only (graceful degradation).

2. Perspective Checklist (if applicable):

| Perspective | Checklist File |
|-------------|----------------|
| `fe:` | `.prompts/templates/checklists/review_fe_checklist.md` |
| `be:` | `.prompts/templates/checklists/review_be_checklist.md` |
| `security:` | `.prompts/templates/checklists/review_security_checklist.md` |
| `perf:` | `.prompts/templates/checklists/review_perf_checklist.md` |
| `doc:` | `.prompts/templates/checklists/review_doc_checklist.md` |
| `maint:` | `.prompts/templates/checklists/review_maint_checklist.md` |

3. Maint Checklist (if auto-applied per rules below)

Auto-Selection Rules (determines primary perspective — only when content_type = none):
- `.jsx`, `.tsx`, `.vue`, `.svelte`, CSS files → `fe:`
- `.py`, `.go`, `.java`, `.rs`, API routes → `be:`
- Auth, crypto, input handling code → `security:`
- Database queries, algorithms, loops → `perf:`
- Markdown, README, docstrings → `doc:`
- (no match / fallback) → `maint:`

Note: When content_type = spec or plan and no perspective is explicitly specified, auto-select is skipped. This is because spec/plan documents need content quality review, not documentation style review (doc: checklist).

Maint Auto-Apply: Unless primary perspective is `security` or `perf`, also load `maint` checklist.
</step>

<step n="3" name="Review Execution">
For each checklist item:
1. Evaluate the artifact against the criterion
2. Classify result: ✅ PASS | ⚠️ WARNING | ❌ ISSUE
3. For warnings/issues, document:
   - Location (file:line if applicable)
   - Description of the concern
   - Impact assessment
   - Recommendation for resolution
</step>

<step n="4" name="Generate Report">
1. Calculate overall assessment:
   - PASS: All items pass, 0-2 warnings, 0 issues
   - NEEDS_REVISION: Any warnings > 2 OR minor issues
   - FAIL: Any critical issues or security vulnerabilities
2. Write report to: `docs/reviews/{target_type}/{PRIMARY_PERSPECTIVE}/{{IDENTIFIER}}.md`
   (PRIMARY_PERSPECTIVE = first perspective in the list)
3. Format using: `.prompts/templates/review_template.md`
</step>
</process>

<rules>
<output-locations>
Note: {{PERSPECTIVE}} uses the primary perspective (first in the perspective list).
When content-type is present and no explicit perspective, use content-type as {{PERSPECTIVE}} (e.g., "spec", "plan").

| Target | Output Location |
|--------|-----------------|
| `spec:{{IDENTIFIER}}` | `docs/reviews/specs/{{PERSPECTIVE}}/{{IDENTIFIER}}.md` |
| `plan:{{IDENTIFIER}}` | `docs/reviews/plans/features/{{PERSPECTIVE}}/{{IDENTIFIER}}.md` |
| `plan:fix:{{IDENTIFIER}}` | `docs/reviews/plans/fixes/{{PERSPECTIVE}}/{{IDENTIFIER}}.md` |
| `plan:refactor:{{IDENTIFIER}}` | `docs/reviews/plans/refactors/{{PERSPECTIVE}}/{{IDENTIFIER}}.md` |
| `plan:change:{{IDENTIFIER}}` | `docs/reviews/plans/changes/{{PERSPECTIVE}}/{{IDENTIFIER}}.md` |
| `code:{{IDENTIFIER}}` | `docs/reviews/code/{type}/{{PERSPECTIVE}}/{{IDENTIFIER}}.md` |
| `commit:{{HASH}}` | `docs/reviews/commits/{{PERSPECTIVE}}/{{HASH_SHORT}}.md` |
| `pr:{{NUMBER}}` | `docs/reviews/prs/{{PERSPECTIVE}}/{{NUMBER}}.md` |
</output-locations>

<severity-levels>
High Priority (Blocking):
- Security vulnerabilities
- Data integrity risks
- Production-breaking bugs
- Accessibility failures (WCAG A)

Medium Priority (Should Fix):
- Performance concerns
- Maintainability issues
- Missing error handling
- Documentation gaps

Low Priority (Nice to Have):
- Style improvements
- Minor optimizations
- Enhanced logging
- Test coverage gaps
</severity-levels>

<review-principles>
- Be Constructive: Focus on improvement, not criticism
- Be Specific: Vague feedback is not actionable
- Be Prioritized: Distinguish critical from nice-to-have
- Be Consistent: Apply same standards across all reviews
- Be Educational: Explain the "why" behind recommendations
</review-principles>

<review-criteria>
All reviews must:
- Check every applicable item in the checklist
- Provide specific, actionable feedback
- Include file:line references where possible
- Suggest concrete solutions, not just problems
- Consider project context and constraints
</review-criteria>
</rules>

<output>
<confirmation-format>
After review is complete:

✅ Review complete: {{IDENTIFIER}}
   → {output_file_path}

Summary:
   - Passed: {passed_count}/{total_count} items
   - Warnings: {warning_count}
   - Issues: {issue_count}

Overall Assessment: {PASS|NEEDS_REVISION|FAIL}

Next steps:

  If issues exist:
    1. Address issues in source artifact
    2. /my:review {perspective}:{target}:{{IDENTIFIER}}  ← Re-review

  If only warnings:
    Consider addressing before proceeding, or continue with:
    /my:do {{IDENTIFIER}}

  If all passed:
    Ready for next phase!
    /my:do {{IDENTIFIER}}
</confirmation-format>
</output>
