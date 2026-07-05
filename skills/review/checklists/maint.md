# Maintainability Review Checklist

Purpose: review code for naming quality, comment hygiene, readability, organization, and internal consistency.
Report violations only; severity tags are defaults, adjust with justification.

## Naming (命名)
- [M] 変数名・関数名から目的が読み取れるか (`d`, `tmp`, `data` のような曖昧な名前を避ける)
- [L] 命名規則 (camelCase / snake_case / PascalCase) がプロジェクト内で統一されているか
- [M] ドメイン用語が正確に使われ、同じ概念に複数の名前を使っていないか
- [L] 不要な略語を避けているか (`usrMgr` → `userManager`。`id`, `url`, `api` 等は許容)
- [L] Boolean に `is/has/can/should` プレフィックスがあるか。否定形 (`isNotReady`) を避けているか
- [L] コレクションが複数形か。Map は関係が分かる名前か (`userById`)
- [L] 関数名が動詞で始まるか (`fetchUserData`, `validateInput`)
- [L] 識別子の語順が自然か (英語: 動詞+目的語+修飾語。`getUserById` ✅ / `getByIdUser` ❌)
- [L] 時制・態が状態を正しく反映しているか (`isDeleted` ✅ / `isDelete` ❌、`wasProcessed` ✅ / `isProcess` ❌)
- [L] 単語の組み合わせが意味的に整合しているか (具体的な目的語: `createUser` ✅ / `createData` ⚠️ 曖昧)

## Comments (コメント)
- [L] コメントが「なぜ (Why)」を説明しているか (「何をしているか (What)」だけのコメントは冗長)
- [M] コメントの内容がコードの実際の動作と一致しているか (古いコメントの検出。`ユーザーを削除` と書いて実際は無効化 → ❌)
- [L] コメントアウトされたコードブロックが残っていないか
- [L] TODO/FIXME に Issue 参照 (`// TODO(#123): ...`) が含まれているか
- [M] エクスポートされた関数・クラスに docstring/JSDoc があるか (パラメータ・戻り値が正確か)
- [L] 自明なコードに不要なコメントが付いていないか
- [L] コメント文の文法が正しいか (日本語: てにをは・主述の対応 / 英語: 文構造の崩れがないか)
- [L] 主語・目的語が明示されており、指示対象が曖昧でないか (`これを処理する` → 何を？)

## Readability (可読性)
- [M] 関数が長すぎないか (目安: 30-50行)
- [M] ネストが深すぎないか (目安: 3-4レベル以内)
- [L] Guard clause (早期 return) で異常系を先に処理しているか
- [L] 複合条件 (`&&`/`||` 3つ以上) がヘルパー変数・関数に抽出されているか
- [M] マジックナンバー・マジックストリングが名前付き定数に置き換えられているか
- [L] 論理的なブロック間に適切な空行があり、関連処理がグループ化されているか

## Code Organization (コード構造)
- [M] 1つの関数/クラス/モジュールが1つの責務に集中しているか (SRP)
- [L] 関連する関数・変数が近くに配置されているか (凝集度)
- [M] 使用されていない変数・関数・import・パラメータがないか (Dead code)
- [L] import が整理されているか (標準 → 外部 → 内部。ワイルドカード回避)
- [L] ファイルが大きすぎないか (目安: 300行。過度な分割も避ける)

## Consistency (一貫性)
- [L] 同種のものに同じ命名パターンを使っているか (例: handler は `handleXxx` に統一)
- [M] エラーハンドリングパターンが統一されているか (try-catch / Result 型 の混在回避)
- [L] コードスタイル (インデント、引用符、末尾カンマ) が統一されているか
- [L] 同じ問題に対して同じ解法パターンを使っているか (`map` と `for` の混在回避)
- [L] 同種の関数が同じ形式で値を返しているか (戻り値・引数パターンの統一)
