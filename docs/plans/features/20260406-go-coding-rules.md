# Implementation Plan: Go Coding Rules for Claude Code

## 1. Overview

Go 言語のコーディングベストプラクティスを Claude Code の rules として 8 カテゴリに体系化し、`rules/go/` ディレクトリに配置する。各ファイルは `paths: ["**/*.go"]` フロントマター付きで、`.go` ファイル編集時に自動ロードされる。シンボリックリンクによる他プロジェクトへの配備も可能な構造とする。

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260406-go-coding-rules.md`

### 1.2 References
- Specification: `docs/specs/20260406-go-coding-rules.md`
- Research: `docs/research/20260406-go-coding-rules.md`
- Effective Go: https://go.dev/doc/effective_go
- Go Code Review Comments: https://github.com/golang/go/wiki/CodeReviewComments

### 1.3 Implementation Strategy

全 8 ファイルを優先度順（P0 → P1 → P2）に作成する。各ファイルは独立しているため、フェーズ内では並列作成が可能。全ファイル作成後にフォーマット検証・行数チェックを行い、最後にシンボリックリンクによる統合テストを実施する。

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `rules/go/go-style-naming.md` | 命名規則・スタイル・フォーマット | P0 |
| `rules/go/go-error-handling.md` | エラーハンドリングパターン | P0 |
| `rules/go/go-concurrency.md` | goroutine・チャネル・sync の安全な使用 | P1 |
| `rules/go/go-interfaces.md` | インターフェース設計 | P1 |
| `rules/go/go-testing.md` | テストのベストプラクティス | P1 |
| `rules/go/go-security.md` | セキュリティルール | P1 |
| `rules/go/go-performance.md` | パフォーマンスガイドライン | P2 |
| `rules/go/go-antipatterns.md` | 避けるべきパターン集 | P2 |

### 2.2 Files to Modify

なし。本計画は新規ファイルの追加のみ。

### 2.3 Files to Delete

なし。

---

## 3. Implementation Steps

### Phase 1: Foundation — ディレクトリ構造と P0 ルール作成

#### Step 1.1: ディレクトリ作成
**File:** `rules/go/`
**Action:** Create

**Details:**
```
- rules/go/ ディレクトリを作成
```

**Verification:**
- [ ] `rules/go/` ディレクトリが存在する

#### Step 1.2: go-style-naming.md 作成
**File:** `rules/go/go-style-naming.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.go"]
- MixedCaps / mixedCaps 命名規則
- パッケージ名: 短く、小文字、単数形、具体的な名前
- エクスポート名にパッケージ名を含めない
- レシーバー名: 短く一貫した 1-2 文字（self/this 禁止）
- インターフェース名: -er サフィックス
- アクロニムは全大文字（URL, HTTP, ID）
- gofmt / goimports によるフォーマット
- ファイル構成: 1 パッケージ 1 ディレクトリ
- DO / DON'T 形式で具体的なコード例を含める
```

**Verification:**
- [ ] フロントマターに `paths: ["**/*.go"]` が設定されている
- [ ] 200 行以下である
- [ ] DO / DON'T が明確に区別されている

#### Step 1.3: go-error-handling.md 作成
**File:** `rules/go/go-error-handling.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.go"]
- エラーチェック必須（_ = someFunc() 禁止）
- fmt.Errorf("context: %w", err) によるラッピング
- Sentinel errors パターン
- カスタムエラー型の定義
- errors.Is() / errors.As() による検査
- エラーメッセージ: 小文字開始、句点なし
- panic は回復不能な場合のみ
- defer でのリソースクリーンアップ
- DO / DON'T 形式で具体的なコード例を含める
```

**Verification:**
- [ ] フロントマターに `paths: ["**/*.go"]` が設定されている
- [ ] 200 行以下である
- [ ] エラーラッピング・Sentinel errors のコード例がある

---

### Phase 2: Core Logic — P1 ルール作成

#### Step 2.1: go-concurrency.md 作成
**File:** `rules/go/go-concurrency.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.go"]
- goroutine リーク防止: context.Context による制御
- チャネルの方向指定（chan<-, <-chan）
- sync.WaitGroup パターン
- sync.Mutex vs sync.RWMutex の使い分け
- select + context.Done() パターン
- errgroup.Group による並行エラーハンドリング
- データ競合の回避（-race フラグ）
- goroutine のライフサイクル管理
```

**Verification:**
- [ ] フロントマターが正しい
- [ ] 200 行以下
- [ ] goroutine リーク防止パターンのコード例がある

#### Step 2.2: go-interfaces.md 作成
**File:** `rules/go/go-interfaces.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.go"]
- 小さいインターフェース（1-3 メソッド推奨）
- 消費者側でインターフェースを定義
- Accept interfaces, return structs 原則
- 空インターフェース interface{} / any の使用最小化
- インターフェースの合成（embedding）
- 標準ライブラリのインターフェースパターン
- 不要な抽象化の回避
```

**Verification:**
- [ ] フロントマターが正しい
- [ ] 200 行以下
- [ ] "Accept interfaces, return structs" のコード例がある

#### Step 2.3: go-testing.md 作成
**File:** `rules/go/go-testing.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.go"]
- Table-driven tests パターン
- t.Run() によるサブテスト
- t.Helper() の使用
- t.Parallel() による並列テスト
- テストヘルパー関数の設計
- testdata/ ディレクトリの活用
- モック: インターフェースベースの注入
- 標準テストユーティリティ（httptest 等）
- ゴールデンファイルテスト
```

**Verification:**
- [ ] フロントマターが正しい
- [ ] 200 行以下
- [ ] Table-driven tests のコード例がある

#### Step 2.4: go-security.md 作成
**File:** `rules/go/go-security.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.go"]
- SQL インジェクション防止: プレースホルダー使用必須
- コマンドインジェクション防止: exec.Command の引数分離
- パストラバーサル防止: filepath.Clean + 検証
- crypto/rand 使用（math/rand はセキュリティ用途に使わない）
- HTTPS 強制、TLS 設定
- 入力バリデーション
- 機密情報のログ出力禁止
- html/template（XSS 防止）vs text/template
```

**Verification:**
- [ ] フロントマターが正しい
- [ ] 200 行以下
- [ ] 各脆弱性カテゴリに DO / DON'T コード例がある

---

### Phase 3: Integration — P2 ルール作成と統合

#### Step 3.1: go-performance.md 作成
**File:** `rules/go/go-performance.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.go"]
- 計測なき最適化の禁止（pprof 推奨）
- strings.Builder による文字列結合
- スライスの事前確保（make([]T, 0, cap)）
- sync.Pool によるオブジェクト再利用
- ポインタ vs 値レシーバーの使い分け
- 不要なメモリアロケーションの回避
- range ループでの値コピー注意
- バッファリング I/O（bufio）
```

**Verification:**
- [ ] フロントマターが正しい
- [ ] 200 行以下

#### Step 3.2: go-antipatterns.md 作成
**File:** `rules/go/go-antipatterns.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.go"]
- init() 関数の濫用
- グローバル変数への依存
- interface{} の過度な使用
- エラーの握りつぶし（_ = err）
- 過度のチャネル使用（mutex で十分な場面）
- 巨大な関数・パッケージ
- 不適切なコンテキスト伝搬（context.Background() の乱用）
- goto 文の使用
- 不要な else ブロック（early return 推奨）
```

**Verification:**
- [ ] フロントマターが正しい
- [ ] 200 行以下
- [ ] 各アンチパターンに問題点と改善例がある

---

### Phase 4: Testing — 検証

#### Step 4.1: フォーマット検証
**Action:** Verify

**Test Cases:**
- [ ] 全 8 ファイルが `rules/go/` に存在する
- [ ] 全ファイルの YAML フロントマターに `paths: ["**/*.go"]` が設定されている
- [ ] 全ファイルが 200 行以下である（`wc -l rules/go/*.md`）

#### Step 4.2: コンテンツ検証
**Action:** Verify

**Test Cases:**
- [ ] 各カテゴリの Key Topics（仕様セクション 6）が網羅されている
- [ ] コード例が構文的に正しい Go コードである
- [ ] DO / DON'T が明確に区別されている
- [ ] ファイル名からカテゴリが識別可能

#### Step 4.3: 統合検証
**Action:** Verify

**Test Cases:**
- [ ] シンボリックリンク作成手順が動作する
- [ ] `rules/go/` ディレクトリ単位でシンボリックリンク可能

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

なし。本計画は Markdown ファイルの作成のみで、外部パッケージは不要。

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `rules/` ディレクトリ | 未作成 | Phase 1 で作成 |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [ ] 仕様書（`docs/specs/20260406-go-coding-rules.md`）をレビュー済み
- [ ] リサーチドキュメント（`docs/research/20260406-go-coding-rules.md`）を参照済み

### 5.2 Post-Implementation
- [ ] 全 8 ファイルが作成されている
- [ ] 全ファイルが 200 行以下
- [ ] 全ファイルに正しいフロントマターが設定されている
- [ ] DO / DON'T 形式が統一されている
- [ ] コード例が構文的に正しい

### 5.3 Acceptance Criteria Verification
- [ ] AC-001: `rules/go/` ディレクトリに 8 つのカテゴリ別 rules ファイルが存在する
- [ ] AC-002: 各ファイルに `paths: ["**/*.go"]` フロントマターが設定されている
- [ ] AC-003: `.go` ファイル編集時にルールが自動ロードされる
- [ ] AC-004: 各ファイルが 200 行以下である

---

## 6. Rollback Plan

1. `rules/go/` ディレクトリごと削除: `rm -rf rules/go/`
2. 既存ファイルへの変更はないため、副作用なし

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Foundation | Medium | P0 ルール 2 ファイル作成。コード例を含むため中程度 |
| Phase 2: Core Logic | Medium | P1 ルール 4 ファイル作成。並行処理・セキュリティは注意深く記述 |
| Phase 3: Integration | Low | P2 ルール 2 ファイル作成 |
| Phase 4: Testing | Low | フォーマット・行数の自動チェック |

---
**Created:** 2026-04-06
**Status:** Draft
**Assignee:**
