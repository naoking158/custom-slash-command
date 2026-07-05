---
paths:
  - "**/*.go"
---

# Go Error Handling

## Core Principles

### DO: Always check errors

Never ignore returned errors.

```go
// DO
f, err := os.Open(filename)
if err != nil {
    return fmt.Errorf("opening config: %w", err)
}
defer f.Close()

// DON'T
f, _ := os.Open(filename)
```

### DO: Wrap errors with context using %w

```go
// DO
data, err := os.ReadFile(path)
if err != nil {
    return nil, fmt.Errorf("loading config from %s: %w", path, err)
}

// DON'T - no context
if err != nil {
    return nil, err
}
```

## Sentinel Errors

### DO: Define sentinel errors for expected conditions

```go
var (
    ErrNotFound     = errors.New("not found")
    ErrUnauthorized = errors.New("unauthorized")
)
```

### DO: Check with errors.Is(), not ==

```go
// DO
if errors.Is(err, ErrNotFound) {
    http.Error(w, "not found", http.StatusNotFound)
    return
}

// DON'T - breaks if error is wrapped
if err == ErrNotFound { ... }
```

## Custom Error Types

### DO: Define custom types for rich error info, check with errors.As()

```go
type ValidationError struct {
    Field   string
    Message string
}

func (e *ValidationError) Error() string {
    return fmt.Sprintf("validation: %s: %s", e.Field, e.Message)
}

// Check with errors.As()
var valErr *ValidationError
if errors.As(err, &valErr) {
    log.Printf("field %s: %s", valErr.Field, valErr.Message)
}
```

## Error Messages

### DO: Start lowercase, no trailing punctuation

Error messages are composed via wrapping, so keep them chainable.

```go
// DO: "loading config: reading user 42: file not found"
return fmt.Errorf("reading user %d: %w", id, err)

// DON'T: "Loading config: Failed to read user 42."
return fmt.Errorf("Failed to read user %d: %w.", id, err)
```

## Panic

### DON'T: Use panic for normal error handling

Only for truly unrecoverable situations: programmer errors or initialization failures.

```go
// OK - Must* helpers for init-time panics
func MustCompileRegex(pattern string) *regexp.Regexp {
    re, err := regexp.Compile(pattern)
    if err != nil {
        panic(fmt.Sprintf("invalid regex %q: %v", pattern, err))
    }
    return re
}

// DON'T - panic for runtime errors
func GetUser(id string) *User {
    user, err := db.FindUser(id)
    if err != nil {
        panic(err) // should return error
    }
    return user
}
```

## Resource Cleanup with defer

### DO: Defer cleanup immediately after acquisition

```go
f, err := os.Open(path)
if err != nil {
    return nil, fmt.Errorf("opening file: %w", err)
}
defer f.Close()
```

### DON'T: Defer in loops

```go
// DON'T - handles accumulate until function returns
for _, path := range paths {
    f, err := os.Open(path)
    if err != nil { continue }
    defer f.Close() // won't close until function returns
}

// DO - extract to a function
for _, path := range paths {
    if err := processFile(path); err != nil {
        log.Printf("processing %s: %v", path, err)
    }
}
```

## Error Flow

### DO: Handle errors early, keep happy path unindented

```go
// DO - early return
if input == "" {
    return nil, errors.New("empty input")
}
data, err := fetch(input)
if err != nil {
    return nil, fmt.Errorf("fetching: %w", err)
}
return transform(data)

// DON'T - deeply nested
if input != "" {
    data, err := fetch(input)
    if err == nil {
        return transform(data)
    }
}
```

### DON'T: Use type assertions for errors, use errors.As()

```go
// DON'T
if e, ok := err.(*os.PathError); ok { ... }

// DO
var pathErr *os.PathError
if errors.As(err, &pathErr) { ... }
```
