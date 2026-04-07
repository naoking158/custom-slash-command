---
paths:
  - "**/*.go"
---

# Go Concurrency

## Goroutine Lifecycle

### DO: Use context.Context to control goroutine lifetime

Every goroutine must have a clear shutdown path. Use `context.Context` for cancellation.

```go
// DO
func worker(ctx context.Context, jobs <-chan Job) {
    for {
        select {
        case <-ctx.Done():
            return
        case job := <-jobs:
            process(job)
        }
    }
}
```

### DON'T: Launch goroutines without shutdown control

```go
// DON'T - goroutine leak
go func() {
    for msg := range ch {
        handle(msg)
    }
}()
// Who closes ch? Who waits for this goroutine?
```

## Channel Patterns

### DO: Specify channel direction in function signatures

```go
// DO
func producer(out chan<- int) { ... }
func consumer(in <-chan int) { ... }

// DON'T
func producer(out chan int) { ... }
```

### DO: Use select with context.Done()

```go
select {
case result := <-resultCh:
    return result, nil
case <-ctx.Done():
    return nil, ctx.Err()
}
```

## Synchronization

### DO: Use sync.WaitGroup for fan-out

```go
var wg sync.WaitGroup
for _, item := range items {
    wg.Add(1)
    go func() {
        defer wg.Done()
        process(item)
    }()
}
wg.Wait()
```

### DO: Use errgroup for concurrent operations with error handling

```go
g, ctx := errgroup.WithContext(ctx)
for _, url := range urls {
    g.Go(func() error {
        return fetch(ctx, url)
    })
}
if err := g.Wait(); err != nil {
    return fmt.Errorf("fetching urls: %w", err)
}
```

### DO: Choose sync.Mutex vs sync.RWMutex appropriately

```go
// Use Mutex for exclusive access
var mu sync.Mutex
mu.Lock()
defer mu.Unlock()

// Use RWMutex when reads far outnumber writes
var rw sync.RWMutex
rw.RLock()         // multiple readers OK
defer rw.RUnlock()
```

## Data Race Prevention

### DO: Run tests with -race flag

```bash
go test -race ./...
```

### DON'T: Share mutable state without synchronization

```go
// DON'T
var count int
go func() { count++ }()
go func() { count++ }()

// DO - use atomic or mutex
var count atomic.Int64
go func() { count.Add(1) }()
go func() { count.Add(1) }()
```

## Common Pitfalls

### DON'T: Use channels when a mutex suffices

Channels are for communication. Mutexes are for protecting shared state. Don't overcomplicate with channels when a simple mutex works.

```go
// DO - simple shared counter
type Counter struct {
    mu    sync.Mutex
    count int
}
func (c *Counter) Inc() {
    c.mu.Lock()
    defer c.mu.Unlock()
    c.count++
}

// DON'T - overengineered channel-based counter
type Counter struct {
    incCh chan struct{}
    getCh chan int
}
```

### DON'T: Forget to close channels when done sending

```go
// DO
func generate(ctx context.Context) <-chan int {
    ch := make(chan int)
    go func() {
        defer close(ch)
        for i := 0; ; i++ {
            select {
            case ch <- i:
            case <-ctx.Done():
                return
            }
        }
    }()
    return ch
}
```

### DO: Prefer buffered channels when producer/consumer rates differ

```go
// Buffered channel to reduce blocking
jobs := make(chan Job, workerCount)
```
