# Commit Review Checklist

## Message Quality
- [ ] タイトルが明確で簡潔 (50文字以内推奨)
- [ ] タイトルが命令形で記述 (Add, Fix, Update, Remove)
- [ ] 本文で「なぜ」この変更が必要かを説明
- [ ] 関連 Issue/PR への参照あり (Fixes #xxx, Refs #xxx)
- [ ] Breaking changes の明示 (該当する場合)

## Change Scope
- [ ] 単一の論理的変更に限定
- [ ] 関連しない変更の混入なし
- [ ] 適切なサイズ (目安: 300行以下)
- [ ] リファクタと機能追加が分離されている

## Code Quality
- [ ] 新規/変更コードにテスト追加
- [ ] 型エラー・lint エラーなし
- [ ] console.log / debugger 残存なし
- [ ] TODO コメントに Issue 参照あり
- [ ] 機密情報 (API キー等) の混入なし

## Documentation
- [ ] 公開 API 変更時は README/docs 更新
- [ ] 破壊的変更は CHANGELOG に記載
- [ ] 複雑なロジックにコメント追加
