# Implementation Plan: TypeScript & React Coding Rules

## 1. Overview

TypeScript および React のコーディングルールを `rules/typescript/` と `rules/react/` に作成する。既存の `rules/go/` と同一フォーマット（YAML frontmatter + DO/DON'T パターン）で、合計 11 ファイルを新規作成する。

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260406-ts-react-rules.md`

### 1.2 References
- Specification: `docs/specs/20260406-ts-react-rules.md`
- Research: `docs/research/20260406-ts-react-rules.md`
- Go Rules (format reference): `rules/go/`

### 1.3 Implementation Strategy
Go ルールのフォーマット（YAML frontmatter → H1 タイトル → H2 セクション → H3 DO/DON'T + コード例）を厳密に踏襲する。TypeScript 5 ファイル → React 6 ファイルの順に作成し、各ファイルは 100-200 行に収める。

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| `rules/typescript/ts-style-naming.md` | 命名規則、ファイル構成、import 整理 | P1 |
| `rules/typescript/ts-type-system.md` | strict mode, generics, utility types, satisfies, discriminated unions | P1 |
| `rules/typescript/ts-error-handling.md` | Result 型, カスタムエラー, unknown catch | P1 |
| `rules/typescript/ts-async-patterns.md` | async/await, AbortController, Promise パターン | P2 |
| `rules/typescript/ts-antipatterns.md` | any 禁止, non-null assertion, namespace 等 | P1 |
| `rules/react/react-components.md` | 関数コンポーネント, Props 型定義, composition, hooks | P1 |
| `rules/react/react-state.md` | state 管理, useReducer, Context 分割, 派生値 | P2 |
| `rules/react/react-performance.md` | memo, useMemo, useCallback, lazy, key | P2 |
| `rules/react/react-testing.md` | Testing Library, role ベースクエリ, hook テスト | P2 |
| `rules/react/react-security.md` | XSS, dangerouslySetInnerHTML, URL 検証, CSP | P1 |
| `rules/react/react-accessibility.md` | セマンティック HTML, ARIA, キーボードナビ | P3 |

### 2.2 Files to Modify

なし。

### 2.3 Files to Delete

なし。

---

## 3. Implementation Steps

### Phase 1: Foundation — ディレクトリ作成 + 高優先度 TypeScript ルール

#### Step 1.1: ディレクトリ作成
**Action:** Create directories

**Details:**
```
- rules/typescript/ ディレクトリを作成
- rules/react/ ディレクトリを作成
```

**Verification:**
- [ ] `rules/typescript/` が存在する
- [ ] `rules/react/` が存在する

#### Step 1.2: ts-style-naming.md 作成
**File:** `rules/typescript/ts-style-naming.md`
**Action:** Create

**Details:**
```
- YAML frontmatter: paths: ["**/*.ts", "**/*.tsx"]
- 命名規則: camelCase (変数/関数), PascalCase (型/クラス/コンポーネント), UPPER_SNAKE_CASE (定数)
- ファイル命名: kebab-case (.ts), PascalCase (.tsx コンポーネント)
- import 整理: named import 優先、barrel export の注意点
- go-style-naming.md のフォーマットを厳密に踏襲
```

**Verification:**
- [ ] YAML frontmatter に paths フィールドがある
- [ ] DO/DON'T パターンでコード例がある
- [ ] 100-200 行に収まっている

#### Step 1.3: ts-type-system.md 作成
**File:** `rules/typescript/ts-type-system.md`
**Action:** Create

**Details:**
```
- YAML frontmatter: paths: ["**/*.ts", "**/*.tsx"]
- strict: true + noUncheckedIndexedAccess 必須
- satisfies 演算子の活用
- discriminated unions パターン
- as const + union literal type（enum の代替）
- utility types の適切な使用
```

**Verification:**
- [ ] satisfies, as const, discriminated unions がカバーされている
- [ ] DO/DON'T 形式で記述されている

#### Step 1.4: ts-antipatterns.md 作成
**File:** `rules/typescript/ts-antipatterns.md`
**Action:** Create

**Details:**
```
- YAML frontmatter: paths: ["**/*.ts", "**/*.tsx"]
- any 禁止 → unknown + type narrowing
- non-null assertion (!) の濫用禁止
- namespace の不使用
- type assertion (as) の最小化
- @ts-ignore / @ts-expect-error の制限
```

**Verification:**
- [ ] any 禁止パターンがカバーされている
- [ ] 各アンチパターンに代替案がある

#### Step 1.5: ts-error-handling.md 作成
**File:** `rules/typescript/ts-error-handling.md`
**Action:** Create

**Details:**
```
- YAML frontmatter: paths: ["**/*.ts", "**/*.tsx"]
- catch の引数は unknown 型で受け取る
- Result 型パターン（成功/失敗を型で表現）
- カスタムエラークラスの定義
- Error cause の活用
```

**Verification:**
- [ ] unknown catch パターンが含まれている
- [ ] Result 型の具体例がある

---

### Phase 2: Core Logic — 残りの TypeScript ルール + 高優先度 React ルール

#### Step 2.1: ts-async-patterns.md 作成
**File:** `rules/typescript/ts-async-patterns.md`
**Action:** Create

**Details:**
```
- YAML frontmatter: paths: ["**/*.ts", "**/*.tsx"]
- async/await の適切な使用（Promise.all での並列実行）
- AbortController によるキャンセル処理
- Promise.allSettled の活用
- トップレベル await の注意点
```

**Verification:**
- [ ] async/await パターンがカバーされている
- [ ] AbortController の例がある

#### Step 2.2: react-components.md 作成
**File:** `rules/react/react-components.md`
**Action:** Create

**Details:**
```
- YAML frontmatter: paths: ["**/*.tsx"]
- React.FC を使わず明示的 Props 型定義
- 関数コンポーネントの書き方
- composition パターン（children, render props）
- カスタム hooks の抽出基準
- コンポーネントの責務分離
```

**Verification:**
- [ ] Props 型定義パターンがある
- [ ] React.FC を使わない理由が説明されている

#### Step 2.3: react-security.md 作成
**File:** `rules/react/react-security.md`
**Action:** Create

**Details:**
```
- YAML frontmatter: paths: ["**/*.tsx"]
- dangerouslySetInnerHTML + DOMPurify 必須
- XSS 防止パターン
- URL 検証（javascript: プロトコル拒否）
- 外部入力の Zod runtime validation
- CSP 準拠の指針
```

**Verification:**
- [ ] XSS 防止の DO/DON'T がある
- [ ] DOMPurify の具体例がある
- [ ] Zod validation の例がある

---

### Phase 3: Integration — 残りの React ルール

#### Step 3.1: react-state.md 作成
**File:** `rules/react/react-state.md`
**Action:** Create

**Details:**
```
- YAML frontmatter: paths: ["**/*.tsx"]
- useState vs useReducer の使い分け
- 派生値は state ではなく計算で導出
- useEffect を state 同期に使わない
- Context の適切な分割
```

**Verification:**
- [ ] useEffect アンチパターンが明記されている
- [ ] 派生値パターンの例がある

#### Step 3.2: react-performance.md 作成
**File:** `rules/react/react-performance.md`
**Action:** Create

**Details:**
```
- YAML frontmatter: paths: ["**/*.tsx"]
- React.memo の適切な使用
- useMemo / useCallback の過剰使用を避ける
- React.lazy + Suspense によるコード分割
- key の適切な設定（index を key にしない）
```

**Verification:**
- [ ] memo 系 hooks の使用基準が明確
- [ ] key アンチパターンが含まれている

#### Step 3.3: react-testing.md 作成
**File:** `rules/react/react-testing.md`
**Action:** Create

**Details:**
```
- YAML frontmatter: paths: ["**/*.tsx"]
- Testing Library のベストプラクティス
- role ベースクエリを優先（getByRole > getByTestId）
- userEvent > fireEvent
- カスタム hooks のテスト（renderHook）
- act() の適切な使用
```

**Verification:**
- [ ] クエリ優先順位が明記されている
- [ ] userEvent の例がある

#### Step 3.4: react-accessibility.md 作成
**File:** `rules/react/react-accessibility.md`
**Action:** Create

**Details:**
```
- YAML frontmatter: paths: ["**/*.tsx"]
- セマンティック HTML 要素の使用
- ARIA 属性の適切な使用（不要な ARIA を避ける）
- キーボードナビゲーション対応
- フォームのラベル付け
```

**Verification:**
- [ ] セマンティック HTML の DO/DON'T がある
- [ ] ARIA の過剰使用への注意がある

---

### Phase 4: Testing — フォーマット検証 + カバレッジ確認

#### Step 4.1: フォーマット検証
**Action:** Verify all files

**Test Cases:**
- [ ] 全 11 ファイルに YAML frontmatter（paths フィールド）がある
- [ ] TypeScript ルール（5 ファイル）の paths が `["**/*.ts", "**/*.tsx"]`
- [ ] React ルール（6 ファイル）の paths が `["**/*.tsx"]`
- [ ] 全ファイルが DO/DON'T パターンを含む
- [ ] 全ファイルが 100-200 行に収まっている
- [ ] Go ルール（`rules/go/`）と同一フォーマット構造

#### Step 4.2: カバレッジ確認
**Action:** Verify against spec requirements

**Test Cases:**
- [ ] Top 10 重要ルールが全てカバーされている:
  1. `strict: true` + `noUncheckedIndexedAccess` → ts-type-system.md
  2. `any` 禁止 → ts-antipatterns.md
  3. enum より `as const` → ts-type-system.md
  4. `satisfies` → ts-type-system.md
  5. Zod runtime validation → react-security.md
  6. `React.FC` 不使用 → react-components.md
  7. useEffect 濫用禁止 → react-state.md
  8. role ベースクエリ → react-testing.md
  9. DOMPurify 必須 → react-security.md
  10. Server/Client 境界意識 → スコープ外（DD-003）
- [ ] User Stories US-001 〜 US-004 の Acceptance Criteria が全て満たされている

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

なし（ルールファイルはドキュメントのみ）。

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| `rules/go/` | Completed | フォーマット参照元 |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [ ] Spec document reviewed and approved
- [ ] Go ルールのフォーマット確認済み

### 5.2 Post-Implementation
- [ ] 全 11 ファイルが作成されている
- [ ] YAML frontmatter が正しい
- [ ] DO/DON'T パターンが一貫している
- [ ] 各ファイルが 100-200 行に収まっている
- [ ] Go ルールとフォーマットが一致している

### 5.3 Acceptance Criteria Verification
- [ ] US-001 AC-001: 各ルールファイルに paths の YAML frontmatter がある
- [ ] US-001 AC-002: DO/DON'T パターンでコード例が提示されている
- [ ] US-001 AC-003: Go ルールと同一フォーマットで記述されている
- [ ] US-002 AC-001: React ルールに paths: ["**/*.tsx"] がある
- [ ] US-002 AC-002: React 18+ のモダンパターンがカバーされている
- [ ] US-002 AC-003: Testing Library のベストプラクティスが含まれている
- [ ] US-003 AC-001: XSS 防止パターンが DO/DON'T 形式で記述されている
- [ ] US-003 AC-002: Zod runtime validation パターンが含まれている
- [ ] US-003 AC-003: URL 検証、CSP の指針が含まれている
- [ ] US-004 AC-001: 命名規則が明確に定義されている
- [ ] US-004 AC-002: アンチパターンが列挙されている
- [ ] US-004 AC-003: 各ファイルが 100-200 行程度

---

## 6. Rollback Plan

1. `rules/typescript/` ディレクトリを削除
2. `rules/react/` ディレクトリを削除

全て新規作成のため、既存コードへの影響なし。

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1: Foundation | Medium | 4 ファイル + ディレクトリ作成 |
| Phase 2: Core Logic | Medium | 3 ファイル作成 |
| Phase 3: Integration | Medium | 4 ファイル作成 |
| Phase 4: Testing | Low | フォーマット検証のみ |

---
**Created:** 2026-04-06
**Status:** Draft
**Assignee:**
