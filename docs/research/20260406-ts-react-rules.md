# Research: TypeScript & React Coding Rules

## 1. Overview

`rules/go/` に既に整備された Go コーディングルールと同等の品質・構造で、TypeScript および React のコーディングルールを整備する。AI アシスタント（Claude Code 等）がコードレビューやコード生成時に参照するルールファイルとして機能させる。

## 2. Problem Statement

Go のルールは8ファイル（style-naming, error-handling, concurrency, interfaces, testing, security, performance, antipatterns）に分かれて体系的に整備されているが、TypeScript/React には対応するルールが存在しない。フロントエンド開発時のコード品質・一貫性を担保するため、同等のルールセットが必要。

## 3. Requirements Analysis

### 3.1 Functional Requirements
- [x] FR-001: Go ルールと同一フォーマット（YAML frontmatter + DO/DON'T パターン）で作成
- [x] FR-002: TypeScript 5+ のモダンなパターンをカバー（satisfies, const assertions, discriminated unions）
- [x] FR-003: React 18+ のベストプラクティスをカバー（hooks, Server Components 意識, Testing Library）
- [x] FR-004: paths フィールドで適用対象ファイルを指定（`**/*.ts`, `**/*.tsx`）
- [x] FR-005: セキュリティ（XSS, 入力バリデーション）をカバー

### 3.2 Non-Functional Requirements
- [x] NFR-001: 各ルールファイルは100-200行程度に収め、読みやすさを維持
- [x] NFR-002: コード例は実践的で、コピー可能な品質
- [x] NFR-003: Go ルールとのカテゴリ対応を意識し、一貫性を保つ

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| 開発者 | コーディング規約の一貫した適用 | High |
| AI アシスタント | コードレビュー/生成時の参照ルール | High |
| チーム | フロントエンドコードの品質統一 | Medium |

## 5. Technical Investigation

### 5.1 Existing Solutions / Best Practices

調査した主要なリソース:
- **TypeScript Handbook** - Do's and Don'ts セクション
- **Google TypeScript Style Guide** - 命名規則、型使用方針
- **Total TypeScript (Matt Pocock)** - モダン TypeScript パターン
- **React 公式ドキュメント** - Hooks, Server Components, パフォーマンス
- **Testing Library** - テストのベストプラクティス
- **OWASP** - フロントエンドセキュリティ

### 5.2 Technology Options

Go ルールとの対応表に基づくファイル構成案:

| Go ルールファイル | TypeScript 対応 | React 対応 |
|-------------------|----------------|------------|
| go-style-naming.md | ts-style-naming.md | - |
| go-error-handling.md | ts-error-handling.md | - |
| go-concurrency.md | ts-async-patterns.md | - |
| go-interfaces.md | ts-type-system.md | - |
| go-testing.md | - | react-testing.md |
| go-security.md | ts-security.md | react-security.md (統合可) |
| go-performance.md | ts-performance.md | react-performance.md |
| go-antipatterns.md | ts-antipatterns.md | react-antipatterns.md |
| - (Go にない) | - | react-components.md |
| - (Go にない) | - | react-state.md |
| - (Go にない) | - | react-accessibility.md |

**推奨構成** (11ファイル):

**TypeScript (5ファイル)**:
1. `ts-style-naming.md` - 命名規則、ファイル構成、import 整理
2. `ts-type-system.md` - strict mode, generics, utility types, satisfies, discriminated unions
3. `ts-error-handling.md` - Result 型, カスタムエラー, unknown catch
4. `ts-async-patterns.md` - async/await, AbortController, Promise パターン
5. `ts-antipatterns.md` - any 禁止, non-null assertion, namespace 等

**React (6ファイル)**:
1. `react-components.md` - 関数コンポーネント, Props 型定義, composition, hooks
2. `react-state.md` - state 管理, useReducer, Context 分割, 派生値
3. `react-performance.md` - memo, useMemo, useCallback, lazy, key
4. `react-testing.md` - Testing Library, role ベースクエリ, hook テスト
5. `react-security.md` - XSS, dangerouslySetInnerHTML, URL 検証, CSP
6. `react-accessibility.md` - セマンティック HTML, ARIA, キーボードナビ

### 5.3 Constraints & Dependencies

- Go ルールのフォーマット（YAML frontmatter + DO/DON'T 形式）に準拠する必要あり
- TypeScript 5+ / React 18+ を前提とする
- paths フィールドの設定:
  - TypeScript ルール: `**/*.ts`, `**/*.tsx`
  - React ルール: `**/*.tsx` のみ

## 6. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| ルールが多すぎて参照されない | Medium | Medium | カテゴリ毎に100-200行に収める |
| TypeScript/React のバージョンアップで陳腐化 | Low | Medium | バージョン前提を明記、定期レビュー |
| Go ルールとのフォーマット不一致 | Low | Low | 既存ファイルをテンプレートとして使用 |
| セキュリティルールの TS/React 間の重複 | Low | Medium | React security に統合し、TS security は言語レベルに限定 |

## 7. Open Questions
- [x] Q1: TypeScript と React のルールを `rules/typescript/` と `rules/react/` に分けるか、`rules/frontend/` に統合するか → **分ける（Go と同じ粒度）**
- [x] Q2: セキュリティルールを TypeScript / React で分けるか統合するか → **統合して `react-security.md` に（フロントエンド特有のため）**
- [ ] Q3: Next.js / Server Components 固有のルールを含めるか → spec フェーズで決定
- [ ] Q4: ESLint / Prettier 設定の推奨も含めるか → scope 外とし別途検討

## 8. Recommendations

### 推奨アプローチ
1. **Go ルールと同一フォーマット**で作成（YAML frontmatter + DO/DON'T コード例）
2. **11ファイル構成**（TypeScript 5 + React 6）
3. **ディレクトリ構成**: `rules/typescript/` と `rules/react/` に分離
4. **優先度の高いルール**から着手:
   - `ts-type-system.md` (strict mode, any 禁止が最もインパクト大)
   - `react-components.md` (コンポーネント設計の基本)
   - `ts-antipatterns.md` (よくある間違いの防止)

### 重要度ランキング Top 10
| # | ルール | カテゴリ |
|---|--------|---------|
| 1 | `strict: true` + `noUncheckedIndexedAccess` 必須 | TS 型安全 |
| 2 | `any` 禁止、`unknown` + type narrowing を使う | TS 型安全 |
| 3 | enum より `as const` + union literal type | TS モダン |
| 4 | `satisfies` で型チェック + リテラル推論を両立 | TS 5+ |
| 5 | 外部入力は Zod 等で runtime validation | セキュリティ |
| 6 | `React.FC` を使わず明示的 Props 型定義 | React |
| 7 | useEffect を state 同期に使わない（派生値は計算で） | React |
| 8 | Testing Library で role ベースクエリを優先 | テスト |
| 9 | `dangerouslySetInnerHTML` には DOMPurify 必須 | セキュリティ |
| 10 | Server/Client Component の境界を意識する | React 18+ |

## 9. Next Steps
- [x] Proceed to `/my:spec` phase with: `20260406-ts-react-rules`

---
**Created:** 2026-04-06
**Status:** Draft
