# Placeholder Reference

<placeholders>
All placeholders use `{{PLACEHOLDER}}` syntax (double braces, uppercase).

| Placeholder | Description | Example |
|-------------|-------------|---------|
| `{{FEATURE_NAME}}` | Feature identifier (kebab-case) | `user-auth` |
| `{{DATE}}` | Current date (YYYYMMDD) | `20241218` |
| `{{INPUT}}` | Raw user input | `ユーザー認証` |
| `{{IDENTIFIER}}` | Normalized identifier | `user-auth` |
| `{{SOURCE_PATH}}` | Source document path | `docs/specs/user-auth.md` |
| `{{OUTPUT_PATH}}` | Output file path | `docs/plans/features/user-auth.md` |

<usage-rules>
- Always use double braces: `{{NAME}}` (not `{name}` or `$NAME`)
- Always use uppercase: `{{IDENTIFIER}}` (not `{{identifier}}`)
- Use underscores for multi-word names: `{{FEATURE_NAME}}` (not `{{FEATURENAME}}`)
</usage-rules>
</placeholders>
