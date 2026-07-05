---
paths:
  - "**/*.go"
---

# Go Style & Naming Conventions

## Naming Rules

### DO: Use MixedCaps / mixedCaps

Go uses `MixedCaps` (exported) and `mixedCaps` (unexported). Never use underscores.

```go
// DO
var maxRetryCount int
type HTTPClient struct{}

// DON'T
var max_retry_count int
type Http_Client struct{}
```

### DO: Keep package names short, lowercase, singular

Avoid generic names like `util`, `common`, `misc`.

```go
// DO: httputil, auth, user
// DON'T: httpUtils, common_helpers, users
```

### DON'T: Stutter with package name in exported identifiers

```go
// DO                    // DON'T
http.Server              http.HTTPServer
auth.Token               auth.AuthToken
```

### DO: Use short, consistent receiver names (1-2 chars)

Never use `self` or `this`. Use consistent abbreviation across all methods of a type.

```go
// DO
func (s *Server) Start() error { ... }
func (s *Server) Stop() error { ... }

// DON'T
func (self *Server) Start() error { ... }
```

### DO: Name single-method interfaces with -er suffix

```go
type Reader interface { Read(p []byte) (n int, err error) }
type Stringer interface { String() string }

// Multi-method: use descriptive nouns
type FileSystem interface {
    Open(name string) (File, error)
    Stat(name string) (FileInfo, error)
}
```

### DO: Use ALL CAPS for acronyms

```go
// DO: userID, HTTPServer, ParseURL, XMLParser
// DON'T: odEd, HttpServer, ParseUrl
```

## Formatting

### DO: Use gofmt and goimports

Always format with `gofmt`. Use `goimports` to manage imports.

### DO: Group imports in standard order

```go
import (
    // 1. Standard library
    "context"
    "fmt"

    // 2. Third-party
    "github.com/gorilla/mux"

    // 3. Internal
    "github.com/yourorg/project/internal/auth"
)
```

## File Organization

### DO: One package per directory

Package name should match directory name.

### DO: Name files after their primary type or responsibility

```
user/
  user.go          // User type and core methods
  store.go         // Store interface
  handler.go       // HTTP handlers
  handler_test.go
```

### DON'T: Create overly generic files

Avoid `utils.go`, `helpers.go`, `common.go`. Place functions near where they are used.

## Declarations

### DO: Use := inside functions, var at package level

```go
// Inside functions
s := &Server{}
err := doSomething()

// Package level
var defaultTimeout = 30 * time.Second
```

### DO: Use iota for related constants

```go
type Status int
const (
    StatusPending Status = iota
    StatusActive
    StatusInactive
)
```
