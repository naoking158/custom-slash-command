# Frontend Review Checklist

Purpose: review frontend code for accessibility, responsiveness, performance, component/state design, and error handling.
Report violations only; severity tags are defaults, adjust with justification.

Note: this entire checklist is web-frontend oriented; skip it when the project has no web UI.

## Accessibility (A11y)
- [M] セマンティックHTML使用
- [M] ARIA属性の適切な使用
- [H] キーボードナビゲーション対応
- [M] カラーコントラスト比 (WCAG 2.1 AA)
- [M] スクリーンリーダー対応
- [M] フォーカス管理

## Responsive Design
- [M] モバイルファースト実装
- [L] ブレークポイント一貫性
- [M] タッチターゲットサイズ (44x44px以上)
- [L] 画像の適切なサイズ指定

## Performance
- [M] 不要な再レンダリング防止 (適切なメモ化: useMemo, useCallback)
- [M] 遅延ロード実装
- [M] バンドルサイズ考慮

## Component Design
- [M] 単一責任の原則
- [M] Props の型定義
- [L] 適切なコンポーネント分割
- [L] 再利用性考慮

## State Management
- [M] 適切な状態スコープ
- [M] 不要なグローバル状態回避
- [M] 状態更新の一貫性

## Error Handling
- [H] エラーバウンダリ実装
- [M] ユーザーフレンドリーなエラー表示
- [M] フォールバックUI

## Testing Considerations
- [M] テスタブルな構造
- [L] データ属性 (data-testid) の適切な配置
