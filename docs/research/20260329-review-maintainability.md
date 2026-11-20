# Research: Review Maintainability Enhancement

## 1. Overview

`/my:review` コマンドにおいて、コードの保守性（命名、コメント、可読性、一貫性など）に関するレビュー観点を強化する。現在の review システムには `fe`, `be`, `security`, `perf`, `doc`, `commit`, `pr` の 7 つの perspective が存在するが、命名やコメント品質といった保守性に特化した観点が不足している。

## 2. Problem Statement

現在の `/my:review` には以下の問題がある:

1. **命名品質のチェックが欠如**: 変数名・関数名・クラス名の適切さを体系的に評価する項目がない
2. **コメント品質の評価が不十分**: `review_doc_checklist.md` はドキュメント全体を対象としており、コード内コメントの品質は対象外
3. **可読性の観点が分散**: BE checklist に "Maintainability" セクション（4 項目のみ）があるが、FE/共通には無い
4. **コード構造の複雑度が未評価**: 認知的複雑度、ネストの深さ、関数の長さなどが未チェック
5. **一貫性のチェックが不在**: コーディングスタイル・パターンの統一性に関する項目がない

これらの欠如により、レビューで検出されるべき保守性上の問題が見落とされている。

## 3. Requirements Analysis

### 3.1 Functional Requirements

- [x] FR-001: 新しい perspective `maint:` (maintainability) を追加し、保守性特化のレビューを可能にする
- [x] FR-002: 保守性チェックリスト `review_maint_checklist.md` を作成する
- [x] FR-003: Auto-Selection Rules に保守性観点の自動選択ルールを追加する
- [x] FR-004: 既存の BE/FE checklist の Maintainability セクションと整合性を取る
- [x] FR-005: commit/PR レビュー時にも保守性チェックを適用可能にする

### 3.2 Non-Functional Requirements

- [x] NFR-001: チェック項目は具体的かつアクション可能であること（曖昧な基準を避ける）
- [x] NFR-002: 既存の review ワークフロー・出力形式と一貫性を保つこと
- [x] NFR-003: 言語非依存な項目と言語固有の項目を分離すること
- [x] NFR-004: チェック項目数は適切な範囲（20-35 項目）に収めること

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| 開発者（自身のコードレビュー） | 命名やコメントの品質を客観的に評価してほしい | High |
| レビュアー | 保守性の観点を体系的にカバーしたい | High |
| チーム（将来的な保守担当） | 6ヶ月後に読み直しても理解できるコードにしたい | Medium |
| `/my:review` ユーザー | 既存ワークフローに自然に組み込みたい | High |

## 5. Technical Investigation

### 5.1 Existing Solutions / Best Practices

#### 業界標準のコードレビュー観点（保守性関連）

**1. 命名 (Naming)**
- 意図が明確な名前（`data` → `userProfiles` など）
- 一貫した命名規則（camelCase / snake_case の混在禁止）
- ドメイン用語の正確な使用
- 略語の最小化（`usr` → `user`）
- Boolean は `is/has/can/should` プレフィックス
- コレクションは複数形
- 関数名は動詞で始める
- スコープに応じた名前の長さ

**2. コメント品質 (Comment Quality)**
- "What" ではなく "Why" を説明するコメント
- 古くなったコメントの検出
- コメントアウトされたコードの禁止
- TODO/FIXME に Issue 参照を含める（commit checklist と重複→統合）
- JSDoc/docstring のパラメータ・戻り値の正確性
- 自明なコードへの不要コメント回避

**3. 可読性 (Readability)**
- 認知的複雑度（Cognitive Complexity）の制限
- 関数あたりの行数制限（目安: 30-50 行）
- ネストの深さ制限（目安: 3-4 レベル）
- 早期 return / Guard clause パターン
- 条件式の明確さ（複雑な条件はヘルパー関数に）
- マジックナンバー・マジックストリングの排除

**4. コード構造 (Code Organization)**
- 単一責任の原則（SRP）
- 凝集度の高さ（関連するものを近くに配置）
- Dead code の除去
- 適切なファイル分割
- import の整理

**5. 一貫性 (Consistency)**
- プロジェクト内での命名パターンの統一
- エラーハンドリングパターンの統一
- ファイル構成パターンの統一
- API スタイルの統一

#### 既存ツールの知見

- **SonarQube**: Cognitive Complexity メトリクスを導入、コードスメルの分類体系
- **ESLint/Biome**: 命名規則（`naming-convention`）、複雑度（`complexity`）のルール化
- **Google Code Review Guidelines**: "Readability" を独立した品質属性として重視
- **Microsoft Code Review Checklist**: Maintainability Index を数値化

### 5.2 Technology Options

新しい perspective を追加する方法として、以下の選択肢がある:

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| A: 新 perspective `maint:` を追加 | 独立してレビューできる。既存 perspective と並列使用可能 | チェックリストの一部が BE/FE と重複する | ✅ 推奨 |
| B: 既存 BE/FE の Maintainability セクション拡張 | 追加コストが低い | 保守性だけのレビューができない。FE/BE に縛られる | △ 補助的に検討 |
| C: 全 checklist に共通の保守性項目を追加 | 漏れなくチェックできる | 全 checklist が肥大化する。重複管理が煩雑 | × 不推奨 |

### 5.3 Constraints & Dependencies

- **既存ファイル構成との整合性**: `prompts/templates/checklists/review_maint_checklist.md` として追加
- **8_review.md の更新**: perspective リストに `maint:` を追加
- **commands/my/review.md の更新**: ヘルプテキストに `maint:` を追加
- **_shared/processes/review.md の更新**: Auto-Selection Rules に保守性ルールを追加
- **既存 BE checklist との関係**: BE の Maintainability セクション（4 項目）は維持しつつ、`maint:` はより詳細な保守性レビューを提供

## 6. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| チェック項目の主観性が高すぎる | Medium | High | 各項目に具体的な基準・例を記載する |
| 既存 checklist との重複 | Low | Medium | BE/FE の Maintainability セクションは概要レベルに留め、`maint:` で詳細化する棲み分けを明確にする |
| Auto-Selection で `maint:` が選ばれにくい | Medium | Medium | 全コードファイルに適用可能とし、他の perspective と補完的に使えるようにする |
| チェック項目が多すぎてレビュー疲れ | Medium | Low | カテゴリごとに「必須」と「推奨」を分ける |

## 7. Open Questions

- [x] Q1: `maint:` の Auto-Selection はどのようなトリガーで発動させるか？ → 提案: 全コードファイルに対して `be:`/`fe:` と並行して選択可能とし、明示的な `maint:` 指定を推奨
- [ ] Q2: 言語固有のチェック項目（例: TypeScript の `any` 型禁止）をどこまで含めるか？ → 言語非依存セクションと分離して管理するか要検討
- [ ] Q3: `maint:` と `doc:` の境界線をどう引くか？ → `maint:` はコード内コメント品質、`doc:` はドキュメントファイル品質と棲み分け

## 8. Recommendations

**推奨アプローチ: Option A — 新 perspective `maint:` の追加**

以下のカテゴリ構成で `review_maint_checklist.md` を作成する:

1. **Naming（命名）** — 7-8 項目
   - 意図の明確さ、規則の一貫性、ドメイン用語、略語、Boolean/コレクション命名
2. **Comments（コメント）** — 5-6 項目
   - Why コメント、古いコメント検出、コメントアウトコード禁止、TODO 管理
3. **Readability（可読性）** — 6-7 項目
   - 認知的複雑度、関数長、ネスト深度、ガード節、マジック値排除
4. **Code Organization（コード構造）** — 4-5 項目
   - SRP、凝集度、Dead code、import 整理
5. **Consistency（一貫性）** — 4-5 項目
   - 命名パターン統一、エラー処理パターン統一、スタイル統一

合計: 約 26-31 項目（適正範囲）

変更対象ファイル:
- `prompts/templates/checklists/review_maint_checklist.md`（新規）
- `prompts/8_review.md`（perspective 追加）
- `commands/my/review.md`（ヘルプ更新）
- `prompts/_shared/processes/review.md`（Auto-Selection ルール追加）

## 9. Next Steps

- [x] Proceed to `/my:spec` phase with: `20260329-review-maintainability`

---
**Created:** 2026-03-29
**Status:** Draft
