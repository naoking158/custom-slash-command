# Review Report: {identifier}

## Metadata
- **Target**: {target_type} / {identifier}
- **Content-Type**: {content_type or "none"}
- **Perspectives**: {perspectives}
- **Reviewed**: {timestamp}
- **Input Files**: {input_files}

## Executive Summary

| Category | Status | Issues |
|----------|--------|--------|
| {content_type_category (if any)} | ✅/⚠️/❌ | {count} |
| {category} | ✅/⚠️/❌ | {count} |

**Overall Assessment**: {PASS|NEEDS_REVISION|FAIL}

## Detailed Findings

<!-- Content-type section: only include when content_type = spec or plan -->
### [content-type] {Spec|Plan} Content Review

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

<!-- Perspective section: only include when a perspective checklist is applied -->
### [{primary_perspective}] {Primary Perspective Name} Review

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

### [maint] Maintainability Review

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
