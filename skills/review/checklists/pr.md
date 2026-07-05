# Pull Request Review Checklist

Purpose: review a pull request for description quality, change scope, code quality, test coverage, and merge readiness.
Report violations only; severity tags are defaults, adjust with justification.

## PR Description
- [M] 変更の目的が明確に記載
- [L] 実装アプローチの説明あり
- [M] テスト方法・確認手順の記載
- [L] スクリーンショット/動画 (UI変更時)
- [L] 関連 Issue へのリンク

## Change Analysis
- [M] 変更範囲が PR タイトルと一致
- [M] 不要なファイル変更なし
- [M] 依存関係の追加は妥当
- [H] マイグレーション手順の明記 (該当時)

## Code Review
- [M] 既存パターン・規約に準拠
- [H] エラーハンドリングが適切
- [H] エッジケースの考慮
- [M] パフォーマンスへの影響考慮
- [C] セキュリティ上の懸念なし

## Testing
- [H] 新規テストの追加
- [M] 既存テストの更新 (該当時)
- [H] CI パイプライン通過
- [M] 手動テスト完了

## Merge Readiness
- [H] コンフリクト解消済み
- [H] 必要なレビュー承認取得
- [M] ドキュメント更新完了
- [L] リリースノート準備 (該当時)
