---
session_id: 7a063d83-1234-4abc-89de-f0123456789a
date: 2026-06-27
project: custom-slash-command
categories: [mistake, pattern]
confidence: medium
recurrence: 1
status: raw
source_commits: []
tags: [typescript, error-handling]
---

## Request

ユーザは TypeScript で API レスポンスをラップする薄い fetch wrapper を実装したい。
エラー時に投げられる例外を catch する型注釈について Claude に助けを求めた。

## Investigated

- TypeScript 4.4+ で `useUnknownInCatchVariables` がデフォルト有効化されたこと
- `catch (e: any)` を使うと型情報が失われ、後段で `e.message` 等にアクセスする際に
  ランタイムで `undefined` になり得ること
- `Error` を `instanceof` で narrow するか、`unknown` 型のまま安全に accesor を書く
  ためのユーティリティ (`isError(e): e is Error`) を検討

## Learned

- TypeScript の `catch` 句は `unknown` で受けるのが原則。`any` で受けると catch 内で
  型情報が消え、`e.message` などが noisy に通ってしまう。
- `instanceof Error` で narrow するか、`unknown` のまま `typeof` チェックで分岐する。
- プロジェクト共通の `isError` / `toError` ヘルパを `rules/typescript/error-handling.md`
  に明文化しておくと、レビュー時に毎回指摘する必要がなくなる。

## Completed

- fetch wrapper の `catch` 句を `catch (e: unknown)` に修正
- `isError` ヘルパを追加し、エラーログのフォーマットを統一
- 既存テストは挙動変更なし (型注釈のみの変更) でグリーン

## Next Steps / Open Threads

- `rules/typescript/ts-error-handling.md` に「catch は unknown 必須」のルールが
  存在しないため、`/my:retro` で昇格候補に挙がるはず
- Node の `process.on('uncaughtException', ...)` ハンドラ側でも同様の方針を採るか
  別途確認したい (open-question)

## Suggested Actions (promotion candidates)

- target: `rules/typescript/ts-error-handling.md`
  change: catch 句に `unknown` 型注釈を明示するルールと例コードを追記
  rationale: TS 4.4+ の `useUnknownInCatchVariables` default true を前提に、
    `e.message` のような型情報損失を伴う書き方をレビュー前に防ぎたい

<!--
NOTE: 本ファイルはあくまで journal entry の **テンプレ例** である。
実体の journal はリポジトリに置かない。書き込み先は machine-local の
~/.claude/projects/<repo>/memory/journal/ のみ (Spec §3.4 / US-003 invariant)。
このリポジトリ内に docs/journal/ ディレクトリを作ってはならない。
-->
