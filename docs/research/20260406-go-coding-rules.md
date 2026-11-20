# Research: Go Coding Rules for Claude Code

## 1. Overview

言語・フレームワークごとのベストプラクティスを Claude Code の rules として整備し、コーディング時やレビュー時に自動参照させる仕組みを構築する。本リサーチでは Go 言語に関する rules を初回対象として調査する。

本 repository に `rules/` ディレクトリを作成し、各プロジェクトにシンボリックリンクで配備する運用を前提とする。

## 2. Problem Statement

- Claude Code でコーディング・レビューを行う際、言語固有のベストプラクティスが暗黙知として埋もれており、一貫した品質を担保しにくい
- チーム・プロジェクト横断で統一的なコーディング規約を適用したい
- rules として明文化・構造化することで、AI アシスタントが常に参照可能な状態にしたい

## 3. Requirements Analysis

### 3.1 Functional Requirements

- [x] FR-001: Go のコーディングベストプラクティスを網羅した rules ファイルを作成
- [x] FR-002: Claude Code の `.claude/rules/` 配下で動作する形式で記述
- [x] FR-003: `paths` フロントマターにより `.go` ファイル編集時のみ自動ロードされるようスコープを設定
- [x] FR-004: 複数ファイルに分割し、トピックごとに管理可能にする
- [x] FR-005: シンボリックリンクで他プロジェクトから参照可能な構造にする

### 3.2 Non-Functional Requirements

- [x] NFR-001: 各 rules ファイルは 200 行以下を目安とし、コンテキスト消費を抑制
- [x] NFR-002: 他言語の rules 追加時にスケーラブルなディレクトリ構造
- [x] NFR-003: 具体的かつアクション可能なルール記述（「良いコードを書く」ではなく具体的指示）
- [x] NFR-004: 公式ガイドライン準拠（Effective Go, Go Code Review Comments, Google/Uber Style Guide）

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| 開発者（Claude Code ユーザー） | Go コード生成時に自動的にベストプラクティスが適用される | High |
| レビュアー | レビュー時に規約違反を自動検出・指摘できる | High |
| チームリード | プロジェクト横断で一貫した品質基準を適用 | Medium |
| 新規メンバー | Go の慣用的な書き方を学びやすい環境 | Medium |

## 5. Technical Investigation

### 5.1 Claude Code Rules System

Claude Code は `.claude/rules/` ディレクトリに Markdown ファイルを配置することで、コーディング指示を自動参照する仕組みを持つ。

**主要な特徴:**
- YAML フロントマターで `paths` を指定し、特定のファイルパターンにマッチした場合のみルールをロード
- Markdown 形式で記述。見出し・箇条書き・テーブルをサポート
- シンボリックリンクを解決してロード可能
- ユーザーレベル（`~/.claude/rules/`）とプロジェクトレベル（`.claude/rules/`）のスコープ

**パス指定の例:**
```yaml
---
paths:
  - "**/*.go"
---
```

### 5.2 Go ベストプラクティスの調査結果

以下のソースから Go のベストプラクティスを網羅的に調査した:

| Source | 特徴 | 権威性 |
|--------|------|--------|
| Effective Go | Go 公式の慣用パターン解説 | 最高（公式） |
| Go Code Review Comments | コードレビュー時のチェックポイント集 | 最高（公式） |
| Google Go Style Guide | Google 社内の Go スタイルガイド | 高 |
| Uber Go Style Guide | 大規模プロダクション運用のベストプラクティス | 高 |
| Go Blog (errors, testing, etc.) | トピック別の公式ガイダンス | 高 |

**カバレッジ（rules として整備すべきカテゴリ）:**

1. **Code Style & Naming** — 命名規則、パッケージ構成、フォーマット
2. **Error Handling** — エラーパターン、ラッピング、sentinel errors
3. **Concurrency** — goroutine 管理、チャネル、sync プリミティブ
4. **Interface Design** — 小さいインターフェース、消費者側定義
5. **Testing** — table-driven tests、サブテスト、ヘルパー
6. **Performance** — メモリ割り当て、プロファイリング
7. **Security** — SQL インジェクション防止、暗号、入力検証
8. **Anti-patterns** — 避けるべきパターン集
9. **Module Management** — go.mod、依存管理
10. **Documentation** — godoc 規約

### 5.3 ディレクトリ構造案

```
custom-slash-command/
└── rules/
    └── go/
        ├── go-style-naming.md       # 命名・スタイル規約
        ├── go-error-handling.md      # エラーハンドリング
        ├── go-concurrency.md        # 並行処理
        ├── go-interfaces.md         # インターフェース設計
        ├── go-testing.md            # テスト
        ├── go-performance.md        # パフォーマンス
        ├── go-security.md           # セキュリティ
        └── go-antipatterns.md       # アンチパターン

対象プロジェクト/
└── .claude/
    └── rules/
        └── go -> ~/path/to/custom-slash-command/rules/go/
```

### 5.4 Technology Options

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| 単一ファイル（all-in-one） | 管理が簡単 | 200行制限超過、コンテキスト消費大 | 非推奨 |
| カテゴリ別分割（推奨） | トピックごとに管理・更新可能、コンテキスト効率良い | ファイル数が増える | **推奨** |
| 言語別ディレクトリ | スケーラブル、他言語追加が容易 | 初期構造がやや大きい | **推奨（併用）** |

### 5.5 Constraints & Dependencies

- Claude Code の rules ファイルは `.claude/rules/` 配下に配置が必要
- YAML フロントマターの `paths` でスコープ制御
- シンボリックリンクは解決されてロードされる（循環リンク対策あり）
- 各ファイル 200 行以下推奨（超過するとコンテキスト消費増大・遵守率低下）

## 6. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| rules が長すぎてコンテキストを圧迫 | High | Medium | カテゴリ分割、200行制限厳守 |
| 全 .go ファイルに一律適用で過剰指示 | Medium | Low | paths パターンを適切に設定 |
| 他ルールとの矛盾（CLAUDE.md 等） | Medium | Low | 既存の CLAUDE.md と整合性確認 |
| rules の陳腐化（Go バージョンアップ） | Medium | Medium | 定期レビューの仕組みを設ける |
| シンボリックリンクの管理負荷 | Low | Medium | セットアップスクリプトを用意 |

## 7. Open Questions

- [x] Q1: rules ファイルの粒度はどの程度が最適か → カテゴリ別（8ファイル前後）で各200行以下
- [ ] Q2: レビュー専用のルールとコーディング専用のルールを分けるべきか
- [ ] Q3: プロジェクト固有のカスタマイズ（特定の lint ルール等）はどう扱うか
- [ ] Q4: Go のバージョン依存ルール（1.22+ のループ変数等）はどう管理するか
- [ ] Q5: rules の配備（シンボリックリンク作成）を自動化するスクリプトは必要か

## 8. Recommendations

### 推奨アプローチ

1. **カテゴリ別分割**: Go rules を 7-8 ファイルに分割し、各ファイルを 200 行以下に収める
2. **言語別ディレクトリ**: `rules/go/` 構造を採用し、将来の Python, TypeScript 等の追加に備える
3. **paths スコープ**: 各ファイルに `paths: ["**/*.go"]` を設定し、Go ファイル編集時のみロード
4. **公式ガイドライン準拠**: Effective Go, Go Code Review Comments, Google/Uber Style Guide をベースに
5. **シンボリックリンク運用**: `rules/go/` ディレクトリ単位でリンクし、管理を簡素化

### Rules の優先カテゴリ（実装順）

| Priority | Category | 理由 |
|----------|----------|------|
| P0 | Error Handling | Go で最も差が出る領域。不適切なエラー処理はバグの温床 |
| P0 | Style & Naming | 基本中の基本。慣用的な Go コードの土台 |
| P1 | Testing | テスト品質が直接コード品質に影響 |
| P1 | Concurrency | Go の強みだが誤用しやすい領域 |
| P1 | Security | セキュリティ問題は発見が遅れるほどコスト増 |
| P2 | Interface Design | 設計品質の向上 |
| P2 | Performance | 計測ベースの最適化を促進 |
| P2 | Anti-patterns | 既知の落とし穴を事前回避 |

## 9. Next Steps

- [x] Proceed to `/my:spec` phase with: Go rules の詳細仕様策定
- [ ] `rules/go/` ディレクトリ構造の確定
- [ ] 各カテゴリの rules ファイル作成
- [ ] シンボリックリンク配備スクリプトの検討
- [ ] 既存 Go プロジェクトでの動作検証

---
**Created:** 2026-04-06
**Status:** Draft
**Sources:** Effective Go, Go Code Review Comments, Google Go Style Guide, Uber Go Style Guide, Claude Code Documentation
