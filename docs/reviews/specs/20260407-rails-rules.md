# Review Report: 20260407-rails-rules

## Metadata
- **Target**: spec / 20260407-rails-rules
- **Content-Type**: spec
- **Perspectives**: spec, maint
- **Reviewed**: 2026-04-07
- **Input Files**: `docs/specs/20260407-rails-rules.md`, `docs/research/20260407-rails-rules.md`

## Executive Summary

| Category | Status | Issues |
|----------|--------|--------|
| Spec Content Review | ⚠️ | 3 warnings, 1 issue |
| Maintainability Review | ⚠️ | 2 warnings |

**Overall Assessment**: NEEDS_REVISION

---

## Detailed Findings

### [spec] Spec Content Review

#### Passed

- **Completeness - Required Sections**: Overview, User Stories, Interface (Section 3), Data Models (Section 4), Edge Cases (Section 7) が全て存在する
- **User Stories - Acceptance Criteria**: US-001 ~ US-005 の全てに具体的な Acceptance Criteria が定義されている
- **Scope Definition**: In Scope / Out of Scope テーブルが明確に定義されている。Hotwire、RuboCop 設定、Slim/Haml を明示的にスコープ外としている
- **Terminology Consistency**: spec 全体を通じて用語（paths, frontmatter, rules, DO/DON'T）が一貫して使用されている
- **No Contradictions**: 要件間に矛盾はない。Rails 8 を前提としつつ代替（Devise, Sidekiq）も併記する方針が一貫している
- **Research Consistency**: Research Document のカテゴリ構成（9 ファイル）、優先度、主要ルールが正しく反映されている
- **Technical Feasibility**: 全要件が技術的に実現可能。Claude Code の rules 仕様に沿った paths / frontmatter 設計
- **Data Models Consistency**: RulesFile, RulesDirectory, SymlinkDeployment の各エンティティが Interface 定義と整合している
- **Traceability**: Research Document、Go Rules、TS/React Rules への参照が 1.3 References で明記されている
- **Existing Spec Consistency**: Go spec（8 ファイル構成、同一 frontmatter / DO-DON'T フォーマット、同一 Data Model 構造、同一 Sequence Diagram パターン）と構造的に一致している
- **Code Examples Correctness**: Section 6 のコード例（SQL injection prevention, N+1, params.expect, Solid Cache TTL）は全て構文的・意味的に正しい Ruby / Rails コード
- **Verifiability - AC Format**: Acceptance Criteria が全て二値判定可能な形式で記載されている

#### Warnings

- **[W001]** `secure_headers` gem が Research Document (line 188) で言及されているが、Spec の rails-security.md Key Topics に含まれていない
  - **Location**: `docs/specs/20260407-rails-rules.md` Section 6.1 (line 297-325)
  - **Impact**: Low - `secure_headers` はセキュリティヘッダの一括管理に有用だが、Rails 7.1+ ではデフォルトでいくつかのセキュリティヘッダが設定されるため、必須ではない
  - **Suggestion**: Key Topics に `secure_headers` を追加するか、Out of Scope として明示的に除外理由を記載する

- **[W002]** `Gemfile` / `Rakefile` が rules ロード対象外である点が Edge Cases (Section 7) で記載されているが、Open Items Q3 でも同様の懸念が挙がっている。`Gemfile` は Ruby ファイルとして重要だが、対応方針が未確定
  - **Location**: `docs/specs/20260407-rails-rules.md` Section 7 (line 524) / Section 12 Q3 (line 674)
  - **Impact**: Low - `Gemfile` 編集時にセキュリティ rules（bundler-audit 等）が参照されない可能性がある
  - **Suggestion**: Q3 を Design Decision として確定する（対象外にするならその理由を DD として記録）

- **[W003]** Quality Constraints (Section 9) で「DO/DON'T パターン: 各ファイルに最低 3 組以上」とあるが、これが Acceptance Criteria に含まれていない。US-004 AC-001 は「DO / DON'T の両方をコード例付きで含む」のみで最低数の指定がない
  - **Location**: `docs/specs/20260407-rails-rules.md` Section 9 (line 586) vs Section 2 US-004 (line 81)
  - **Impact**: Low - Quality Constraints と AC 間の微妙な不整合。実装時にどちらを基準とするか曖昧
  - **Suggestion**: US-004 AC-001 に「各ファイルに最低 3 組以上の DO/DON'T パターン」を追記して整合させる

#### Issues

- **[E001]** `params.require.permit` が DON'T として記載されている (Section 6.3, line 386-388) が、これは Rails 7.x 以前では標準パターンであり、Rails 8 でも引き続き動作する有効な API である。Research Document (line 102-106) でも「引き続き動作するが非推奨」としているものの、DON'T ラベルは強すぎる
  - **Location**: `docs/specs/20260407-rails-rules.md` Section 6.3 (line 385-388)
  - **Impact**: Medium - Rails 7.x プロジェクトでこの rules を使用した場合、正当なコードパターンが誤って否定される。Open Items Q4 で Rails 7.x 対応を検討中であることとも矛盾する
  - **Recommendation**: DON'T ではなく「PREFER / AVOID」のような段階的な表現にするか、コメントで「Rails 8+ では params.expect を推奨。Rails 7.x では require.permit が標準」と明記する。Go/TS specs では deprecated パターンを DON'T としていないため、既存 spec との一貫性の観点からも修正が望ましい
  - **Priority**: Medium

---

### [maint] Maintainability Review

#### Passed

- **Naming**: ファイル名の命名規則 `rails-{category}.md` がカテゴリと1対1で対応し、識別しやすい。Go (`go-{category}.md`) / TS (`ts-{category}.md`) と同一パターン
- **Document Structure (SRP)**: 各セクションが明確な責務を持ち、適切に分離されている（Interface / Data Models / Flow / Categories / Edge Cases / Deployment）
- **Consistency**: Go spec と同一のセクション構成（Overview -> User Stories -> Interface -> Data Models -> Flow -> Categories -> Edge Cases -> Deployment -> Quality -> Design Decisions -> Testing -> Open Items）を踏襲している
- **Readability**: Mermaid ダイアグラム（ER図、Sequence 図、State 図、Directory 図）が適切に使われ、視覚的に理解しやすい
- **Code Examples**: Ruby コード例にインラインコメント付きで DO/DON'T が明示されている
- **Cross-reference Table**: DD-006 (line 619-633) で Go/TS/React との対応表が明示されており、保守性が高い

#### Warnings

- **[W004]** Section 6 の各カテゴリ仕様の記述粒度にばらつきがある。rails-security.md (Section 6.1) と rails-activerecord.md (Section 6.2) にはコード例が含まれるが、rails-ruby-style.md (Section 6.4) と rails-testing.md (Section 6.5) にはコード例が含まれていない
  - **Location**: `docs/specs/20260407-rails-rules.md` Section 6.4 (line 391-408), Section 6.5 (line 410-432)
  - **Suggestion**: 各カテゴリに最低 1 つのコード例を含めることで、実装者が期待される出力を明確に把握できる。特に rails-testing.md は RSpec / Minitest 両方のコード例があると実装時の判断が容易になる

- **[W005]** paths 設定で `**/*.rb` が全ファイルに含まれているため、Rails プロジェクトで任意の `.rb` ファイルを編集すると最大 9 ファイル全てがロードされる可能性がある。コンテキスト消費への影響が Section 7 Edge Cases に記載されていない
  - **Location**: `docs/specs/20260407-rails-rules.md` Section 3.2 (line 127-137)
  - **Suggestion**: Edge Cases に「全 9 ファイルが同時ロードされた場合のコンテキスト消費量」を追加し、許容範囲内であることを確認する。または、paths を精緻化して不要なロードを減らす設計を検討する（例: rails-api.md から `**/*.rb` を除外し `app/controllers/api/**/*.rb` のみにする等）

---

## Action Items

| Priority | Item | Location |
|----------|------|----------|
| Medium | [E001] `params.require.permit` の DON'T 表記を緩和し、Rails 7.x との互換性を考慮した表現に修正する | Section 6.3 (line 385-388) |
| Low | [W001] `secure_headers` の扱いを明確化（追加 or 除外理由記載） | Section 6.1 |
| Low | [W002] Q3 (Gemfile/Rakefile 対応) を Design Decision として確定する | Section 12 Q3 |
| Low | [W003] Quality Constraints の DO/DON'T 最低 3 組を US-004 AC に反映する | Section 2 US-004 / Section 9 |
| Low | [W004] rails-ruby-style.md, rails-testing.md のカテゴリ仕様にコード例を追加する | Section 6.4, 6.5 |
| Low | [W005] 全 9 ファイル同時ロード時のコンテキスト消費を Edge Cases に記載する | Section 7 |

## Metrics

- **Passed**: 12 / 18 items
- **Warnings**: 5
- **Issues**: 1

## Next Steps

NEEDS_REVISION のため、少なくとも E001 (Medium) を修正してから実装フェーズに進むことを推奨する。

1. E001 の `params.require.permit` 表記を修正する
2. 可能であれば W004 (コード例の粒度統一) も対応する
3. `/my:review spec:20260407-rails-rules` で再レビュー
