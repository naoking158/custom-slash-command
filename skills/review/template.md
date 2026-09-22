# Review Report: {identifier}

## Metadata
- **Target**: {target_type} / {identifier}
- **Content-Type**: {content_type or "none"}
- **Perspectives**: {perspectives}
- **Reviewed**: {timestamp}
- **Input Files**: {input_files}

Checked: {checklists used}

## Findings

<!-- Violations only, grouped by severity. Omit any severity section with no
     findings. Do not list passed items — "Checked" above covers them. -->

### Critical
- **[C001]** {finding_description}
  - **Location**: {file:line}
  - **Impact**: {impact}
  - **Recommendation**: {recommendation}

### High
- **[H001]** {finding_description}
  - **Location**: {file:line}
  - **Impact**: {impact}
  - **Recommendation**: {recommendation}

### Medium
- **[M001]** {finding_description}
  - **Location**: {file:line}
  - **Impact**: {impact}
  - **Recommendation**: {recommendation}

### Low
- **[L001]** {finding_description}
  - **Location**: {file:line}
  - **Impact**: {impact}
  - **Recommendation**: {recommendation}

## Action Items

| Priority | Item | Location |
|----------|------|----------|
| Critical | {item} | {location} |
| High | {item} | {location} |
| Medium | {item} | {location} |
| Low | {item} | {location} |

## Overall Assessment

**{PASS|NEEDS_REVISION}**

<!-- Rule: any Critical or High finding → NEEDS_REVISION; otherwise PASS.
     Do not gate on Medium/Low counts. -->

## Next Steps

- If PASS: `/my:do {identifier}` (doc reviews) or commit / merge approval (code reviews)
- If NEEDS_REVISION: address every Critical/High finding, then `/my:review {identifier}` again
- Applying findings: commit messages and PR bodies describe the change itself. This report, its finding IDs, and `docs/reviews/` paths are local working files — never cite them.
