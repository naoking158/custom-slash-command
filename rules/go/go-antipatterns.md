---
paths:
  - "**/*.go"
---

# Go Anti-Patterns

## init() Abuse

### DON'T: Use init() for complex initialization

`init()` runs implicitly, makes testing difficult, and creates hidden dependencies.

```go
// DON'T
var db *sql.DB
func init() {
    var err error
    db, err = sql.Open("postgres", os.Getenv("DATABASE_URL"))
    if err != nil {
        log.Fatal(err)
    }
}

// DO - explicit initialization
func NewDB(dsn string) (*sql.DB, error) {
    return sql.Open("postgres", dsn)
}
```

**Acceptable uses of init():** registering drivers/codecs, setting simple package-level defaults.

## Global Mutable State

### DON'T: Rely on package-level mutable variables

```go
// DON'T
var logger *Logger
var config *Config

func HandleRequest(w http.ResponseWriter, r *http.Request) {
    logger.Info(config.Prefix + ": handling request")
}

// DO - inject dependencies
type Handler struct {
    logger *Logger
    config *Config
}

func (h *Handler) HandleRequest(w http.ResponseWriter, r *http.Request) {
    h.logger.Info(h.config.Prefix + ": handling request")
}
```

## interface{} / any Overuse

### DON'T: Use interface{} when concrete types or generics work

```go
// DON'T
func Process(data interface{}) interface{} {
    m := data.(map[string]interface{})
    return m["result"]
}

// DO - use concrete types
func Process(data *Request) *Response { ... }

// DO - use generics when needed
func Map[T, U any](items []T, fn func(T) U) []U { ... }
```

## Swallowed Errors

### DON'T: Ignore errors silently

```go
// DON'T
result, _ := riskyOperation()
json.Unmarshal(data, &v) // error ignored

// DO
result, err := riskyOperation()
if err != nil {
    return fmt.Errorf("risky operation: %w", err)
}
```

## Channel Misuse

### DON'T: Use channels when a mutex is simpler

```go
// DON'T - overengineered
type Cache struct {
    setCh chan setReq
    getCh chan getReq
}

// DO - straightforward
type Cache struct {
    mu    sync.RWMutex
    items map[string]any
}

func (c *Cache) Get(key string) (any, bool) {
    c.mu.RLock()
    defer c.mu.RUnlock()
    v, ok := c.items[key]
    return v, ok
}
```

## God Functions / Packages

### DON'T: Write functions or packages that do too much

```go
// DON'T - 500-line function
func ProcessOrder(ctx context.Context, order *Order) error {
    // validate... 50 lines
    // check inventory... 80 lines
    // charge payment... 60 lines
    // send notification... 40 lines
    // update database... 70 lines
}

// DO - break into focused functions
func ProcessOrder(ctx context.Context, order *Order) error {
    if err := validateOrder(order); err != nil {
        return fmt.Errorf("validation: %w", err)
    }
    if err := checkInventory(ctx, order); err != nil {
        return fmt.Errorf("inventory: %w", err)
    }
    // ...
}
```

## Context Misuse

### DON'T: Use context.Background() everywhere

```go
// DON'T
func handleRequest(w http.ResponseWriter, r *http.Request) {
    result, err := db.Query(context.Background(), query)
    // ignores request cancellation
}

// DO - propagate the request context
func handleRequest(w http.ResponseWriter, r *http.Request) {
    result, err := db.Query(r.Context(), query)
}
```

### DON'T: Store request-scoped values in context excessively

Use context for deadlines, cancellation, and cross-cutting request-scoped data (trace IDs, auth). Don't use it as a replacement for function parameters.

## Unnecessary else

### DO: Use early return instead of else

```go
// DO
func validate(s string) error {
    if s == "" {
        return errors.New("empty string")
    }
    return nil
}

// DON'T
func validate(s string) error {
    if s == "" {
        return errors.New("empty string")
    } else {
        return nil
    }
}
```

## goto

### DON'T: Use goto

Go supports `goto` but it almost never improves readability. Use loops, functions, or named returns instead.
