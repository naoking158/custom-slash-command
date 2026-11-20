# Change Analysis: 全 agents で modular-mcp を有効化

## 1. Current Behavior

### 1.1 Agent 定義の現状

| Agent | tools | mcpServers | model |
|-------|-------|------------|-------|
| researcher | Read, Glob, Grep, Write, Bash, WebSearch, WebFetch | `gemini-grounded-search` | sonnet |
| specifier | Read, Glob, Grep, Write | (なし) | inherit |
| reviewer | Read, Glob, Grep, Write | (なし) | opus |
| planner | Read, Glob, Grep, Write, Bash | (なし) | inherit |
| implementer | Read, Glob, Grep, Write, Edit, Bash | (なし) | sonnet |
| fixer | Read, Glob, Grep, Write, Edit | (なし) | sonnet |
| changer | Read, Glob, Grep, Write, Edit, Bash | (なし) | sonnet |

### 1.2 modular-mcp の構成

`~/.claude/modular-mcp.json` で以下のツールが提供されている:

- **playwright**: ブラウザ自動化・E2E テスト
- **morphllm-fast-apply**: 高速コード変換
- **chrome-devtools**: Chrome DevTools デバッグ
- **magic**: UI コンポーネント生成 (21st.dev)
- **tavily**: Web 検索・リアルタイム情報取得
- **serena**: セマンティックコード解析
- **sequential-thinking**: 多段推論エンジン
- **context7**: 公式ライブラリドキュメント参照

### 1.3 MCP サーバーの利用状況

- メインセッション: `modular-mcp` と `gemini-grounded-search` が利用可能
- Subagent: `researcher` のみ `gemini-grounded-search` を指定
- 他の 6 agent は MCP サーバーへのアクセスなし

## 2. Desired Behavior

全 7 agent の frontmatter に `mcpServers: modular-mcp` を追加し、subagent からも modular-mcp 経由の各種ツール（tavily, context7, sequential-thinking 等）を利用可能にする。

### 2.1 Acceptance Criteria

- [ ] 全 agent の frontmatter に `mcpServers` フィールドが存在すること
- [ ] 全 agent で `modular-mcp` が指定されていること
- [ ] `researcher` は既存の `gemini-grounded-search` も維持すること
- [ ] agent の `tools` や `model` など他のフィールドは変更しないこと

## 3. Gap Analysis

### 3.1 変更が必要なファイル

| File | Current mcpServers | After |
|------|--------------------|-------|
| `agents/researcher.md` | `gemini-grounded-search` | `gemini-grounded-search, modular-mcp` |
| `agents/specifier.md` | (なし) | `modular-mcp` |
| `agents/reviewer.md` | (なし) | `modular-mcp` |
| `agents/planner.md` | (なし) | `modular-mcp` |
| `agents/implementer.md` | (なし) | `modular-mcp` |
| `agents/fixer.md` | (なし) | `modular-mcp` |
| `agents/changer.md` | (なし) | `modular-mcp` |

### 3.2 変更しないもの

- `tools` フィールド（各 agent 固有のツールセットは維持）
- `model` フィールド
- `description` フィールド
- agent 本文（Instructions, Constraints, Return Format）
- `~/.claude/modular-mcp.json`（MCP サーバー定義自体は変更不要）

## 4. Impact Assessment

### 4.1 影響範囲

- **直接影響**: 7 つの agent 定義ファイル（frontmatter のみ）
- **間接影響**: なし（MCP サーバー定義自体は変更しない）

### 4.2 リスク

| リスク | 重要度 | 対策 |
|--------|--------|------|
| mcpServers フィールドの複数指定構文が未検証 | Medium | researcher で `gemini-grounded-search, modular-mcp` の動作を確認 |
| modular-mcp が不要な agent に付与されるコスト（起動時間等） | Low | modular-mcp は lazy load のため影響は最小限 |

### 4.3 Breaking Changes

なし。既存の動作に影響を与えない追加のみ。
