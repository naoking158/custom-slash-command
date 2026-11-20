# Change Plan: Maintainability Checklist - Linguistic Correctness Check

## Summary
review_maint_checklist.md の Naming と Comments セクションに、言語的・論理的な正しさをチェックする項目を追加する。

## Plan Details

- **Source Document:** `docs/analysis/changes/review-maint-linguistic-check.md`
- **Type:** Change (チェックリスト拡張)
- **Complexity:** Low
- **Files to Create:** 0
- **Files to Modify:** 1 (`prompts/templates/checklists/review_maint_checklist.md`)

## Prerequisites
- なし

## Phase 1: Naming セクションへの項目追加

### Step 1.1: 語順・文法の正しさに関する項目を追加

`review_maint_checklist.md` の Naming セクション末尾（L10 の後）に以下の3項目を追加:

```markdown
- [ ] 識別子の語順が自然か (英語: 動詞+目的語+修飾語。`getUserById` ✅ / `getByIdUser` ❌)
- [ ] 時制・態が状態を正しく反映しているか (`isDeleted` ✅ / `isDelete` ❌、`wasProcessed` ✅ / `isProcess` ❌)
- [ ] 単語の組み合わせが意味的に整合しているか (具体的な目的語: `createUser` ✅ / `createData` ⚠️ 曖昧)
```

## Phase 2: Comments セクションへの項目追加

### Step 2.1: 文法・論理の正しさに関する項目を追加

`review_maint_checklist.md` の Comments セクション末尾（L18 の後）に以下の3項目を追加:

```markdown
- [ ] コメント文の文法が正しいか (日本語: てにをは・主述の対応 / 英語: 文構造の崩れがないか)
- [ ] 主語・目的語が明示されており、指示対象が曖昧でないか (`これを処理する` → 何を？)
- [ ] コメントの説明とコードの実際の動作が論理的に対応しているか (`ユーザーを削除` と書いて実際は無効化 → ❌)
```

## Verification

- [ ] チェックリストの全項目が `- [ ]` フォーマットに統一されていること
- [ ] 新規項目が既存セクション内に自然に配置されていること
- [ ] 既存項目が変更されていないこと
- [ ] Markdown のフォーマットが崩れていないこと
