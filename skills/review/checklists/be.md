# Backend Review Checklist

Purpose: review backend code for API design, error handling, data integrity, scalability, maintainability, and testability.
Report violations only; severity tags are defaults, adjust with justification.

## API Design
- [M][web] RESTful 原則準拠 (または GraphQL ベストプラクティス)
- [H][web] 適切なHTTPステータスコード
- [M][web] 一貫したレスポンス形式 (エラーレスポンス形式含む)
- [M][web] バージョニング戦略
- [L][web] 適切なエンドポイント命名

## Error Handling
- [M] 適切なエラーログ出力
- [C] 機密情報の非露出
- [M] リトライ可能なエラーの明示

## Data Integrity
- [H] 入力バリデーション
- [H] トランザクション管理
- [M] 楽観的/悲観的ロック考慮
- [H] データ整合性制約

## Scalability
- [M] N+1 クエリ問題回避
- [M] 適切なインデックス設計
- [M] キャッシュ戦略
- [M] 非同期処理の適切な使用

## Maintainability
- [M] 適切なレイヤー分離
- [L] 依存性注入
- [M] 設定の外部化
- [L] ログの適切な粒度

## Testing Considerations
- [M] ユニットテスト可能な構造
- [M] モック可能な外部依存
- [L] テストデータ戦略
