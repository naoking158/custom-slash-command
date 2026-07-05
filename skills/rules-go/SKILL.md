---
description: "Coding rules for Go: error handling, concurrency, interfaces, testing, performance, security, style/naming, antipatterns. Loaded automatically when working with Go files."
user-invocable: false
paths: ["**/*.go", "**/go.mod"]
---

# Go Coding Rules

When editing Go code, consult the relevant reference before writing non-trivial code; follow these rules over general habits.

## INDEX

- `references/antipatterns.md` — Patterns to avoid: init() abuse, global mutable state, interface{}/any overuse, swallowed errors, channels-where-a-mutex-suffices, god functions/packages, context misuse, unnecessary else, goto.
- `references/concurrency.md` — Goroutine lifecycle control via context, channel direction and select patterns, WaitGroup/errgroup/mutex choice, data race prevention with -race, channel closing and buffering pitfalls.
- `references/error-handling.md` — Always check and wrap errors with %w, sentinel errors with errors.Is, custom error types with errors.As, error message style, panic avoidance, defer-based cleanup, early-return error flow.
- `references/interfaces.md` — Small (1-3 method) interfaces defined on the consumer side, accept-interfaces/return-structs, composition via embedding, avoiding single-implementation abstractions, implementing standard library interfaces.
- `references/performance.md` — Profile before optimizing; strings.Builder, slice/map pre-allocation, sync.Pool, pointer vs value receivers, hot-loop allocation, bufio for I/O, range copy semantics, benchmarking.
- `references/security.md` — SQL/command injection prevention, path traversal validation, crypto/rand, TLS configuration, input validation, keeping secrets out of logs and errors, html/template for XSS, HTTP timeouts and resource limits.
- `references/style-naming.md` — MixedCaps naming, package/receiver/interface naming conventions, acronym casing, gofmt/goimports, import grouping, file organization, := vs var, iota constants.
- `references/testing.md` — Table-driven tests, t.Run/t.Parallel subtests, t.Helper, testdata/ and golden files, interface-based mocking, httptest/fstest, avoiding assert libraries and testing unexported functions.
