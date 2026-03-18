# Implementation Plan: Gemini CLI Agentic Execution Fix

## 1. Overview

`/do-by-gemini` コマンドで gemini-cli を使用した agentic 実行を正常に動作させるための改善。API キーの Unicode 文字問題を検出し、ファイルベースのプロンプト渡しを実装して、信頼性の高い agentic 実行を実現する。

### 1.1 Input Source
- **Source Type:** Feature
- **Source Document:** `docs/specs/20260121-gemini-cli-agentic-execution.md`

### 1.2 References
- Specification: `docs/specs/20260121-gemini-cli-agentic-execution.md`
- Research: `docs/research/20260121-gemini-cli-agentic-execution.md`

### 1.3 Implementation Strategy
1. API キー検証機能を実装し、不正文字を事前検出
2. ファイルベースのプロンプト渡しに変更してエンコーディング問題を回避
3. ストリーミング出力とログ保存を確実に動作させる
4. エラーハンドリングを強化し、ユーザーに適切なガイダンスを提供

---

## 2. Affected Files

### 2.1 Files to Create

| File Path | Purpose | Priority |
|-----------|---------|----------|
| なし | 既存ファイルの修正のみ | - |

### 2.2 Files to Modify

| File Path | Changes Required | Impact |
|-----------|------------------|--------|
| `prompts/9_do_by_gemini.md` | API キー検証ステップ追加、ファイルベースプロンプト実行への変更、エラーハンドリング強化 | High |
| `commands/do-by-gemini.md` | エラーコードとドキュメント更新 | Medium |

### 2.3 Files to Delete (if any)

| File Path | Reason |
|-----------|--------|
| なし | - |

---

## 3. Implementation Steps

### Phase 1: API キー検証機能

#### Step 1.1: API キー検証ステップの追加
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- Step 1 "Parse Options and Check Prerequisites" に API キー検証を追加
- 検証内容:
  1. GEMINI_API_KEY が設定されているか
  2. "AIza" で始まるか
  3. Unicode 不正文字（e280 など）が含まれていないか
- 各エラー種別に対応するエラーメッセージを追加
```

**Verification:**
- [ ] 存在しない API キーでエラーメッセージが表示される
- [ ] 不正なプレフィックスでエラーメッセージが表示される
- [ ] Unicode 文字検出でエラーメッセージと修正方法が表示される

#### Step 1.2: API キーエラーメッセージの追加
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- error-api-key-missing メッセージ追加
- error-api-key-invalid-prefix メッセージ追加
- error-api-key-unicode メッセージ追加（修正方法含む）
```

**Verification:**
- [ ] 各エラーメッセージが適切なフォーマットで定義されている

---

### Phase 2: ファイルベースプロンプト実行

#### Step 2.1: プロンプト構築方法の変更
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- Step 4 "Construct Gemini Prompt" を Step 5 "Execute with File-based Prompt" に統合
- プロンプトを一時ファイルに書き出す処理を追加
- 一時ファイルから stdin 経由で gemini に渡す
- 実行後に一時ファイルを削除する
```

**Verification:**
- [ ] 一時ファイルが正しく作成される
- [ ] マルチバイト文字が正しく処理される
- [ ] 実行後に一時ファイルが削除される

#### Step 2.2: 実行コマンドの更新
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- Step 5 のコマンド実行部分を更新
- 変更前: gemini -p "{prompt}" -y 2>&1 | tee ${log_path}
- 変更後: cat "$prompt_file" | gemini -y 2>&1 | tee "$log_path"
- モデル指定がある場合: cat "$prompt_file" | gemini -m {model} -y 2>&1 | tee "$log_path"
- パイプライン全体の終了コードを正しくキャプチャ (PIPESTATUS)
```

**Verification:**
- [ ] ストリーミング出力がリアルタイムで表示される
- [ ] ログファイルに出力が保存される
- [ ] 終了コードが正しくキャプチャされる

---

### Phase 3: エラーハンドリング強化

#### Step 3.1: API エラーの詳細処理
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- error-gemini-execution を拡張
- API エラーのパターンマッチング追加:
  - "Cannot convert argument to a ByteString" → API キーの Unicode 問題
  - "401" → 認証エラー
  - "429" → レートリミット
  - "Network" → ネットワークエラー
- 各パターンに対応する修正提案を表示
```

**Verification:**
- [ ] 各 API エラーパターンが正しく検出される
- [ ] 適切な修正提案が表示される

#### Step 3.2: タイムアウト処理の改善
**File:** `prompts/9_do_by_gemini.md`
**Action:** Modify

**Details:**
```
- タイムアウト時に部分結果をログに保存
- 部分結果の有無をユーザーに通知
- レビューを部分結果に対して実行するオプションを提供
```

**Verification:**
- [ ] タイムアウト時にログファイルが保持される
- [ ] 部分結果の存在がユーザーに通知される

---

### Phase 4: ドキュメント更新

#### Step 4.1: コマンドドキュメントの更新
**File:** `commands/do-by-gemini.md`
**Action:** Modify

**Details:**
```
- Exit Codes セクションに API キーエラー (1) を追加
- Error Handling セクションに API キー検証エラーを追加
- Gemini-Specific Notes に API キー要件を追加
```

**Verification:**
- [ ] Exit Codes が正しく文書化されている
- [ ] エラーハンドリングが網羅的に文書化されている

#### Step 4.2: 実装ノートの追加
**File:** `commands/do-by-gemini.md`
**Action:** Modify

**Details:**
```
- Implementation Notes セクションを追加（オプション）
- API キー検証のコードサンプル
- ファイルベースプロンプト実行のコードサンプル
```

**Verification:**
- [ ] 実装例が明確に記載されている

---

## 4. Dependencies & Prerequisites

### 4.1 External Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| gemini-cli | >= 0.1.9 | Gemini API の CLI ツール |

### 4.2 Internal Dependencies

| Module | Status | Notes |
|--------|--------|-------|
| prompts/9_do_by_gemini.md | Exists | 修正対象 |
| commands/do-by-gemini.md | Exists | 修正対象 |

---

## 5. Verification Checklist

### 5.1 Pre-Implementation
- [x] Spec document reviewed and approved
- [x] Dependencies identified and available
- [x] Environment set up

### 5.2 Post-Implementation
- [ ] All unit tests passing
- [ ] All integration tests passing
- [ ] Code review completed
- [ ] Documentation updated
- [ ] No linting/type errors

### 5.3 Acceptance Criteria Verification
<!-- Map back to spec acceptance criteria -->
- [ ] US-001: API キーの検証
  - [ ] AC-001: API キーが `AIza` で始まることを検証する
  - [ ] AC-002: API キーに不可視の Unicode 文字が含まれていないことを検証する
  - [ ] AC-003: 検証失敗時に明確なエラーメッセージを表示する
  - [ ] AC-004: エラーメッセージに修正方法を含める
- [ ] US-002: ファイルベースのプロンプト実行
  - [ ] AC-001: プロンプトを一時ファイルに安全に書き出す
  - [ ] AC-002: 一時ファイルから gemini-cli にプロンプトを渡す
  - [ ] AC-003: 実行完了後に一時ファイルを削除する
  - [ ] AC-004: マルチバイト文字を正しく処理する
- [ ] US-003: リアルタイムストリーミング出力
  - [ ] AC-001: 出力がリアルタイムでコンソールに表示される
  - [ ] AC-002: 出力が同時にログファイルに保存される
  - [ ] AC-003: バッファリングによる遅延が最小限である
- [ ] US-004: Agentic モードでのファイル編集
  - [ ] AC-001: YOLO モード (-y) で自動承認が有効になる
  - [ ] AC-002: Sandbox 設定が適切に管理される
  - [ ] AC-003: ファイル編集操作が正常に実行される
- [ ] US-005: エラー診断とリカバリ
  - [ ] AC-001: API エラーの詳細がログに記録される
  - [ ] AC-002: タイムアウト時に部分結果が保存される
  - [ ] AC-003: エラーの種類に応じた対処方法が提示される

---

## 6. Rollback Plan

1. git でコミット前の状態に戻す: `git checkout -- prompts/9_do_by_gemini.md commands/do-by-gemini.md`
2. 以前のバージョンが必要な場合: `git log` で確認し `git checkout <commit> -- <file>` で復元

---

## 7. Estimated Effort

| Phase | Complexity | Notes |
|-------|------------|-------|
| Phase 1 | Low | API キー検証ロジックの追加 |
| Phase 2 | Medium | 実行フローの変更 |
| Phase 3 | Low | エラーメッセージの拡張 |
| Phase 4 | Low | ドキュメント更新 |

---
**Created:** 2026-01-21
**Status:** Ready
**Assignee:** Claude Code
