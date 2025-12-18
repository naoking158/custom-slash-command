# Frontend Review Checklist

## Accessibility (A11y)
- [ ] セマンティックHTML使用
- [ ] ARIA属性の適切な使用
- [ ] キーボードナビゲーション対応
- [ ] カラーコントラスト比 (WCAG 2.1 AA)
- [ ] スクリーンリーダー対応
- [ ] フォーカス管理

## Responsive Design
- [ ] モバイルファースト実装
- [ ] ブレークポイント一貫性
- [ ] タッチターゲットサイズ (44x44px以上)
- [ ] 画像の適切なサイズ指定

## Performance
- [ ] 不要な再レンダリング防止
- [ ] 適切なメモ化 (useMemo, useCallback)
- [ ] 遅延ロード実装
- [ ] バンドルサイズ考慮

## Component Design
- [ ] 単一責任の原則
- [ ] Props の型定義
- [ ] 適切なコンポーネント分割
- [ ] 再利用性考慮

## State Management
- [ ] 適切な状態スコープ
- [ ] 不要なグローバル状態回避
- [ ] 状態更新の一貫性

## Error Handling
- [ ] エラーバウンダリ実装
- [ ] ユーザーフレンドリーなエラー表示
- [ ] フォールバックUI

## Testing Considerations
- [ ] テスタブルな構造
- [ ] データ属性 (data-testid) の適切な配置
