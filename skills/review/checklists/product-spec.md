# Product Spec Review Checklist

Purpose: review a functional spec for PRD coverage, behavioral completeness, testable acceptance criteria, and edge-case discipline.
Report violations only; severity tags are defaults, adjust with justification.

## Coverage
- [C] PRD の Must 要求の全カバー(カバレッジ表の整合)
- [H] Should 要求のカバー、または除外理由の明記

## Behavior
- [H] メインフローと代替フローの記述
- [H] FR ごとのトリガー・入力・挙動・出力・状態変化
- [M] 権限・ロール別の可否の定義

## Edge Cases
- [H] エッジケース全カテゴリの検討(N/A には理由)
- [M] エラー時のユーザー向け挙動の定義

## Acceptance Criteria
- [C] 全 FR への Given/When/Then
- [H] 検証可能性(形容詞のみの基準の排除)

## Measurement
- [M] 成功指標を計算できるイベント定義(指標との対応)

## Consistency
- [M] 前提(Assumptions)と未決事項の分離
- [M] 未決事項の担当者・期限
- [L] 用語の一貫性
