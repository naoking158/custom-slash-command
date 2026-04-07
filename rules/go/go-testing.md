---
paths:
  - "**/*.go"
---

# Go Testing Best Practices

## Table-Driven Tests

### DO: Use table-driven tests for multiple cases

```go
func TestParseSize(t *testing.T) {
    tests := []struct {
        name    string
        input   string
        want    int64
        wantErr bool
    }{
        {name: "bytes", input: "100B", want: 100},
        {name: "kilobytes", input: "1KB", want: 1024},
        {name: "invalid", input: "abc", wantErr: true},
        {name: "empty", input: "", wantErr: true},
    }
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            got, err := ParseSize(tt.input)
            if (err != nil) != tt.wantErr {
                t.Fatalf("ParseSize(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
            }
            if got != tt.want {
                t.Errorf("ParseSize(%q) = %d, want %d", tt.input, got, tt.want)
            }
        })
    }
}
```

## Subtests and Parallel

### DO: Use t.Run() for subtests

Subtests enable selective test execution (`go test -run TestFoo/subtest`) and clearer failure output.

### DO: Use t.Parallel() when tests are independent

```go
func TestAPI(t *testing.T) {
    t.Parallel()
    tests := []struct{ name string; /* ... */ }{...}
    for _, tt := range tests {
        t.Run(tt.name, func(t *testing.T) {
            t.Parallel()
            // test logic
        })
    }
}
```

## Test Helpers

### DO: Use t.Helper() in test helper functions

```go
func assertNoError(t *testing.T, err error) {
    t.Helper() // points failure to caller's line
    if err != nil {
        t.Fatalf("unexpected error: %v", err)
    }
}

func createTestUser(t *testing.T, db *DB) *User {
    t.Helper()
    u := &User{Name: "test"}
    if err := db.Create(u); err != nil {
        t.Fatalf("creating test user: %v", err)
    }
    return u
}
```

## Test Data

### DO: Use testdata/ directory for test fixtures

Files in `testdata/` are ignored by the Go toolchain.

```go
func TestProcess(t *testing.T) {
    input, err := os.ReadFile("testdata/input.json")
    if err != nil {
        t.Fatal(err)
    }
    // ...
}
```

### DO: Use golden files for complex output validation

```go
func TestRender(t *testing.T) {
    got := render(input)
    golden := filepath.Join("testdata", t.Name()+".golden")
    if *update {
        os.WriteFile(golden, got, 0o644)
    }
    want, _ := os.ReadFile(golden)
    if !bytes.Equal(got, want) {
        t.Errorf("output mismatch; run with -update to refresh golden files")
    }
}
```

## Mocking

### DO: Use interface-based dependency injection

```go
// Define interface in consumer
type Notifier interface {
    Send(ctx context.Context, msg string) error
}

// Mock for tests
type mockNotifier struct {
    sent []string
}

func (m *mockNotifier) Send(_ context.Context, msg string) error {
    m.sent = append(m.sent, msg)
    return nil
}

func TestService(t *testing.T) {
    mock := &mockNotifier{}
    svc := NewService(mock)
    svc.Process()
    if len(mock.sent) != 1 {
        t.Errorf("expected 1 notification, got %d", len(mock.sent))
    }
}
```

## Standard Test Utilities

### DO: Use httptest for HTTP handler tests

```go
func TestHandler(t *testing.T) {
    req := httptest.NewRequest("GET", "/users/1", nil)
    w := httptest.NewRecorder()
    handler.ServeHTTP(w, req)
    if w.Code != http.StatusOK {
        t.Errorf("status = %d, want %d", w.Code, http.StatusOK)
    }
}
```

### DO: Use testing/fstest for filesystem tests

```go
func TestReadConfig(t *testing.T) {
    fs := fstest.MapFS{
        "config.yaml": &fstest.MapFile{Data: []byte("key: value")},
    }
    cfg, err := ReadConfig(fs, "config.yaml")
    // ...
}
```

## Common Mistakes

### DON'T: Use assert libraries when standard testing suffices

The standard `testing` package with clear error messages is preferred in Go.

### DON'T: Test unexported functions directly

Test through the public API. If unexported logic needs direct testing, consider if it should be exported or restructured.

### DON'T: Skip error checks in tests

```go
// DON'T
result, _ := Parse(input)

// DO
result, err := Parse(input)
if err != nil {
    t.Fatal(err)
}
```
