# Implementation Plan: Ruby on Rails Coding Rules for Claude Code

## 1. Overview

Ruby on Rails のコーディングベストプラクティスを Claude Code の rules として 9 カテゴリに体系化し、`rules/rails/` ディレクトリに配置する。各ファイルは適切な `paths` フロントマター付きで、`.rb` / `.erb` ファイル編集時に自動ロードされる。Rails 8 / Ruby 3.2+ を前提とし、シンボリックリンクによる他プロジェクトへの配備も可能な構造とする。

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260407-rails-rules.md`

### 1.2 References
- Specification: `docs/specs/20260407-rails-rules.md`
- Go Rules (format reference): `rules/go/`
- TS/React Rules (format reference): `rules/typescript/`, `rules/react/`
- [Ruby Style Guide](https://github.com/rubocop/ruby-style-guide)
- [Rails Style Guide](https://github.com/rubocop/rails-style-guide)
- [Rails Guides](https://guides.rubyonrails.org/)
- [OWASP Ruby on Rails Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Ruby_on_Rails_Cheat_Sheet.html)

### 1.3 Implementation Strategy

全 9 ファイルを優先度順（P0 -> P1 -> P2）に作成する。各ファイルは独立しているため、フェーズ内では並列作成が可能。Go / TS / React ルールと同一の DO / DON'T フォーマットを使用し、全ファイル 200 行以下の制約を遵守する。

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `rules/rails/rails-security.md` | セキュリティベストプラクティス | P0 |
| `rules/rails/rails-activerecord.md` | ActiveRecord クエリ最適化・N+1 対策 | P0 |
| `rules/rails/rails-architecture.md` | MVC パターン・アーキテクチャ規約 | P0 |
| `rules/rails/rails-ruby-style.md` | Ruby スタイル・命名規約 | P1 |
| `rules/rails/rails-testing.md` | テスト規約（RSpec / Minitest） | P1 |
| `rules/rails/rails-antipatterns.md` | アンチパターン集 | P1 |
| `rules/rails/rails-migrations.md` | マイグレーション・スキーマ規約 | P2 |
| `rules/rails/rails-performance.md` | パフォーマンス・キャッシュ | P2 |
| `rules/rails/rails-api.md` | API 設計パターン | P2 |

### 2.2 Files to Modify

なし。本計画は新規ファイルの追加のみ。

### 2.3 Files to Delete

なし。

---

## 3. Implementation Steps

### Phase 1: Foundation -- ディレクトリ構造と P0 ルール作成

#### Step 1.1: ディレクトリ作成
**File:** `rules/rails/`
**Action:** Create

**Details:**
```
- rules/rails/ ディレクトリを作成
- 既存の rules/go/, rules/typescript/, rules/react/ と同階層に配置
```

**Verification:**
- [ ] `rules/rails/` ディレクトリが存在する

#### Step 1.2: rails-security.md 作成 (P0)
**File:** `rules/rails/rails-security.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.rb", "**/*.erb"]
- Strong Parameters: params.expect (Rails 8) を優先、params.require.permit も記載
- CSRF 対策: protect_from_forgery の有効化
- XSS 防止: ERB 自動エスケープの信頼、raw / html_safe の制限
- SQL インジェクション防止: プレースホルダー必須、文字列補間禁止
- 認証: Rails 8 認証ジェネレータ推奨、Devise は高度な要件向け
- 認可: Pundit / CanCanCan
- Brakeman: CI への組み込み推奨
- bundler-audit: 依存 gem のセキュリティ監査
- rack-attack: レートリミティング
- 暗号化: Rails.application.credentials で秘密情報管理
- HTTPS: config.force_ssl = true
- DO / DON'T 形式で SQL インジェクション、XSS、CSRF のコード例
```

**Verification:**
- [ ] フロントマターに `paths: ["**/*.rb", "**/*.erb"]` が設定されている
- [ ] 200 行以下である
- [ ] SQL インジェクション・XSS・CSRF の DO / DON'T コード例がある

#### Step 1.3: rails-activerecord.md 作成 (P0)
**File:** `rules/rails/rails-activerecord.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.rb"]
- N+1 対策: includes / preload / eager_load の使い分け
- strict_loading: lazy loading の防止 (Rails 7+)
- Bullet gem: 開発環境での N+1 検出
- find_each / find_in_batches: バッチ処理
- pluck: 必要カラムのみ取得（メモリ効率）
- exists? / any?: count > 0 より効率的
- トランザクション: 複数 DB 操作の原子性保証
- Raw SQL の回避: ActiveRecord クエリインターフェース優先
- インデックス: 外部キー、WHERE / ORDER BY 対象カラム
- DO / DON'T 形式で N+1、pluck、exists? のコード例
```

**Verification:**
- [ ] フロントマターに `paths: ["**/*.rb"]` が設定されている
- [ ] 200 行以下である
- [ ] N+1 対策の includes / preload / eager_load コード例がある

#### Step 1.4: rails-architecture.md 作成 (P0)
**File:** `rules/rails/rails-architecture.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.rb"]
- Skinny Controller, Fat Model: Controller はリクエスト処理に専念
- Concerns: 複数クラス間の共有機能のみ。単一クラスの複雑さ隠蔽に使わない
- Service Objects: -er 命名を避け、ドメインモデルとしての抽象化を検討
- Strong Parameters: Controller で必須。Rails 8 では params.expect 推奨
- Callbacks: before_action / after_action は最小限
- ActiveRecord スコープ: 再利用可能なクエリは scope 定義
- Validation: Model に記述、Custom validator は app/validators/ に配置
- Enum: マジックナンバー排除
- Rails 8 認証ジェネレータの活用
- DO / DON'T 形式で params.expect、Skinny Controller のコード例
```

**Verification:**
- [ ] フロントマターに `paths: ["**/*.rb"]` が設定されている
- [ ] 200 行以下である
- [ ] params.expect (Rails 8) と params.require.permit (Rails 7.x) 両方の例がある

---

### Phase 2: Core Logic -- P1 ルール作成

#### Step 2.1: rails-ruby-style.md 作成 (P1)
**File:** `rules/rails/rails-ruby-style.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.rb"]
- インデント: 2 spaces（タブ禁止）
- 命名: snake_case（メソッド・変数）、PascalCase（クラス・モジュール）、SCREAMING_SNAKE_CASE（定数）
- メソッド長: 10 行以下目安
- クラス長: 100 行以下目安
- 未使用変数: _ prefix
- accessor: get_ / set_ prefix 禁止、attr_name / attr_name= 使用
- frozen string literal: # frozen_string_literal: true
- ドキュメント: YARD 形式
- 論理演算子: && / || を条件式に使用（and / or は制御フロー限定）
- Pattern matching（Ruby 3.x）の活用推奨
- RuboCop / rubocop-rails との整合性
- DO / DON'T 形式で命名・スタイルのコード例
```

**Verification:**
- [ ] フロントマターに `paths: ["**/*.rb"]` が設定されている
- [ ] 200 行以下である
- [ ] snake_case / PascalCase の命名コード例がある

#### Step 2.2: rails-testing.md 作成 (P1)
**File:** `rules/rails/rails-testing.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["spec/**/*.rb", "test/**/*.rb", "**/*.rb"]
- テストピラミッド: Unit (多) > Integration (中) > System (少)
- RSpec 規約: describe / context / let / let! / subject / shared_examples
- Minitest 規約: test_ prefix、assert 系メソッド、fixtures
- FactoryBot: create より build / build_stubbed を優先
- 外部 API モック: WebMock, VCR
- System Tests: Capybara + headless browser
- カバレッジ: SimpleCov 80% 以上目標
- 推奨: 新規プロジェクトでは Minitest（Rails 8 デフォルト）
- DO / DON'T 形式で RSpec / Minitest 両方のコード例
```

**Verification:**
- [ ] フロントマターに `paths: ["spec/**/*.rb", "test/**/*.rb", "**/*.rb"]` が設定されている
- [ ] 200 行以下である
- [ ] RSpec と Minitest 両方のコード例がある

#### Step 2.3: rails-antipatterns.md 作成 (P1)
**File:** `rules/rails/rails-antipatterns.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.rb"]
- Fat Controller: ビジネスロジックを Controller に書かない
- God Model: 1 つの Model が多すぎる責務を持たない
- 過度な Callbacks: before_save / after_create の連鎖は予測困難
- Service Object の乱用: -er 命名を避ける
- Concerns の誤用: 単一クラスの行数削減目的で使わない
- 例外による制御フロー: 例外は異常系のみ
- Raw SQL の多用: AR クエリインターフェースを優先
- ネストしたトランザクション: Service Object 間のトランザクション問題
- default_scope: 暗黙的なクエリ条件の追加を避ける
- Skip Validations: update_column / save(validate: false) は原則禁止
- 各アンチパターンに問題点と改善例のコード例
```

**Verification:**
- [ ] フロントマターに `paths: ["**/*.rb"]` が設定されている
- [ ] 200 行以下である
- [ ] 各アンチパターンに問題のあるコードと改善コードの対比がある

---

### Phase 3: Integration -- P2 ルール作成と統合

#### Step 3.1: rails-migrations.md 作成 (P2)
**File:** `rules/rails/rails-migrations.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["db/migrate/**/*.rb", "**/*.rb"]
- 単一責任: 1 マイグレーション = 1 つの変更
- change メソッド優先: 自動リバーシブル
- strong_migrations gem: テーブルロックを引き起こす危険な操作の検出
- データマイグレーション分離: スキーマ変更とデータ変更の混在禁止（data_migrate gem）
- 命名規約: AddColumnToTable, RemoveColumnFromTable, CreateTable
- schema.rb のコミット: マイグレーション追加時に必ず一緒にコミット
- NOT NULL 制約: デフォルト値付きを推奨
- 外部キー制約: add_foreign_key 明示
- 本番環境安全性: add_index :concurrently, 段階的 remove_column
- DO / DON'T 形式でマイグレーションのコード例
```

**Verification:**
- [ ] フロントマターに `paths: ["db/migrate/**/*.rb", "**/*.rb"]` が設定されている
- [ ] 200 行以下である
- [ ] strong_migrations / 安全なマイグレーションのコード例がある

#### Step 3.2: rails-performance.md 作成 (P2)
**File:** `rules/rails/rails-performance.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["**/*.rb", "**/*.erb"]
- N+1 対策（ActiveRecord と重複するが重要性から再掲）
- Fragment Caching: cache ヘルパー
- Russian Doll Caching: ネストしたキャッシュフラグメント
- Low-level Caching: Rails.cache.fetch
- Solid Cache（Rails 8）: DB ベースキャッシュ、TTL 戦略
- Solid Queue（Rails 8）: Active Job バックエンド、キュー設計
- Counter Cache: belongs_to :parent, counter_cache: true
- Background Jobs: Solid Queue（Rails 8 デフォルト）/ Sidekiq
- Pagination: kaminari / pagy
- select / pluck: 必要カラムのみ取得
- DO / DON'T 形式で Solid Cache TTL、Fragment Caching のコード例
```

**Verification:**
- [ ] フロントマターに `paths: ["**/*.rb", "**/*.erb"]` が設定されている
- [ ] 200 行以下である
- [ ] Solid Cache / Solid Queue (Rails 8) のコード例がある

#### Step 3.3: rails-api.md 作成 (P2)
**File:** `rules/rails/rails-api.md`
**Action:** Create

**Details:**
```
- YAML フロントマター: paths: ["app/controllers/api/**/*.rb", "**/*.rb"]
- バージョニング: /api/v1/ prefix + Api::V1:: namespace
- Serializer: jsonapi-serializer / jbuilder
- HTTP ステータスコード: :ok, :created, :unprocessable_entity 等
- ページネーション: Link ヘッダー
- エラーレスポンス: 一貫した JSON フォーマット
- 認証: Token ベース（JWT / API key）
- レートリミティング: rack-attack
- 冪等性: Idempotency key の考慮
- DO / DON'T 形式で API バージョニング、エラーレスポンスのコード例
```

**Verification:**
- [ ] フロントマターに `paths: ["app/controllers/api/**/*.rb", "**/*.rb"]` が設定されている
- [ ] 200 行以下である
- [ ] API バージョニングと一貫したエラーレスポンスのコード例がある

---

### Phase 4: Testing -- 検証

#### Step 4.1: フォーマット検証
**Action:** Verify

**Test Cases:**
- [ ] 全 9 ファイルが `rules/rails/` に存在する
- [ ] 全ファイルの YAML フロントマターに適切な `paths` が設定されている
- [ ] 全ファイルが 200 行以下である（`wc -l rules/rails/*.md`）

#### Step 4.2: コンテンツ検証
**Action:** Verify

**Test Cases:**
- [ ] 各カテゴリの Key Topics（仕様セクション 6）が網羅されている
- [ ] コード例が構文的に正しい Ruby / ERB コードである
- [ ] DO / DON'T が明確に区別されコード例付きである
- [ ] ファイル名からカテゴリが識別可能
- [ ] Rails 8 固有機能（params.expect, Solid Queue, Solid Cache, 認証ジェネレータ）がカバーされている

#### Step 4.3: 統合検証
**Action:** Verify

**Test Cases:**
- [ ] シンボリックリンク作成手順が動作する
  ```bash
  mkdir -p /path/to/rails-project/.claude/rules
  ln -s /path/to/custom-slash-command/rules/rails /path/to/rails-project/.claude/rules/rails
  ls -la /path/to/rails-project/.claude/rules/rails/
  ```
- [ ] `rules/rails/` ディレクトリ単位でシンボリックリンク可能
- [ ] Go / TS / React ルールとフォーマットが一致している

#### Step 4.4: カバレッジ確認
**Action:** Verify

Research で特定された重要ルールの網羅確認:
- [ ] N+1 対策（includes / preload / eager_load） -- rails-activerecord.md
- [ ] Strong Parameters（Rails 8 params.expect） -- rails-architecture.md
- [ ] SQL インジェクション防止 -- rails-security.md
- [ ] XSS 防止（ERB 自動エスケープ） -- rails-security.md
- [ ] Skinny Controller, Fat Model -- rails-architecture.md
- [ ] テストピラミッド（Unit > Integration > System） -- rails-testing.md
- [ ] マイグレーション安全性（strong_migrations） -- rails-migrations.md
- [ ] Solid Queue / Solid Cache（Rails 8） -- rails-performance.md
- [ ] アンチパターン検出（Fat Controller, God Model, default_scope） -- rails-antipatterns.md
- [ ] 認証・認可パターン（Rails 8 ジェネレータ / Pundit） -- rails-security.md

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

なし。本計画は Markdown ファイルの作成のみで、外部パッケージは不要。

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `rules/` ディレクトリ | 存在済み | `rules/go/`, `rules/typescript/`, `rules/react/` が既存 |
| `rules/rails/` ディレクトリ | 未作成 | Phase 1 Step 1.1 で作成 |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [ ] 仕様書（`docs/specs/20260407-rails-rules.md`）をレビュー済み
- [ ] Go ルール（`rules/go/`）のフォーマットを参照済み

### 5.2 Post-Implementation
- [ ] 全 9 ファイルが作成されている
- [ ] 全ファイルが 200 行以下
- [ ] 全ファイルに正しいフロントマターが設定されている
- [ ] DO / DON'T 形式が Go / TS / React ルールと統一されている
- [ ] コード例が構文的に正しい Ruby コードである

### 5.3 Acceptance Criteria Verification
- [ ] AC-001: `rules/rails/` ディレクトリに 9 つのカテゴリ別 rules ファイルが存在する
- [ ] AC-002: 各ファイルに適切な `paths` フロントマターが設定されている
- [ ] AC-003: `.rb` / `.erb` ファイル編集時にルールが自動ロードされる
- [ ] AC-004: 各ファイルが 200 行以下である

---

## 6. Rollback Plan

1. `rules/rails/` ディレクトリごと削除: `rm -rf rules/rails/`
2. 既存ファイルへの変更はないため、副作用なし

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Foundation | Medium | P0 ルール 3 ファイル作成。セキュリティ・ActiveRecord はコード例が多い |
| Phase 2: Core Logic | Medium | P1 ルール 3 ファイル作成。テストは RSpec / Minitest 両対応が必要 |
| Phase 3: Integration | Low-Medium | P2 ルール 3 ファイル作成。Rails 8 固有機能のコード例を含む |
| Phase 4: Testing | Low | フォーマット・行数・カバレッジの検証 |

---
**Created:** 2026-04-07
**Status:** Draft
**Assignee:**
