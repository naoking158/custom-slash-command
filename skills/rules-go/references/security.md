---
paths:
  - "**/*.go"
---

# Go Security Rules

## SQL Injection

### DO: Use parameterized queries

```go
// DO
row := db.QueryRow("SELECT * FROM users WHERE id = $1", userID)

// DON'T
query := fmt.Sprintf("SELECT * FROM users WHERE id = '%s'", userID)
row := db.QueryRow(query)
```

## Command Injection

### DO: Pass arguments separately to exec.Command

```go
// DO
cmd := exec.Command("git", "log", "--oneline", "-n", "10")

// DON'T
cmd := exec.Command("sh", "-c", "git log --oneline -n "+userInput)
```

## Path Traversal

### DO: Clean and validate file paths

```go
// DO
func servefile(basedir, requested string) ([]byte, error) {
    cleaned := filepath.Clean(requested)
    full := filepath.Join(basedir, cleaned)
    if !strings.HasPrefix(full, basedir) {
        return nil, errors.New("path traversal attempt")
    }
    return os.ReadFile(full)
}

// DON'T
func serveFile(basedir, requested string) ([]byte, error) {
    return os.ReadFile(filepath.Join(basedir, requested))
}
```

## Cryptography

### DO: Use crypto/rand for security-sensitive randomness

```go
// DO
import "crypto/rand"
b := make([]byte, 32)
if _, err := rand.Read(b); err != nil {
    return err
}
token := base64.URLEncoding.EncodeToString(b)

// DON'T
import "math/rand"
token := fmt.Sprintf("%d", rand.Int()) // predictable
```

## TLS / HTTPS

### DO: Enforce HTTPS and configure TLS properly

```go
// DO
srv := &http.Server{
    TLSConfig: &tls.Config{
        MinVersion: tls.VersionTLS12,
    },
}

// DON'T
tr := &http.Transport{
    TLSClientConfig: &tls.Config{InsecureSkipVerify: true},
}
```

## Input Validation

### DO: Validate and sanitize all external input

```go
// DO
func parseAge(s string) (int, error) {
    age, err := strconv.Atoi(s)
    if err != nil {
        return 0, fmt.Errorf("invalid age: %w", err)
    }
    if age < 0 || age > 150 {
        return 0, errors.New("age out of range")
    }
    return age, nil
}
```

## Sensitive Data

### DON'T: Log sensitive information

```go
// DON'T
log.Printf("user login: %s password: %s", user, password)
log.Printf("API key: %s", apiKey)

// DO
log.Printf("user login: %s", user)
log.Printf("API key: %s", mask(apiKey)) // show only last 4 chars
```

### DON'T: Include secrets in error messages

```go
// DON'T
return fmt.Errorf("auth failed for token %s", token)

// DO
return errors.New("authentication failed")
```

## Template Safety

### DO: Use html/template for user-facing HTML (XSS prevention)

```go
// DO - auto-escapes HTML
import "html/template"
tmpl := template.Must(template.New("page").Parse(`<p>{{.Name}}</p>`))

// DON'T - no escaping
import "text/template"
tmpl := template.Must(template.New("page").Parse(`<p>{{.Name}}</p>`))
```

## Timeout and Resource Limits

### DO: Set timeouts on HTTP clients and servers

```go
// DO
client := &http.Client{Timeout: 10 * time.Second}

srv := &http.Server{
    ReadTimeout:  5 * time.Second,
    WriteTimeout: 10 * time.Second,
    IdleTimeout:  120 * time.Second,
}
```

### DO: Limit request body size

```go
// DO
r.Body = http.MaxBytesReader(w, r.Body, 1<<20) // 1MB limit
```
