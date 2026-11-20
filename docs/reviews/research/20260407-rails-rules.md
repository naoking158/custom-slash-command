# Review Report: 20260407-rails-rules

## Metadata
- **Target**: research / 20260407-rails-rules
- **Content-Type**: research (doc review applied)
- **Perspectives**: doc, maint
- **Reviewed**: 2026-04-07
- **Input Files**: docs/research/20260407-rails-rules.md

## Executive Summary

| Category | Status | Issues |
|----------|--------|--------|
| Completeness | PASS | 0 |
| Accuracy | WARNING | 2 |
| Structure | PASS | 0 |
| Currency (Rails 7/8) | WARNING | 3 |
| Actionability | WARNING | 2 |
| Maintainability | PASS | 0 |

**Overall Assessment**: NEEDS_REVISION

Research document は全体的に高品質で、Rails の主要トピックを9カテゴリに分類して網羅的にカバーしている。ただし、Rails 8 の最新機能に関する調査の深さ、一部カテゴリの具体性、Hotwire 関連の欠落について改善の余地がある。

## Detailed Findings

### [doc] Documentation / Completeness Review

#### PASS
- **[P001]** 全体構造が既存の Go/TS/React research ドキュメントと一貫したフォーマットで記述されている（Overview, Problem Statement, Requirements, Stakeholder Needs, Technical Investigation, Risk Assessment, Open Questions, Recommendations, Next Steps）
- **[P002]** 9つの rules ファイルへの分割案が明確で、各ファイルの対象パス（`paths` フロントマター）が具体的に示されている
- **[P003]** 調査ソース（Section 5.1）が権威性の高いソースを網羅しており、公式ドキュメント・コミュニティ標準・セキュリティガイドをバランスよく参照している
- **[P004]** Go / TS / React ルールとの対応表（Section 5.4）が既存アセットとの整合性を示しており、spec フェーズでの構造設計に有用
- **[P005]** Risk Assessment が6項目にわたり具体的な Mitigation を提示している
- **[P006]** ディレクトリ構造案（Section 5.3）がシンボリックリンク運用まで含めて具体的
- **[P007]** 優先順位付き実装順（Section 8）が明確で、P0/P1/P2 の根拠も記載されている
- **[P008]** Requirements が Functional / Non-Functional に分離され、チェック済みマーク付き

#### WARNING
- **[W001]** Hotwire (Turbo / Stimulus) に関する調査が不足
  - **Location**: Section 7, Q2
  - **Impact**: Medium - Rails 7+ のフロントエンド標準である Hotwire は、現代の Rails 開発において避けて通れない。Open Question として挙げられているが、research フェーズで少なくとも基礎調査を行い、スコープ内外の判断材料を提供すべき。
  - **Suggestion**: Turbo Frames / Turbo Streams / Stimulus の基本パターンと、それに伴うコーディング規約（data-controller 命名、Stimulus values/targets の規約等）を Section 5.2 に追加するか、明確にスコープ外とする根拠を記載する。

- **[W002]** ViewComponent / Phlex などのモダンな View レイヤーパターンへの言及がない
  - **Location**: Section 5.2 全体
  - **Impact**: Low - Rails 7/8 エコシステムでは ViewComponent や Phlex がコンポーネント指向の View 開発で採用が増えている。research として認知しておくべき。
  - **Suggestion**: Section 5.2.2 (Architecture) または別セクションで、View レイヤーのモダンパターンとして簡潔に言及する。

#### ISSUE
(なし)

### [accuracy] Technical Accuracy Review

#### PASS
- **[P009]** ActiveRecord の N+1 対策（includes / preload / eager_load の使い分け）は正確
- **[P010]** Security セクションの CSRF / XSS / SQL injection 対策は Rails の実装と整合
- **[P011]** Migration 規約（strong_migrations, change メソッド優先）は現在のベストプラクティスと合致
- **[P012]** Testing セクションの RSpec / Minitest 両方の規約記載は正確

#### WARNING
- **[W003]** `strict_loading` の説明が「Rails 7+」となっているが、正確には Rails 6.1 で導入
  - **Location**: Section 5.2.3, line 101
  - **Impact**: Low - 機能自体の説明は正しいが、バージョン情報が不正確。
  - **Suggestion**: 「Rails 6.1+ で導入、Rails 7+ で改善」と修正する。

- **[W004]** セッション管理で「データベースベースのセッションストアを推奨（OWASP）」とあるが、Rails 8 のデフォルトは cookie store のまま
  - **Location**: Section 5.2.6, line 161
  - **Impact**: Low - OWASP の推奨としては正しいが、Rails のデフォルト設定との乖離を明記すべき。多くの Rails アプリケーションでは cookie store で十分なケースも多い。
  - **Suggestion**: OWASP 推奨と Rails デフォルトの両方を記載し、ユースケースに応じた選択ガイドラインを追加する。

### [currency] Rails 7/8 Currency Review

#### PASS
- **[P013]** Rails 8 の Solid Queue / Solid Cache / Solid Cable への言及がある
- **[P014]** Rails 8 認証ジェネレータへの言及がある
- **[P015]** Ruby 3.2+ の pattern matching / Data class への言及がある

#### WARNING
- **[W005]** Rails 8 の Solid Queue / Solid Cache の具体的なベストプラクティスが薄い
  - **Location**: Section 5.2.7, line 173-176
  - **Impact**: Medium - Solid Cache は「Redis 不要のデータベースベースキャッシュ」という一行のみ。Solid Queue も Background Jobs セクションで Sidekiq と並列に言及されるだけ。Rails 8 を前提とするなら、これらのデフォルトスタックに関するより具体的な規約（設定パターン、キュー設計、Cache 戦略）を調査すべき。
  - **Suggestion**: Solid Queue のキュー命名規約、優先度設計、Solid Cache の TTL 戦略等を追加調査する。

- **[W006]** Kamal (デプロイ) / Thruster (Web サーバー) への言及がない
  - **Location**: Section 5.2 全体
  - **Impact**: Low - Rails 8 のデフォルトデプロイツールである Kamal 2 と、Thruster (HTTP/2, 自動 SSL) はインフラ寄りだが、Dockerfile のベストプラクティスやデプロイ設定の規約として関連する可能性がある。
  - **Suggestion**: スコープ外とする場合でも、Section 7 (Open Questions) に追加して判断を明示する。

- **[W007]** Rails 8 の `params.expect` (Strong Parameters の新 API) への言及がない
  - **Location**: Section 5.2.2, 5.2.6
  - **Impact**: Medium - Rails 8 で導入された `params.expect` は `params.require.permit` のより安全な代替。セキュリティとアーキテクチャの両方に関わる重要な変更。
  - **Suggestion**: Section 5.2.2 (Architecture) の Strong Parameters 規約に `params.expect` を追加する。

### [actionability] Actionability Review

#### PASS
- **[P016]** 各カテゴリの「主要ルール」が箇条書きで列挙されており、DO/DON'T 形式の rules に変換しやすい構造
- **[P017]** ディレクトリ構造案と paths スコープが具体的で、実装に直結する
- **[P018]** 優先順位（P0/P1/P2）が明確で、段階的な実装計画を立てやすい

#### WARNING
- **[W008]** 各カテゴリの「主要ルール」にコード例が含まれていない
  - **Location**: Section 5.2 全体
  - **Impact**: Medium - 「DO / DON'T パターンで具体的かつアクション可能な記述」（NFR-002）を requirements として掲げているが、research 段階でコード例が一切ない。spec フェーズでのルール策定時に、各ルールの具体的な良い例・悪い例を一から調査する必要が生じる。
  - **Suggestion**: 特に P0 カテゴリ（Security, ActiveRecord, Architecture）の主要ルールについて、最低限の DO/DON'T コード例を research に含める。例: N+1 の良い例/悪い例、Strong Parameters の正しい書き方等。

- **[W009]** Open Questions (Section 7) の Q1-Q6 が全て未解決のまま
  - **Location**: Section 7
  - **Impact**: Medium - research フェーズの目的は spec フェーズへのインプット提供。6つの Open Questions のうち、少なくとも recommendation 付きで解決可能なものがある（例: Q1 は「Rails 8 デフォルトの Minitest を基本とし、RSpec は別途オプション」、Q6 は「Rails 8 認証ジェネレータを推奨し、Devise は既存プロジェクト向け」等）。
  - **Suggestion**: 各 Open Question に対して、調査結果に基づく推奨案を追記する。完全な決定でなくとも、spec フェーズでの議論の出発点を提供する。

### [maint] Maintainability Review

#### PASS
- **[P019]** セクション構成が既存 research ドキュメント（Go, TS/React）と一貫している
- **[P020]** 日本語/英語の使い分けが適切（技術用語は英語、説明は日本語）
- **[P021]** ソース一覧が末尾にリンク付きで整理されている
- **[P022]** Status: Draft が明記されており、ドキュメントのライフサイクルが明確
- **[P023]** 命名規則が一貫している（セクション番号、ファイル名の `rails-` prefix）

## Action Items

| Priority | Item | Location |
|----------|------|----------|
| Medium | Rails 8 `params.expect` の調査と追記 | Section 5.2.2, 5.2.6 |
| Medium | Solid Queue / Solid Cache の具体的なベストプラクティス追加 | Section 5.2.7 |
| Medium | P0 カテゴリの主要ルールにコード例（DO/DON'T）を追加 | Section 5.2 全体 |
| Medium | Open Questions に推奨案を追記 | Section 7 |
| Low | Hotwire (Turbo / Stimulus) の基礎調査追加またはスコープ判断の明示 | Section 5.2 or Section 7 |
| Low | `strict_loading` のバージョン情報修正 | Section 5.2.3 |
| Low | セッション管理の OWASP 推奨 vs Rails デフォルトの整理 | Section 5.2.6 |
| Low | ViewComponent / Phlex への言及追加 | Section 5.2.2 |
| Low | Kamal / Thruster のスコープ判断追加 | Section 7 |

## Metrics

- **Passed**: 23 items
- **Warnings**: 9 items
- **Issues**: 0 items

## Next Steps

NEEDS_REVISION 判定。Medium priority の4項目を対処した後、spec フェーズに進むことを推奨。

1. 上記 Action Items の Medium 項目を対処し、research ドキュメントを更新
2. `/my:review research:20260407-rails-rules` で再レビュー
3. PASS 後、`/my:spec 20260407-rails-rules` で spec フェーズへ
