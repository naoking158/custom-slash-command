# Research: Ruby on Rails Coding Rules for Claude Code

## 1. Overview

Go / TypeScript / React に続き、Ruby on Rails のコーディングルールを Claude Code の rules として整備する。Rails の Convention over Configuration の哲学に沿いつつ、AI アシスタントがコード生成・レビュー時に参照できる実践的なルールセットを構築する。

本 repository の `rules/rails/` ディレクトリに配置し、シンボリックリンクで各プロジェクトに配備する運用を前提とする。

## 2. Problem Statement

- Rails は Convention over Configuration を重視するが、その慣習の多くが暗黙知として存在し、新規メンバーやAIアシスタントが見落としやすい
- ActiveRecord の N+1 問題、セキュリティ脆弱性、テスト設計の不備など、Rails 固有の落とし穴が多数存在する
- Rails 8 で導入された Solid Queue / Solid Cache / Solid Cable や認証ジェネレータなど、最新のベストプラクティスを反映する必要がある
- チーム横断で一貫した Rails コーディング品質を担保したい

## 3. Requirements Analysis

### 3.1 Functional Requirements

- [x] FR-001: Ruby のコーディングスタイル（community style guide 準拠）をカバーした rules ファイルを作成
- [x] FR-002: Rails 固有のパターン（MVC, ActiveRecord, Concerns 等）をカバー
- [x] FR-003: テスト規約（RSpec / Minitest 両対応）をカバー
- [x] FR-004: セキュリティベストプラクティス（OWASP for Rails, Brakeman）をカバー
- [x] FR-005: パフォーマンスパターン（N+1 対策、キャッシュ、インデックス）をカバー
- [x] FR-006: データベース / マイグレーション規約をカバー
- [x] FR-007: API 設計パターン（JSON serializer, versioning）をカバー
- [x] FR-008: `paths` フロントマターにより `.rb` / `.erb` ファイル編集時のみ自動ロード
- [x] FR-009: 各ファイル 200 行以下で、既存 Go/TS/React ルールと同一フォーマット

### 3.2 Non-Functional Requirements

- [x] NFR-001: 各 rules ファイルは 200 行以下（コンテキスト消費抑制）
- [x] NFR-002: DO / DON'T パターンで具体的かつアクション可能な記述
- [x] NFR-003: Rails 7.1+ / Rails 8 を前提とし、最新の慣習を反映
- [x] NFR-004: Ruby 3.2+ のモダンな機能（pattern matching, Data class 等）を考慮
- [x] NFR-005: RuboCop / rubocop-rails の主要ルールと整合性を保つ

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| 開発者（Claude Code ユーザー） | Rails コード生成時に自動的にベストプラクティスが適用される | High |
| レビュアー | レビュー時に Rails 固有の問題（N+1, セキュリティ等）を自動検出 | High |
| チームリード | プロジェクト横断で一貫した Rails コーディング品質を適用 | Medium |
| 新規メンバー | Rails の慣用的な書き方・パターンを学びやすい環境 | Medium |

## 5. Technical Investigation

### 5.1 調査ソース

| Source | 特徴 | 権威性 |
|--------|------|--------|
| Ruby Style Guide (rubocop/ruby-style-guide) | コミュニティ標準の Ruby スタイルガイド | 最高（コミュニティ標準） |
| Rails Style Guide (rubocop/rails-style-guide) | Rails 固有のスタイルガイド | 最高（コミュニティ標準） |
| Rails Guides (guides.rubyonrails.org) | 公式ドキュメント | 最高（公式） |
| RuboCop / rubocop-rails | Linter のルールセット | 高 |
| OWASP Ruby on Rails Cheat Sheet | Rails セキュリティガイド | 高（OWASP） |
| Brakeman | Rails 静的セキュリティ解析 | 高 |
| strong_migrations gem | 安全なマイグレーションガイド | 高 |
| Bullet gem | N+1 検出ツール | 高 |

### 5.2 Rules カテゴリ詳細

#### 5.2.1 Ruby Style & Naming (`rails-ruby-style.md`)

**対象パス:** `**/*.rb`

主要ルール:
- インデント: 2 spaces（タブ禁止）
- 命名: snake_case（メソッド・変数）、PascalCase（クラス・モジュール）、SCREAMING_SNAKE_CASE（定数）
- メソッド長: 10行以下を目安
- クラス長: 100行以下を目安
- 未使用変数は `_` prefix
- accessor は `get_` / `set_` prefix 禁止、`attr_name` / `attr_name=` を使用
- `freeze` を文字列リテラルに適用（`# frozen_string_literal: true`）
- ドキュメントは YARD 形式
- `&&` / `||` を条件式に使用（`and` / `or` は制御フロー限定）
- pattern matching（Ruby 3.x）の活用推奨

#### 5.2.2 Rails MVC & Architecture (`rails-architecture.md`)

**対象パス:** `**/*.rb`

主要ルール:
- **Skinny Controller, Fat Model**: Controller はリクエスト処理・レスポンス生成に専念。ビジネスロジックは Model へ
- **Concerns の適切な使用**: 複数クラス間での共有機能に使用。単一クラスの複雑さを隠すために使わない
- **Service Objects の注意点**: 安易な `-er` クラス（Manager, Processor）を避け、ドメインモデルとして適切な抽象化を検討
- **Strong Parameters**: Controller で必ず使用。Mass assignment 脆弱性の防止
- **Callbacks の節度**: before_action / after_action は最小限に。複雑なロジックは明示的なメソッド呼び出しに
- **ActiveRecord スコープ**: 再利用可能なクエリは scope で定義
- **Validation**: Model に記述。Custom validator は `app/validators/` に配置
- **Enum**: `enum` を活用し、マジックナンバーを排除
- Rails 8: 認証ジェネレータの活用（Devise 不要のケース）
- **Rails 8 `params.expect`**: `params.require(...).permit(...)` の代替として導入された安全な API。配列パラメータの曖昧な扱いを排除し、予期しない入力で ActionController::ParameterMissing を発生させる

```ruby
# DO (Rails 8): params.expect で型と構造を明示
def user_params
  params.expect(user: [:name, :email, { roles: [] }])
end

# DON'T: require + permit は Rails 8 以前の書き方（引き続き動作するが非推奨）
def user_params
  params.require(:user).permit(:name, :email, roles: [])
end
```

#### 5.2.3 ActiveRecord & Database (`rails-activerecord.md`)

**対象パス:** `**/*.rb`

主要ルール:
- **N+1 対策**: `includes` / `preload` / `eager_load` を適切に使い分け
- **strict_loading**: Rails 6.1 で導入、Rails 7+ で改善。本番環境での lazy loading を防止
- **Bullet gem**: 開発環境で N+1 を検出
- **find_each / find_in_batches**: 大量レコードの反復処理にはバッチ処理を使用
- **pluck**: 必要なカラムのみ取得（メモリ効率）
- **exists? / any?**: レコード存在確認は `count > 0` より効率的
- **トランザクション**: 複数の DB 操作はトランザクションで囲む
- **Raw SQL の回避**: できる限り ActiveRecord クエリインターフェースを使用
- **インデックス**: 外部キー、WHERE / ORDER BY で頻繁に使用するカラムにインデックスを追加

```ruby
# DO: includes で N+1 を回避
posts = Post.includes(:author, :tags).limit(20)
posts.each { |p| puts p.author.name }  # クエリ追加なし

# DON'T: 関連を遅延ロードして N+1 を発生させる
posts = Post.limit(20)
posts.each { |p| puts p.author.name }  # posts の件数分だけ追加クエリが発生

# DO: pluck で必要なカラムのみ取得
user_ids = User.active.pluck(:id)

# DON'T: 全カラムをロードしてからマッピング
user_ids = User.active.map(&:id)
```

#### 5.2.4 Migration & Schema (`rails-migrations.md`)

**対象パス:** `db/migrate/**/*.rb`, `**/*.rb`

主要ルール:
- **単一責任**: 1 マイグレーション = 1 つの変更
- **change メソッド優先**: `up` / `down` より `change` を使い、自動リバーシブルに
- **strong_migrations gem**: テーブルロックを引き起こす危険な操作を検出
- **データマイグレーション分離**: スキーマ変更とデータ変更を混在させない（data_migrate gem 推奨）
- **命名規約**: `AddColumnToTable`, `RemoveColumnFromTable`, `CreateTable` 形式
- **schema.rb のコミット**: マイグレーション追加時に必ず schema.rb も一緒にコミット
- **NOT NULL 制約**: 新しいカラムはデフォルト値付き NOT NULL を推奨
- **外部キー制約**: `add_foreign_key` を明示的に追加
- **本番環境での安全性**: `add_index :concurrently`, `remove_column` は段階的に

#### 5.2.5 Testing (`rails-testing.md`)

**対象パス:** `spec/**/*.rb`, `test/**/*.rb`, `**/*.rb`

主要ルール:
- **テストピラミッド**: Unit Tests (多) > Integration Tests (中) > System Tests (少)
- **RSpec 規約**:
  - `describe` でクラス/メソッドを指定、`context` で条件分岐
  - `let` / `let!` で遅延評価・即時評価を使い分け
  - `subject` で対象を明示
  - `shared_examples` / `shared_context` で DRY に
  - `before` は最小限のセットアップのみ
- **Minitest 規約**:
  - テストメソッドは `test_` prefix
  - assert 系メソッドを活用
  - fixtures でテストデータを管理
- **FactoryBot**: テストデータ生成には FactoryBot（RSpec の場合）。`create` より `build` / `build_stubbed` を優先
- **テスト対象の分離**: 外部 API はモック/スタブ（WebMock, VCR）
- **System Tests**: Capybara + headless browser。ユーザーシナリオのE2Eテスト
- **カバレッジ**: SimpleCov で計測。80% 以上を目標

#### 5.2.6 Security (`rails-security.md`)

**対象パス:** `**/*.rb`, `**/*.erb`

主要ルール:
- **Strong Parameters**: 許可するパラメータを明示的に指定（Mass assignment 防止）。Rails 8 では `params.expect` を優先
- **CSRF 対策**: `protect_from_forgery` を有効化（Rails デフォルト）
- **XSS 防止**: ERB では自動エスケープを信頼。`raw` / `html_safe` は最小限に
- **SQL インジェクション**: プレースホルダーを必ず使用。文字列補間で SQL を組み立てない
- **認証・認可**: Rails 8 認証ジェネレータ or Devise。認可には Pundit / CanCanCan
- **Brakeman**: 静的解析でセキュリティ脆弱性を検出。CI に組み込み
- **bundler-audit**: 依存 gem のセキュリティ脆弱性を検出
- **rack-attack**: レートリミティング、IP ブロッキング
- **secure_headers**: セキュリティヘッダの一括適用
- **暗号化**: `Rails.application.credentials` で秘密情報を管理。`.env` にハードコードしない
- **セッション管理**: Rails デフォルトは cookie store（署名付き・暗号化済み）。機密データを大量に扱う場合や複数サーバー環境では ActiveRecord セッションストアを検討（OWASP 推奨）
- **HTTPS**: 本番環境では `config.force_ssl = true`

```ruby
# DO: SQL インジェクション防止 - プレースホルダーを使用
User.where("email = ?", params[:email])
User.where(email: params[:email])

# DON'T: 文字列補間で SQL を直接組み立てる
User.where("email = '#{params[:email]}'")  # SQL インジェクション脆弱性

# DO: XSS 防止 - ERB の自動エスケープに任せる
<%= user.bio %>

# DON'T: raw / html_safe を安易に使用
<%= user.bio.html_safe %>  # XSS 脆弱性（ユーザー入力を信頼している）
```

#### 5.2.7 Performance (`rails-performance.md`)

**対象パス:** `**/*.rb`, `**/*.erb`

主要ルール:
- **N+1 対策**: includes / preload / eager_load（ActiveRecord と重複するが強調）
- **Fragment Caching**: ビューの部分キャッシュ。`cache` ヘルパーを活用
- **Russian Doll Caching**: ネストしたキャッシュフラグメント。自動依存解決
- **Low-level Caching**: `Rails.cache.fetch` で任意のデータをキャッシュ
- **Solid Cache (Rails 8)**: Redis 不要のデータベースベースキャッシュ。Rails 8 新規プロジェクトのデフォルト。`config/cache.yml` でキュー別 TTL を設定可能
- **Solid Queue (Rails 8)**: Active Job バックエンド。Rails 8 新規プロジェクトのデフォルト。`config/queue.yml` でキュー設計を管理
- **データベースインデックス**: 適切なインデックス設計で 10x 以上の改善
- **Counter Cache**: `belongs_to :parent, counter_cache: true` で COUNT クエリを排除
- **Background Jobs**: 重い処理は Solid Queue（Rails 8 デフォルト）/ Sidekiq でバックグラウンド実行
- **Pagination**: kaminari / pagy で大量レコードのページネーション
- **select / pluck**: 必要なカラムのみ取得

**Solid Queue キュー設計（Rails 8）:**
```yaml
# config/queue.yml
production:
  dispatchers:
    - polling_interval: 1
      batch_size: 500
  workers:
    - queues: "critical"      # 決済・認証など即時性が必要な処理
      threads: 3
      processes: 2
    - queues: "default"       # 通常業務ジョブ
      threads: 5
    - queues: "bulk_mailer"   # メール一括送信など低優先度の処理
      threads: 2
      polling_interval: 10
```

**Solid Cache TTL 戦略（Rails 8）:**
```ruby
# config/environments/production.rb
config.cache_store = :solid_cache_store

# DO: キャッシュは必ず TTL を設定し、stale なデータの蓄積を防ぐ
Rails.cache.fetch("user_#{id}_profile", expires_in: 1.hour) do
  user.build_profile_summary
end

# DON'T: TTL なしで大量データをキャッシュ（ストレージを圧迫）
Rails.cache.write("all_products", Product.all.to_a)
```

#### 5.2.8 API Design (`rails-api.md`)

**対象パス:** `app/controllers/api/**/*.rb`, `**/*.rb`

主要ルール:
- **バージョニング**: `/api/v1/` prefix + `Api::V1::` namespace
- **Serializer**: jsonapi-serializer（JSON:API 準拠）or jbuilder（柔軟性重視）
- **HTTP ステータスコード**: 適切なステータスコードを返す（`:ok`, `:created`, `:unprocessable_entity` 等）
- **ページネーション**: Link ヘッダーでページネーション情報を返す
- **エラーレスポンス**: 一貫した JSON エラーフォーマット
- **認証**: Token ベース認証（JWT or API key）
- **レートリミティング**: rack-attack で API エンドポイントを保護
- **Idempotency**: 冪等性を考慮した設計

#### 5.2.9 Anti-patterns (`rails-antipatterns.md`)

**対象パス:** `**/*.rb`

主要ルール:
- **Fat Controller**: ビジネスロジックを Controller に書かない
- **God Model**: 1 つの Model が多すぎる責務を持たない。Concerns / 分割で対処
- **過度な Callbacks**: `before_save` / `after_create` の連鎖は予測困難。明示的なメソッド呼び出しを推奨
- **Service Object の乱用**: `-er` 命名（Manager, Processor）は避ける。ドメインモデルとしての抽象化を検討
- **Concerns の誤用**: 単一クラスの行数削減のために使わない。複数クラス間の共有機能のためのみ
- **例外による制御フロー**: 例外は異常系のみ。正常な分岐に例外を使わない
- **Raw SQL の多用**: ActiveRecord クエリインターフェースで表現可能なものは AR を使う
- **ネストしたトランザクション**: Service Object 間でトランザクションがネストする問題
- **default_scope**: 予期しないクエリ条件を暗黙的に追加。明示的な scope を使う
- **Skip Validations**: `update_column` / `save(validate: false)` は原則使わない

### 5.3 ディレクトリ構造案

```
custom-slash-command/
└── rules/
    └── rails/
        ├── rails-ruby-style.md        # Ruby スタイル・命名規約
        ├── rails-architecture.md      # MVC・アーキテクチャパターン
        ├── rails-activerecord.md      # ActiveRecord・クエリ
        ├── rails-migrations.md        # マイグレーション・スキーマ
        ├── rails-testing.md           # テスト規約
        ├── rails-security.md          # セキュリティ
        ├── rails-performance.md       # パフォーマンス
        ├── rails-api.md               # API 設計
        └── rails-antipatterns.md      # アンチパターン

対象プロジェクト/
└── .claude/
    └── rules/
        └── rails -> ~/path/to/custom-slash-command/rules/rails/
```

### 5.4 Go / TS / React ルールとの対応表

| Go ルール | TS ルール | React ルール | Rails ルール |
|-----------|----------|-------------|-------------|
| go-style-naming | ts-style-naming | - | rails-ruby-style |
| go-error-handling | ts-error-handling | - | (rails-architecture に統合) |
| go-concurrency | ts-async-patterns | - | (rails-performance に統合) |
| go-interfaces | ts-type-system | - | (rails-architecture に統合) |
| go-testing | - | react-testing | rails-testing |
| go-security | - | react-security | rails-security |
| go-performance | ts-performance | react-performance | rails-performance |
| go-antipatterns | ts-antipatterns | react-antipatterns | rails-antipatterns |
| - | - | react-components | rails-architecture |
| - | - | react-state | rails-activerecord |
| - | - | - | rails-migrations (Rails 固有) |
| - | - | - | rails-api (Rails 固有) |

### 5.5 Constraints & Dependencies

- Claude Code の rules ファイルは `.claude/rules/` 配下に配置が必要
- YAML フロントマターの `paths` でスコープ制御
- 各ファイル 200 行以下推奨
- Rails 7.1+ / Rails 8 を前提（Solid Queue, Solid Cache 等）
- Ruby 3.2+ を前提（pattern matching, Data class 等）
- RuboCop / rubocop-rails のルールと整合性を保つ

## 6. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| rules が長すぎてコンテキストを圧迫 | High | Medium | 9 ファイルに分割、各 200 行以下厳守 |
| Rails バージョンアップで陳腐化 | Medium | Medium | バージョン前提を明記、定期レビュー |
| RSpec / Minitest 両対応で冗長に | Medium | Medium | テストファイルで両方記載、paths で分岐も検討 |
| Service Object の是非で意見が分かれる | Low | High | 両論併記し、チームで決定するガイドラインに |
| 他ルール（CLAUDE.md）との矛盾 | Medium | Low | 既存の CLAUDE.md と整合性確認 |
| Rails 固有すぎて汎用性が低い | Low | Low | Convention over Configuration の哲学に従い許容 |

## 7. Open Questions

- [ ] Q1: RSpec と Minitest のどちらをデフォルトとして推奨するか（プロジェクト依存）
  - **推奨案**: Rails 8 デフォルトの Minitest を基本として推奨。RSpec はチームが採用している場合のオプション扱いとし、`rails-testing.md` で両方を記載する。新規プロジェクトには Minitest を推奨することで、gem 依存を最小化できる。
- [ ] Q2: Hotwire (Turbo / Stimulus) 固有のルールを含めるか
  - **推奨案**: スコープ内として扱い、`rails-hotwire.md` を追加ファイルとして検討する（P2 優先度）。Rails 7+ の標準フロントエンドとして採用が広いため、Turbo Frames / Turbo Streams の基本パターンと Stimulus の命名規約（`data-controller`、targets、values）を最低限カバーする。spec フェーズで詳細スコープを確定する。
- [ ] Q3: ERB vs Slim/Haml のテンプレートエンジン規約を含めるか
  - **推奨案**: ERB のみをカバー（Rails デフォルト）。Slim/Haml は gem 依存のオプションであり、プロジェクト固有の判断に委ねる。スコープ外として明示する。
- [ ] Q4: Rails 8 の Solid Queue / Solid Cache を前提とするか、Sidekiq / Redis も併記するか
  - **推奨案**: Rails 8 新規プロジェクトでは Solid Queue / Solid Cache をデフォルトとして記載。Sidekiq / Redis は既存プロジェクトや高スループット要件向けの代替として併記する。`rails-performance.md` で両方のパターンを提供する。
- [ ] Q5: RuboCop の推奨設定（`.rubocop.yml`）も rules として提供するか → scope 外として別途検討
  - **推奨案**: 本 rules のスコープ外。RuboCop 設定はプロジェクト固有の要件が大きく、別途テンプレートリポジトリで管理するのが適切。`rails-ruby-style.md` では RuboCop との整合性を示すにとどめる。
- [ ] Q6: Devise vs Rails 8 認証ジェネレータのどちらを推奨するか
  - **推奨案**: 新規プロジェクトには Rails 8 認証ジェネレータを推奨（gem 依存なし、コードが自プロジェクト内に生成されカスタマイズ容易）。Devise は既存プロジェクトや OAuth / 多要素認証など高度な機能が必要な場合の選択肢として併記する。

## 8. Recommendations

### 推奨アプローチ

1. **9 ファイル構成**: Ruby スタイル、アーキテクチャ、ActiveRecord、マイグレーション、テスト、セキュリティ、パフォーマンス、API、アンチパターン
2. **言語別ディレクトリ**: `rules/rails/` 構造を採用（Go / TS / React と並列）
3. **paths スコープ**: 各ファイルに適切な paths を設定し、関連ファイル編集時のみロード
4. **DO / DON'T 形式**: 既存ルールと同一フォーマットでコード例付き
5. **Rails 8 対応**: Solid Queue / Solid Cache / 認証ジェネレータ等の最新機能を反映

### Rules の優先カテゴリ（実装順）

| Priority | Category | File | 理由 |
|----------|----------|------|------|
| P0 | Security | rails-security.md | セキュリティ問題は発見が遅れるほどコスト増。Rails 固有の脆弱性が多い |
| P0 | ActiveRecord | rails-activerecord.md | N+1 問題は Rails で最も頻出するパフォーマンス問題 |
| P0 | Architecture | rails-architecture.md | MVC パターンの適切な適用が Rails 開発の基本 |
| P1 | Ruby Style | rails-ruby-style.md | コミュニティ標準に沿ったスタイルの統一 |
| P1 | Testing | rails-testing.md | テスト品質が直接コード品質に影響 |
| P1 | Anti-patterns | rails-antipatterns.md | 既知の落とし穴を事前回避 |
| P2 | Migrations | rails-migrations.md | 安全なスキーマ変更の担保 |
| P2 | Performance | rails-performance.md | キャッシュ・最適化パターン |
| P2 | API Design | rails-api.md | API モードのプロジェクトで必要 |

## 9. Next Steps

- [ ] Proceed to `/my:spec` phase with: `20260407-rails-rules`
- [ ] `rules/rails/` ディレクトリ構造の確定
- [ ] 各カテゴリの rules ファイル作成（P0 から着手）
- [ ] 既存 Rails プロジェクトでの動作検証
- [ ] RuboCop 設定との整合性確認

---
**Created:** 2026-04-07
**Status:** Draft
**Sources:**
- [Ruby Style Guide](https://github.com/rubocop/ruby-style-guide)
- [Rails Style Guide](https://github.com/rubocop/rails-style-guide)
- [Rails Guides](https://guides.rubyonrails.org/)
- [RuboCop Rails](https://docs.rubocop.org/rubocop-rails/)
- [OWASP Ruby on Rails Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Ruby_on_Rails_Cheat_Sheet.html)
- [Rails 8.0 Release Notes](https://guides.rubyonrails.org/8_0_release_notes.html)
- [strong_migrations gem](https://github.com/ankane/strong_migrations)
- [Bullet gem](https://github.com/flyerhzm/bullet)
- [Rails Best Practices 2025](https://medium.com/@alessandro_89911/rails-best-practices-2025-for-us-why-boring-works-14028f8ef11b)
- [10 Best Practices for Clean & Maintainable Rails Code](https://rubyroidlabs.com/blog/2025/06/best-practices-clean-and-maintainable-ror-code/)
