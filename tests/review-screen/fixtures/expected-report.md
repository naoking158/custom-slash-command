# Review Report: sample-review

## Metadata
- **Target**: code / sample-review
- **Content-Type**: diff
- **Perspectives**: be, maint
- **Reviewed**: 2026-07-25T10:00:00+09:00
- **Input Files**: git -c core.quotepath=false diff, docs/plans/features/sample.md

Checked: be.md, maint.md

## Findings

### High
- **[H001]** token を渡さない既存呼び出しが壊れる
  - **Location**: src/auth.ts（新L3〜） [h001]
  - **Impact**: login() の必須引数が増えたが、差分には呼び出し側の更新が含まれていないため、既存の呼び出しはすべて型エラーになる。
  - **Recommendation**: token を optional にして段階移行するか、同じ変更で全呼び出し箇所を更新する。
  - **Note**: plan 上は意図的な変更だが、実装として改善を求める
  - **Source**: Pass 1

### Medium
- **[M001]** LEGACY フラグ反転の影響範囲が追えない
  - **Location**: src/auth.ts（新L24〜） [h002]
  - **Impact**: LEGACY を false に変えた影響が差分だけでは判断できず、参照側の挙動が変わる可能性がある。
  - **Recommendation**: LEGACY を参照している箇所を洗い出し、切り替えの意図をコメントで残す。
  - **Source**: Pass 2

## Action Items

| Priority | Item | Location |
|----------|------|----------|
| High | token を渡さない既存呼び出しが壊れる | src/auth.ts（新L3〜） |
| Medium | LEGACY フラグ反転の影響範囲が追えない | src/auth.ts（新L24〜） |

## Overall Assessment

**NEEDS_REVISION**

## Next Steps

- If PASS: implement from the document (doc reviews) or commit and open a draft PR (code reviews)
- If NEEDS_REVISION: address every Critical/High finding, then `/my:review sample-review` again
