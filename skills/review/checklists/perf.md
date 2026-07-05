# Performance Review Checklist

Purpose: review code for algorithmic, database, caching, network, memory, and concurrency performance issues.
Report violations only; severity tags are defaults, adjust with justification.

## Algorithm & Complexity
- [M] 時間計算量の妥当性
- [M] 空間計算量の妥当性
- [M] 不要なループのネスト回避

## Database
- [M] クエリ最適化
- [M] インデックス活用
- [M] N+1 問題回避
- [M] 適切なページネーション

## Caching
- [M] キャッシュ戦略の妥当性
- [H] キャッシュ無効化ロジック
- [L] キャッシュヒット率考慮

## Network
- [M] 不要なAPI呼び出し削減
- [M] バッチ処理の活用
- [L] 適切なペイロードサイズ

## Memory
- [H] メモリリーク防止
- [M] 大規模データのストリーム処理
- [L] オブジェクト生成の最適化

## Concurrency
- [M] 並列処理の適切な活用
- [H] デッドロック回避
- [H] スレッドセーフティ
