# Security Review Checklist

Purpose: review code and configuration against OWASP Top 10 (2021) and common secret/token handling failures.
Report violations only; severity tags are defaults, adjust with justification.

## OWASP Top 10 (2021)

### A01: Broken Access Control
- [C] 認可チェックの実装
- [H][web] CORS 設定の適切性
- [C] ディレクトリトラバーサル対策

### A02: Cryptographic Failures
- [C] 機密データの暗号化
- [H] 適切なハッシュアルゴリズム使用
- [H][web] TLS 強制

### A03: Injection
- [C] SQLインジェクション対策 (パラメータ化クエリ)
- [C][web] XSS対策 (出力エスケープ)
- [C] コマンドインジェクション対策

### A04: Insecure Design
- [M] 脅威モデリング実施
- [H] セキュアなデフォルト設定

### A05: Security Misconfiguration
- [M] 不要な機能の無効化
- [M] 適切なエラーメッセージ
- [H][web] セキュリティヘッダー設定

### A06: Vulnerable Components
- [H] 依存ライブラリの脆弱性チェック
- [H] 最新パッチ適用状況

### A07: Authentication Failures
- [H] 強力なパスワードポリシー
- [H][web] ブルートフォース対策
- [H][web] セッション管理の適切性

### A08: Data Integrity Failures
- [H] 署名検証
- [M] CI/CD パイプラインセキュリティ

### A09: Logging & Monitoring
- [M] セキュリティイベントのログ
- [C] 機密情報のログ出力防止

### A10: SSRF
- [H][web] 外部リクエストの検証
- [H][web] 内部ネットワークアクセス制限

## Additional Checks
- [C] シークレット管理 (ハードコード禁止)
- [H] 認証トークンの適切な管理
- [M][web] レート制限の実装
