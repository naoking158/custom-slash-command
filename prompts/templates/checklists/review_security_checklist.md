# Security Review Checklist

## OWASP Top 10 (2021)

### A01: Broken Access Control
- [ ] 認可チェックの実装
- [ ] CORS 設定の適切性
- [ ] ディレクトリトラバーサル対策

### A02: Cryptographic Failures
- [ ] 機密データの暗号化
- [ ] 適切なハッシュアルゴリズム使用
- [ ] TLS 強制

### A03: Injection
- [ ] SQLインジェクション対策 (パラメータ化クエリ)
- [ ] XSS対策 (出力エスケープ)
- [ ] コマンドインジェクション対策

### A04: Insecure Design
- [ ] 脅威モデリング実施
- [ ] セキュアなデフォルト設定

### A05: Security Misconfiguration
- [ ] 不要な機能の無効化
- [ ] 適切なエラーメッセージ
- [ ] セキュリティヘッダー設定

### A06: Vulnerable Components
- [ ] 依存ライブラリの脆弱性チェック
- [ ] 最新パッチ適用状況

### A07: Authentication Failures
- [ ] 強力なパスワードポリシー
- [ ] ブルートフォース対策
- [ ] セッション管理の適切性

### A08: Data Integrity Failures
- [ ] 署名検証
- [ ] CI/CD パイプラインセキュリティ

### A09: Logging & Monitoring
- [ ] セキュリティイベントのログ
- [ ] 機密情報のログ出力防止

### A10: SSRF
- [ ] 外部リクエストの検証
- [ ] 内部ネットワークアクセス制限

## Additional Checks
- [ ] シークレット管理 (ハードコード禁止)
- [ ] 認証トークンの適切な管理
- [ ] レート制限の実装
