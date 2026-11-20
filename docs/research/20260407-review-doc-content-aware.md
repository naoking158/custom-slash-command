# Research: Review Document Content-Aware Enhancement

## 1. Overview

`/my:review` コマンドで技術文書（設計書、仕様書、計画書、調査書など）をレビューする際に、文書の種類と内容に応じた適切なレビュー観点を自動的に適用する機能を追加する。

現在のシステムでは、spec や plan などの技術文書をレビューする場合、Auto-Selection が Markdown ファイルであることから `doc:` perspective に解決されるが、`doc:` チェックリストは API ドキュメントやユーザーガイドのような「ドキュメンテーション品質」を評価するものであり、設計書・仕様書・計画書それぞれの「内容品質」を評価する観点が欠落している。

## 2. Problem Statement

### 現状の問題

1. **Auto-Selection が文書種別を考慮しない**: ファイル拡張子ベースの判定（`.md` → `doc:`）のみで、target type（`spec:`, `plan:` など）から文書の種類を判別していない
2. **doc チェックリストが汎用的すぎる**: 現在の `review_doc_checklist.md` は「API 仕様の網羅性」「サンプルコードの動作確認」など、ユーザー向けドキュメンテーション品質にフォーカスしており、設計・仕様・計画の内容品質を評価できない
3. **文書種別ごとの評価基準がない**:
   - **仕様書（spec）**: 要件の完全性、曖昧さの排除、テスト可能性、一貫性、実現可能性 → チェック項目なし
   - **計画書（plan）**: タスク分解の妥当性、依存関係、リスク評価、タイムライン、ロールバック戦略 → チェック項目なし
   - **調査書（research）**: 分析深度、情報源の信頼性、結論の根拠、調査の網羅性 → チェック項目なし
4. **perspective とtarget type が直交する概念なのに混同されている**: `doc:` は perspective（ドキュメント品質の観点）だが、target type が `spec:` なら仕様書の内容品質という別の軸のレビューが必要

### 具体例

```
/my:review spec:user-auth
```
- 現在: `doc:` checklist（API 仕様の網羅性、サンプルコードの確認...）+ `maint:` checklist が適用される
- 期待: 仕様書として「要件が曖昧でないか」「テスト可能か」「矛盾がないか」「スコープが適切か」を評価してほしい

```
/my:review plan:user-auth
```
- 現在: 同じく `doc:` + `maint:` が適用される
- 期待: 計画書として「タスク分解が適切か」「依存関係は正しいか」「リスク評価があるか」「実装順序は妥当か」を評価してほしい

## 3. Requirements Analysis

### 3.1 Functional Requirements

- [ ] FR-001: target type（`spec:`, `plan:`, `research:` など）に基づく content-type checklist を自動適用する仕組みを追加
- [ ] FR-002: 仕様書（spec）用レビューチェックリスト `review_spec_checklist.md` を作成
- [ ] FR-003: 計画書（plan）用レビューチェックリスト `review_plan_checklist.md` を作成
- [ ] FR-004: 調査書（research）用レビューチェックリスト `review_research_checklist.md` を作成（優先度: Low）
- [ ] FR-005: 既存の perspective（`fe:`, `be:`, `security:` 等）と content-type checklist を組み合わせ可能にする
- [ ] FR-006: Auto-Selection ロジックを更新し、target type から content-type checklist を自動選択する

### 3.2 Non-Functional Requirements

- [ ] NFR-001: 既存の review ワークフローとの後方互換性を維持する
- [ ] NFR-002: チェック項目は具体的かつアクション可能であること
- [ ] NFR-003: 各チェックリストは 15-25 項目に収めること（網羅性と実用性のバランス）
- [ ] NFR-004: 既存の perspective チェックリストの形式・構造と一貫性を保つ

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| 仕様書作成者 | 仕様の完全性・曖昧さ・実現可能性を客観的に評価してほしい | High |
| 計画書作成者 | 計画の妥当性・リスク・依存関係を体系的にチェックしてほしい | High |
| `/my:review` ユーザー | target type を指定するだけで適切なレビューが自動で行われてほしい | High |
| 実装者 | レビュー結果から具体的な改善アクションが分かるようにしてほしい | Medium |

## 5. Technical Investigation

### 5.1 Existing Solutions / Best Practices

#### 業界標準の技術文書レビュー観点

**仕様書レビュー（IEEE 830 / ISO/IEC/IEEE 29148 準拠）:**
- Correctness（正確性）: 要件が実際のニーズを正しく反映しているか
- Unambiguity（非曖昧性）: 各要件が一つの解釈のみ可能か
- Completeness（完全性）: すべての必要な要件が含まれているか
- Consistency（一貫性）: 要件間に矛盾がないか
- Verifiability（検証可能性）: 各要件をテストで確認できるか
- Modifiability（変更容易性）: 要件の変更が容易な構造か
- Traceability（追跡可能性）: 要件の出典・根拠が明確か
- Feasibility（実現可能性）: 技術的・リソース的に実現可能か

**計画書レビュー（PMBOK / Agile 準拠）:**
- Task Decomposition: タスクが適切な粒度に分解されているか
- Dependency Management: タスク間の依存関係が明示されているか
- Risk Assessment: リスクの特定と軽減策があるか
- Timeline Realism: スケジュールが現実的か（バッファ含む）
- Rollback Strategy: 失敗時の復旧計画があるか
- Acceptance Criteria: 完了条件が定義されているか
- Scope Control: スコープが明確に制限されているか

**設計書レビュー:**
- Architecture Fitness: アーキテクチャが要件を満たすか
- Trade-off Analysis: 設計判断のトレードオフが議論されているか
- Interface Design: インターフェースが明確に定義されているか
- Error Handling Strategy: エラー処理の戦略が包括的か
- Scalability Consideration: 拡張性への考慮があるか

#### 参考文献
- [Software Requirement Specification (SRS) Document Checklist | GeeksforGeeks](https://www.geeksforgeeks.org/software-requirement-specification-srs-document-checklist/)
- [Checklist for Requirements Specification Reviews (University of Toronto)](https://www.cs.toronto.edu/~sme/CSC340F/2005/assignments/inspections/reqts_checklist.pdf)
- [Software Design Review Checklist](https://checklist.gg/templates/software-design-review-checklist)
- [Plan Review Skill | Smithery](https://smithery.ai/skills/flight505/plan-review)
- [Technical Document Review Checklist | zipBoard](https://zipboard.co/blog/document-collaboration/the-ultimate-technical-document-review-checklist-and-guide/)

### 5.2 Technology Options

#### Option A: Content-Type Layer の追加（推奨）

perspective 軸（`fe:`, `be:` 等）に加えて、content-type 軸（`spec`, `plan`, `research`）を追加する。target type から content-type を自動判別し、対応するチェックリストを追加で適用する。

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| **A: Content-Type Layer 追加** | 既存 perspective と直交して組み合わせ可能。後方互換性維持。target type から自動判別できる | チェックリストの適用ロジックが複雑化する | ✅ 推奨 |
| B: 新 perspective として追加 (`spec:`, `plan:`) | 既存の仕組みに自然に統合できる | perspective と target type の概念が混同される。`be:spec:` のような組み合わせが表現しにくい | ❌ |
| C: doc checklist を文書種別で分岐 | 変更量が最小 | `doc:` perspective の意味が曖昧になる。汎用 doc レビューができなくなる | ❌ |

#### Option A の詳細設計

**チェックリスト適用ロジック:**

```
レビュー実行時に適用されるチェックリスト = [
  content-type checklist (target type から自動選択),
  perspective checklist (perspective prefix から選択 or auto-select),
  maint checklist (auto-apply ルールに従う)
]
```

**content-type チェックリストの選択ルール:**

| Target Type | Content-Type Checklist |
|-------------|----------------------|
| `spec:{id}` | `review_spec_checklist.md` |
| `plan:{id}`, `plan:fix:{id}`, `plan:refactor:{id}`, `plan:change:{id}` | `review_plan_checklist.md` |
| `code:{id}` | なし（既存 perspective で十分） |
| `commit:{hash}` | なし（既存 commit checklist で十分） |
| `pr:{number}` | なし（既存 PR checklist で十分） |
| `{id}` (auto-detect で spec に解決) | `review_spec_checklist.md` |
| `{id}` (auto-detect で plan に解決) | `review_plan_checklist.md` |

**perspective の auto-select 変更:**

技術文書（spec, plan）の場合、ファイル拡張子ベースの auto-select ではなく、文書内容から適切な perspective を選択する:
- spec/plan 内にフロントエンド関連の要件が多い → `fe:`
- spec/plan 内にバックエンド関連の要件が多い → `be:`
- spec/plan 内にセキュリティ関連の要件が多い → `security:`
- 判定不能 → perspective auto-select をスキップし、content-type checklist + maint のみ適用

### 5.3 Constraints & Dependencies

- **既存チェックリストとの整合性**: 新しい content-type チェックリストは既存のチェックリストと同じ形式（Markdown チェックリスト）を使用する必要がある
- **プロンプト長の制約**: 複数のチェックリストを組み合わせる場合、プロンプトが長くなりすぎないよう項目数を制限する必要がある
- **既存の review テンプレート**: `review_template.md` は perspective ベースのセクション構造を持っており、content-type セクションを追加する必要がある
- **Gemini review との整合性**: `gemini/commands/my/review.toml` にも対応する変更が必要

## 6. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| チェックリスト項目が多すぎてレビューが形骸化する | Medium | Medium | 各チェックリスト 15-25 項目に制限。優先度付けを明確に |
| content-type と perspective の組み合わせ爆発 | Medium | Low | content-type は target type から一意に決まるため、ユーザーが明示的に選択する必要なし |
| 既存の `doc:` perspective との意味的重複 | Low | High | `doc:` はドキュメンテーション品質（書き方）、content-type は内容品質（中身）と明確に区別する |
| プロンプトサイズ増加によるレビュー品質低下 | Medium | Low | content-type checklist は必要最小限に。perspective が auto-select 不能な場合はスキップ |

## 7. Open Questions

- [ ] Q1: `research:` target type を新設するか（現在は target type として存在しない）。もし新設するなら `docs/research/{id}.md` への直接参照が可能になる
- [ ] Q2: content-type checklist と perspective checklist のレポート内での表示順序はどうするか（content-type を先にすべきか）
- [ ] Q3: `doc:` perspective の既存チェックリストを改訂する必要があるか（content-type checklist との重複排除）
- [ ] Q4: gemini review (`gemini/commands/my/review.toml`) にも同等の変更を入れるか、Claude Code 側のみの変更とするか

## 8. Recommendations

### 推奨アプローチ: Option A — Content-Type Layer の追加

1. **content-type チェックリストを新規作成**: `review_spec_checklist.md` と `review_plan_checklist.md` を優先的に作成
2. **レビュープロセスに content-type 判定ステップを追加**: target type から content-type を自動判別し、対応チェックリストを追加適用
3. **review テンプレートを更新**: content-type セクションを追加
4. **段階的な導入**: まず spec/plan チェックリストを追加し、research は後から追加

### 推奨する仕様書チェックリストの主要カテゴリ

1. **Completeness（完全性）**: 必須セクション、スコープ定義、受入基準
2. **Clarity（明確性）**: 曖昧な表現の排除、用語の一貫性
3. **Correctness（正確性）**: 要件間の矛盾、技術的実現可能性
4. **Verifiability（検証可能性）**: テスト可能な基準、定量的指標
5. **Traceability（追跡可能性）**: 要件の根拠、関連文書へのリンク

### 推奨する計画書チェックリストの主要カテゴリ

1. **Structure（構造）**: タスク分解、依存関係、実装順序
2. **Feasibility（実現可能性）**: 技術的リスク、リソース見積もり
3. **Completeness（完全性）**: エラー処理、ロールバック、受入基準
4. **Clarity（明確性）**: ステップの具体性、曖昧さの排除
5. **Risk Management（リスク管理）**: リスク特定、軽減策

## 9. Next Steps

- [ ] Proceed to `/my:spec` phase with: `20260407-review-doc-content-aware`
  - 仕様書チェックリストの詳細項目定義
  - 計画書チェックリストの詳細項目定義
  - content-type 判定ロジックの仕様
  - review プロセス・テンプレートの更新仕様
  - 既存 `doc:` checklist との差分整理

---
**Created:** 2026-04-07
**Status:** Draft
