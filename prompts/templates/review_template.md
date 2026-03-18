# Review Report: {identifier}

## Metadata
- **Target**: {target_type} / {identifier}
- **Perspective**: {perspective}
- **Reviewed**: {timestamp}
- **Input Files**: {input_files}

## Executive Summary

| Category | Status | Issues |
|----------|--------|--------|
| {category} | ✅/⚠️/❌ | {count} |

**Overall Assessment**: {PASS|NEEDS_REVISION|FAIL}

## Detailed Findings

### {Category 1}

#### ✅ Passed
- {passed_item}

#### ⚠️ Warnings
- **[W001]** {warning_description}
  - **Location**: {file:line}
  - **Suggestion**: {suggestion}

#### ❌ Issues
- **[E001]** {issue_description}
  - **Location**: {file:line}
  - **Impact**: {impact}
  - **Recommendation**: {recommendation}

### {Category 2}
...

## Action Items

| Priority | Item | Location |
|----------|------|----------|
| 🔴 High | {item} | {location} |
| 🟡 Medium | {item} | {location} |
| 🟢 Low | {item} | {location} |

## Next Steps

{Based on assessment, suggest next command}

- If PASS: `/my:do {identifier}` or merge approval
- If NEEDS_REVISION: Address warnings, then `/my:review {identifier}` again
- If FAIL: Address issues, update artifact, then `/my:review {identifier}`
