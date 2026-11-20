# Change Plan: 全 agents で modular-mcp を有効化

## Overview

全 7 agent の frontmatter に `mcpServers: modular-mcp` を追加する。

## Source

- Analysis: `docs/analysis/changes/agents-modular-mcp.md`

## Changes

### Phase 1: researcher の mcpServers 更新

**File**: `agents/researcher.md`

既存の `gemini-grounded-search` に `modular-mcp` を追加。

```yaml
# Before
mcpServers: gemini-grounded-search

# After
mcpServers: gemini-grounded-search, modular-mcp
```

### Phase 2: 他 6 agent に mcpServers 追加

各 agent の frontmatter に `mcpServers: modular-mcp` 行を追加する。
`model:` 行の後（closing `---` の直前）に挿入。

**Files**:
- `agents/specifier.md`
- `agents/reviewer.md`
- `agents/planner.md`
- `agents/implementer.md`
- `agents/fixer.md`
- `agents/changer.md`

```yaml
# Before (例: specifier.md)
---
name: specifier
description: "..."
tools: Read, Glob, Grep, Write
model: inherit
---

# After
---
name: specifier
description: "..."
tools: Read, Glob, Grep, Write
model: inherit
mcpServers: modular-mcp
---
```

## Verification

- [ ] 全 7 ファイルの frontmatter に `mcpServers` が存在すること
- [ ] researcher は `gemini-grounded-search, modular-mcp` であること
- [ ] 他 6 agent は `modular-mcp` であること
- [ ] frontmatter 以外の内容が変更されていないこと

## Rollback

各ファイルから `mcpServers: modular-mcp` 行を削除するだけでロールバック可能。
