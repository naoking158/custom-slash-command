# Research: Gemini CLI Agentic Execution Issues

## 1. Overview

`/do-by-gemini` コマンドで gemini-cli を使用して agentic に実行する際、ログファイルに何も出力されず、gemini-cli が正常に動作していない問題の調査と解決策の研究。

## 2. Problem Statement

現在の `/do-by-gemini` コマンドには以下の問題がある：

1. **ログファイルに出力がない** - `tee` コマンドでの出力キャプチャが機能していない
2. **gemini-cli が正常に動作しない** - コマンド実行自体に問題がある
3. **agentic モードが有効になっていない可能性** - ファイル編集などのツール使用が期待通りに動作しない

## 3. Requirements Analysis

### 3.1 Functional Requirements

- [x] FR-001: gemini-cli を headless mode で実行できること
- [x] FR-002: プロンプトを非対話的に渡せること
- [x] FR-003: YOLO mode (-y) で自動承認が動作すること
- [x] FR-004: 実行出力をリアルタイムでストリーミングできること
- [x] FR-005: 出力をログファイルに保存できること
- [ ] FR-006: gemini-cli がファイル編集を実行できること（agentic mode）

### 3.2 Non-Functional Requirements

- [x] NFR-001: API 認証が正しく設定されていること
- [ ] NFR-002: 環境変数に不正な文字が含まれていないこと
- [x] NFR-003: タイムアウト処理が適切であること
- [x] NFR-004: エラーハンドリングが十分であること

## 4. Stakeholder Needs

| Stakeholder | Need | Priority |
|-------------|------|----------|
| Developer | gemini-cli で計画を実行したい | High |
| Developer | 実行ログをファイルに保存したい | High |
| Developer | リアルタイムで出力を確認したい | Medium |
| Developer | エラー時の診断情報が欲しい | Medium |

## 5. Technical Investigation

### 5.1 発見された問題

#### 5.1.1 API キーの Unicode 文字問題 (Critical)

**症状:**
```
[API Error: Cannot convert argument to a ByteString because the character at index 0 has a value of 8206 which is greater than 255.]
```

**原因:**
環境変数 `GEMINI_API_KEY` の先頭に不可視の Unicode 文字（U+200E: Left-to-Right Mark）が含まれている。

**検証結果:**
```
$ printenv GEMINI_API_KEY | xxd | head -5
00000000: e280 8e41 497a 6153 7943 7543 4b74 4144  ...AIzaSyCuCKtAD
```

`e2 80 8e` は UTF-8 エンコードされた U+200E（Left-to-Right Mark）。

**解決策:**
1. 環境変数を再設定して不正な文字を除去
2. シェル設定ファイル（`.zshrc` など）で API キーを確認・修正
3. `~/.gemini/.env` ファイルを使用する（推奨）

### 5.1.2 Headless Mode の理解

gemini-cli は以下の方法で非対話的に実行できる：

| Method | Flag | Description |
|--------|------|-------------|
| Direct Prompt | `-p "prompt"` | プロンプトを直接渡す |
| Stdin | `echo "prompt" \| gemini` | 標準入力からプロンプトを受け取る |
| Combined | `cat file \| gemini -p "instructions"` | ファイル内容 + 指示 |

### 5.1.3 YOLO Mode と Agentic 実行

- `-y` または `--yolo` フラグで自動承認モードを有効化
- YOLO mode ではすべてのツール呼び出し（ファイル編集、コマンド実行）が自動承認される
- デフォルトで sandbox mode が有効になる場合がある

### 5.1.4 出力形式オプション

| Option | Description |
|--------|-------------|
| `--output-format text` | テキスト出力（デフォルト） |
| `--output-format json` | JSON 構造化出力 |

### 5.2 Technology Options

| Option | Pros | Cons | Recommendation |
|--------|------|------|----------------|
| Direct `-p` execution | シンプル、低オーバーヘッド | 長いプロンプトで問題の可能性 | 短いプロンプト向け |
| File-based prompt | 長いプロンプト対応、デバッグ容易 | 一時ファイル管理が必要 | **推奨** |
| Stdin pipe | 柔軟性が高い | エンコーディング問題の可能性 | 条件付き推奨 |

### 5.3 Constraints & Dependencies

**依存関係:**
- gemini-cli v0.1.9+（現在インストール済み）
- 有効な `GEMINI_API_KEY`（不正文字なし）
- Node.js 環境（gemini-cli の内部依存）

**制約:**
- YOLO mode はデフォルトで sandbox を有効化
- 長時間の実行はタイムアウトの可能性
- ネットワーク接続が必要

## 6. Risk Assessment

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| API キーに不正文字 | Critical | High (確認済み) | 環境変数の再設定、`.env` ファイル使用 |
| プロンプトのエンコーディング | High | Medium | ファイルベースのプロンプト渡し |
| Sandbox によるファイル編集制限 | Medium | Medium | `--sandbox=false` または設定変更 |
| 長時間実行のタイムアウト | Medium | Low | 適切なタイムアウト設定 |
| ストリーミング出力の遅延 | Low | Medium | バッファリング設定の調整 |

## 7. Open Questions

- [x] Q1: API キーの問題はどう解決するか？ → **環境変数の再設定**
- [x] Q2: Headless mode は正しく動作するか？ → **API キー修正後に検証が必要**
- [ ] Q3: Sandbox mode は無効化すべきか？ → **ファイル編集が必要なら無効化**
- [ ] Q4: 長いプロンプトの最適な渡し方は？ → **ファイルベースを推奨**
- [ ] Q5: `tee` でのログ保存が動作しない原因は？ → **API キー問題解決後に再検証**

## 8. Recommendations

### 8.1 Immediate Fix（即座の修正）

1. **API キーの修正**
   ```bash
   # ~/.zshrc または ~/.bashrc で
   export GEMINI_API_KEY="AIzaSy..." # 引用符で囲み、コピペ時の不正文字を除去

   # または ~/.gemini/.env を使用
   echo 'GEMINI_API_KEY="AIzaSy..."' > ~/.gemini/.env
   ```

2. **修正後の動作確認**
   ```bash
   gemini -p "Say hello" 2>&1
   ```

### 8.2 Implementation Improvements（実装改善）

1. **ファイルベースのプロンプト渡し**
   ```bash
   # プロンプトを一時ファイルに保存
   prompt_file=$(mktemp)
   cat > "$prompt_file" << 'PROMPT'
   {plan_content}
   PROMPT

   # ファイルからプロンプトを読み込んで実行
   cat "$prompt_file" | gemini -y 2>&1 | tee "$log_file"
   ```

2. **環境変数の事前検証**
   ```bash
   # API キーの検証（不正文字チェック）
   if ! printenv GEMINI_API_KEY | grep -q '^AIza'; then
     echo "Error: Invalid GEMINI_API_KEY format"
     exit 1
   fi
   ```

3. **エラーハンドリングの強化**
   - API エラーの詳細なパース
   - リトライロジックの追加
   - タイムアウト時の部分結果保存

### 8.3 Best Practices for Agentic Execution

1. **チェックポイントの活用**
   ```bash
   gemini -y --checkpointing -p "..."
   ```

2. **Sandbox の適切な設定**
   - 信頼できるプロジェクトでは `--sandbox=false` を検討
   - または設定ファイルで sandbox behavior を調整

3. **出力の適切なキャプチャ**
   ```bash
   # unbuffered output for real-time streaming
   script -q /dev/null gemini -y -p "..." 2>&1 | tee "$log_file"
   ```

## 9. Next Steps

1. [ ] API キーの不正文字を修正
2. [ ] 修正後の gemini-cli 動作確認
3. [ ] `/do-by-gemini` コマンドの実装を更新
   - 環境変数検証の追加
   - ファイルベースのプロンプト渡しに変更
   - エラーハンドリングの強化
4. [ ] 統合テストの実施
5. [ ] ドキュメントの更新

---
**Created:** 2026-01-21
**Status:** Draft
**Identifier:** gemini-cli-agentic-execution
