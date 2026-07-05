# Commit Review Checklist

Purpose: review a commit for message quality, scope discipline, code quality, and documentation follow-through.
Report violations only; severity tags are defaults, adjust with justification.

## Message Quality
- [L] タイトルが明確で簡潔 (50文字以内推奨)
- [L] タイトルが命令形で記述 (Add, Fix, Update, Remove)
- [M] 本文で「なぜ」この変更が必要かを説明
- [L] 関連 Issue/PR への参照あり (Fixes #xxx, Refs #xxx)
- [H] Breaking changes の明示 (該当する場合)

## Change Scope
- [M] 単一の論理的変更に限定
- [M] 関連しない変更の混入なし
- [L] 適切なサイズ (目安: 300行以下)
- [M] リファクタと機能追加が分離されている

## Code Quality
- [H] 新規/変更コードにテスト追加
- [H] 型エラー・lint エラーなし
- [M] console.log / debugger 残存なし
- [L] TODO コメントに Issue 参照あり
- [C] 機密情報 (API キー等) の混入なし

## Documentation
- [M] 公開 API 変更時は README/docs 更新
- [M] 破壊的変更は CHANGELOG に記載
- [L] 複雑なロジックにコメント追加
